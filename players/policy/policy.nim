## Numeric policy over the ordinary Infinite Blocks player socket.

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

when isMainModule:
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
      let index = chooseNumeric(request, session)
      lastAction = Actions[index]
      let mask = case lastAction
        of "left": ButtonLeft
        of "right": ButtonRight
        of "down": ButtonDown
        of "rotate": ButtonA
        else: 0'u8
      socket.send(inputBlob(mask), BinaryMessage)
    of BinaryMessage, Pong: discard
