package main

import "core:math"
import glm "core:math/linalg/glsl"

import w4 "wasm4"

// Types ///////////////////////////////////////////////////////////////////////////////////////////

Color :: enum u32 {
  Black =  0x101015,
  Gray =   0x606060,
  White =  0xF7F5F3,
  Orange = 0xE69F00,
  Cyan =   0x56B4E9,
  Green =  0x009E73,
  Yellow = 0xF0E442,
}

Depth :: distinct u8
to_depth :: proc(z : f32) -> Depth {
  return Depth(clamp(255*z, 0, 255))
}

// State ///////////////////////////////////////////////////////////////////////////////////////////

depth_buffer := ((^[w4.SCREEN_SIZE*w4.SCREEN_SIZE]Depth)(uintptr(MEM_DEPTH_BUFFER)))

matrix_projection : glm.mat4

@(private="file") pallet_cycle : u8
current_color : Color

// Interface ///////////////////////////////////////////////////////////////////////////////////////

init_graphics :: proc() {
  matrix_projection = glm.mat4Perspective(60 * math.RAD_PER_DEG, 1, 0.5, 100)
}

update_pallet :: proc() {
  CYCLE_LENGTH :: 10
  defer pallet_cycle += 1

  if pallet_cycle % CYCLE_LENGTH == 0 {
    pallet_cycle %= 4*CYCLE_LENGTH
    switch pallet_cycle {
      case 0*CYCLE_LENGTH:
        current_color = Color.Orange
      case 1*CYCLE_LENGTH:
        current_color = Color.Cyan
      case 2*CYCLE_LENGTH:
        current_color = Color.Green
      case 3*CYCLE_LENGTH:
        current_color = Color.Yellow
    }
    w4.PALLET^ = { u32(Color.Black), u32(Color.Gray), u32(Color.White), u32(current_color) }
  }
}

clear_depth_buffer :: proc() {
  for i in 0..<len(depth_buffer) {
    depth_buffer[i] = 0xFF
  }
}

// Drawing /////////////////////////////////////////////////////////////////////////////////////////

DrawOptionSet :: bit_set[DrawOption]
DrawOption :: enum u8 {
  No_Cull_CW,
  Cull_CCW,
  No_Cull_Depth_Occluded,
  Cull_Depth_Front,
  Pixel_Border,
  No_Color_Write,
  No_Depth_Write,
}

draw_triangle :: proc(a, b, c : V3, color : Color, options := DrawOptionSet{}) -> bool {

  // Vertex Processing ---------

  mvp := get_mvp()

  a := hclip_to_screen(mvp * V4{ a.x, a.y, a.z, 1 })
  b := hclip_to_screen(mvp * V4{ b.x, b.y, b.z, 1 })
  c := hclip_to_screen(mvp * V4{ c.x, c.y, c.z, 1 })

  winding := triangle_direction(a.xy, b.xy, c.xy)
  if (.No_Cull_CW not_in options && winding == .Clockwise) ||
     (.Cull_CCW in options && winding == .Counter_Clockwise) ||
     winding == .None {
    return false
  }

  // Rasterization -------------

  Interpolator :: struct {
    dpos : V3,
  }

  Vary :: struct {
    using pos : V3,
  }

  make_d_dy :: proc(from, to : Vary) -> Interpolator {
    dy := max(1, abs(math.round(to.y) - math.round(from.y)))
    return Interpolator{
      dpos = (to.pos - from.pos) / dy,
    }
  }

  make_d_dx :: proc(from, to : Vary) -> Interpolator {
    dx := max(1, abs(math.round(to.x) - math.round(from.x)))
    return Interpolator{
      dpos = (to.pos - from.pos) / dx,
    }
  }

  iterate :: proc(base : Vary, d_dy : Interpolator, steps : int) -> Vary {
    result := base
    result.pos += f32(steps) * d_dy.dpos
    return result
  }

  // Sort verticies:
  top, right, left : Vary = ---, ---, ---
  {
    if a.y < b.y && a.y < c.y {
      top = { a }
      right = { c }
      left = { b }
    } else if b.y < c.y {
      top = { b }
      right = { a }
      left = { c }
    } else {
      top = { c }
      right = { b }
      left = { a }
    }
  }
  if winding == .Clockwise {
    left, right = right, left
  }

  left_dy, right_dy : Interpolator = ---, ---
  {
    left_dy = make_d_dy(top, left)
    right_dy = make_d_dy(top, right)
  }

  // Draw:
  left_base, right_base := top, top
  left_steps, right_steps : int
  left_border, right_border : [3]int = ---, ---
  if .Pixel_Border in options {
    start_x := iround(top.x)
    left_border = start_x-1
    right_border = start_x+1
  }

  left_y := iround(left.y)
  right_y := iround(right.y)
  top_px := iround(top.y)
  bottom_px := iround(max(left.y, right.y))
  if .Pixel_Border in options {
    bottom_px += 2
  }
  if top_px < 0 {
    left_steps = -top_px
    right_steps = -top_px
    if left_y < 0 {
      left_base = left
      left_steps = -left_y
      left_dy = make_d_dy(left, right)
    }
    if right_y < 0 {
      right_base = right
      right_steps = -right_y
      right_dy = make_d_dy(right, left)
    }
  }
  for y in max(0, top_px)..=min(w4.SCREEN_SIZE-1, bottom_px) {
    draw_y := y

    row_left := iterate(left_base, left_dy, left_steps)
    row_right := iterate(right_base, right_dy, right_steps)
    left_px := iround(row_left.x)
    right_px := iround(row_right.x)
    row_step := 0

    if .Pixel_Border in options {
      for i in 0..=1 {
        left_border[i] = left_border[i+1]
        right_border[i] = right_border[i+1]
      }
      if y <= bottom_px-2 && left_px <= right_px {
        left_border[2] = left_px-1
        right_border[2] = right_px+1
      } else {
        left_border[2] = w4.SCREEN_SIZE
        right_border[2] = 0
      }
      draw_y -= 1
      left_px = min(left_border[0], min(left_border[1], left_border[2]))
      right_px = max(right_border[0], max(right_border[1], right_border[2]))
      row_left = iterate(left_base, left_dy, left_steps-1)
      row_right = iterate(right_base, right_dy, right_steps-1)
      row_step = left_px - iround(row_left.x)
    }

    row_dx := make_d_dx(row_left, row_right)
    if left_px < 0 {
      row_step -= left_px
    }
    for draw_x in max(0, left_px)..=min(w4.SCREEN_SIZE-1, right_px) {
      frag := iterate(row_left, row_dx, row_step)
      if frag.z >= 0 || frag.z <= 1 {
        depth := to_depth(frag.z)
        depth_idx := draw_x + w4.SCREEN_SIZE*draw_y
        if .No_Cull_Depth_Occluded not_in options && depth >= depth_buffer[depth_idx] {
          continue
        }
        if .Cull_Depth_Front in options && depth <= depth_buffer[depth_idx] {
          continue
        }

        if .No_Color_Write not_in options {
          set_pixel(draw_x, draw_y, color)
        }
        if .No_Depth_Write not_in options {
          depth_buffer[depth_idx] = depth
        }
      }
      row_step += 1
    }

    if y == left_y {
      left_base = left
      left_steps = 0
      left_dy = make_d_dy(left, right)
    }
    if y == right_y {
      right_base = right
      right_steps = 0
      right_dy = make_d_dy(right, left)
    }
    left_steps += 1
    right_steps += 1
  }

  return true
}

set_pixel :: proc(#any_int x, y : int, color : Color) {
  if x < 0 || y < 0 || x >= w4.SCREEN_SIZE || y >= w4.SCREEN_SIZE {
    return
  }

  w4_color : u8
  if color == current_color {
    w4_color = 4
  } else {
    #partial switch color {
      case .Black:
        w4_color = 1
      case .Gray:
        w4_color = 2
      case .White:
        w4_color = 3
    }
  }

  if w4_color >= 1 && w4_color <= 4 {
    screen_idx := x + (y * w4.SCREEN_SIZE)
    screen_offset := screen_idx % 4
    screen_idx /= 4
    w4.FRAMEBUFFER[screen_idx] = (w4.FRAMEBUFFER[screen_idx] & ~(0b11 << u8(2*screen_offset))) | (w4_color-1) << u8(2*screen_offset)
  }
}

// Utility /////////////////////////////////////////////////////////////////////////////////////////

get_mvp :: proc() -> glm.mat4 {
  return matrix_projection
}

hclip_to_screen :: proc(hclip : V4) -> V3 {
  hclip := hclip.xyz / hclip.w
  hclip.y = -hclip.y
  hclip.xy = (hclip.xy + 1) * (w4.SCREEN_SIZE/2)
  return V3(hclip)
}
