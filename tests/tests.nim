import std/os

{.warning[UnusedImport]: off.}
import infinite_blocks
{.warning[UnusedImport]: on.}

echo "Testing Infinite Blocks"
doAssert fileExists("coworld_manifest.json"), "manifest should exist"
doAssert fileExists("data/sprites.aseprite"), "sprites should exist"
doAssert fileExists("src/infinite_blocks.nim"), "game source should exist"
