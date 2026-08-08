import std/[json, os, sequtils]

{.warning[UnusedImport]: off.}
import infinite_blocks, replays, bitworld/spriteprotocol
{.warning[UnusedImport]: on.}

echo "Testing Infinite Blocks"
doAssert fileExists("coworld_manifest_template.json"), "manifest template should exist"
doAssert fileExists("data/sprites.aseprite"), "sprites should exist"
doAssert fileExists("src/infinite_blocks.nim"), "game source should exist"

echo "Testing result attribution follows authenticated slots"
block:
  var sim = initSimServer(17)
  doAssert sim.addPlayer("slot-two", 2) == 0,
    "the first connection should retain internal player index zero"
  doAssert sim.addPlayer("slot-zero", 0) == 1,
    "the second connection should retain internal player index one"
  let results = parseJson(sim.playerResultsJson(3))
  doAssert results["names"].getElems().mapIt(it.getStr()) ==
    @["slot-zero", "", "slot-two"],
    "result names should use authenticated slot order"
  doAssert results["alive"].getElems().mapIt(it.getBool()) ==
    @[true, false, true],
    "unjoined slots should remain explicit and inactive"
  sim.removePlayerAt(0)
  let afterDisconnect = parseJson(sim.playerResultsJson(3))
  doAssert afterDisconnect["names"].getElems().mapIt(it.getStr()) ==
    @["slot-zero", "", "slot-two"],
    "a disconnected player's final result should remain in its slot"
  doAssert afterDisconnect["alive"].getElems().mapIt(it.getBool()) ==
    @[true, false, false],
    "a disconnected player's retained result should be marked inactive"

echo "Testing uncredentialed result fallback preserves arrival order and liveness"
block:
  var sim = initSimServer(23)
  doAssert sim.addPlayer("first") == 0
  doAssert sim.addPlayer("second") == 1
  sim.removePlayerAt(1)
  let results = parseJson(sim.playerResultsJson(0))
  doAssert results["names"].getElems().mapIt(it.getStr()) ==
    @["first", "second"],
    "fallback results should retain original websocket arrival order"
  doAssert results["alive"].getElems().mapIt(it.getBool()) ==
    @[true, false],
    "fallback results should distinguish connected and departed players"

echo "Testing replay round trip"
block:
  const
    TestSeed = 4242
    TestTicks = 200
  let replayPath = getTempDir() / "infinite-blocks-test-replay.bitreplay"

  # Record: drive a live-style sim with scripted inputs and a chat,
  # reproducing the live loop's rising-edge attack detection.
  var
    recSim = initSimServer(TestSeed)
    writer = openReplayWriter(replayPath, $(%*{"seed": TestSeed}))
  doAssert recSim.addPlayer("alice") == 0, "alice should join first"
  writer.writeJoin(tickTime(0), 0, "alice", 0, "")
  writer.lastMasks.add(0)
  doAssert recSim.addPlayer("bob") == 1, "bob should join second"
  writer.writeJoin(tickTime(0), 1, "bob", 1, "")
  writer.lastMasks.add(0)

  var
    masks = [0'u8, 0'u8]
    previousMasks = [0'u8, 0'u8]
  for tick in 0 ..< TestTicks:
    masks[0] =
      if tick < 40:
        ButtonRight
      elif tick < 90:
        ButtonRight or ButtonDown
      elif tick < 120:
        ButtonA
      else:
        ButtonUp or ButtonLeft
    masks[1] =
      if tick mod 30 < 15:
        ButtonLeft
      else:
        ButtonDown or ButtonA
    var inputs = newSeq[InputState](2)
    for playerIndex in 0 ..< 2:
      writer.writeInputMaskChange(
        tickTime(recSim.tickCount),
        playerIndex,
        masks[playerIndex]
      )
      inputs[playerIndex] = decodeInputMask(masks[playerIndex])
      inputs[playerIndex].attack =
        (masks[playerIndex] and ButtonA) != 0 and
        (previousMasks[playerIndex] and ButtonA) == 0
      previousMasks[playerIndex] = masks[playerIndex]
    if tick == 100:
      recSim.applyPlayerChat(0, "hello bob")
      writer.writeChat(tickTime(recSim.tickCount), 0, "hello bob")
    recSim.step(inputs)
    writer.writeHash(uint32(recSim.tickCount), recSim.gameHash())
  let recordedHash = recSim.gameHash()
  writer.closeReplayWriter()

  # Play back against a fresh sim and validate every recorded hash.
  let data = loadReplay(replayPath)
  doAssert data.configJson == $(%*{"seed": TestSeed}),
    "replay config should round trip"
  doAssert data.joins.len == 2, "replay should keep both joins"
  doAssert data.chats.len == 1, "replay should keep the chat"
  doAssert data.hashes.len == TestTicks, "replay should hash every tick"
  var
    playSim = initSimServer(TestSeed)
    replay = initReplayPlayer(data)
  doAssert replay.replayMaxTick() == TestTicks, "max tick should match"
  while replay.playing and replay.hashIndex < data.hashes.len:
    replay.stepReplay(playSim)
  doAssert not replay.hashValidationFailed, "replay hashes should validate"
  doAssert playSim.gameHash() == recordedHash,
    "playback should reproduce the final game hash"
  doAssert playSim.gameHash() == data.hashes[^1].hash,
    "final hash should match the recorded stream"

  echo "Testing replay keyframe seeks"
  block:
    let keyframes = data.buildReplayKeyframes(TestSeed, interval = 100)
    doAssert keyframes.len == 3, "200 ticks should give keyframes 0/100/200"
    var
      seekSim = initSimServer(TestSeed)
      seeker = initReplayPlayer(data)
    for target in [0, 1, 42, 99, 100, 101, 155, 200, 55, 100, 7]:
      seeker.applyReplaySeek(seekSim, keyframes, target)
      doAssert not seeker.playing, "seeking should pause playback"
      doAssert seekSim.tickCount == target,
        "seek should land on tick " & $target
      if target > 0:
        doAssert seekSim.gameHash() == data.hashes[target - 1].hash,
          "seek to tick " & $target & " should match the recorded hash"
    seeker.applyReplayCommand(seekSim, keyframes, ' ')
    doAssert seeker.playing, "space should resume playback"
    seeker.applyReplayCommand(seekSim, keyframes, '8')
    doAssert seeker.replaySpeed() == 8, "speed 8x should apply"
    seeker.applyReplayCommand(seekSim, keyframes, 'e')
    doAssert seekSim.tickCount == 200, "end command should seek to the end"
  removeFile(replayPath)
