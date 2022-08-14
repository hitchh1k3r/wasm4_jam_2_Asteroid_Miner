package main

import "core:math"

import w4 "wasm4"

time : f32

@export
start :: proc "c" () {
  context = {}

  init_math()
  init_graphics()
}

@export
update :: proc "c" () {
  context = {}

  time += 1.0/60.0

  update_pallet()
  clear_depth_buffer()

  draw_triangle({ -0.2, 0.5*sin(0.5*time), -3 }, { -0.3, -0.2+0.5*sin(0.5*time), -2 }, {  0.3, -0.2+0.5*sin(0.5*time), -2 }, .Black, { .Pixel_Border, .No_Cull_Depth_Occluded })
  draw_triangle({ -0.9, 0.2*sin(0.5*time), -3 }, { -0.5, -0.5, -2 }, {  0.9,  0.2, -2 }, .Black, { .Pixel_Border, .No_Cull_Depth_Occluded })
  draw_triangle({  0.2, 0, -3 }, {  0.3+0.1*sin(0.5*time),  0.2+0.1*cos(0.5*time), -2 }, { -0.3,  0.4, -2 }, .Black, { .Pixel_Border, .No_Cull_Depth_Occluded })
  draw_triangle({  0.9, 0, -3 }, {  0.5,  0.1, -2 }, { -0.8+0.1*cos(0.5*time), -0.4, -2 }, .Black, { .Pixel_Border, .No_Cull_Depth_Occluded })

  draw_triangle({ -0.2, 0.5*sin(0.5*time), -3 }, { -0.3, -0.2+0.5*sin(0.5*time), -2 }, {  0.3, -0.2+0.5*sin(0.5*time), -2 }, .Gray, { .No_Cull_Depth_Occluded })
  draw_triangle({ -0.9, 0.2*sin(0.5*time), -3 }, { -0.5, -0.5, -2 }, {  0.9,  0.2, -2 }, .Gray, { .No_Cull_Depth_Occluded })
  draw_triangle({  0.2, 0, -3 }, {  0.3+0.1*sin(0.5*time),  0.2+0.1*cos(0.5*time), -2 }, { -0.3,  0.4, -2 }, .Gray, { .No_Cull_Depth_Occluded })
  draw_triangle({  0.9, 0, -3 }, {  0.5,  0.1, -2 }, { -0.8+0.1*cos(0.5*time), -0.4, -2 }, .Gray, { .No_Cull_Depth_Occluded })

  draw_triangle({ -0.2, 0.5*sin(0.5*time), -3 }, { -0.3, -0.2+0.5*sin(0.5*time), -2 }, {  0.3, -0.2+0.5*sin(0.5*time), -2 }, .Cyan, { .No_Cull_Depth_Occluded })
  draw_triangle({ -0.9, 0.2*sin(0.5*time), -3 }, { -0.5, -0.5, -2 }, {  0.9,  0.2, -2 }, .Orange, { .No_Cull_Depth_Occluded })
  draw_triangle({  0.2, 0, -3 }, {  0.3+0.1*sin(0.5*time),  0.2+0.1*cos(0.5*time), -2 }, { -0.3,  0.4, -2 }, .Green, { .No_Cull_Depth_Occluded })
  draw_triangle({  0.9, 0, -3 }, {  0.5,  0.1, -2 }, { -0.8+0.1*cos(0.5*time), -0.4, -2 }, .Yellow, { .No_Cull_Depth_Occluded })

  draw_triangle({ -3, -3, 0.5*sin(time)-2.5 }, { 10, -3, 0.5*sin(time)-2.5 }, { -3, 10, 0.5*sin(time)-2.5 }, .Gray, {  })

  for x in 0..<w4.SCREEN_SIZE {
    set_pixel(x, w4.SCREEN_SIZE/2+int((w4.SCREEN_SIZE/2 - 10)*sin(0.01*(f32(x)+50*time))), .White)
  }

  s := f32_to_str(time)
  w4.DRAW_COLORS^ = 0x0001
  w4.text(s, 11, 11)
  w4.DRAW_COLORS^ = 0x0003
  w4.text(s, 10, 10)

  w4.DRAW_COLORS^ = 0x0004
  w4.text(f32_to_str(math.mod(0.1*time, math.TAU), 3), 80, 10)
  w4.text(f32_to_str(sin(math.mod(0.1*time, math.TAU)), 3), 80, 20)

  w4.DRAW_COLORS^ = 0x0003
  w4.text(f32_to_str(1.0, 3), 10, 25)
  w4.text(f32_to_str(sin(1.0), 3), 10, 35)

  w4.text(f32_to_str(1.6, 3), 10, 50)
  w4.text(f32_to_str(sin(1.6), 3), 10, 60)

  w4.text(f32_to_str(2.2, 3), 10, 75)
  w4.text(f32_to_str(sin(2.2), 3), 10, 85)

  w4.text(f32_to_str(math.PI, 3), 10, 100)
  w4.text(f32_to_str(sin(math.PI), 3), 10, 110)

  w4.text(f32_to_str(0.0, 3), 10, 125)
  w4.text(f32_to_str(sin(0.0), 3), 10, 135)

  w4.text(f32_to_str(0.499*math.PI, 3), 80, 35)
  w4.text(f32_to_str(sin(0.45*math.PI), 3), 80, 45)

  w4.text(f32_to_str(0.5*math.PI, 3), 80, 60)
  w4.text(f32_to_str(sin(0.5*math.PI), 3), 80, 70)

  w4.text(f32_to_str(0.501*math.PI, 3), 80, 85)
  w4.text(f32_to_str(sin(0.55*math.PI), 3), 80, 95)

  w4.text(f32_to_str(3.6, 3), 80, 110)
  w4.text(f32_to_str(sin(3.6), 3), 80, 120)

}
