package main

import w4 "wasm4"

time : f32

@export
start :: proc "c" () {
  context = {}
}

@export
update :: proc "c" () {
  context = {}

  time += 1.0/60.0

  w4.DRAW_COLORS^ = 0x0004
  w4.text(f32_to_str(time), 10, 10)
}
