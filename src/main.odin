package main

import "core:math"
import "core:math/rand"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

import w4 "wasm4"

time : u32

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
  players[1].pos.x = 3
  players[2].pos.x = 6
  players[3].pos.x = 9
}

@export
update :: proc "c" () {
  context = {}

  time += 1

  defer {
    for i in 0..<4 {
      _input_prev[i] = input_held[i]^
    }
  }
  for i in 0..<4 {
    input_press[i] = input_held[i]^ & (input_held[i]^ ~ _input_prev[i])
  }

  update_pallet()
  clear_depth_buffer()

  matrix_view = glm.mat4LookAt(players[0].pos + la.mul(players[0].rotation, V3{ 0, 0.2, 0.5 }), players[0].pos + 10*la.mul(players[0].rotation, V3_FORWARD), la.mul(players[0].rotation, V3_UP))

  star_rand := rand.create(42)
  for star in 0..<100 {
    draw_star({ 2*rand.float32(&star_rand) - 1, 2*rand.float32(&star_rand) - 1, 2*rand.float32(&star_rand) - 1 }, (rand.float32(&star_rand) > 0.9 ? .White : .Gray))
  }

  draw_model(model_asteroid_01, { 0, 0, 0 }, { material_asteroid }, quatAxisAngle(V3_UP, 0.5*f32(time)/60.0) * quatAxisAngle(V3_RIGHT, 0.3333*f32(time)/60.0))

  for player, i in &players {
    pitch : f32
    yaw_roll : f32
    if .Down in input_held[i] {
      pitch += 0.01
    }
    if .Up in input_held[i] {
      pitch -= 0.01
    }
    if .Left in input_held[i] {
      yaw_roll -= 0.01
    }
    if .Right in input_held[i] {
      yaw_roll += 0.01
    }

    player.rotation = la.normalize(player.rotation * quatAxisAngle(V3_RIGHT, math.TAU+pitch))
    if .A in input_held[i] {
      player.rotation = player.rotation * quatAxisAngle(V3_FORWARD, math.TAU+2*yaw_roll)
    } else {
      player.rotation = player.rotation * quatAxisAngle(V3_UP, math.TAU-yaw_roll)
    }
    player.rotation = la.normalize(player.rotation)

    player.pos += la.mul(player.rotation, V3{ 0, 0, -0.05 })
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

    left_offset :=  la.mul(player.rotation, V3{ -0.5, 0, 0 })
    right_offset := la.mul(player.rotation, V3{  0.5, 0, 0 })
    material_lamp := material_orange_lamp
    if i % 2 == 0 {
      material_lamp = material_cyan_lamp
    }
    draw_model(model_player_ship, player.pos + left_offset, { material_metal, material_lamp, material_engine, material_black }, player.rotation, { -1, 1, 1 })
    draw_model(model_player_ship, player.pos + right_offset, { material_metal, material_lamp, material_engine, material_black }, player.rotation)
  }
}
