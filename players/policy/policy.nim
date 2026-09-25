## Numeric and Jev policies over the ordinary Infinite Blocks player socket.

import std/[json, os, random, strutils, times]
import bitworld/spriteprotocol
import curly, whisky

const Actions = ["watch", "left", "right", "down", "rotate"]

proc inputBlob(mask: uint8): string =
  blobFromBytes([0x84'u8, mask and 0x7f'u8])

proc chooseNumeric(request: JsonNode, session: string): int =
  let endpoint = getEnv("PLAYER_NUMERIC_URL")
  var headers: HttpHeaders
  headers["content-type"] = "application/json"
  let key = getEnv("PLAYER_NUMERIC_KEY")
  if key.len > 0: headers["authorization"] = "Bearer " & key
  let body = %*{"session": session, "seat": request["seat"],
    "decision_id": request["tick"], "values": request["values"],
    "action_mask": [true, true, true, true, true]}
  let response = newCurly().post(endpoint, headers, $body, 5)
  if response.code < 200 or response.code >= 300:
    raise newException(ValueError, "numeric policy HTTP " & $response.code)
  let actions = parseJson(response.body)["actions"]
  if actions.len != 1:
    raise newException(ValueError, "numeric policy returned wrong action count")
  result = actions[0].getInt()
  if result < 0 or result >= Actions.len:
    raise newException(ValueError, "numeric policy returned illegal action")

proc chooseJev(request: JsonNode): int =
  let sidecar = getEnv("AWS_ENDPOINT_URL_BEDROCK_RUNTIME").strip()
  let capture = getEnv("METTA_CAPTURE_URL").strip()
  var endpoint, model, key: string
  if sidecar.len > 0:
    endpoint = sidecar
    model = "typesafe/jev-1.13"
  elif capture.len > 0:
    endpoint = capture
    model = getEnv("METTA_CAPTURE_MODEL", "jev-latest")
    key = getEnv("METTA_CAPTURE_KEY").strip()
  else:
    endpoint = getEnv("TYPESAFE_BASE_URL", "https://api.typesafe.ai")
    model = getEnv("TYPESAFE_DEFAULT_MODEL", "jev-latest")
    key = getEnv("TYPESAFE_API_KEY").strip()
  if endpoint.len == 0 or (sidecar.len == 0 and key.len == 0):
    raise newException(ValueError, "Infinite Blocks Jev has no model transport")
  var headers: HttpHeaders
  headers["content-type"] = "application/json"
  if key.len > 0:
    headers["authorization"] = "Bearer " & key
  else:
    headers["x-coworld-player-slot"] = $request["seat"].getInt()
  var criteria = newJObject()
  for index, action in Actions:
    criteria[$index] = %("Use " & action & " for the next five game ticks")
  let body = %*{"model": model,
    "state": "Choose one five-tick movement action for the falling piece. " &
      "The column heights and local 21x21 board are public. " & $request,
    "questions": {"action": {"type": "choice",
      "instructions": "Choose one action from the catalog.",
      "criteria": criteria}}}
  let response = newCurly().post(endpoint.strip(chars = {'/'},
    leading = false) & "/v1/systemone", headers, $body, 10)
  if response.code < 200 or response.code >= 300:
    raise newException(ValueError, "Jev HTTP " & $response.code)
  let answer = parseJson(response.body)["answers"]["action"]
  let probabilities = answer["probabilities"]
  if answer["type"].getStr() != "choice" or
      probabilities.len != Actions.len or
      answer["confidence"].getFloat() < 0 or
      answer["confidence"].getFloat() > 1:
    raise newException(ValueError, "Jev returned the wrong action catalog")
  var best = -1.0
  var total = 0.0
  for index in 0 ..< Actions.len:
    let probability = probabilities[$index].getFloat()
    if probability < 0 or probability > 1:
      raise newException(ValueError, "Jev probability outside [0, 1]")
    total += probability
    if probability > best:
      best = probability
      result = index
  if abs(total - 1) > Actions.len.float * 0.005 + 1e-6:
    raise newException(ValueError, "Jev probabilities do not sum to one")

when isMainModule:
  let numeric = getEnv("PLAYER_NUMERIC_URL").len > 0
  let jev = getEnv("PLAYER_JEV") == "1"
  if numeric == jev:
    quit("Choose exactly one policy mode", 1)
  let url = getEnv("COGAMES_ENGINE_WS_URL")
  if url.len == 0:
    quit("COGAMES_ENGINE_WS_URL is required", 1)
  randomize()
  let session = "infinite-blocks:" & $getCurrentProcessId() & ":" &
    $getTime().toUnix() & ":" & $rand(high(int))
  let policyUrl = url & (if '?' in url: "&" else: "?") &
    "policy_observations=1"
  let socket = newWebSocket(policyUrl)
  var lastAction = "watch"
  while true:
    let received = socket.receiveMessage()
    if received.isNone: break
    let message = received.get()
    case message.kind
    of Ping: socket.send(message.data, Pong)
    of TextMessage:
      let request = parseJson(message.data)
      if request["type"].getStr() == "final": break
      if request["type"].getStr() != "decision": continue
      doAssert request["values"].len == 615
      doAssert request["actions"].len == Actions.len
      for index, action in Actions:
        doAssert request["actions"][index]["action"].getStr() == action
      socket.send(inputBlob(0), BinaryMessage)
      let index = if numeric: chooseNumeric(request, session)
        else: chooseJev(request)
      lastAction = Actions[index]
      let mask = case lastAction
        of "left": ButtonLeft
        of "right": ButtonRight
        of "down": ButtonDown
        of "rotate": ButtonA
        else: 0'u8
      socket.send(inputBlob(mask), BinaryMessage)
    of BinaryMessage, Pong: discard
