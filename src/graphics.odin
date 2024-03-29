package main

import w4 "wasm4"

// Color ///////////////////////////////////////////////////////////////////////////////////////////

Color :: enum u8 {
  None = 0,
  Black = 1,
  Gray = 2,
  White = 3,
  Red = 4,
  Cyan = 5,
  Green = 6,
  Yellow = 7,
}

color_map := #partial [Color]u32 {
  .Black =  0x101015,
  .Gray =   0x434850,
  .White =  0xF7F5F3,
  .Red =    0xF53F20,
  .Cyan =   0x56B4E9,
  .Green =  0x009E73,
  .Yellow = 0xF0E442,
}

FIRST_SPECIAL_COLOR :: Color.Red
TEAM1_COLOR :: Color.Cyan
TEAM2_COLOR :: Color.Yellow

// Depth ///////////////////////////////////////////////////////////////////////////////////////////

Depth :: distinct u8

to_depth :: proc "contextless" (z : f32) -> Depth {
  return Depth(clamp(255*z, 0, 255))
}

// Storage /////////////////////////////////////////////////////////////////////////////////////////

BLUE_NOISE_SIZE :: 16
blue_noise_void_cluster := #load("../res/blue_noise_void_cluster_16.bytes") // 256 bytes

ORDERED_NOISE_SIZE :: 4
ordered_noise := [ORDERED_NOISE_SIZE*ORDERED_NOISE_SIZE]byte {
    0, 136,  34, 170,
  204,  68, 238, 102,
   51, 187,  17, 153,
  255, 119, 221,  85,
}



Model3D :: distinct []u8

ModelFlagSet :: bit_set[ModelFlag; u8]
ModelFlag :: enum u8 {
  Has_Normals = 0,
}

model_cube := Model3D(#load("../res/model_cube.bytes")) // 62 bytes
model_asteroid_01 := Model3D(#load("../res/model_asteroid_01.bytes")) // 494 bytes
model_asteroid_02 := Model3D(#load("../res/model_asteroid_02.bytes")) // 494 bytes
model_player_ship := Model3D(#load("../res/model_player_ship.bytes")) // 296 bytes
model_mine := Model3D(#load("../res/model_mine.bytes")) // 458 bytes
model_space_station_cap := Model3D(#load("../res/model_space_station_cap.bytes")) // 656 bytes
model_space_station_center := Model3D(#load("../res/model_space_station_center.bytes")) // 440 bytes

Material :: enum u8 {
  None,
  Asteroid,
  Metal,
  Engine,
  Physic,
  Outline,
  Black,
  White,
  Laser,
  Trail,
  Light_Mine,
  Light_HUD_Team1,
  Light_HUD_Team2,
  Light_Black_Team1,
  Light_Black_Team2,
  Light_White_Team1,
  Light_White_Team2,
  Death,
}

sprite_hud_plus := [?]u8{
  0b_00100001,
  0b_00111110,
  0b_01000010,
}

sprite_hud_home := [?]u8{
  0b_00000000, 0b_01000000, 0b_00000000, 0b_01100100,
  0b_00000000, 0b_01101010, 0b_01000000, 0b_01101010,
  0b_10100100, 0b_01101010, 0b_10101010, 0b_01011010,
  0b_10101010, 0b_10010101, 0b_10101010, 0b_10010100,
  0b_01101001, 0b_10100100, 0b_00011010, 0b_01101001,
  0b_00000101, 0b_01010101, 0b_01000000,
}

/*
sprite_hud_box := [?]u8{
  0b_11100111,
  0b_10000001,
  0b_10000001,
  0b_00000000,
  0b_00000000,
  0b_10000001,
  0b_10000001,
  0b_11100111,
}
*/

// State ///////////////////////////////////////////////////////////////////////////////////////////

depth_buffer := ((^[w4.SCREEN_SIZE*w4.SCREEN_SIZE]Depth)(uintptr(MEM_DEPTH_BUFFER)))

light_dir : V3
rendering_pysic_density : f32

matrix_projection : Matrix
matrix_view : Matrix
matrix_VP : Matrix

screen_shake : u8

@(private="file") pallet_cycle : u8
current_color : Color

// Interface ///////////////////////////////////////////////////////////////////////////////////////

NEAR_CLIP :: 0.5
FAR_CLIP :: 200
FOV :: 60
init_graphics :: proc "contextless" () {
  light_dir = norm_v3(V3{ 1, 4, 2 })
  // Make Projection Matrix
  {
    tan_half_fovy := tan(f32(FOV/2.0 * RAD_PER_DEG))
    matrix_projection[0, 0] = 1.0 / tan_half_fovy
    matrix_projection[1, 1] = 1.0 / tan_half_fovy
    matrix_projection[2, 2] = -(FAR_CLIP + NEAR_CLIP) / (FAR_CLIP - NEAR_CLIP)
    matrix_projection[3, 2] = -1.0
    matrix_projection[2, 3] = -2.0*FAR_CLIP*NEAR_CLIP / (FAR_CLIP - NEAR_CLIP)
  }
}

update_pallet :: proc "contextless" () {
  CYCLE_LENGTH :: 5
  defer pallet_cycle += 1

  if pallet_cycle % CYCLE_LENGTH == 0 {
    pallet_cycle %= 4*CYCLE_LENGTH
    switch pallet_cycle {
      case 0*CYCLE_LENGTH:
        current_color = Color.Red
      case 1*CYCLE_LENGTH:
        current_color = Color.Cyan
      case 2*CYCLE_LENGTH:
        current_color = Color.Green
      case 3*CYCLE_LENGTH:
        current_color = Color.Yellow
    }
    w4.PALLET^ = { color_map[.Black], color_map[.Gray], color_map[.White], color_map[current_color] }
  }
}

clear_depth_buffer :: proc "contextless" () {
  for i in 0..<len(depth_buffer) {
    depth_buffer[i] = 0xFF
  }
}

// Drawing /////////////////////////////////////////////////////////////////////////////////////////

DrawOptionsSet :: bit_set[DrawOptions; u8]
DrawOptions :: enum u8 {
  Border,
  Reverse_Winding,
  No_Backface_Culling,
}

// TODO (hitch) 2022-08-19 WHAT DRAW OPTIONS ARE USED?
TriangleOptionsSet :: bit_set[TriangleOptions; u8]
TriangleOptions :: enum u8 {
  No_Cull_CW,
  Cull_CCW,
  No_Cull_Depth_Occluded,
  Cull_Depth_Front,
  Pixel_Border,
}

LODCallback :: #type proc "contextless" (distance : f16)

LODOptions :: struct {
  cutoff_distance : f16,
  lod_0_distance : f16,
  lod_0_callback : LODCallback,
  lod_1_distance : f16,
  lod_1_callback : LODCallback,
  border_distance : f16,
}

draw_star :: proc "contextless" (dir : V3) {
  screen_point := model_to_screen(V4{ dir.x, dir.y, dir.z, 0 })
  if screen_point.z > 0 {
    set_pixel(iround(screen_point.x), iround(screen_point.y), .White)
  }
}

draw_model :: proc "contextless" (model : Model3D, model_matrix : Matrix, radius : f32, materials : []Material, options := DrawOptionsSet{}) {
  center := V3{ model_matrix[0, 3], model_matrix[1, 3], model_matrix[2, 3] }
  screen_point := model_to_screen(V4{ center.x, center.y, center.z, 1 })

  tan_half_fov := tan(60.0 * RAD_PER_DEG / 2.0)
  screen_radius := w4.SCREEN_SIZE *  0.5*radius / (f32(screen_point.z)*(FAR_CLIP-NEAR_CLIP) * tan_half_fov)
  if screen_point.x < -screen_radius ||
     screen_point.y < -screen_radius ||
     screen_point.z < -screen_radius ||
     screen_point.x > w4.SCREEN_SIZE+screen_radius ||
     screen_point.y > w4.SCREEN_SIZE+screen_radius ||
     screen_point.z > w4.SCREEN_SIZE+screen_radius {
    return
  }

  model_flags := transmute(ModelFlagSet)model[0]
  vert_count := int(model[1])

  vert_size := 3
  if .Has_Normals in model_flags {
    vert_size += 3
  }

  fill_options := TriangleOptionsSet{  }
  border_options := TriangleOptionsSet{ .No_Cull_CW, .Cull_CCW }
  if .Reverse_Winding in options {
    fill_options, border_options = border_options, fill_options
  }
  border_options |= { .Pixel_Border }
  if .No_Backface_Culling in options {
    fill_options |= { .No_Cull_CW }
  }

  decode_f32 :: proc "contextless" (bits : u8) -> f32 {
    return (f32(bits) / 255.0) - 0.5
  }

  for face_read := vert_size*vert_count+2; face_read < len(model); face_read += 3 {
    data := model[face_read:face_read+3]
    a_idx := vert_size*int(data[0] & 0b01111111)
    b_idx := vert_size*int(data[1] & 0b01111111)
    c_idx := vert_size*int(data[2] & 0b01111111)
    material_idx := (data[0] >> 5 & 0b100) | (data[1] >> 6 & 0b010) | (data[2] >> 7 & 0b001)
    a, b, c : Vary
    a.pos = V3(mul(model_matrix, V4{ decode_f32(model[a_idx + 2]), decode_f32(model[a_idx + 3]), decode_f32(model[a_idx + 4]), 1 }).xyz)
    b.pos = V3(mul(model_matrix, V4{ decode_f32(model[b_idx + 2]), decode_f32(model[b_idx + 3]), decode_f32(model[b_idx + 4]), 1 }).xyz)
    c.pos = V3(mul(model_matrix, V4{ decode_f32(model[c_idx + 2]), decode_f32(model[c_idx + 3]), decode_f32(model[c_idx + 4]), 1 }).xyz)
    face_norm := norm_v3(cross(b.pos-a.pos, c.pos-a.pos))

    if .Has_Normals in model_flags {
      a_norm := V3(mul(model_matrix, V4{ decode_f32(model[a_idx + 5]), decode_f32(model[a_idx + 6]), decode_f32(model[a_idx + 7]), 0 }).xyz)
      b_norm := V3(mul(model_matrix, V4{ decode_f32(model[b_idx + 5]), decode_f32(model[b_idx + 6]), decode_f32(model[b_idx + 7]), 0 }).xyz)
      c_norm := V3(mul(model_matrix, V4{ decode_f32(model[c_idx + 5]), decode_f32(model[c_idx + 6]), decode_f32(model[c_idx + 7]), 0 }).xyz)
      a.norm = (0.75*a_norm + 0.25*face_norm)
      b.norm = (0.75*b_norm + 0.25*face_norm)
      c.norm = (0.75*c_norm + 0.25*face_norm)
    } else {
      a.norm = face_norm
      b.norm = face_norm
      c.norm = face_norm
    }

    if .Border in options {
      draw_triangle(a, b, c, .Outline, border_options, 0.01)
    }
    draw_triangle(a, b, c, materials[material_idx], fill_options)
  }
}

Vary :: struct {
  using pos : V3,
  norm : V3,
}

@(private="file")
Interpolator :: struct {
  dpos :  V3,
  dnorm : V3,
}

@(private="file")
make_d_dy :: proc "contextless" (from, to : Vary) -> Interpolator {
  dy := max(1, abs(round(to.y) - round(from.y)))
  result : Interpolator
  result.dpos = to.pos
  result.dpos.x = (result.dpos.x - from.pos.x) / dy
  result.dpos.y = (result.dpos.y - from.pos.y) / dy
  result.dpos.z = (result.dpos.z - from.pos.z) / dy
  result.dnorm = to.norm
  result.dnorm.x = (result.dnorm.x - from.norm.x) / dy
  result.dnorm.y = (result.dnorm.y - from.norm.y) / dy
  result.dnorm.z = (result.dnorm.z - from.norm.z) / dy
  return result
}

@(private="file")
make_d_dx :: proc "contextless" (from, to : Vary) -> Interpolator {
  dx := max(1, abs(round(to.x) - round(from.x)))
  result : Interpolator
  result.dpos = to.pos
  result.dpos.x = (result.dpos.x - from.pos.x) / dx
  result.dpos.y = (result.dpos.y - from.pos.y) / dx
  result.dpos.z = (result.dpos.z - from.pos.z) / dx
  result.dnorm = to.norm
  result.dnorm.x = (result.dnorm.x - from.norm.x) / dx
  result.dnorm.y = (result.dnorm.y - from.norm.y) / dx
  result.dnorm.z = (result.dnorm.z - from.norm.z) / dx
  return result
}

@(private="file")
iterate :: proc "contextless" (base : Vary, d_dy : Interpolator, steps : int) -> Vary {
  dist := f32(steps)
  result := base
  result.pos.x += dist * d_dy.dpos.x
  result.pos.y += dist * d_dy.dpos.y
  result.pos.z += dist * d_dy.dpos.z
  result.norm.x += dist * d_dy.dnorm.x
  result.norm.y += dist * d_dy.dnorm.y
  result.norm.z += dist * d_dy.dnorm.z
  return result
}

draw_line :: proc "contextless" (a, b : Vary, material : Material, depth_offset := f32(0)) {
  // TODO (hitch) 2022-08-20 FUNCTION CANDITATE:
  material_color : Color
  {
    switch material {
      case .None:
        return
      case .Asteroid:
        material_color = .Gray
      case .Metal:
        material_color = .Gray
      case .Engine:
        material_color = ((time % 2) == 0) ? .White : .Black
      case .Physic:
        material_color = .Green
        if current_color != material_color {
          return
        }
      case .Outline:
        material_color = .White
      case .Black:
        material_color = .Black
      case .White:
        material_color = .White
      case .Laser:
        if (time % 2) == 0 {
          material_color = (current_color == .Red) ? .Red : .White
        } else {
          return
        }
      case .Trail:
        material_color = .White
      case .Light_Mine:
        material_color = (current_color == .Red) ? .Red : .Black
      case .Light_HUD_Team1:
        material_color = TEAM1_COLOR
        if current_color != material_color {
          return
        }
      case .Light_HUD_Team2:
        material_color = TEAM2_COLOR
        if current_color != material_color {
          return
        }
      case .Light_Black_Team1:
        material_color = (current_color == TEAM1_COLOR) ? TEAM1_COLOR : .Black
      case .Light_Black_Team2:
        material_color = (current_color == TEAM2_COLOR) ? TEAM2_COLOR : .Black
      case .Light_White_Team1:
        material_color = (current_color == TEAM1_COLOR) ? TEAM1_COLOR : .White
      case .Light_White_Team2:
        material_color = (current_color == TEAM2_COLOR) ? TEAM2_COLOR : .White
      case .Death:
        material_color = .Black
    }
  }

  // Vertex Processing ---------

  a := a
  b := b

  a.pos = model_to_screen(V4{ a.pos.x, a.pos.y, a.pos.z, 1 })
  b.pos = model_to_screen(V4{ b.pos.x, b.pos.y, b.pos.z, 1 })
  a.pos.z += depth_offset
  b.pos.z += depth_offset

  if (a.pos.x < 0 && b.pos.x < 0) ||
     (a.pos.x >= w4.SCREEN_SIZE && b.pos.x >= w4.SCREEN_SIZE) ||
     (a.pos.y < 0 && b.pos.y < 0) ||
     (a.pos.y >= w4.SCREEN_SIZE && b.pos.y >= w4.SCREEN_SIZE) ||
     (a.pos.z < 0 || b.pos.z < 0) ||
     (a.pos.z > 1 || b.pos.z > 1) {
      return
  }

  // Rasterization -------------

  if abs(a.pos.x - b.pos.x) > abs(a.pos.y - b.pos.y) {
    left, right : Vary
    if (a.pos.x < b.pos.x) {
      left, right = a, b
    } else {
      left, right = b, a
    }
    interp := make_d_dx(left, right)
    steps := 0

    left_px := iround(left.pos.x)
    if left_px < 0 {
      steps = -left_px
      left_px = 0
    }

    for x in left_px..=min(iround(right.pos.x), w4.SCREEN_SIZE-1) {
      frag := iterate(left, interp, steps)
      draw_fragment(x, iround(frag.pos.y), frag, material, material_color)
      steps += 1
    }
  } else {
    top, bottom : Vary
    if (a.pos.y < b.pos.y) {
      top, bottom = a, b
    } else {
      top, bottom = b, a
    }
    interp := make_d_dy(top, bottom)
    steps := 0

    top_px := iround(top.pos.y)
    if top_px < 0 {
      steps = -top_px
      top_px = 0
    }

    for y in top_px..=min(iround(bottom.pos.y), w4.SCREEN_SIZE-1) {
      frag := iterate(top, interp, steps)
      draw_fragment(iround(frag.pos.x), y, frag, material, material_color)
      steps += 1
    }
  }
}

draw_triangle :: proc "contextless" (a, b, c : Vary, material : Material, options := TriangleOptionsSet{}, depth_offset := f32(0)) -> bool {
  // TODO (hitch) 2022-08-20 FUNCTION CANDITATE:
  material_color : Color
  {
    switch material {
      case .None:
        return false
      case .Asteroid:
        material_color = .Gray
      case .Metal:
        material_color = .Gray
      case .Engine:
        material_color = ((time % 2) == 0) ? .White : .Black
      case .Physic:
        material_color = .Green
        if current_color != material_color {
          return false
        }
      case .Outline:
        material_color = .White
      case .Black:
        material_color = .Black
      case .White:
        material_color = .White
      case .Laser:
        if (time % 2) == 0 {
          material_color = (current_color == .Red) ? .Red : .White
        } else {
          return false
        }
      case .Trail:
        material_color = .White
      case .Light_Mine:
        material_color = (current_color == .Red) ? .Red : .Black
      case .Light_HUD_Team1:
        material_color = TEAM1_COLOR
        if current_color != material_color {
          return false
        }
      case .Light_HUD_Team2:
        material_color = TEAM2_COLOR
        if current_color != material_color {
          return false
        }
      case .Light_Black_Team1:
        material_color = (current_color == TEAM1_COLOR) ? TEAM1_COLOR : .Black
      case .Light_Black_Team2:
        material_color = (current_color == TEAM2_COLOR) ? TEAM2_COLOR : .Black
      case .Light_White_Team1:
        material_color = (current_color == TEAM1_COLOR) ? TEAM1_COLOR : .White
      case .Light_White_Team2:
        material_color = (current_color == TEAM2_COLOR) ? TEAM2_COLOR : .White
      case .Death:
        material_color = .Black
    }
  }

  // Vertex Processing ---------

  a_norm := a.norm
  b_norm := b.norm
  c_norm := c.norm

  a := model_to_screen(V4{ a.x, a.y, a.z, 1 })
  b := model_to_screen(V4{ b.x, b.y, b.z, 1 })
  c := model_to_screen(V4{ c.x, c.y, c.z, 1 })
  a.z += depth_offset
  b.z += depth_offset
  c.z += depth_offset

  if (a.x < 0 && b.x < 0 && c.x < 0) ||
     (a.x >= w4.SCREEN_SIZE && b.x >= w4.SCREEN_SIZE && c.x >= w4.SCREEN_SIZE) ||
     (a.y < 0 && b.y < 0 && c.y < 0) ||
     (a.y >= w4.SCREEN_SIZE && b.y >= w4.SCREEN_SIZE && c.y >= w4.SCREEN_SIZE) ||
     (a.z < 0 && b.z < 0 && c.z < 0) ||
     (a.z > 1 && b.z > 1 && c.z > 1) {
      return false
  }

  winding := triangle_direction(a.xy, b.xy, c.xy)
  if (.No_Cull_CW not_in options && winding == .Clockwise) ||
     (.Cull_CCW in options && winding == .Counter_Clockwise) ||
     winding == .None {
    return false
  }

  if winding == .Clockwise {
    a_norm = -a_norm
    b_norm = -b_norm
    c_norm = -c_norm
  }

  // Rasterization -------------

  // Sort verticies:
  top, right, left : Vary
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

  left_dy, right_dy : Interpolator
  {
    left_dy = make_d_dy(top, left)
    right_dy = make_d_dy(top, right)
  }

  // Draw:
  left_base, right_base := top, top
  left_steps, right_steps : int
  left_border, right_border : [3]int
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
  if top_px <= 0 {
    left_steps = -top_px
    right_steps = -top_px
    if left_y <= 0 && left_y <= right_y {
      left_base = left
      left_steps = -left_y
      left_dy = make_d_dy(left, right)
    }
    if right_y <= 0 && right_y < left_y {
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
      draw_fragment(draw_x, draw_y, frag, material, material_color)
      row_step += 1
    }

    if y == left_y && left_y <= right_y {
      left_base = left
      left_steps = 0
      left_dy = make_d_dy(left, right)
    }
    if y == right_y && right_y < left_y {
      right_base = right
      right_steps = 0
      right_dy = make_d_dy(right, left)
    }
    left_steps += 1
    right_steps += 1
  }

  return true
}

draw_fragment :: proc "contextless" (x, y : int, frag : Vary, material : Material, color : Color) {
  color := color
  if x >= 0 && x < w4.SCREEN_SIZE &&
     y >= 0 && y < w4.SCREEN_SIZE &&
     frag.pos.z >= 0 && frag.pos.z <= 1 {
    depth := to_depth(frag.pos.z)
    depth_idx := x + w4.SCREEN_SIZE*y
    if depth >= depth_buffer[depth_idx] {
      return
    }

    physic_sparkle :: proc "contextless" (x, y : int, dust : bool) -> bool {
      offset := int(7*(time/20) % BLUE_NOISE_SIZE)
      noise_idx := ((x/8) % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*(((y/8)+offset) % BLUE_NOISE_SIZE))
      threshold := blue_noise_void_cluster[noise_idx]
      test := u8(((x + w4.SCREEN_SIZE*y) + int(37*(time/20))) % 255)
      if dust {
        threshold %= 50
        test %= 50
      }
      if threshold == test {
        if dust {
          noise_idx := (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
          threshold := blue_noise_void_cluster[noise_idx]
          return threshold < u8(((x + w4.SCREEN_SIZE*y) + int(37*(time/20))) % (1+int(254*rendering_pysic_density)))
        } else {
          return true
        }
      }
      return false
    }

    if material == .Death {
      offset := int(7*(time/20) % BLUE_NOISE_SIZE)
      noise_idx := (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
      threshold := blue_noise_void_cluster[noise_idx]
      if threshold < 127 {
        return
      }
    }

    if material == .Physic && !physic_sparkle(x, y, true) {
      return
    }

    if material == .Trail {
      offset := int(7*(time/5) % BLUE_NOISE_SIZE)
      noise_idx := (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
      threshold := blue_noise_void_cluster[noise_idx]
      test := u8(255*(1-frag.pos.z)*ease_quad_out(1-frag.norm.y))
      if test < threshold {
        return
      }
      if test < 255+threshold/2 {
        color = .Gray
      }
    }

    lighting: if material == .Asteroid || material == .Metal {
      light := u8(255*ease_quad_out(clamp(0.75*dot(light_dir, frag.norm) + 0.5, 0, 1)))
      threshold := u8(128)

      if material == .Metal {
        noise_idx := (x % ORDERED_NOISE_SIZE) + (ORDERED_NOISE_SIZE*(y % ORDERED_NOISE_SIZE))
        threshold = ordered_noise[noise_idx]
      } else {
        if current_color == .Green && physic_sparkle(x, y, false) {
          color = .Green
          break lighting
        }
        offset := int(7*(time/5) % BLUE_NOISE_SIZE)
        noise_idx := (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
        threshold = blue_noise_void_cluster[noise_idx]
      }

      if light < threshold {
        color = .Black
      }
    }

    set_pixel(x, y, color)
    depth_buffer[depth_idx] = depth
  }
}

set_pixel :: proc "contextless" (x, y : int, color : Color) {
  if x < 0 || y < 0 || x >= w4.SCREEN_SIZE || y >= w4.SCREEN_SIZE {
    return
  }

  w4_color := u8(color)
  if color >= FIRST_SPECIAL_COLOR {
    if color != current_color {
      return
    }
    w4_color = 4
  }

  screen_idx := x + (y * w4.SCREEN_SIZE)
  screen_offset := screen_idx % 4
  screen_idx /= 4
  w4.FRAMEBUFFER[screen_idx] = (w4.FRAMEBUFFER[screen_idx] & ~(0b11 << u8(2*screen_offset))) | (w4_color-1) << u8(2*screen_offset)
}

// Utility /////////////////////////////////////////////////////////////////////////////////////////

model_to_clip :: proc "contextless" (model : V4) -> V3 {
  projected_point := mul(matrix_VP, model)
  if projected_point.w != 0 {
    projected_point.x = projected_point.x / projected_point.w
    projected_point.y = projected_point.y / projected_point.w
    projected_point.z = projected_point.z / projected_point.w
  }

  return V3(projected_point.xyz)
}

model_to_screen :: proc "contextless" (model : V4) -> V3 {
  view_point := mul(matrix_view, model)
  projected_point := model_to_clip(model)

  projected_point.y = -projected_point.y
  projected_point.x = (projected_point.x + 1) * (w4.SCREEN_SIZE/2)
  projected_point.y = (projected_point.y + 1) * (w4.SCREEN_SIZE/2)
  if view_point.z > 0 {
    projected_point.x = -projected_point.x
    projected_point.y = -projected_point.y
  }
  projected_point.z = remap(view_point.z, -NEAR_CLIP, -FAR_CLIP, 0.0, 1.0)
  return projected_point
}
