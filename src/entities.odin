package main

import w4 "wasm4"

players := (^[4]EntityPlayer)(uintptr(MEM_PLAYERS))
asteroids := (^[1024]EntityAsteroid)(uintptr(MEM_ASTEROIDS))
// 16 asteroids per 50x50x50 unit tile
// 1024 max asteroids
// 0b_HH_llllll
// start_offset := 16 * HH
// tile_count := 0..15

// Player Ship /////////////////////////////////////////////////////////////////////////////////////

TRAIL_LENGHT :: 8

PlayerFlag :: enum u8 {
  Team2,
}
PlayerFlagSet :: bit_set[PlayerFlag; u8]

EntityPlayer :: struct {       // 103 bytes
  speed : f32,                 //    4 bytes
  physic : u8,                 //    1 byte
  health : u8,                 //    1 byte   // goes down 120 per hit, increases 1 every 5 frames
  pos : V3,                    //   12 bytes
  rotation : Quat,             //   12 bytes
  pos_velocity : V3,           //   12 bytes
  rot_velocity : V3,           //   12 bytes
  trail : [2][TRAIL_LENGHT]H3, //   96 bytes  // we could reduce the resolution (less than H3), and only record one pos and an aproximate roll
  flags : PlayerFlagSet,       //    1 byte
}

setup_current_player_view_matrix :: proc "contextless" () {
  look_from := add(players[player_id].pos, mul(players[player_id].rotation, V3{ 0, 0.5*players[player_id].speed + 0.6, 1.5*players[player_id].speed+0.5 }))
  look_at := add(players[player_id].pos, mul(10.0, mul(players[player_id].rotation, V3_FORWARD)))
  look_up := mul(players[player_id].rotation, V3_UP)

  matrix_view = mat_look(look_from, look_at, look_up)
  
}

current_player_color :: proc "contextless" () -> Color {
  return .Team2 in players[player_id].flags ? TEAM2_COLOR : TEAM1_COLOR
}

update_player :: proc "contextless" (using player : ^EntityPlayer, player_idx : int) {
  if player.health < 255 && time % 15 == 0 {
    player.health += 1
  }

  effective_speed := 0.1+ease_quad_out(0.94*player.speed)
  if .A in input_held[player_idx] {
    if .Down in input_held[player_idx] {
      player.speed = max(0, player.speed - 0.01)
    }
    if .Up in input_held[player_idx] {
      player.speed = min(1, player.speed + 0.02)
    }
    if .Left in input_held[player_idx] {
      player.rot_velocity.z += 0.01 * effective_speed
    }
    if .Right in input_held[player_idx] {
      player.rot_velocity.z -= 0.01 * effective_speed
    }
  } else {
    if .Down in input_held[player_idx] {
      player.rot_velocity.x -= 0.005 * effective_speed
    }
    if .Up in input_held[player_idx] {
      player.rot_velocity.x += 0.005 * effective_speed
    }
    if .Left in input_held[player_idx] {
      player.rot_velocity.y += 0.005 * effective_speed
    }
    if .Right in input_held[player_idx] {
      player.rot_velocity.y -= 0.005 * effective_speed
    }
  }

  player.rotation = mul(player.rotation, quat_euler(player.rot_velocity))
  player.rot_velocity = mul(0.9, player.rot_velocity)

  player.pos_velocity = add(player.pos_velocity, mul(player.rotation, V3{ 0, 0, -0.1*player.speed }))
  player.pos = add(player.pos, player.pos_velocity)
  player.pos_velocity = mul(0.85, player.pos_velocity)

  if time % 15 == 0 {
    sample_trail(player)
  }

  if player.pos.x < -WORLD_SIZE/2 {
    offset_player(player, { WORLD_SIZE, 0, 0 })
  }
  if player.pos.x > WORLD_SIZE/2 {
    offset_player(player, { -WORLD_SIZE, 0, 0 })
  }
  if player.pos.y < -WORLD_SIZE/2 {
    offset_player(player, { 0, WORLD_SIZE, 0 })
  }
  if player.pos.y > WORLD_SIZE/2 {
    offset_player(player, { 0, -WORLD_SIZE, 0 })
  }
  if player.pos.z < -WORLD_SIZE/2 {
    offset_player(player, { 0, 0, WORLD_SIZE })
  }
  if player.pos.z > WORLD_SIZE/2 {
    offset_player(player, { 0, 0, -WORLD_SIZE })
  }
}

sample_trail :: proc "contextless" (using player : ^EntityPlayer) {
  for i in 0..<TRAIL_LENGHT-1 {
    trail[0][i] = trail[0][i+1]
    trail[1][i] = trail[1][i+1]
  }

  left_pos := add(pos, mul(rotation, V3{ -0.5, 0, 0 }))
  right_pos := add(pos, mul(rotation, V3{  0.5, 0, 0 }))
  trail[0][TRAIL_LENGHT-1] = to_h3(left_pos)
  trail[1][TRAIL_LENGHT-1] = to_h3(right_pos)
}

offset_player :: proc "contextless" (using player : ^EntityPlayer, offset : V3) {
  pos = add(pos, offset)
  for i in 0..<TRAIL_LENGHT {
    trail[0][i] = to_h3(add(to_v3(trail[0][i]), offset))
    trail[1][i] = to_h3(add(to_v3(trail[1][i]), offset))
  }
  setup_current_player_view_matrix()
}

// Asteroid ////////////////////////////////////////////////////////////////////////////////////////

EntityAsteroid :: struct { // 8 bytes
  pos : H3,                //   6 bytes
  occupancy : u8,          //   1 byte   // 0b__E?SSSSSS  E=enabled  S=partition protrusions
  variant : u8,            //   1 byte   // 0b__VVVSTTTT  V=direction  S=size  T=rotation time offset
}
