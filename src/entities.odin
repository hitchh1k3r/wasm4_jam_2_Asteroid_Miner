package main

import la "core:math/linalg"
import glm "core:math/linalg/glsl"

team1_base : EntityBase // 6 bytes
team2_base : EntityBase // 6 bytes
players := (^[4]EntityPlayer)(uintptr(MEM_PLAYERS))

// TODO (hitch) 2022-08-17 Quad tree for collisions (and improved culling)
asteroids := (^[200]EntityAsteroid)(uintptr(MEM_ASTEROIDS))

EntityBase :: struct { // 6 bytes
  pos : H3,            //   6 bytes
}

PlayerFlag :: enum u8 {
  Team2,
}
PlayerFlagSet :: bit_set[PlayerFlag; u8]

EntityPlayer :: struct { // 107 bytes
  speed : f32,           //    4 bytes
  physic : u8,           //    1 byte
  health : u8,           //    1 byte   // goes down 120 per hit, increases 1 every 5 frames
  pos : V3,              //   12 bytes
  rotation : Q,          //   16 bytes
  pos_velocity : V3,     //   12 bytes
  rot_velocity : V3,     //   12 bytes
  trail : [2][4]H3,      //   48 bytes
  flags : PlayerFlagSet, //    1 byte
}

EntityAsteroid :: struct { // 8 bytes
  pos : H3,                //   6 bytes
  variant : u8,            //   1 byte   ///   0b__VVSSTTTT M=model  S=size  T=rotation time offset
  health : u8,             //   1 byte
}

// 16 asteroids per 50x50x50 unit tile
// 1024 max asteroids
// 0b_HH_llllll
// start_offset := 16 * HH
// tile_count := 0..15


setup_player_matrix :: proc() {
  matrix_view = glm.mat4LookAt(players[player_id].pos + la.mul(players[player_id].rotation, V3{ 0, 0.5*players[player_id].speed + 0.6, 1.5*players[player_id].speed+0.5 }), players[player_id].pos + 10*la.mul(players[player_id].rotation, V3_FORWARD), la.mul(players[player_id].rotation, V3_UP))
}

sample_trail :: proc(using player : ^EntityPlayer) {
  LAST_INDEX :: len(trail[0])-1
  for i in 0..<LAST_INDEX {
    trail[0][i] = trail[0][i+1]
    trail[1][i] = trail[1][i+1]
  }

  left_pos :=  la.mul(rotation, V3{ -0.5, 0, 0 })
  left_pos.x += pos.x
  left_pos.y += pos.y
  left_pos.z += pos.z
  right_pos := la.mul(rotation, V3{  0.5, 0, 0 })
  right_pos.x += pos.x
  right_pos.y += pos.y
  right_pos.z += pos.z
  trail[0][LAST_INDEX] = to_h3(left_pos)
  trail[1][LAST_INDEX] = to_h3(right_pos)
}

offset_player :: proc(using player : ^EntityPlayer, offset : V3) {
  pos.x += offset.x
  pos.y += offset.y
  pos.z += offset.z
  for i in 0..<len(trail[0]) {
    for s in 0..=1 {
      v := to_v3(trail[s][i])
      v.x += offset.x
      v.y += offset.y
      v.z += offset.z
      trail[s][i] = to_h3(v)
    }
  }
  setup_player_matrix()
}

player_color :: proc() -> Color {
  return .Team2 in players[player_id].flags ? TEAM2_COLOR : TEAM1_COLOR
}
