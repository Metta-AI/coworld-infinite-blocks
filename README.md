# Infinite Blocks

Multiplayer Coworld falling-blocks game where players stack pieces, clear
lines, and compete for score on one shared board.

## Coworld package

This repository owns the Coworld manifest template and every image build declared by it:

```bash
coworld build --version 0.1.5
coworld certify dist/coworld_manifest.json
coworld upload-coworld dist/coworld_manifest.json
```

## Running

```bash
nimble build
./infinite_blocks --address:0.0.0.0 --port:8080
```

Open `http://localhost:8080/client/global` to spectate.

## Bot

The bundled Nim bot is `stacker`.

```bash
nim c --path:src players/stacker/stacker.nim
./players/stacker/stacker --address:ws://localhost:8080/player
```

## Player policy and training bridge

Policy players add `policy_observations=1` to the ordinary `/player` socket URL.
The game then sends a `decision` text message at least five ticks after the
previous decision on that socket. It contains
the acting seat's visible piece, public column
heights, a 21×21 local board, other players' public positions and scores, and
615 numeric values. Existing Sprite players keep sending input masks.

`players/policy/policy.nim` chooses one of `watch`, `left`, `right`, `down`, or
`rotate` from that message, then sends the corresponding Sprite input mask.
Set `PLAYER_NUMERIC_URL` to an `/actions` endpoint returning
`{"actions":[index]}`, or set `PLAYER_JEV=1` for Jev System One. Both modes run
in the ordinary player container. The game owns the rules, scores, and replay.
The normal certification roster keeps the `stacker` baseline.

`/bin/infinite-blocks-bridge` runs the seeded game simulator with the same
observation and five-action catalog over JSONL `reset`, `encode`, `teacher`,
and `step` commands. Pass the game checkout or packaged asset directory as
its first argument. It uses five-tick actions and the game's line-clear
scores. Set `INFINITE_BLOCKS_TRAINING_TICKS` to a positive horizon; the default
is the 300-tick certification length. The bundled teacher returns `watch` as
a protocol baseline, not a quality target. Numeric reinforcement learning can
use the bridge with a 615-value, five-action `DecisionEnvironment` codec and
`max_decisions` of at least 360 for six seats at 300 ticks. Token post-training
is a poor fit for per-frame movement.
