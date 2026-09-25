## JSONL decision bridge over the maintained Infinite Blocks simulator.

import std/[hashes, json, os, strutils]
import bitworld/spriteprotocol
import infinite_blocks

const Seats = 6
const ActionTicks = 5
const Actions = ["watch", "left", "right", "down", "rotate"]

setCurrentDir(paramStr(1))

var
  game: SimServer
  horizon: int
  seat: int
  decisionId: int
  selected: array[Seats, string]
  previousMasks: array[Seats, uint8]

proc currentView(): JsonNode = game.policyObservation(seat, horizon)

proc currentDecision(): JsonNode =
  let view = currentView()
  %*{"kind": "decision", "game": "infinite_blocks",
    "decision_id": decisionId, "seat": seat, "engine_seat": seat,
    "turn": game.tickCount, "semantic_view": view,
    "inbox": [], "messages": [{"role": "user", "content": $view}],
    "speech_messages": [],
    "action_schema": {"type": "object", "additionalProperties": false,
      "properties": {"action": {"type": "string", "enum": Actions}},
      "required": ["action"]},
    "typed_question": newJNull()}

proc reset(request: JsonNode): JsonNode =
  doAssert request["players"].getInt() == Seats
  horizon = parseInt(getEnv("INFINITE_BLOCKS_TRAINING_TICKS", "300"))
  doAssert horizon > 1
  let seed = int(hash(request["seed"].getStr()) and hash(high(int)))
  game = initSimServer(seed)
  for index in 0 ..< Seats:
    doAssert game.addPlayer("training-" & $index, index) == index
  game.step(newSeq[InputState](Seats))
  seat = 0
  decisionId = 0
  for index in 0 ..< Seats:
    selected[index] = "watch"
    previousMasks[index] = 0
  currentDecision()

proc step(request: JsonNode): JsonNode =
  if request["decision_id"].getInt() != decisionId:
    return %*{"kind": "rejected", "reason": "stale decision"}
  let action = parseJson(request["response"].getStr())
  if action.kind != JObject or action["action"].getStr() notin Actions:
    return %*{"kind": "rejected", "reason": "action outside catalog"}
  selected[seat] = action["action"].getStr()
  inc decisionId
  if seat < Seats - 1:
    inc seat
    return %*{"kind": "accepted", "action": action,
      "observation": currentDecision()}
  for repeat in 0 ..< min(ActionTicks, horizon - game.tickCount):
    var inputs = newSeq[InputState](Seats)
    for index in 0 ..< Seats:
      let mask = case selected[index]
        of "left": ButtonLeft
        of "right": ButtonRight
        of "down": ButtonDown
        of "rotate": (if repeat == 0: ButtonA else: 0'u8)
        else: 0'u8
      inputs[index] = decodeInputMask(mask)
      inputs[index].attack = (mask and ButtonA) != 0 and
        (previousMasks[index] and ButtonA) == 0
      previousMasks[index] = mask
    game.step(inputs)
  if game.tickCount >= horizon:
    let results = parseJson(game.playerResultsJson(Seats))
    var scores = newJObject()
    for index in 0 ..< Seats:
      scores[$index] = results["scores"][index]
    return %*{"kind": "accepted", "action": action,
      "observation": {"kind": "terminal", "scores": scores}}
  seat = 0
  %*{"kind": "accepted", "action": action,
    "observation": currentDecision()}

when isMainModule:
  for line in stdin.lines:
    let request = parseJson(line)
    let response = case request["kind"].getStr()
      of "reset": reset(request)
      of "encode": %*{"decision_id": decisionId,
        "values": currentView()["values"],
        "actions": currentView()["actions"]}
      of "teacher": %*{"response": "{\"action\":\"watch\"}"}
      of "step": step(request)
      else: raise newException(ValueError, "unknown command")
    stdout.writeLine($response)
    stdout.flushFile()
