# Infinite Blocks

Multiplayer Coworld falling-blocks game where players stack pieces, clear
lines, and compete for score on one shared board.

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
