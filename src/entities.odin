package main

import w4 "wasm4"

MAX_ENTITIES :: 1024
entity_rand : Rand
players := (^[4]EntityPlayer)(uintptr(MEM_PLAYERS))
entities := (^[MAX_ENTITIES]EntityUnion)(uintptr(MEM_ENTITIES))
entity_count : int
asteroid_count : i16

// Player Ship /////////////////////////////////////////////////////////////////////////////////////

  TRAIL_LENGHT :: 32

  PlayerFlag :: enum u8 {
    Team2,
  }
  PlayerFlagSet :: bit_set[PlayerFlag; u8]

  EntityPlayer :: struct {       // 106 bytes
    mute_music : bool,           //    1 byte
    speed : f32,                 //    4 bytes
    physic : u8,                 //    1 byte
    health : u8,                 //    1 byte   // goes down 120 per hit, increases 1 every 5 frames
    respawn_time : u16,          //    2 bytes
    invincibility : u8,          //    1 byte
    pos : V3,                    //   12 bytes
    rotation : Quat,             //   12 bytes
    pos_velocity : V3,           //   12 bytes
    rot_velocity : V3,           //   12 bytes
    trail : [2][TRAIL_LENGHT]H3, //   96 bytes  // we could reduce the resolution (less than H3), and only record one pos and an aproximate roll
    flags : PlayerFlagSet,       //    1 byte
  }

  setup_current_player_view_matrix :: proc "contextless" () {
    speed_precent := 1.25*players[player_id].speed / (0.25+max(0.1, f32(players[player_id].health)/255))
    look_from := add(players[player_id].pos, mul(players[player_id].rotation, V3{ 0, 0.5*speed_precent + 0.6, 1.5*speed_precent+0.5 }))
    look_at := add(players[player_id].pos, mul(10.0, mul(players[player_id].rotation, V3_FORWARD)))
    look_up := mul(players[player_id].rotation, V3_UP)

    matrix_view = mat_look(look_from, look_at, look_up)

    if screen_shake > 0 {
      matrix_view = mul(quat_to_mat(quat_euler({ 0, 0, rand_float32(&graphics_rand)*f32(screen_shake)/60 })), matrix_view)
    }
  }

  current_player_color :: proc "contextless" () -> Color {
    return .Team2 in players[player_id].flags ? TEAM2_COLOR : TEAM1_COLOR
  }

  update_player :: proc "contextless" (using player : ^EntityPlayer, player_idx : int) {
    if time % 6 == 0 {
      sample_trail(player)
    }

    if respawn_time > 0 {
      respawn_time -= 1
    }

    if health == 0 {
      if respawn_time < 1550 && .A in input_press[player_idx] {
        if respawn_time == 0 {
          speed = 0.5
          if .Team2 in player.flags {
            pos = TEAM2_LAUNCH
          } else {
            pos = TEAM1_LAUNCH
          }
          pos.y += 3*(f32(player_idx)-1.5)
          physic = 0
          health = 255
          for _ in 0..<TRAIL_LENGHT {
            sample_trail(player)
          }
          return
        }

        if .Team2 in flags {
          if team_2.physic_collected >= u32(respawn_time) {
            team_2.physic_collected -= u32(respawn_time)
            respawn_time = 0
          }
        } else {
          if team_1.physic_collected >= u32(respawn_time) {
            team_1.physic_collected -= u32(respawn_time)
            respawn_time = 0
          }
        }
      }

      speed = 0
      rotation = mul(rotation, quat_euler({ 0, 0.003, 0 }))
      if physic > 0 {
        add_entity(EntityPhysic{ to_h3(pos), 255, physic })
        physic = 0
      }
      return
    }

    if invincibility > 0 {
      invincibility -= 1
    }
    if invincibility == 0 && health < 255 && time % 15 == 0 {
      health += 1
    }

    effective_speed := 0.1+ease_quad_out(0.94*speed)
    if .A in input_held[player_idx] {
      if .B in input_press[player_idx] && physic >= 100 {
        physic -= 100
        play_sound_effect(.Mine_Place, pos, 1.0)
        add_entity(EntityMine{ to_h3(add(pos, mul(rotation, V3{ 0, 0, 2 }))), false })
      }
      if .Down in input_held[player_idx] {
        speed -= 0.01
      }
      if .Up in input_held[player_idx] {
        speed += 0.02
      }
      if .Left in input_held[player_idx] {
        rot_velocity.z += 0.01 * effective_speed
      }
      if .Right in input_held[player_idx] {
        rot_velocity.z -= 0.01 * effective_speed
      }
    } else {
      if .B in input_press[player_idx] {
        play_sound_effect(.Player_Laser, pos, 1.0)
        forward := mul(rotation, V3_FORWARD)
        norm : [3]u16
        norm.x = u16(31 * (0.5*forward.x + 0.5))
        norm.y = u16(31 * (0.5*forward.y + 0.5))
        norm.z = u16(31 * (0.5*forward.z + 0.5))
        add_entity(EntityLaser{ to_h3(add(pos, forward)), 30, (norm.x << 10) | (norm.y << 5) | norm.z })
      }
      if .Down in input_held[player_idx] {
        rot_velocity.x -= 0.005 * effective_speed
      }
      if .Up in input_held[player_idx] {
        rot_velocity.x += 0.005 * effective_speed
      }
      if .Left in input_held[player_idx] {
        rot_velocity.y += 0.005 * effective_speed
      }
      if .Right in input_held[player_idx] {
        rot_velocity.y -= 0.005 * effective_speed
      }
    }
    speed = clamp(speed, 0, f32(health)/255)

    rotation = mul(rotation, quat_euler(rot_velocity))
    rot_velocity = mul(0.9, rot_velocity)

    pos_velocity = add(pos_velocity, mul(rotation, V3{ 0, 0, -0.1*speed }))
    pos = add(pos, pos_velocity)
    pos_velocity = mul(0.85, pos_velocity)

    if pos.x < -WORLD_SIZE/2 {
      offset_player(player, { WORLD_SIZE, 0, 0 })
    }
    if pos.x > WORLD_SIZE/2 {
      offset_player(player, { -WORLD_SIZE, 0, 0 })
    }
    if pos.y < -WORLD_SIZE/2 {
      offset_player(player, { 0, WORLD_SIZE, 0 })
    }
    if pos.y > WORLD_SIZE/2 {
      offset_player(player, { 0, -WORLD_SIZE, 0 })
    }
    if pos.z < -WORLD_SIZE/2 {
      offset_player(player, { 0, 0, WORLD_SIZE })
    }
    if pos.z > WORLD_SIZE/2 {
      offset_player(player, { 0, 0, -WORLD_SIZE })
    }

    if invincibility == 0 {
      for other, other_idx in players {
        if player_idx != other_idx && other.invincibility == 0 && test_overlap(pos, 0.5, other.pos, 0.5) {
          damage := u8(clamp((0.8*speed + 0.2*other.speed) * 255, 0, 255))
          other_damage := u8(clamp((0.2*speed + 0.8*other.speed) * 255, 0, 255))
          play_sound_effect(.Player_Death, other.pos, 0.8*max(speed, other.speed))
          damage_player(player, u8(player_idx), damage)
          damage_player(&other, u8(other_idx), other_damage)
          invincibility = 60
          other.invincibility = 60
        }
      }
    }

    eject_from_sphere :: proc "contextless" (using player : ^EntityPlayer, center : V3, radius : f32) {
      offset := dir(center, pos)
      sq_mag := dot(offset, offset)
      if sq_mag < radius*radius {
        ejection := mul(1/sqrt(sq_mag), offset)
        pos = add(center, mul(radius+0.1, ejection))
        setup_current_player_view_matrix()
      }
    }
    eject_from_sphere(player, { -50, -50, -50 }, 7)
    eject_from_sphere(player, {  50,  50,  50 }, 7)

    // in range
    {
      base_pos : V3 = .Team2 in flags ? { 50, 50, 50 } : { -50, -50, -50 }
      if test_overlap(base_pos, 20, pos, 0.5) {
        if health < 255 {
          health += 1
        }
        if physic > 0 {
          physic -= 1
          if .Team2 in flags {
            team_2.physic_collected += 1
          } else {
            team_1.physic_collected += 1
          }
        }
      }
    }
  }

  sample_trail :: proc "contextless" (using player : ^EntityPlayer) {
    for i in 0..<TRAIL_LENGHT-1 {
      trail[0][i] = trail[0][i+1]
      trail[1][i] = trail[1][i+1]
    }

    left_pos := add(pos, mul(rotation, V3{ -1.1, -0.5, 0 }))
    right_pos := add(pos, mul(rotation, V3{  1.1, -0.5, 0 }))
    trail[0][TRAIL_LENGHT-1] = to_h3(left_pos)
    trail[1][TRAIL_LENGHT-1] = to_h3(right_pos)
  }

  damage_player :: proc "contextless" (using player : ^EntityPlayer, player_idx : u8, damage : u8) {
    player.health = player.health - min(damage, player.health)
    if player_idx == player_id {
      screen_shake = max(damage/3, max(10, screen_shake))
    }
  }

  offset_player :: proc "contextless" (using player : ^EntityPlayer, offset : V3) {
    pos = add(pos, offset)
    setup_current_player_view_matrix()
  }

// Entities //////////////////////////////////////////////////////////////////////////////////////

  EntityUnion :: union {
    EntityAsteroid,
    EntityPhysic,
    EntityLaser,
    EntityMine,
  }

  get_priority :: proc "contextless" (entity : EntityUnion) -> int {
    switch entity in entity {
      case EntityAsteroid:
        return int((entity.variant & 0b__11_000000) >> 6) + 1
      case EntityPhysic:
        return 10
      case EntityLaser:
        return 7
      case EntityMine:
        return 5
    }
    return 0
  }

  add_entity :: proc "contextless" (entity : EntityUnion) -> bool {
    if _, ok := entity.(EntityAsteroid); ok {
      asteroid_count += 1
    }
    if entity_count < len(entities) {
      entities[entity_count] = entity
      entity_count += 1
      return true
    } else {
      min_priority := max(int)
      min_idx := -1
      for entity, entity_idx in entities {
        priority := get_priority(entity)
        if priority < min_priority {
          min_priority = priority
          min_idx = entity_idx
        }
      }
      if min_idx >= 0 && min_priority < get_priority(entity) {
        entities[min_idx] = entity
      }
    }
    return false
  }

  remove_entity :: proc "contextless" (idx : int) {
    // assert(entity_count > idx)

    if _, ok := entities[idx].(EntityAsteroid); ok {
      asteroid_count -= 1
    }

    entities[idx] = entities[entity_count-1]
    entity_count -= 1

    for (asteroid_count < game_settings.num_asteroids) {
      add_entity(EntityAsteroid{
          pos = {u16(rand_uint32(&level_rand)), u16(rand_uint32(&level_rand)), u16(rand_uint32(&level_rand))},
          variant = u8(rand_uint32(&entity_rand)),
          state = 0,
        })
    }
  }

  update_entity :: proc "contextless" (entity : ^EntityUnion, entity_idx : ^int) {
    switch entity in entity {
      case EntityAsteroid:
        update_asteroid(&entity, entity_idx)
      case EntityPhysic:
        update_physic(&entity, entity_idx)
      case EntityLaser:
        update_laser(&entity, entity_idx)
      case EntityMine:
        update_mine(&entity, entity_idx)
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
    size := (variant & 0b__11_000000) >> 6
    speed := clamp((f32(velocity.x*velocity.x) + f32(velocity.y*velocity.y) + f32(velocity.z*velocity.z)) / 1000, 0, 1)

    H_SIZE :: 65536
    pos.x = u16((i32(pos.x) + H_SIZE + velocity.x) % H_SIZE)
    pos.y = u16((i32(pos.y) + H_SIZE + velocity.y) % H_SIZE)
    pos.z = u16((i32(pos.z) + H_SIZE + velocity.z) % H_SIZE)

    destroy := false

    if test_overlap(to_h3({ 50, 50, 50 }), 4, pos, size) {
      destroy = true
    }
    if test_overlap(to_h3({ -50, -50, -50 }), 4, pos, size) {
      destroy = true
    }

    invincibility := state & 0b__000_11111
    collision_check: if invincibility > 0 {
      invincibility -= 1
      state = (state & 0b__111_00000) | invincibility
    } else if !destroy {
      for player, player_idx in players {
        if player.invincibility == 0 && test_overlap(pos, size, to_h3(player.pos), 1) {
          damage := u8(clamp((0.2*speed + 0.8*player.speed) * f32(size) * 255/4, 0, 255))
          play_sound_effect(.Player_Death, player.pos, f32(damage)/255)
          damage_player(&player, u8(player_idx), damage)
          player.invincibility = 60
          split_asteroid(asteroid^)
          destroy = true
          break collision_check
        }
      }
      for other_idx := entity_idx^+1; other_idx < entity_count; other_idx += 1 {
        #partial switch other_entity in entities[other_idx] {
          case EntityAsteroid:
            other_invincibility := other_entity.state & 0b__000_11111
            if other_invincibility == 0 {
              other_size := (other_entity.variant & 0b__11_000000) >> 6
              if test_overlap(pos, size, other_entity.pos, other_size) {
                if other_size >= size-2 {
                  if other_size <= size+1 {
                    split_asteroid(other_entity)
                  }
                  remove_entity(other_idx)
                  other_idx -= 1
                }
                if size >= other_size-2 {
                  if size <= other_size+1 {
                    split_asteroid(asteroid^)
                  }
                  destroy = true
                  break collision_check
                }
              }
            }
          case EntityLaser:
            if test_overlap(pos, size, other_entity.pos, 1) {
              remove_entity(other_idx)
              other_idx -= 1
              split_asteroid(asteroid^)
              destroy = true
              break collision_check
            }
          case EntityMine:
            if test_overlap(pos, size, other_entity.pos, 1) {
              detonate_mine(other_entity)
              remove_entity(other_idx)
              other_idx -= 1
              // NOTE (hitch) 2022-08-21 We assume that the mine has destroyed us:
              entity_idx^ -= 1
              return
            }
        }
      }
    }

    if destroy {
      remove_entity(entity_idx^)
      entity_idx^ -= 1
    }
  }

  split_asteroid :: proc "contextless" (parent_asteroid : EntityAsteroid) {
    parent_size := (parent_asteroid.variant & 0b__11_000000) >> 6
    if parent_size > 0 {
      variant : u8

      OFFSETS := [][3]i32{
        {  15,   0,   0 },
        { -15,   0,   0 },
        {  10,   5,   0 },
        {  10,  -5,   0 },
        { -10,   5,   0 },
        { -10,  -5,   0 },
        {  10,   0,   5 },
        {  10,   0,  -5 },
        { -10,   0,   5 },
        { -10,   0,  -5 },
        {   5,  10,   0 },
        {  -5,  10,   0 },
        {   5, -10,   0 },
        {  -5, -10,   0 },
        {   0,  10,   5 },
        {   0,  10,  -5 },
        {   0, -10,   5 },
        {   0, -10,  -5 },
        {   5,   0,  10 },
        {  -5,   0,  10 },
        {   5,   0, -10 },
        {  -5,   0, -10 },
        {   0,   5,  10 },
        {   0,  -5,  10 },
        {   0,   5, -10 },
        {   0,  -5, -10 },
        {   5,   5,   5 },
        {  -5,   5,   5 },
        {   5,  -5,   5 },
        {  -5,  -5,   5 },
        {   5,   5,  -5 },
        {  -5,   5,  -5 },
        {   5,  -5,  -5 },
        {  -5,  -5,  -5 },
      }

      offset := OFFSETS[uint(rand_uint32(&entity_rand)) % len(OFFSETS)]

      spawn_point := parent_asteroid.pos
      spawn_point.x = u16((i32(spawn_point.x) + i32(max(u16)) + offset.x) % i32(max(u16)))
      spawn_point.y = u16((i32(spawn_point.y) + i32(max(u16)) + offset.y) % i32(max(u16)))
      spawn_point.z = u16((i32(spawn_point.z) + i32(max(u16)) + offset.z) % i32(max(u16)))
      variant = (u8(rand_uint32(&entity_rand)) & 0b__00_111111) | ((parent_size-1) << 6)
      add_entity(EntityAsteroid{ spawn_point, variant, 31 })

      spawn_point = parent_asteroid.pos
      spawn_point.x = u16((i32(spawn_point.x) + i32(max(u16)) - offset.x) % i32(max(u16)))
      spawn_point.y = u16((i32(spawn_point.y) + i32(max(u16)) - offset.y) % i32(max(u16)))
      spawn_point.z = u16((i32(spawn_point.z) + i32(max(u16)) - offset.z) % i32(max(u16)))
      variant = (u8(rand_uint32(&entity_rand)) & 0b__00_111111) | ((parent_size-1) << 6)
      add_entity(EntityAsteroid{ spawn_point, variant, 31 })
    }
    physic := rand_float32(&entity_rand)
    physic = 0.95*(physic*physic*physic) + 0.05
    add_entity(EntityPhysic{ parent_asteroid.pos, 255, u8(physic*120) })
  }

  test_overlap :: proc{ test_overlap_h3, test_overlap_v3 }

  test_overlap_h3 :: proc "contextless" (my_pos : H3, my_size : u8, other_pos : H3, other_size : u8) -> bool {
    radius := f32(0)
    switch my_size {
      case 0:
        radius += 0.25
      case 1:
        radius += 0.5
      case 2:
        radius += 1
      case 3:
        radius += 2
      case 4:
        radius += 20
    }
    switch other_size {
      case 0:
        radius += 0.25
      case 1:
        radius += 0.5
      case 2:
        radius += 1
      case 3:
        radius += 2
      case 4:
        radius += 20
    }
    dx := (f32(my_pos.x) - f32(other_pos.x)) * H_TO_WORLD
    dy := (f32(my_pos.y) - f32(other_pos.y)) * H_TO_WORLD
    dz := (f32(my_pos.z) - f32(other_pos.z)) * H_TO_WORLD
    sq_dist := dx*dx + dy*dy + dz*dz
    return sq_dist < radius*radius
  }

  test_overlap_v3 :: proc "contextless" (my_pos : V3, my_radius : f32, other_pos : V3, other_radius : f32) -> bool {
    radius := my_radius + other_radius
    dx := my_pos.x - other_pos.x
    dy := my_pos.y - other_pos.y
    dz := my_pos.z - other_pos.z
    sq_dist := dx*dx + dy*dy + dz*dz
    return sq_dist < radius*radius
  }

// Physic //////////////////////////////////////////////////////////////////////////////////////////

  EntityPhysic :: struct { // 8 bytes
    pos : H3,              //   6 bytes
    ttl : u8,              //   1 byte
    unpayed : u8,          //   1 byte
  }

  update_physic :: proc "contextless" (using physic : ^EntityPhysic, entity_idx : ^int) {
    if ttl > 0 {
      ttl -= 1
      origin := to_v3(pos)
      for player in players {
        if player.physic < 255 && player.health > 0 {
          offset := dir(player.pos, origin)
          sq_dist := dot(offset, offset)
          if sq_dist < 20*20 {
            player.physic += 1
            unpayed -= 1
            if unpayed == 0 {
              remove_entity(entity_idx^)
              entity_idx^ -= 1
              return
            }
          }
        }
      }
    } else {
      remove_entity(entity_idx^)
      entity_idx^ -= 1
    }
  }

// Laser ///////////////////////////////////////////////////////////////////////////////////////////

  EntityLaser :: struct { // 9 bytes
    pos : H3,             //   6 bytes
    ttl : u8,             //   1 byte
    dir : u16,            //   2 bytes  // 0b__?XXXXXYYYYYZZZZZ
  }

  update_laser :: proc "contextless" (using laser : ^EntityLaser, entity_idx : ^int) {
    if ttl > 0 {
      ttl -= 1

      norm : V3
      norm.x = (f32((dir & 0b__0_11111_00000_00000) >> 10) / 31.0) - 0.5
      norm.y = (f32((dir & 0b__0_00000_11111_00000) >> 5) / 31.0) - 0.5
      norm.z = (f32(dir & 0b__0_00000_00000_11111) / 31.0) - 0.5
      mag := 1.0/sqrt(dot(norm, norm))

      LASER_SPEED :: 2000

      velocity : [3]i32
      velocity.x = i32(iround(LASER_SPEED*norm.x/mag))
      velocity.y = i32(iround(LASER_SPEED*norm.y/mag))
      velocity.z = i32(iround(LASER_SPEED*norm.z/mag))

      H_SIZE :: 65536
      pos.x = u16((i32(pos.x) + H_SIZE + velocity.x) % H_SIZE)
      pos.y = u16((i32(pos.y) + H_SIZE + velocity.y) % H_SIZE)
      pos.z = u16((i32(pos.z) + H_SIZE + velocity.z) % H_SIZE)

      for player, player_idx in players {
        if player.invincibility == 0 && test_overlap(pos, 1, to_h3(player.pos), 1) {
          damage := u8(120)
          play_sound_effect(.Player_Death, player.pos, f32(damage)/255)
          damage_player(&player, u8(player_idx), damage)
          player.invincibility = 30
          remove_entity(entity_idx^)
          entity_idx^ -= 1
          return
        }
      }
      for other_idx := entity_idx^+1; other_idx < entity_count; other_idx += 1 {
        #partial switch other_entity in entities[other_idx] {
          case EntityAsteroid:
            other_invincibility := other_entity.state & 0b__000_11111
            if other_invincibility == 0 {
              other_size := (other_entity.variant & 0b__11_000000) >> 6
              if test_overlap(pos, 1, other_entity.pos, other_size) {
                split_asteroid(other_entity)
                remove_entity(other_idx)
                other_idx -= 1
                remove_entity(entity_idx^)
                entity_idx^ -= 1
                return
              }
            }
          case EntityMine:
            if test_overlap(pos, 1, other_entity.pos, 1) {
              detonate_mine(other_entity)
              remove_entity(other_idx)
              other_idx -= 1
              remove_entity(entity_idx^)
              entity_idx^ -= 1
              return
            }
        }
      }
    } else {
      remove_entity(entity_idx^)
      entity_idx^ -= 1
    }
  }

// Mine ////////////////////////////////////////////////////////////////////////////////////////////

  EntityMine :: struct { // 7 bytes
    pos : H3,            //   6 bytes
    active : bool,       //   1 bytes
  }

  update_mine :: proc "contextless" (using mine : ^EntityMine, entity_idx : ^int) {
    if test_overlap(to_h3({ 50, 50, 50 }), 4, pos, 3) ||
       test_overlap(to_h3({ -50, -50, -50 }), 4, pos, 3) {
        remove_entity(entity_idx^)
        entity_idx^ -= 1
        return
    }

    v_pos := to_v3(pos)
    min_player_sq_dist := max(f32)
    for player, player_idx in players {
      offset := dir(v_pos, player.pos)
      sq_dist := dot(offset, offset)
      if sq_dist < min_player_sq_dist {
        min_player_sq_dist = sq_dist
      }
    }

    if active {
      if min_player_sq_dist < 20*20 {
        detonate_mine(mine^)
        remove_entity(entity_idx^)
        entity_idx^ -= 1
      }
    } else if min_player_sq_dist > 25*25 {
      active = true
      play_sound_effect(.Mine_Activate, v_pos, 1)
    }

    for other_idx := entity_idx^+1; other_idx < entity_count; other_idx += 1 {
      #partial switch other_entity in entities[other_idx] {
        case EntityAsteroid:
          other_invincibility := other_entity.state & 0b__000_11111
          if other_invincibility == 0 {
            other_size := (other_entity.variant & 0b__11_000000) >> 6
            if test_overlap(pos, 1, other_entity.pos, other_size) {
              detonate_mine(mine^)
              remove_entity(entity_idx^)
              entity_idx^ -= 1
              return
            }
          }
        case EntityLaser:
          if test_overlap(pos, 1, other_entity.pos, 1) {
            detonate_mine(mine^)
            remove_entity(entity_idx^)
            entity_idx^ -= 1
            return
          }
      }
    }
  }

  detonate_mine :: proc "contextless" (mine : EntityMine) {
    v_pos := to_v3(mine.pos)
    play_sound_effect(.Mine_Explode, v_pos, 1)

    for player, player_idx in players {
      if player.invincibility == 0 && test_overlap(mine.pos, 4, to_h3(player.pos), 1) {
        damage_player(&player, u8(player_idx), 200)
        player.invincibility = 30
      }
    }

    for other_idx := 0; other_idx < entity_count; other_idx += 1 {
      #partial switch other_entity in entities[other_idx] {
        case EntityAsteroid:
          other_invincibility := other_entity.state & 0b__000_11111
          if other_invincibility == 0 {
            other_size := (other_entity.variant & 0b__11_000000) >> 6
            if test_overlap(mine.pos, 4, other_entity.pos, other_size) {
              if other_size > 1 {
                split_asteroid(other_entity)
              }
              remove_entity(other_idx)
              other_idx -= 1
            }
          }
      }
    }
  }
