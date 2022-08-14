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

// Storage /////////////////////////////////////////////////////////////////////////////////////////

BLUE_NOISE_SIZE :: 16
blue_noise_void_cluster := #load("../res/blue_noise_void_cluster_16.bytes")

Model3D :: distinct []u8

ModelFlagSet :: bit_set[ModelFlag; u8]
ModelFlag :: enum u8 {
  Has_Normals = 0,
}

model_asteroid_01 := Model3D(#load("../res/model_asteroid_01.bytes"))

// State ///////////////////////////////////////////////////////////////////////////////////////////

depth_buffer := ((^[w4.SCREEN_SIZE*w4.SCREEN_SIZE]Depth)(uintptr(MEM_DEPTH_BUFFER)))

matrix_projection : glm.mat4
matrix_view : glm.mat4

@(private="file") pallet_cycle : u8
current_color : Color

// Interface ///////////////////////////////////////////////////////////////////////////////////////

init_graphics :: proc() {
  matrix_projection = glm.mat4Perspective(60 * math.RAD_PER_DEG, 1, 0.5, 100)
  matrix_view = glm.identity(glm.mat4)
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
  Do_Lighting,
}

draw_star :: proc(dir : V3) {
  vp_mat := get_vp_mat()
  screen_point := hclip_to_screen(vp_mat * V4{ dir.x, dir.y, dir.z, 0 })
  if screen_point.x >= 0 && screen_point.x < w4.SCREEN_SIZE && screen_point.y >= 0 && screen_point.y < w4.SCREEN_SIZE {
    set_pixel(iround(screen_point.x), iround(screen_point.y), .Gray)
  }
}

draw_model :: proc(model : Model3D, center : V3, rotation := glm.quat{}, size := V3_ONE) {
  model_matrix := glm.mat4Translate(center) * glm.mat4Scale(size) * glm.mat4FromQuat(rotation)

  model_flags := transmute(ModelFlagSet)model[0]
  vert_count := int(model[1])

  vert_size := 3
  if .Has_Normals in model_flags {
    vert_size += 3
  }

  decode_f32 :: proc(bits : u8) -> f32 {
    return (f32(bits) / 255.0) - 0.5
  }

  for face_read := vert_size*vert_count+2; face_read < len(model); face_read += 3 {
    data := model[face_read:face_read+3]
    a_idx := vert_size*int(data[0])
    b_idx := vert_size*int(data[1])
    c_idx := vert_size*int(data[2])
    a := V3((model_matrix * V4{ decode_f32(model[a_idx + 2]), decode_f32(model[a_idx + 3]), decode_f32(model[a_idx + 4]), 1 }).xyz)
    b := V3((model_matrix * V4{ decode_f32(model[b_idx + 2]), decode_f32(model[b_idx + 3]), decode_f32(model[b_idx + 4]), 1 }).xyz)
    c := V3((model_matrix * V4{ decode_f32(model[c_idx + 2]), decode_f32(model[c_idx + 3]), decode_f32(model[c_idx + 4]), 1 }).xyz)

    if .Has_Normals in model_flags {
      a_norm := V3((model_matrix * V4{ decode_f32(model[a_idx + 5]), decode_f32(model[a_idx + 6]), decode_f32(model[a_idx + 7]), 0 }).xyz)
      b_norm := V3((model_matrix * V4{ decode_f32(model[b_idx + 5]), decode_f32(model[b_idx + 6]), decode_f32(model[b_idx + 7]), 0 }).xyz)
      c_norm := V3((model_matrix * V4{ decode_f32(model[c_idx + 5]), decode_f32(model[c_idx + 6]), decode_f32(model[c_idx + 7]), 0 }).xyz)
      face_norm := glm.normalize(glm.cross(b-a, c-a))
      a_norm = (0.75*a_norm + 0.25*face_norm)
      b_norm = (0.75*b_norm + 0.25*face_norm)
      c_norm = (0.75*c_norm + 0.25*face_norm)
      draw_triangle_norm(a, b, c, a_norm, b_norm, c_norm, .White, { .No_Cull_CW, .Cull_CCW, .Pixel_Border }, 0.05)
      draw_triangle_norm(a, b, c, a_norm, b_norm, c_norm, .Gray, { .Do_Lighting })
    } else {
      draw_triangle(a, b, c, .White, { .No_Cull_CW, .Cull_CCW, .Pixel_Border }, 0.05)
      draw_triangle(a, b, c, .Gray, { .Do_Lighting })
    }
  }
}

draw_triangle :: proc(a, b, c : V3, color : Color, options := DrawOptionSet{}, depth_offset := f32(0)) -> bool {
  norm := glm.normalize(glm.cross(b-a, c-a))
  return draw_triangle_norm(a, b, c, norm, norm, norm, color, options, depth_offset)
}

draw_triangle_norm :: proc(a, b, c : V3, a_norm, b_norm, c_norm : V3, color : Color, options := DrawOptionSet{}, depth_offset := f32(0)) -> bool {
  light_dir := glm.normalize(V3{ 1, 4, 2 })

  // Vertex Processing ---------

  vp_mat := get_vp_mat()

  a := hclip_to_screen(vp_mat * V4{ a.x, a.y, a.z, 1 })
  b := hclip_to_screen(vp_mat * V4{ b.x, b.y, b.z, 1 })
  c := hclip_to_screen(vp_mat * V4{ c.x, c.y, c.z, 1 })

  winding := triangle_direction(a.xy, b.xy, c.xy)
  if (.No_Cull_CW not_in options && winding == .Clockwise) ||
     (.Cull_CCW in options && winding == .Counter_Clockwise) ||
     winding == .None {
    return false
  }

  a_norm := a_norm
  b_norm := b_norm
  c_norm := c_norm
  if winding == .Clockwise {
    a_norm = -a_norm
    b_norm = -b_norm
    c_norm = -c_norm
  }

  // Rasterization -------------

  Interpolator :: struct {
    dpos :  V3,
    dnorm : V3,
  }

  Vary :: struct {
    using pos : V3,
    norm : V3,
  }

  make_d_dy :: proc(from, to : Vary) -> Interpolator {
    dy := max(1, abs(math.round(to.y) - math.round(from.y)))
    return Interpolator{
      dpos = (to.pos - from.pos) / dy,
      dnorm = (to.norm - from.norm) / dy,
    }
  }

  make_d_dx :: proc(from, to : Vary) -> Interpolator {
    dx := max(1, abs(math.round(to.x) - math.round(from.x)))
    return Interpolator{
      dpos = (to.pos - from.pos) / dx,
      dnorm = (to.norm - from.norm) / dx,
    }
  }

  iterate :: proc(base : Vary, d_dy : Interpolator, steps : int) -> Vary {
    result := base
    result.pos += f32(steps) * d_dy.dpos
    result.norm += f32(steps) * d_dy.dnorm
    return result
  }

  // Sort verticies:
  top, right, left : Vary = ---, ---, ---
  {
    if a.y < b.y && a.y < c.y {
      top = { a, a_norm }
      right = { c, c_norm }
      left = { b, b_norm }
    } else if b.y < c.y {
      top = { b, b_norm }
      right = { a, a_norm }
      left = { c, c_norm }
    } else {
      top = { c, c_norm }
      right = { b, b_norm }
      left = { a, a_norm }
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
      draw_y -= 1
      if draw_y < 0 {
        continue
      }

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
        depth := to_depth(frag.z+depth_offset)
        depth_idx := draw_x + w4.SCREEN_SIZE*draw_y
        if .No_Cull_Depth_Occluded not_in options && depth >= depth_buffer[depth_idx] {
          continue
        }
        if .Cull_Depth_Front in options && depth <= depth_buffer[depth_idx] {
          continue
        }

        color := color
        if .Do_Lighting in options {
          offset := 7*int(10*time) % BLUE_NOISE_SIZE
          noise_idx := (draw_x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((draw_y+offset) % BLUE_NOISE_SIZE))
          if u8(255*clamp(1.75*glm.dot(light_dir, frag.norm)+0.5, 0, 1)) < blue_noise_void_cluster[noise_idx] {
            color = .Black
          }
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

get_vp_mat :: proc() -> glm.mat4 {
  return matrix_projection * matrix_view
}

hclip_to_screen :: proc(hclip : V4) -> V3 {
  hclip := hclip
  if hclip.w != 0 {
    hclip = hclip / hclip.w
  }
  hclip.y = -hclip.y
  hclip.xy = (hclip.xy + 1) * (w4.SCREEN_SIZE/2)
  return V3(hclip.xyz)
}
