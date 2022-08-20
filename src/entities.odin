package main

import "core:math/rand"

import w4 "wasm4"

entity_rand : rand.Rand
players := (^[4]EntityPlayer)(uintptr(MEM_PLAYERS))
entities := (^[1024]EntityUnion)(uintptr(MEM_ENTITIES))
entity_count : int

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

  if screen_shake > 0 {
    // TODO (hitch) 2022-08-20 NUKE CONTEXT
    context = {}
    matrix_view = mul(quat_to_mat(quat_euler({ 0, 0, rand.float32(&graphics_rand)*f32(screen_shake)/60 })), matrix_view)
  }
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

// Entities //////////////////////////////////////////////////////////////////////////////////////

EntityUnion :: union {
  EntityAsteroid,
}

add_entity :: proc "contextless" (entity : EntityUnion) -> bool {
  if entity_count < len(entities) {
    entities[entity_count] = entity
    entity_count += 1
    return true
  }
  return false
}

remove_entity :: proc "contextless" (idx : int) {
  // assert(entity_count > idx)

  entities[idx] = entities[entity_count]
  entity_count -= 1
}

update_entity :: proc "contextless" (entity : ^EntityUnion, entity_idx : ^int) {
  switch entity in entity {
    case EntityAsteroid:
      update_asteroid(&entity, entity_idx)
  }
}

// Asteroid ////////////////////////////////////////////////////////////////////////////////////////

EntityAsteroid :: struct { // 8 bytes
  pos : H3,                //   6 bytes
  variant : u8,            //   1 byte   // 0b__SSVVVVVV  V=velocity  S=size
  state : u8,              //   1 byte   // 0b__???IIIII  I=invincibility
}

update_asteroid :: proc "contextless" (using asteroid : ^EntityAsteroid, entity_idx : ^int) {
  MoveDirection :: enum u8 { D_1, D_2, D_3, D_4, D_5, D_6 }
  MoveDirectionSet :: bit_set[MoveDirection; u8]
  velocity_dirs := [MoveDirection][3]i32 {
    .D_1 = {  19,  -4, -12 },
    .D_2 = { -11, -20,  12 },
    .D_3 = { -13,   2,  -9 },
    .D_4 = {  10,  19,  11 },
    .D_5 = {  -1,   8,  13 },
    .D_6 = {  -7,  17,   7 },
  }
  velocity_set := transmute(MoveDirectionSet)(variant & 0b00111111)
  velocity : [3]i32
  for offset, direction in velocity_dirs {
    if direction in velocity_set {
      velocity.x += offset.x
      velocity.y += offset.y
      velocity.z += offset.z
    }
  }

  size := i32((variant & 0b__11_000000) >> 6)

  H_SIZE :: 65536
  pos.x = u16((i32(pos.x) + H_SIZE + velocity.x/(size+1)) % H_SIZE)
  pos.y = u16((i32(pos.y) + H_SIZE + velocity.y/(size+1)) % H_SIZE)
  pos.z = u16((i32(pos.z) + H_SIZE + velocity.z/(size+1)) % H_SIZE)

  destroy := false
  spawn := false

  invincibility := state & 0b__000_11111
  if invincibility > 0 {
    invincibility -= 1
    state = (state & 0b__111_00000) | invincibility
  } else {
    if invincibility == 0 && test_overlap(pos, u8(size), to_h3(players[0].pos), 2) {
      players[0].health = players[0].health - min(120, players[0].health)
      screen_shake = max(30, screen_shake)
      destroy = true
      spawn = true
    }
    for other_idx := entity_idx^+1; other_idx < entity_count; other_idx += 1 {
      switch entity in entities[other_idx] {
        case EntityAsteroid:
          // DO COLLISION
      }
    }
  }

  spawn_pos := pos
  if destroy {
    remove_entity(entity_idx^)
    entity_idx^ -= 1
  }

  if spawn && size > 0 {
    // TODO (hitch) 2022-08-20 NUKE CONTEXT
    context = {}
    variant : u8

    variant = (u8(rand.uint32(&entity_rand)) & 0b__00_111111) | (u8(size-1) << 6)
    add_entity(EntityAsteroid{ spawn_pos, variant, 31 })

    variant = (u8(rand.uint32(&entity_rand)) & 0b__00_111111) | (u8(size-1) << 6)
    add_entity(EntityAsteroid{ spawn_pos, variant, 31 })
  }

  test_overlap :: proc "contextless" (asteroid_pos : H3, asteroid_size : u8, other_pos : H3, other_size : u8) -> bool {
    // TODO (hitch) 2022-08-20 Collision misses offten
    radius := f32(0)
    switch asteroid_size {
      case 0:
        radius += 0.5
      case 1:
        radius += 1
      case 2:
        radius += 2
      case 3:
        radius += 4
    }
    switch other_size {
      case 0:
        radius += 0.5
      case 1:
        radius += 1
      case 2:
        radius += 2
      case 3:
        radius += 4
    }
    radius *= WORLD_TO_H
    dx := f32(asteroid_pos.x - other_pos.x)
    dy := f32(asteroid_pos.y - other_pos.y)
    dz := f32(asteroid_pos.z - other_pos.z)
    sq_dist := dx*dx + dy*dy + dz*dz
    return sq_dist < radius*radius
  }
}