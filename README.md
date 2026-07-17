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
