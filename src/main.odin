package main

import "core:math"
import "core:math/rand"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

import w4 "wasm4"

time : u32

graphics_rand := rand.create(42)

input_held : [4]^w4.ButtonSet
_input_prev : [4]w4.ButtonSet
input_press : [4]w4.ButtonSet

@export
start :: proc "c" () {
  context = {}

  input_held = { w4.GAMEPAD1, w4.GAMEPAD2, w4.GAMEPAD3, w4.GAMEPAD4 }

  init_math()
  init_graphics()
  players[0].rotation.w = 1
  players[1].rotation.w = 1
  players[2].rotation.w = 1
  players[3].rotation.w = 1
  players[0].speed = 0.05
  players[1].speed = 0.05
  players[2].speed = 0.05
  players[3].speed = 0.05
  players[1].pos.x = 3
  players[2].pos.x = 6
  players[3].pos.x = 9

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

  player_id := (u8(w4.NETPLAY^) & 0b11)
  matrix_view = glm.mat4LookAt(players[player_id].pos + la.mul(players[player_id].rotation, V3{ 0, 1.25, 2 }), players[player_id].pos + 10*la.mul(players[player_id].rotation, V3_FORWARD), la.mul(players[player_id].rotation, V3_UP))

  defer {
    for i in 0..<4 {
      _input_prev[i] = input_held[i]^
    }
  }
  for i in 0..<4 {
    input_press[i] = input_held[i]^ & (input_held[i]^ ~ _input_prev[i])
  }


  for player, i in &players {
    if .A in input_held[i] {
      if .Down in input_held[i] {
        player.speed = max(0, player.speed - 0.001)
      }
      if .Up in input_held[i] {
        player.speed = min(0.1, player.speed + 0.001)
      }
      if .Left in input_held[i] {
        player.rot_velocity.z += 0.04 * player.speed
      }
      if .Right in input_held[i] {
        player.rot_velocity.z -= 0.04 * player.speed
      }
    } else {
      if .Down in input_held[i] {
        player.rot_velocity.x -= 0.02 * player.speed
      }
      if .Up in input_held[i] {
        player.rot_velocity.x += 0.02 * player.speed
      }
      if .Left in input_held[i] {
        player.rot_velocity.y += 0.02 * player.speed
      }
      if .Right in input_held[i] {
        player.rot_velocity.y -= 0.02 * player.speed
      }
    }

    player.rotation = la.normalize(player.rotation * quat_euler(player.rot_velocity))
    player.rot_velocity *= 0.9

    player.pos_velocity += la.mul(player.rotation, V3{ 0, 0, -player.speed })

    player.pos += player.pos_velocity
    player.pos_velocity *= 0.85

    if player.pos.x < -100 {
      player.pos.x += 200
    }
    if player.pos.x > 100 {
      player.pos.x -= 200
    }
    if player.pos.y < -100 {
      player.pos.y += 200
    }
    if player.pos.y > 100 {
      player.pos.y -= 200
    }
    if player.pos.z < -100 {
      player.pos.z += 200
    }
    if player.pos.z > 100 {
      player.pos.z -= 200
    }
  }


  update_pallet()
  clear_depth_buffer()

  star_rand := rand.create(42)
  for star in 0..<25 {
    y := 2*rand.float32(&star_rand) - 1
    draw_star({ 2*rand.float32(&star_rand) - 1, y, 2*rand.float32(&star_rand) - 1 })
  }
  for star in 0..<50 {
    y := 2*rand.float32(&star_rand) - 1
    draw_star({ 2*rand.float32(&star_rand) - 1, y*y, 2*rand.float32(&star_rand) - 1 })
  }
  for star in 0..<100 {
    y := 2*rand.float32(&star_rand) - 1
    draw_star({ 2*rand.float32(&star_rand) - 1, y*y*y, 2*rand.float32(&star_rand) - 1 })
  }

  LOOP_POS :: []V3{
    { -200, -200, -200 },
    { -200, -200,    0 },
    { -200, -200,  200 },
    { -200,    0, -200 },
    { -200,    0,    0 },
    { -200,    0,  200 },
    { -200,  200, -200 },
    { -200,  200,    0 },
    { -200,  200,  200 },
    {    0, -200, -200 },
    {    0, -200,    0 },
    {    0, -200,  200 },
    {    0,    0, -200 },
    {    0,    0,    0 },
    {    0,    0,  200 },
    {    0,  200, -200 },
    {    0,  200,    0 },
    {    0,  200,  200 },
    {  200, -200, -200 },
    {  200, -200,    0 },
    {  200, -200,  200 },
    {  200,    0, -200 },
    {  200,    0,    0 },
    {  200,    0,  200 },
    {  200,  200, -200 },
    {  200,  200,    0 },
    {  200,  200,  200 },
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

    for player, i in &players {
      left_offset :=  la.mul(player.rotation, V3{ -0.5, 0, 0 })
      right_offset := la.mul(player.rotation, V3{  0.5, 0, 0 })
      material_lamp := MATERIAL_ORANGE_LAMP
      if i % 2 == 0 {
        material_lamp = MATERIAL_CYAN_LAMP
      }
      engine_left := MATERIAL_BLACK
      engine_right := MATERIAL_BLACK
      if player.speed/0.01 + 1 > f32(time % 10) {
        engine_left = MATERIAL_ENGINE
        engine_right = MATERIAL_ENGINE
      }
      draw_model(model_player_ship, player.pos + pos_offset + left_offset, { MATERIAL_METAL, material_lamp, engine_left, MATERIAL_BLACK }, player.rotation, { -1, 1, 1 }, { cutoff_distance = 190, border_distance = 10 })
      draw_model(model_player_ship, player.pos + pos_offset + right_offset, { MATERIAL_METAL, material_lamp, engine_right, MATERIAL_BLACK }, player.rotation, V3_ONE, { cutoff_distance = 190, border_distance = 10 })
    }
  }

  w4.DRAW_COLORS^ = 0x0003
  w4.rect(0, 40, 6, 80)
  w4.DRAW_COLORS^ = 0x0001
  w4.rect(1, 41, 4, 78)
  w4.DRAW_COLORS^ = 0x0002
  w4.rect(1, 41+78-int(78*players[player_id].speed/0.1), 4, int(78*players[player_id].speed/0.1))
}
