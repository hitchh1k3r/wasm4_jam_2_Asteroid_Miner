package main

import w4 "wasm4"

@export
start :: proc "c" () {
  context = {}
}

@export
update :: proc "c" () {
  context = {}

  w4.DRAW_COLORS^ = 0x0004
  w4.text("Hello World", 10, 10)
}
