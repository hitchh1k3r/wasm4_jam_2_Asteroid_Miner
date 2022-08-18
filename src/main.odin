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
  context = {}

  input_held = { w4.GAMEPAD1, w4.GAMEPAD2, w4.GAMEPAD3, w4.GAMEPAD4 }

  init_math()
  init_graphics()

  for i in 0..<4 {
    players[i].rotation.w = 1
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

  team1_base.pos = to_h3(V3{ -50, -50, -50 })
  team2_base.pos = to_h3(V3{ 50, 50, 50 })

  level_rand := rand.create(42)
  for asteroid in asteroids {
    asteroid.pos.x = u16(rand.uint32(&level_rand))
    asteroid.pos.y = u16(rand.uint32(&level_rand))
    asteroid.pos.z = u16(rand.uint32(&level_rand))
    asteroid.variant = u8(rand.uint32(&level_rand))
    asteroid.health = 255
  }
}

@export
update :: proc "c" () {
  context = {}

  time += 1
  player_id = (u8(w4.NETPLAY^) & 0b11)

  setup_player_matrix()

  defer {
    for i in 0..<4 {
      _input_prev[i] = input_held[i]^
    }
  }
  for i in 0..<4 {
    input_press[i] = input_held[i]^ & (input_held[i]^ ~ _input_prev[i])
  }


  for player, i in players {
    if player.health < 255 && time % 15 == 0 {
      player.health += 1
    }

    effective_speed := 1-player.speed
    effective_speed = 1 - 0.9*effective_speed*effective_speed
    if .A in input_held[i] {
      if .Down in input_held[i] {
        player.speed = max(0, player.speed - 0.02)
      }
      if .Up in input_held[i] {
        player.speed = min(1, player.speed + 0.02)
      }
      if .Left in input_held[i] {
        player.rot_velocity.z += 0.01 * effective_speed
      }
      if .Right in input_held[i] {
        player.rot_velocity.z -= 0.01 * effective_speed
      }
    } else {
      if .Down in input_held[i] {
        player.rot_velocity.x -= 0.005 * effective_speed
      }
      if .Up in input_held[i] {
        player.rot_velocity.x += 0.005 * effective_speed
      }
      if .Left in input_held[i] {
        player.rot_velocity.y += 0.005 * effective_speed
      }
      if .Right in input_held[i] {
        player.rot_velocity.y -= 0.005 * effective_speed
      }
    }

    player.rotation = la.normalize(player.rotation * quat_euler(player.rot_velocity))
    player.rot_velocity *= 0.9

    player.pos_velocity += la.mul(player.rotation, V3{ 0, 0, -0.1*player.speed })

    player.pos += player.pos_velocity
    player.pos_velocity *= 0.85

    if time % 30 == 0 {
      sample_trail(&player)
    }

    if player.pos.x < -WORLD_SIZE/2 {
      offset_player(&player, { WORLD_SIZE, 0, 0 })
    }
    if player.pos.x > WORLD_SIZE/2 {
      offset_player(&player, { -WORLD_SIZE, 0, 0 })
    }
    if player.pos.y < -WORLD_SIZE/2 {
      offset_player(&player, { 0, WORLD_SIZE, 0 })
    }
    if player.pos.y > WORLD_SIZE/2 {
      offset_player(&player, { 0, -WORLD_SIZE, 0 })
    }
    if player.pos.z < -WORLD_SIZE/2 {
      offset_player(&player, { 0, 0, WORLD_SIZE })
    }
    if player.pos.z > WORLD_SIZE/2 {
      offset_player(&player, { 0, 0, -WORLD_SIZE })
    }
  }


  update_pallet()
  clear_depth_buffer()

  star_rand := rand.create(42)
  for star in 0..<300 {
    y := 2*rand.float32(&star_rand) - 1
    draw_star({ 2*rand.float32(&star_rand) - 1, y*y*y, 2*rand.float32(&star_rand) - 1 })
  }

  min_base_dist := max(f32)
  min_base_pos : V3
  min_teammate_dist := max(f32)
  min_teammate_pos : V3

  LOOP_POS :: []V3{
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
    {           0,           0,           0 },
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
  for pos_offset in LOOP_POS {
    if (pos_offset.x < 0 && players[player_id].pos.x > 0) ||
       (pos_offset.x > 0 && players[player_id].pos.x < 0) ||
       (pos_offset.y < 0 && players[player_id].pos.y > 0) ||
       (pos_offset.y > 0 && players[player_id].pos.y < 0) ||
       (pos_offset.z < 0 && players[player_id].pos.z > 0) ||
       (pos_offset.z > 0 && players[player_id].pos.z < 0) {
      continue
    }

    no_offset := (pos_offset.x == 0 && pos_offset.y == 0 && pos_offset.z == 0)

    for asteroid in asteroids {
      // TODO (hitch) 2022-08-16 LOD draw Z-Test
      draw_pos := to_v3(asteroid.pos)
      draw_pos.x += pos_offset.x
      draw_pos.y += pos_offset.y
      draw_pos.z += pos_offset.z
      draw_model(model_asteroid_01, draw_pos, { MATERIAL_ASTEROID }, quat_euler({ f32(time)/20.0, f32(time)/30.0, f32(time)/45.0 }), { 3, 3, 3 }, {
        cutoff_distance = 100,
        lod_0_distance = 90, lod_0_callback = proc(distance : f16, center : V3, rotation : Q, size : V3) {
          screen_point := model_to_screen(V4{ center.x, center.y, center.z, 1 })
          x := iround(screen_point.x)
          y := iround(screen_point.y)
          if x > 0 && y > 0 {
            offset := int(7*(time/5) % BLUE_NOISE_SIZE)
            noise_idx := (x % BLUE_NOISE_SIZE) + (BLUE_NOISE_SIZE*((y+offset) % BLUE_NOISE_SIZE))
            if blue_noise_void_cluster[noise_idx] > 64 {
              set_pixel(x, y, .Gray)
            }
          }
        }, lod_1_distance = 80, lod_1_callback = proc(distance : f16, center : V3, rotation : Q, size : V3) {
          screen_point := model_to_screen(V4{ center.x, center.y, center.z, 1 })
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
        }, border_distance = 25 })
    }

    for player, player_idx in players {
      draw_pos := player.pos
      draw_pos.x += pos_offset.x
      draw_pos.y += pos_offset.y
      draw_pos.z += pos_offset.z
      left_pos :=  la.mul(player.rotation, V3{ -0.5, 0, 0 })
      left_pos.x += draw_pos.x
      left_pos.y += draw_pos.y
      left_pos.z += draw_pos.z
      right_pos := la.mul(player.rotation, V3{  0.5, 0, 0 })
      right_pos.x += draw_pos.x
      right_pos.y += draw_pos.y
      right_pos.z += draw_pos.z
      material_lamp := .Team2 in player.flags ? MATERIAL_TEAM2_LAMP : MATERIAL_TEAM1_LAMP
      engine_left := MATERIAL_BLACK
      engine_right := MATERIAL_BLACK
      if player.speed/0.01 + 1 > f32(time % 10) {
        engine_left = MATERIAL_ENGINE
        engine_right = MATERIAL_ENGINE
      }
      draw_model(model_player_ship, left_pos, { MATERIAL_METAL, material_lamp, engine_left, MATERIAL_BLACK }, player.rotation, { -1, 1, 1 }, { cutoff_distance = 190, border_distance = 10 })
      draw_model(model_player_ship, right_pos, { MATERIAL_METAL, material_lamp, engine_right, MATERIAL_BLACK }, player.rotation, V3_ONE, { cutoff_distance = 190, border_distance = 10 })

      if player_id != u8(player_idx) &&
          (.Team2 in player.flags) == (.Team2 in players[player_id].flags) {
        dist := distance(draw_pos, players[player_id].pos)
        if dist < min_teammate_dist {
          min_teammate_dist = dist
          min_teammate_pos = draw_pos
        }
      }
    }

    // BASES
    {
      draw_base :: proc(base : EntityBase, pos_offset : V3, team : TeamID, min_base_dist : ^f32, min_base_pos : ^V3) {
        draw_pos := to_v3(base.pos)
        draw_pos.x += pos_offset.x
        draw_pos.y += pos_offset.y
        draw_pos.z += pos_offset.z
        material_lamp := team == .Team2 ? MATERIAL_TEAM2_LAMP : MATERIAL_TEAM1_LAMP
        draw_model(model_mine, draw_pos, { MATERIAL_METAL, material_lamp }, Q_ID, { 7, 7, 7 }, { cutoff_distance = 190, border_distance = 100 })

        if (.Team2 in players[player_id].flags) == (team == .Team2)
        {
          dist := distance(draw_pos, players[player_id].pos)
          if dist < min_base_dist^ {
            min_base_dist^ = dist
            min_base_pos^ = draw_pos
          }
        }
      }

      draw_base(team1_base, pos_offset, .Team1, &min_base_dist, &min_base_pos)
      draw_base(team2_base, pos_offset, .Team2, &min_base_dist, &min_base_pos)
    }
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
        w4.rect(1, 41+78-height, 2, height)
      }

      // SPEED BAR
      {
        w4.DRAW_COLORS^ = 0x0001
        w4.rect(4, 41, 2, 78)
        w4.DRAW_COLORS^ = 0x0002
        if current_color == .Green && time%2 == 0 {
          w4.DRAW_COLORS^ = 0x0003
        }
        height := i32(78*players[player_id].speed)
        w4.rect(4, 41+78-height, 2, height)
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
        w4.rect(w4.SCREEN_SIZE-3, 41+78-height, 2, height)
      }
    }

    // BASE ICON
    hud_compass_icon(min_base_pos, proc(x, y : int) {
        if current_color == player_color() {
          w4.DRAW_COLORS^ = 0x0410
        } else {
          w4.DRAW_COLORS^ = 0x0210
        }
        w4.blit(&sprite_hud_home[0], x-4, y-5, 9, 10, { .Use_2BPP })
      })

    // TEAMMATE ICON
    {
      if current_color == player_color() &&
          min_teammate_dist < 250 {
        hud_compass_icon(min_teammate_pos, proc(x, y : int) {
            w4.DRAW_COLORS^ = 0x0040
            w4.blit(&sprite_hud_plus[0], x-2, y-2, 5, 5)
          })
      }
    }


    // SCORES
    {
      draw_score :: proc(score : int, color : Color, x : i32) {
        s := to_str(score)
        w4.DRAW_COLORS^ = 0x0001
        w4.text(s, x + 1 - i32(4*len(s)), 6)
        w4.DRAW_COLORS^ = 0x0003
        w4.text(s, x - i32(4*len(s)), 5)
        if current_color == color {
          left := x - 2 - i32(4*len(s))
          width := i32(8*len(s)) + 2
          w4.DRAW_COLORS^ = 0x0011
          w4.rect(left-1, 2, width+3, 3)
          w4.DRAW_COLORS^ = 0x0004
          w4.hline(left, 3, width)
          w4.vline(left, 3, 3)
          w4.vline(left+width, 3, 3)
        }
      }

      draw_score(team_1.score, TEAM1_COLOR, 40)
      draw_score(team_2.score, TEAM2_COLOR, 120)
    }
  }

}

DrawCallback :: #type proc(x, y : int)
hud_compass_icon :: proc(world_pos : V3, draw : DrawCallback)
{
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
  if (distance(world_pos, players[player_id].pos) > 50 || offscreen) {
    clip_point.x = w4.SCREEN_SIZE * (0.5 * clamp(clip_point.x, -0.95, 0.94) + 0.5)
    clip_point.y = w4.SCREEN_SIZE * (1-(0.5 * clamp(clip_point.y, -0.925, 0.94) + 0.5))
    draw(iround(clip_point.x), iround(clip_point.y))
  }
}

distance :: proc "contextless" (a, b : V3) -> f32 {
  x := abs(a.x - b.x)
  y := abs(a.y - b.y)
  z := abs(a.z - b.z)
  return math.sqrt(x*x + y*y + z*z)
}
