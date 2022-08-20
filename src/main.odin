package main

import "core:math"
import "core:math/rand"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

import w4 "wasm4"

time : u32 // 4 bytes
player_id : u8
team_1 : Team
team_2 : Team

TeamID :: enum u8 {
  Team1,
  Team2,
}

Team :: struct {
  score : int,
}

WORLD_SIZE :: f32(200)

graphics_rand := rand.create(42) // 17 bytes

input_held : [4]^w4.ButtonSet // 4 bytes
_input_prev : [4]w4.ButtonSet // 4 bytes
input_press : [4]w4.ButtonSet // 4 bytes

@export
start :: proc "c" () {
  // TODO (hitch) 2022-08-19 Get rand ported, then remove context
  context = {}

  input_held = { w4.GAMEPAD1, w4.GAMEPAD2, w4.GAMEPAD3, w4.GAMEPAD4 }

  init_math()
  init_graphics()

  for i in 0..<4 {
    players[i].speed = 0.5
    players[i].pos.x = f32(3 * i)
    players[i].physic = 200
    players[i].health = 0
    players[i].flags = { .Team2 }
    for _ in 0..<4 {
      sample_trail(&players[i])
    }
  }
  team_1.score = 42
  team_2.score = 1337

  level_rand := rand.create(42)
  for asteroid in asteroids {
    asteroid.pos.x = u16(rand.uint32(&level_rand))
    asteroid.pos.y = u16(rand.uint32(&level_rand))
    asteroid.pos.z = u16(rand.uint32(&level_rand))
    asteroid.variant = u8(rand.uint32(&level_rand))
  }
}

@export
update :: proc "c" () {
  // TODO (hitch) 2022-08-19 Get rand ported, then remove context
  context = {}

  time += 1
  player_id = (u8(w4.NETPLAY^) & 0b11)

  setup_current_player_view_matrix()

  defer {
    for i in 0..<4 {
      _input_prev[i] = input_held[i]^
    }
  }
  for i in 0..<4 {
    input_press[i] = input_held[i]^ & (input_held[i]^ ~ _input_prev[i])
  }


  for player, i in players {
    update_player(&player, i)
  }

  min_base_sq_dist := max(f32)
  min_base_pos : V3
  min_teammate_sq_dist := max(f32)
  min_teammate_pos : V3

  update_pallet()
  clear_depth_buffer()

  // STARS
  {
    star_rand := rand.create(42)
    for star in 0..<300 {
      y := 2*rand.float32(&star_rand) - 1
      draw_star({ 2*rand.float32(&star_rand) - 1, y*y*y, 2*rand.float32(&star_rand) - 1 })
    }
  }

  @(static) valid_offsets : []V3
  // GET VALID OFFSETS
  {
    LOOP_POS :: [?]V3{
      {           0,           0,           0 },
      { -WORLD_SIZE, -WORLD_SIZE, -WORLD_SIZE },
      { -WORLD_SIZE, -WORLD_SIZE,           0 },
      { -WORLD_SIZE, -WORLD_SIZE,  WORLD_SIZE },
      { -WORLD_SIZE,           0, -WORLD_SIZE },
      { -WORLD_SIZE,           0,           0 },
      { -WORLD_SIZE,           0,  WORLD_SIZE },
      { -WORLD_SIZE,  WORLD_SIZE, -WORLD_SIZE },
      { -WORLD_SIZE,  WORLD_SIZE,           0 },
      { -WORLD_SIZE,  WORLD_SIZE,  WORLD_SIZE },
      {           0, -WORLD_SIZE, -WORLD_SIZE },
      {           0, -WORLD_SIZE,           0 },
      {           0, -WORLD_SIZE,  WORLD_SIZE },
      {           0,           0, -WORLD_SIZE },
      {           0,           0,  WORLD_SIZE },
      {           0,  WORLD_SIZE, -WORLD_SIZE },
      {           0,  WORLD_SIZE,           0 },
      {           0,  WORLD_SIZE,  WORLD_SIZE },
      {  WORLD_SIZE, -WORLD_SIZE, -WORLD_SIZE },
      {  WORLD_SIZE, -WORLD_SIZE,           0 },
      {  WORLD_SIZE, -WORLD_SIZE,  WORLD_SIZE },
      {  WORLD_SIZE,           0, -WORLD_SIZE },
      {  WORLD_SIZE,           0,           0 },
      {  WORLD_SIZE,           0,  WORLD_SIZE },
      {  WORLD_SIZE,  WORLD_SIZE, -WORLD_SIZE },
      {  WORLD_SIZE,  WORLD_SIZE,           0 },
      {  WORLD_SIZE,  WORLD_SIZE,  WORLD_SIZE },
    }
    _valid_offsets : [len(LOOP_POS)]V3
    _valid_offset_count := 0
    for pos_offset in LOOP_POS {
      if (pos_offset.x < 0 && players[player_id].pos.x > 0) ||
         (pos_offset.x > 0 && players[player_id].pos.x < 0) ||
         (pos_offset.y < 0 && players[player_id].pos.y > 0) ||
         (pos_offset.y > 0 && players[player_id].pos.y < 0) ||
         (pos_offset.z < 0 && players[player_id].pos.z > 0) ||
         (pos_offset.z > 0 && players[player_id].pos.z < 0) {
        continue
      }
      _valid_offsets[_valid_offset_count] = pos_offset
      _valid_offset_count += 1
    }
    valid_offsets = _valid_offsets[:_valid_offset_count]
  }

  // ASTEROIDS
  {
    asteroid_matrix := mul(quat_to_mat(quat_euler({ f32(time)/120.0, f32(time)/60.0, f32(time)/90.0 })), mat_scale({ 3, 3, 3 }))
    for asteroid in asteroids {
      // TODO (hitch) 2022-08-16 LOD draw Z-Test
      asteroid_pos := to_v3(asteroid.pos)
      for pos_offset in valid_offsets {
        draw_pos := add(asteroid_pos, pos_offset)
        eye := dir(draw_pos, players[player_id].pos)
        sq_dist := dot(eye, eye)
        if sq_dist < 100*100 {
          if sq_dist < 80*80 {
            options : DrawOptionsSet
            if sq_dist < 25*25 {
              options = { .Border }
            }
            asteroid_matrix[0, 3] = draw_pos.x
            asteroid_matrix[1, 3] = draw_pos.y
            asteroid_matrix[2, 3] = draw_pos.z
            draw_model(model_asteroid_01, asteroid_matrix, sqrt(3 * 3*3), { MATERIAL_ASTEROID }, options)
          } else if sq_dist < 90*90 {
            screen_point := model_to_screen(V4{ draw_pos.x, draw_pos.y, draw_pos.z, 1 })
            if screen_point.z > 0 {
              x := iround(screen_point.x)
              y := iround(screen_point.y)
              if x > 0 && y > 0 {
                offset := int(7*(time/5) % BLUE_NOISE_SIZE)
                noise_idx := (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
                if blue_noise_void_cluster[noise_idx] > 32 {
                  set_pixel(x, y, .Gray)
                }
                noise_idx = ((x+BLUE_NOISE_SIZE-1) % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
                if blue_noise_void_cluster[noise_idx] > 128 {
                  set_pixel(x-1, y, .Gray)
                }
                noise_idx = ((x+1) % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
                if blue_noise_void_cluster[noise_idx] > 128 {
                  set_pixel(x+1, y, .Gray)
                }
                noise_idx = (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+BLUE_NOISE_SIZE-1+offset) % BLUE_NOISE_SIZE))
                if blue_noise_void_cluster[noise_idx] > 128 {
                  set_pixel(x, y-1, .Gray)
                }
                noise_idx = (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+1+offset) % BLUE_NOISE_SIZE))
                if blue_noise_void_cluster[noise_idx] > 128 {
                  set_pixel(x, y+1, .Gray)
                }
              }
            }
          } else {
            screen_point := model_to_screen(V4{ draw_pos.x, draw_pos.y, draw_pos.z, 1 })
            if screen_point.z > 0 {
              x := iround(screen_point.x)
              y := iround(screen_point.y)
              if x > 0 && y > 0 {
                offset := int(7*(time/5) % BLUE_NOISE_SIZE)
                noise_idx := (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
                if blue_noise_void_cluster[noise_idx] > 64 {
                  set_pixel(x, y, .Gray)
                }
              }
            }
          }
        }
      }
    }
  }

  // PLAYERS
  {
    for player, player_idx in players {
      left_offset :=  mul(player.rotation, V3{ -0.5, 0, 0 })
      right_offset := -left_offset
      material_lamp := .Team2 in player.flags ? MATERIAL_TEAM2_LAMP : MATERIAL_TEAM1_LAMP
      engine_left := MATERIAL_BLACK
      engine_right := MATERIAL_BLACK
      if player.speed/0.01 + 1 > f32(time % 10) {
        engine_left = MATERIAL_ENGINE
        engine_right = MATERIAL_ENGINE
      }

      model_left_matrix := mul(quat_to_mat(player.rotation), mat_scale({ -1, 1, 1 }))
      model_right_matrix := mul(quat_to_mat(player.rotation), mat_scale({ 1, 1, 1 }))
      for pos_offset in valid_offsets {
        draw_pos := add(player.pos, pos_offset)
        eye := dir(draw_pos, players[player_id].pos)
        sq_dist := dot(eye, eye)
        if sq_dist < 190*190 {
          options : DrawOptionsSet
          if sq_dist < 10*10 {
            options = { .Border }
          }
          left_pos := add(draw_pos, left_offset)
          right_pos := add(draw_pos, right_offset)
          model_left_matrix[0, 3] = left_pos.x
          model_left_matrix[1, 3] = left_pos.y
          model_left_matrix[2, 3] = left_pos.z
          draw_model(model_player_ship, model_left_matrix, sqrt(3 * 1*1), { MATERIAL_METAL, material_lamp, engine_left, MATERIAL_BLACK }, options)
          model_right_matrix[0, 3] = right_pos.x
          model_right_matrix[1, 3] = right_pos.y
          model_right_matrix[2, 3] = right_pos.z
          draw_model(model_player_ship, model_right_matrix, sqrt(3 * 1*1), { MATERIAL_METAL, material_lamp, engine_right, MATERIAL_BLACK }, options | { .Reverse_Winding })
        }

        if player_id != u8(player_idx) &&
            (.Team2 in player.flags) == (.Team2 in players[player_id].flags) {
          if sq_dist < min_teammate_sq_dist {
            min_teammate_sq_dist = sq_dist
            min_teammate_pos = draw_pos
          }
        }
      }
    }
  }

  // BASES
  {
    @static base_matrix : Matrix
    base_matrix = mul(quat_to_mat(quat_euler({ 0, f32(time)/220.0, 0 })), mat_scale({ 7, 7, 7 }))
    draw_base :: proc "contextless" (base_pos : V3, team : TeamID, min_base_sq_dist : ^f32, min_base_pos : ^V3) {
      material_lamp := team == .Team2 ? MATERIAL_TEAM2_LAMP : MATERIAL_TEAM1_LAMP
      for pos_offset in valid_offsets {
        draw_pos := add(base_pos, pos_offset)
        // TODO (hitch) 2022-08-19 function candidate: `sq_mag(dir(VECTOR, players[player_id].pos))`
        eye := dir(draw_pos, players[player_id].pos)
        sq_dist := dot(eye, eye)
        if sq_dist < 190*190 {
          options : DrawOptionsSet
          if sq_dist < 100*100 {
            options = { .Border }
          }
          base_matrix[0, 3] = draw_pos.x
          base_matrix[1, 3] = draw_pos.y
          base_matrix[2, 3] = draw_pos.z

          draw_model(model_mine, base_matrix, sqrt(3 * 7*7), { MATERIAL_METAL, material_lamp }, options)
        }

        if (.Team2 in players[player_id].flags) == (team == .Team2)
        {
          if sq_dist < min_base_sq_dist^ {
            min_base_sq_dist^ = sq_dist
            min_base_pos^ = draw_pos
          }
        }
      }
    }

    draw_base({ -50, -50, -50 }, .Team1, &min_base_sq_dist, &min_base_pos)
    draw_base({ 50, 50, 50 }, .Team2, &min_base_sq_dist, &min_base_pos)
  }

  // HUD
  {
    // BARS
    {
      w4.DRAW_COLORS^ = 0x0003
      w4.rect(0, 40, 7, 80)
      w4.rect(w4.SCREEN_SIZE-4, 40, 4, 80)

      // HEALTH BAR
      {
        w4.DRAW_COLORS^ = 0x0001
        w4.rect(1, 41, 2, 78)
        w4.DRAW_COLORS^ = 0x0002
        if current_color == .Red {
          w4.DRAW_COLORS^ = 0x0004
        }
        height := 78*i32(players[player_id].health) / 255
        w4.rect(1, 41+78-height, 2, u32(height))
      }

      // SPEED BAR
      {
        w4.DRAW_COLORS^ = 0x0001
        w4.rect(4, 41, 2, 78)
        w4.DRAW_COLORS^ = 0x0002
        // TODO (hitch) 2022-08-18 CHECK THIS TIMING
        if (time/10)%2 == 0 && time%2 == 0 {
          w4.DRAW_COLORS^ = 0x0003
        }
        height := i32(78*players[player_id].speed)
        w4.rect(4, 41+78-height, 2, u32(height))
      }

      // PHYSIC BAR
      {
        w4.DRAW_COLORS^ = 0x0001
        w4.rect(w4.SCREEN_SIZE-3, 41, 2, 78)
        w4.DRAW_COLORS^ = 0x0002
        if current_color == .Green {
          w4.DRAW_COLORS^ = 0x0004
        }
        height := 78*i32(players[player_id].physic) / 255
        w4.rect(w4.SCREEN_SIZE-3, 41+78-height, 2, u32(height))
      }
    }

    // BASE ICON
    hud_compass_icon(min_base_pos, proc "contextless" (x, y : int) {
        if current_color == current_player_color() {
          w4.DRAW_COLORS^ = 0x0410
        } else {
          w4.DRAW_COLORS^ = 0x0210
        }
        w4.blit(&sprite_hud_home[0], i32(x)-4, i32(y)-5, 9, 10, { .Use_2BPP })
      })

    // TEAMMATE ICON
    {
      if current_color == current_player_color() &&
          min_teammate_sq_dist < 250*250 {
        hud_compass_icon(min_teammate_pos, proc "contextless" (x, y : int) {
            w4.DRAW_COLORS^ = 0x0040
            w4.blit(&sprite_hud_plus[0], i32(x)-2, i32(y)-2, 5, 5)
          })
      }
    }


    // SCORES
    {
      draw_score :: proc "contextless" (score : int, color : Color, x : i32) {
        s := to_str(score)
        w4.DRAW_COLORS^ = 0x0001
        w4.text(s, x + 1 - i32(4*len(s)), 6)
        w4.DRAW_COLORS^ = 0x0003
        w4.text(s, x - i32(4*len(s)), 5)
        if current_color == color {
          left := x - 2 - i32(4*len(s))
          width := i32(8*len(s)) + 2
          w4.DRAW_COLORS^ = 0x0011
          w4.rect(left-1, 2, u32(width)+3, 3)
          w4.DRAW_COLORS^ = 0x0004
          w4.hline(left, 3, u32(width))
          w4.vline(left, 3, 3)
          w4.vline(left+width, 3, 3)
        }
      }

      draw_score(team_1.score, TEAM1_COLOR, 40)
      draw_score(team_2.score, TEAM2_COLOR, 120)
    }
  }
}

DrawCallback :: #type proc "contextless" (x, y : int)
hud_compass_icon :: proc "contextless" (world_pos : V3, draw : DrawCallback) {
  clip_point := model_to_clip(V4{ world_pos.x, world_pos.y, world_pos.z, 1 })
  mag := max(abs(clip_point.x), abs(clip_point.y))
  offscreen := (mag > 1.1)
  if clip_point.z > 1 {
    clip_point.x /= -mag
    clip_point.y /= -mag
    offscreen = true
  } else {
    if clip_point.x < -1 {
      clip_point.x = -1
      clip_point.y /= -clip_point.x
    } else if clip_point.x > 1 {
      clip_point.x = 1
      clip_point.y /= clip_point.x
    }
    if clip_point.y < -1 {
      clip_point.x /= -clip_point.y
      clip_point.y = -1
    } else if clip_point.y > 1 {
      clip_point.x /= clip_point.y
      clip_point.y = 1
    }
  }
  eye := dir(world_pos, players[player_id].pos)
  if dot(eye, eye) > (50*50) || offscreen {
    clip_point.x = w4.SCREEN_SIZE * (0.5 * clamp(clip_point.x, -0.95, 0.94) + 0.5)
    clip_point.y = w4.SCREEN_SIZE * (1-(0.5 * clamp(clip_point.y, -0.925, 0.94) + 0.5))
    draw(iround(clip_point.x), iround(clip_point.y))
  }
}
