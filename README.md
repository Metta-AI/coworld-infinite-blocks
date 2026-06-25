# Infinite Blocks

<!-- COWORLD-REPO-STATUS:START -->
> [!NOTE]
> Coworld repo status: **incomplete** (`coworld-incomplete`).
> Canonical repository: `Metta-AI/coworld-infinite-blocks`.
> Manifest path: `coworld_manifest.json`.
> Build path: `Dockerfile`
> Certification: blocked until `uv run coworld certify coworld_manifest.json` passes and the result is recorded.
>
> Missing pieces:
> - [ ] Validate the root concrete manifest against the current Coworld schema.
> - [ ] Run `uv run coworld certify coworld_manifest.json` with the bundled players.
> - [ ] Switch the repo topic to `coworld-complete` after certification passes.
<!-- COWORLD-REPO-STATUS:END -->


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
