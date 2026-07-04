import
  bitworld/replays as replayCodec

type
  ReplayPlayer* = object
    data*: ReplayData
    joinIndex*: int
    leaveIndex*: int
    inputIndex*: int
    chatIndex*: int
    hashIndex*: int
    masks*: seq[uint8]
    prevMasks*: seq[uint8]
    playing*: bool
    looping*: bool
    speedIndex*: int
    hashValidationFailed*: bool
    hashMismatchTick*: int

const
  PlaybackSpeeds* = [1, 2, 3, 4, 8, 16]
  ReplayKeyframeTicks* = 100
  ReplayFps* = 30
  InfiniteBlocksGameName* = "infinite_blocks"
  InfiniteBlocksGameVersion* = "0.1.0"
  InfiniteBlocksReplayMagic = "INFBLOCK"
  InfiniteBlocksReplayFormatVersion = 1'u16
  InfiniteBlocksReplaySpec = ReplaySpec(
    magic: InfiniteBlocksReplayMagic,
    formatVersion: InfiniteBlocksReplayFormatVersion,
    gameName: InfiniteBlocksGameName,
    gameVersion: InfiniteBlocksGameVersion,
    joinKind: rjkNameSlotToken,
    allowChat: true,
    allowCompressed: true,
    hashOrder: rhoStop
  )

export replayCodec

proc tickTime*(tick: int): uint32 =
  ## Converts a simulation tick to replay milliseconds.
  replayCodec.tickTime(tick, ReplayFps)

proc openReplayWriter*(path: string, configJson: string): ReplayWriter =
  ## Opens a replay file and writes the header.
  replayCodec.openReplayWriter(path, configJson, InfiniteBlocksReplaySpec)

proc parseReplayBytes*(bytes: string): ReplayData =
  ## Parses one replay file buffer into memory.
  replayCodec.parseReplayBytes(bytes, InfiniteBlocksReplaySpec)

proc loadReplay*(path: string): ReplayData =
  ## Loads a replay file into memory.
  replayCodec.loadReplay(path, InfiniteBlocksReplaySpec)

proc writeInputMaskChange*(
  writer: var ReplayWriter,
  time: uint32,
  playerIndex: int,
  mask: uint8
) =
  ## Writes one replay input event when a player's held mask changes.
  if playerIndex < 0 or playerIndex >= writer.lastMasks.len:
    return
  if writer.lastMasks[playerIndex] == mask:
    return
  writer.writeInput(ReplayInput(
    time: time,
    player: uint8(playerIndex),
    keys: mask
  ))
  writer.lastMasks[playerIndex] = mask

proc initReplayPlayer*(data: ReplayData): ReplayPlayer =
  ## Builds replay playback state.
  result.data = data
  result.masks = @[]
  result.prevMasks = @[]
  result.playing = true
  result.looping = true
  result.speedIndex = 0
  result.hashMismatchTick = -1

proc replaySpeed*(replay: ReplayPlayer): int =
  ## Returns the current integer replay speed.
  PlaybackSpeeds[clamp(replay.speedIndex, 0, PlaybackSpeeds.high)]

proc replayMaxTick*(replay: ReplayPlayer): int =
  ## Returns the final tick available in the replay.
  if replay.data.hashes.len == 0:
    return 0
  int(replay.data.hashes[^1].tick)

proc resetReplay*(replay: var ReplayPlayer) =
  ## Resets replay playback cursors.
  replay.joinIndex = 0
  replay.leaveIndex = 0
  replay.inputIndex = 0
  replay.chatIndex = 0
  replay.hashIndex = 0
  replay.hashValidationFailed = false
  replay.hashMismatchTick = -1
  replay.masks = @[]
  replay.prevMasks = @[]

proc ensureReplayPlayer*(replay: var ReplayPlayer, player: int) =
  ## Expands replay input tables for one player.
  while replay.masks.len <= player:
    replay.masks.add(0)
  while replay.prevMasks.len <= player:
    replay.prevMasks.add(0)
