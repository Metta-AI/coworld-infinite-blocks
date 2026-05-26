version     = "0.1.0"
author      = "treeform@softmax.com"
description = "Infinite Blocks Coworld game."
license     = "MIT"

srcDir = "src"
bin = @["infinite_blocks"]

switch("threads", "on")
switch("mm", "orc")

requires "nim >= 2.2.4"
requires "bitworld >= 0.1.0"
requires "mummy >= 0.4.7"
requires "pixie"
requires "silky >= 0.0.2"
requires "supersnappy >= 2.1.3"
requires "whisky >= 0.1.3"
requires "windy >= 0.4.4"
