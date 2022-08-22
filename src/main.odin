package main

import "core:math"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

import w4 "wasm4"

LEVEL_SEED :: 42
STAR_SEED :: 42
GRAPHICS_SEED :: 42

game_settings : struct{
  num_asteroids : i16, //  50..=500 :: 10 increment
  pysic_to_win : i16, //  5..=1000, -1 :: 5 (500 physic) increment
  time_limit : i16, //    360..=21600, -1 :: 60*6 (minute) increments
  on_timeout : enum { LEADER_WINS, DRAW },
  music_mute : bool,
}

time : u32 // 4 bytes
timer : i16
player_id : u8
team_1 : Team
team_2 : Team

Screen :: enum u8 {
  // Title,
  // TeamSelect,
  GameRules,
  MainGame,
  GameOver,
}

current_screen : Screen

TeamID :: enum u8 {
  Team1,
  Team2,
}

Team :: struct {
  physic_collected : u32,
}

TEAM1_LAUNCH :: V3{ -50, -50, -50-7 }
TEAM2_LAUNCH :: V3{  50,  50,  50-7 }

WORLD_SIZE :: f32(200)

level_rand : Rand // 17 bytes
graphics_rand : Rand // 17 bytes

input_held : [4]^w4.ButtonSet // 4 bytes
_input_prev : [4]w4.ButtonSet // 4 bytes
input_press : [4]w4.ButtonSet // 4 bytes

@export
start :: proc "c" () {
  graphics_rand = rand_create(GRAPHICS_SEED)

  for i in 0..<4 {
    players[i].mute_music = true
    if i % 2 == 1 {
      players[i].flags = { .Team2 }
    }
    for _ in 0..<TRAIL_LENGHT {
      sample_trail(&players[i])
    }
  }

  input_held = { w4.GAMEPAD1, w4.GAMEPAD2, w4.GAMEPAD3, w4.GAMEPAD4 }

  { using game_settings
    num_asteroids = 100
    pysic_to_win = 40
    time_limit = 1800
    on_timeout = .LEADER_WINS
  }

  init_math()
  init_graphics()
  init_sound()

  current_screen = .GameRules
}

start_game :: proc "contextless" () {
  current_screen = .MainGame

  team_1.physic_collected = 0
  team_2.physic_collected = 0

  level_rand = rand_create(LEVEL_SEED)
  entity_rand = rand_create((u64(rand_uint32(&level_rand)) << 32) | u64(rand_uint32(&level_rand)))
  entity_count = 0
  for _ in 0..<game_settings.num_asteroids {
    add_entity(EntityAsteroid{
        pos = {u16(rand_uint32(&level_rand)), u16(rand_uint32(&level_rand)), u16(rand_uint32(&level_rand))},
        variant = u8(rand_uint32(&entity_rand)),
        state = 0,
      })
  }
  timer = game_settings.time_limit
}

@export
update :: proc "c" () {
  player_id = (u8(w4.NETPLAY^) & 0b11)
  if time % 6 == 0 && timer > 0 {
    timer -= 1
    if timer == 0 {
      current_screen = .GameOver
      return
    }
  }

  update_sound()

  defer {
    for i in 0..<4 {
      _input_prev[i] = input_held[i]^
    }
  }
  for i in 0..<4 {
    input_press[i] = input_held[i]^ & (input_held[i]^ ~ _input_prev[i])
  }

  switch current_screen {
    case .GameRules:
      // num_asteroids : i16, //  50..=500 :: 10 increment
      // pysic_to_win : i16, //  5..=1000, -1 :: 5 (500 physic) increment
      // time_limit : i16, //    360..=21600, -1 :: 60*6 (minute) increments
      // on_timeout : enum { LEADER_WINS, DRAW },
      // music_mute : bool,
      @static select : int
      option :: proc "contextless" (index : int, str : string, y : i32) {
        if select == index {
          w4.DRAW_COLORS^ = 0x0022
          w4.rect(0, y-1, 160, 10)
        }
        w4.DRAW_COLORS^ = 0x0003
        w4.text(str, i32(120 - len(str)*8), y)
      }
      val :: proc "contextless" (str : string, y : i32) {
        w4.DRAW_COLORS^ = 0x0003
        w4.text(str, i32(152 - len(str)*8), y)
      }
      option(0, "Num Asteroids", 20)
      val(to_str(int(game_settings.num_asteroids)), 30)
      option(1, "Physic To Win", 40)
      val(to_str(100*int(game_settings.pysic_to_win)), 50)
      option(2, "Time Limit", 60)
      val(to_str(int(game_settings.time_limit)/(6*60)), 70)
      option(3, "On Timeout", 80)
      if game_settings.on_timeout == .LEADER_WINS {
        val("Leader Wins", 90)
      } else {
        val("Draw", 90)
      }
      if game_settings.music_mute {
        option(4, "Enable Music", 100)
      } else {
        option(4, "Disable Music", 100)
      }
      option(5, "Start Game", 120)

      if .Up in input_press[0] {
        select = (select+5) % 6
      }
      if .Down in input_press[0] {
        select = (select+1) % 6
      }
      if .Right in input_press[0] || .A in input_press[0] {
        switch select {
          case 0:
            game_settings.num_asteroids = ((game_settings.num_asteroids - 50 + 10) % 450) + 50
          case 1:
            game_settings.pysic_to_win = ((game_settings.pysic_to_win - 5 + 5) % 995) + 5
          case 2:
            game_settings.time_limit = ((game_settings.time_limit - 360 + 360) % 21600) + 360
          case 3:
            if game_settings.on_timeout == .DRAW {
              game_settings.on_timeout = .LEADER_WINS
            } else if game_settings.on_timeout == .LEADER_WINS {
              game_settings.on_timeout = .DRAW
            }
          case 4:
            game_settings.music_mute = !game_settings.music_mute
          case 5:
            if .A in input_press[0] {
              start_game()
            }
        }
      }
      if .Left in input_press[0] || .B in input_press[0] {
        switch select {
          case 0:
            game_settings.num_asteroids = ((game_settings.num_asteroids - 50 - 10 + 450) % 450) + 50
          case 1:
            game_settings.pysic_to_win = ((game_settings.pysic_to_win - 5 - 5 + 995) % 995) + 5
          case 2:
            game_settings.time_limit = ((game_settings.time_limit - 360 - 360 + 21600) % 21600) + 360
          case 3:
            if game_settings.on_timeout == .DRAW {
              game_settings.on_timeout = .LEADER_WINS
            } else if game_settings.on_timeout == .LEADER_WINS {
              game_settings.on_timeout = .DRAW
            }
          case 4:
            game_settings.music_mute = !game_settings.music_mute
        }
      }
    case .MainGame:
      main_game()
    case .GameOver:
      w4.DRAW_COLORS^ = 0x0003
      winner : enum { T1, T2, DRAW }
      if game_settings.on_timeout == .LEADER_WINS {
        if team_1.physic_collected > team_1.physic_collected {
          winner = .T1
        } else if team_1.physic_collected < team_1.physic_collected {
          winner = .T2
        } else {
          winner = .DRAW
        }
      } else {
        if team_1.physic_collected > 100*u32(game_settings.pysic_to_win) {
          winner = .T1
        } else if team_2.physic_collected > 100*u32(game_settings.pysic_to_win) {
          winner = .T2
        } else {
          winner = .DRAW
        }
      }

      if .Team2 in players[player_id].flags {
        switch winner {
          case .T1:
            w4.text("Defeat", 84 - 3*8, 40)
          case .T2:
            w4.text("Victory!", 84 - 4*8, 40)
          case .DRAW:
            w4.text("Draw", 84 - 4*8, 40)
        }
      } else {
        switch winner {
          case .T1:
            w4.text("Victory!", 84 - 4*8, 40)
          case .T2:
            w4.text("Defeat", 84 - 3*8, 40)
          case .DRAW:
            w4.text("Draw", 84 - 4*8, 40)
        }
      }

      w4.text("Press \x80", 160 - 7*8, 160-8)

      if .A in input_press[0] {
        current_screen = .GameRules
      }
  }
}

main_game :: proc "contextless" () {
  time += 1

  if team_1.physic_collected >= 100*u32(game_settings.pysic_to_win) ||
     team_2.physic_collected >= 100*u32(game_settings.pysic_to_win) {
    current_screen = .GameOver
    return
  }

  if screen_shake > 0 {
    screen_shake -= 1
  }

  setup_current_player_view_matrix()

  for player, i in players {
    update_player(&player, i)
  }

  for entity_idx := 0; entity_idx < entity_count; entity_idx += 1 {
    update_entity(&entities[entity_idx], &entity_idx)
  }

  min_base_sq_dist := max(f32)
  min_base_pos : V3
  min_teammate_sq_dist := max(f32)
  min_teammate_pos : V3

  update_pallet()
  clear_depth_buffer()
  matrix_VP = mul(matrix_projection, matrix_view)

  // STARS
  {
    star_rand := rand_create(STAR_SEED)
    for star in 0..<300 {
      y := 2*rand_float32(&star_rand) - 1
      draw_star({ 2*rand_float32(&star_rand) - 1, y*y*y, 2*rand_float32(&star_rand) - 1 })
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
        //continue
      }
      _valid_offsets[_valid_offset_count] = pos_offset
      _valid_offset_count += 1
    }
    valid_offsets = _valid_offsets[:_valid_offset_count]
  }

  // ENTITIES
  {
    ASTER_OFFSETS :: []V3{ {0, 0, 0}, {0, 1, 0}, {-1, 0, 0}, {0, -1, 0}, {1, 0, 0}, {1, 1, 0}, {-1, 1, 0}, {-1, -1, 0}, {1, -1, 0} }
    aster_norms := []V3{
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[0].x, -ASTER_OFFSETS[0].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[1].x, -ASTER_OFFSETS[1].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[2].x, -ASTER_OFFSETS[2].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[3].x, -ASTER_OFFSETS[3].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[4].x, -ASTER_OFFSETS[4].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[0].x, -ASTER_OFFSETS[5].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[1].x, -ASTER_OFFSETS[6].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[2].x, -ASTER_OFFSETS[7].y, 0 })),
      mul(players[player_id].rotation, norm_v3(V3_BACK+V3{ ASTER_OFFSETS[3].x, -ASTER_OFFSETS[8].y, 0 })),
    }
    aster_rot_mat := quat_to_mat(quat_euler({ f32(time)/120.0, f32(time)/60.0, f32(time)/90.0 }))
    asteroid_matrix_scales := []Matrix{
      mul(aster_rot_mat, mat_scale({ 0.5, 0.5, 0.5 })),
      mul(aster_rot_mat, mat_scale({ 1,   1,   1   })),
      mul(aster_rot_mat, mat_scale({ 2,   2,   2   })),
      mul(aster_rot_mat, mat_scale({ 4,   4,   4   })),
    }

    physic_matrix := mat_scale({ 3, 3, 3 })

    LASER_SCALE :: 0.25
    LASER_OFFSETS :: []V3{
      { 0*LASER_SCALE, 1*LASER_SCALE, 0*LASER_SCALE },{ 0*LASER_SCALE, -1*LASER_SCALE, 0*LASER_SCALE },
      { 1*LASER_SCALE, 0*LASER_SCALE, 0*LASER_SCALE },{ -1*LASER_SCALE, 0*LASER_SCALE, 0*LASER_SCALE },
      { 0*LASER_SCALE, 0*LASER_SCALE, 1*LASER_SCALE },{ 0*LASER_SCALE, 0*LASER_SCALE, -1*LASER_SCALE },
      { 0.5*LASER_SCALE, 0.5*LASER_SCALE, 0*LASER_SCALE },{ -0.5*LASER_SCALE, -0.5*LASER_SCALE, 0*LASER_SCALE },
      { 0.5*LASER_SCALE, 0*LASER_SCALE, 0.5*LASER_SCALE },{ -0.5*LASER_SCALE, 0*LASER_SCALE, -0.5*LASER_SCALE },
      { 0*LASER_SCALE, 0.5*LASER_SCALE, 0.5*LASER_SCALE },{ 0*LASER_SCALE, -0.5*LASER_SCALE, -0.5*LASER_SCALE },
      { -0.5*LASER_SCALE, 0.5*LASER_SCALE, 0*LASER_SCALE },{ 0.5*LASER_SCALE, -0.5*LASER_SCALE, 0*LASER_SCALE },
      { -0.5*LASER_SCALE, 0*LASER_SCALE, 0.5*LASER_SCALE },{ 0.5*LASER_SCALE, 0*LASER_SCALE, -0.5*LASER_SCALE },
      { 0*LASER_SCALE, -0.5*LASER_SCALE, 0.5*LASER_SCALE },{ 0*LASER_SCALE, 0.5*LASER_SCALE, -0.5*LASER_SCALE },
    }

    mine_matrix := mul(quat_to_mat(quat_euler({ f32(time)/30.0, f32(time)/40.0, f32(time)/50.0 })), mat_scale({ 1, 1, 1 }))

    // ENTITIES
    for entity_idx := 0; entity_idx < entity_count; entity_idx += 1 {
      switch entity in entities[entity_idx] {
        case EntityAsteroid:
          size := (entity.variant >> 6) & 0b11
          asteroid_matrix := asteroid_matrix_scales[size]
          asteroid_pos := to_v3(entity.pos)
          for pos_offset in valid_offsets {
            draw_pos := add(asteroid_pos, pos_offset)
            sq_dist := sq_draw_dist(draw_pos)
            if sq_dist < 190*190 {
              if sq_dist < 100*100 {
                options : DrawOptionsSet
                if sq_dist < 25*25 {
                  options = { .Border }
                }
                asteroid_matrix[0, 3] = draw_pos.x
                asteroid_matrix[1, 3] = draw_pos.y
                asteroid_matrix[2, 3] = draw_pos.z
                draw_model(model_asteroid_01, asteroid_matrix, sqrt(3 * 4*4), { .Asteroid }, options)
              } else {
                count := int(size+1) * iround(remap(sq_dist, 190*190, 100*100, 1, f32(len(ASTER_OFFSETS)))) / 4
                screen_point := model_to_screen(V4{ draw_pos.x, draw_pos.y, draw_pos.z, 1 })
                if screen_point.z > 0 {
                  for offset, i in ASTER_OFFSETS {
                    if i == count {
                      break
                    }
                    frag := Vary{ screen_point + offset, aster_norms[i] }
                    draw_fragment(iround(frag.pos.x), iround(frag.pos.y), frag, .Asteroid, .Gray)
                  }
                }
              }
            }
          }
        case EntityPhysic:
          physic_pos := to_v3(entity.pos)
          for pos_offset in valid_offsets {
            draw_pos := add(physic_pos, pos_offset)
            sq_dist := sq_draw_dist(draw_pos)
            if sq_dist < 190*190 {
              physic_matrix[0, 3] = draw_pos.x
              physic_matrix[1, 3] = draw_pos.y
              physic_matrix[2, 3] = draw_pos.z
              rendering_pysic_density = 0.25*f32(entity.ttl)/255 + 0.75*f32(entity.unpayed)/255
              draw_model(model_cube, physic_matrix, sqrt(3 * 3*3), { .Physic }, { .No_Backface_Culling })
            }
          }
        case EntityLaser:
          laser_base := to_v3(entity.pos)
          laser_poses := []V3{
            add(laser_base, LASER_OFFSETS[0]),
            add(laser_base, LASER_OFFSETS[1]),
            add(laser_base, LASER_OFFSETS[2]),
            add(laser_base, LASER_OFFSETS[3]),
            add(laser_base, LASER_OFFSETS[4]),
            add(laser_base, LASER_OFFSETS[5]),
            add(laser_base, LASER_OFFSETS[6]),
            add(laser_base, LASER_OFFSETS[7]),
            add(laser_base, LASER_OFFSETS[8]),
            add(laser_base, LASER_OFFSETS[9]),
            add(laser_base, LASER_OFFSETS[10]),
            add(laser_base, LASER_OFFSETS[11]),
            add(laser_base, LASER_OFFSETS[12]),
            add(laser_base, LASER_OFFSETS[13]),
            add(laser_base, LASER_OFFSETS[14]),
            add(laser_base, LASER_OFFSETS[15]),
            add(laser_base, LASER_OFFSETS[16]),
            add(laser_base, LASER_OFFSETS[17]),
          }
          for pos_offset in valid_offsets {
            sq_dist := sq_draw_dist(add(laser_base, pos_offset))
            if sq_dist < 50*50 {
              for i in 0..<(len(laser_poses)/2) {
                start_pos := add(laser_poses[2*i], pos_offset)
                end_pos := add(laser_poses[2*i + 1], pos_offset)
                draw_line({ start_pos, V3_UP }, { end_pos, V3_UP }, .Laser)
              }
            }
          }
        case EntityMine:
          mine_pos := to_v3(entity.pos)
          for pos_offset in valid_offsets {
            draw_pos := add(mine_pos, pos_offset)
            sq_dist := sq_draw_dist(draw_pos)
            if sq_dist < 190*190 {
              mine_matrix[0, 3] = draw_pos.x
              mine_matrix[1, 3] = draw_pos.y
              mine_matrix[2, 3] = draw_pos.z
              if entity.active {
                if sq_dist < 40*40 && current_color == .Red {
                  draw_model(model_mine, mine_matrix, sqrt(3), { .Light_Mine, .Light_Mine })
                } else {
                  draw_model(model_mine, mine_matrix, sqrt(3), { .Metal, .Light_Mine })
                }
              } else {
                draw_model(model_mine, mine_matrix, sqrt(3), { .Metal, .Black })
              }
            }
          }
      }
    }
  }

  // PLAYERS
  {
    for player, player_idx in players {
      if player.health == 0 {
        continue
      }

      left_offset :=  mul(player.rotation, V3{ -0.5, 0, 0 })
      right_offset := -left_offset
      material_lamp : Material = .Team2 in player.flags ? .Light_Black_Team2 : .Light_Black_Team1
      engine_left := Material.Black
      engine_right := Material.Black
      if player.speed/0.01 + 1 > f32(time % 10) {
        engine_left = .Engine
        engine_right = .Engine
      }

      model_left_matrix := mul(quat_to_mat(player.rotation), mat_scale({ -1, 1, 1 }))
      model_right_matrix := mul(quat_to_mat(player.rotation), mat_scale({ 1, 1, 1 }))
      for pos_offset in valid_offsets {
        draw_pos := add(player.pos, pos_offset)
        sq_dist := sq_draw_dist(draw_pos)
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
          draw_model(model_player_ship, model_left_matrix, sqrt(3 * 1*1), { .Metal, material_lamp, engine_left, .Black }, options)
          model_right_matrix[0, 3] = right_pos.x
          model_right_matrix[1, 3] = right_pos.y
          model_right_matrix[2, 3] = right_pos.z
          draw_model(model_player_ship, model_right_matrix, sqrt(3 * 1*1), { .Metal, material_lamp, engine_right, .Black }, options | { .Reverse_Winding })
        }

        if player_id != u8(player_idx) &&
            (.Team2 in player.flags) == (.Team2 in players[player_id].flags) {
          if sq_dist < min_teammate_sq_dist {
            min_teammate_sq_dist = sq_dist
            min_teammate_pos = draw_pos
          }
        }
      }

      // TRAIL
      {
        last_left := Vary{ ensure_continuity(to_v3(player.trail[0][TRAIL_LENGHT-1]), player.pos), { 0, 0, 0} }
        last_right := Vary{ ensure_continuity(to_v3(player.trail[1][TRAIL_LENGHT-1]), player.pos), { 0, 0, 0} }
        for i := TRAIL_LENGHT-2; i >= 0; i -= 1 {
          new_left := Vary{ ensure_continuity(to_v3(player.trail[0][i]), last_left.pos), { 0, f32(TRAIL_LENGHT-i-1)/TRAIL_LENGHT, 0} }
          new_right := Vary{ ensure_continuity(to_v3(player.trail[1][i]), last_right.pos), { 0, f32(TRAIL_LENGHT-i-1)/TRAIL_LENGHT, 0} }
          for pos_offset in valid_offsets {
            last_left := last_left
            last_right := last_right
            new_left := new_left
            new_right := new_right
            last_left.pos = add(last_left.pos, pos_offset)
            last_right.pos = add(last_right.pos, pos_offset)
            new_left.pos = add(new_left.pos, pos_offset)
            new_right.pos = add(new_right.pos, pos_offset)
            draw_line(last_left, new_left, .Trail)
            draw_line(last_right, new_right, .Trail)
          }
          last_left = new_left
          last_right = new_right
        }

        ensure_continuity :: proc "contextless" (new_pos : V3, last_pos : V3) -> V3 {
          new_pos := new_pos
          if new_pos.x < last_pos.x-(WORLD_SIZE/2) {
            new_pos.x += WORLD_SIZE
          }
          if new_pos.x > last_pos.x+(WORLD_SIZE/2) {
            new_pos.x -= WORLD_SIZE
          }
          if new_pos.y < last_pos.y-(WORLD_SIZE/2) {
            new_pos.y += WORLD_SIZE
          }
          if new_pos.y > last_pos.y+(WORLD_SIZE/2) {
            new_pos.y -= WORLD_SIZE
          }
          if new_pos.z < last_pos.z-(WORLD_SIZE/2) {
            new_pos.z += WORLD_SIZE
          }
          if new_pos.z > last_pos.z+(WORLD_SIZE/2) {
            new_pos.z -= WORLD_SIZE
          }
          return new_pos
        }
      }
    }
  }

  // BASES
  {
    @static base_matrix_top : Matrix
    @static base_matrix_center : Matrix
    @static base_matrix_bottom : Matrix
    base_matrix_top = mul(quat_to_mat(quat_euler({ 0, f32(time)/220.0, 0 })), mat_scale({ 7, -7, 7 }))
    base_matrix_center = mul(quat_to_mat(quat_euler({ 0, -f32(time)/220.0, 0 })), mat_scale({ 7, 7, 7 }))
    base_matrix_bottom = mul(quat_to_mat(quat_euler({ 0, f32(time)/220.0, 0 })), mat_scale({ 7, 7, 7 }))
    draw_base :: proc "contextless" (base_pos : V3, team : TeamID, min_base_sq_dist : ^f32, min_base_pos : ^V3) {
      material_lamp : Material = team == .Team2 ? .Light_White_Team2 : .Light_White_Team1
      for pos_offset in valid_offsets {
        draw_pos := add(base_pos, pos_offset)
        sq_dist := sq_draw_dist(draw_pos)
        if sq_dist < 190*190 {
          options : DrawOptionsSet
          if sq_dist < 50*50 {
            options = { .Border }
          }
          base_matrix_top[0, 3] = draw_pos.x
          base_matrix_top[1, 3] = draw_pos.y
          base_matrix_top[2, 3] = draw_pos.z
          base_matrix_center[0, 3] = draw_pos.x
          base_matrix_center[1, 3] = draw_pos.y
          base_matrix_center[2, 3] = draw_pos.z
          base_matrix_bottom[0, 3] = draw_pos.x
          base_matrix_bottom[1, 3] = draw_pos.y
          base_matrix_bottom[2, 3] = draw_pos.z

          draw_model(model_space_station_cap, base_matrix_top, sqrt(3 * 8*8), { .Metal, .White, material_lamp, .Black }, options | { .Reverse_Winding })
          draw_model(model_space_station_center, base_matrix_center, sqrt(3 * 8*8), { .Metal, .White, material_lamp, .Black }, options)
          draw_model(model_space_station_cap, base_matrix_bottom, sqrt(3 * 8*8), { .Metal, .White, material_lamp, .Black }, options)

          if sq_dist < 100*100 {
            material : Material = (team == .Team1) ? .Light_HUD_Team1 : .Light_HUD_Team2
            top := V3{ 20, 0.5, 0 }
            bottom := V3{ 20, -0.5, 0 }
            left := V3{ 20, 0, 0.5 }
            right := V3{ 20, 0, -0.5 }
            BANDS :: 8
            for i in 0..<BANDS/2
            {
              rot := quat_euler({ 0, f32(i)*math.TAU/BANDS, 0 })
              for _ in 0..<BANDS
              {
                rot = mul(rot, quat_euler({ 0, 0, math.TAU/BANDS }))
                top := Vary{ add(draw_pos, mul(rot, top)), V3_UP }
                bottom := Vary{ add(draw_pos, mul(rot, bottom)), V3_UP }
                left := Vary{ add(draw_pos, mul(rot, left)), V3_UP }
                right := Vary{ add(draw_pos, mul(rot, right)), V3_UP }
                draw_line(top, bottom, material)
                draw_line(left, right, material)
              }
            }
          }
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
        if time%2 == 0 && players[player_id].speed/0.01 + 1 > f32(time % 10) {
          w4.DRAW_COLORS^ = 0x0003
        }
        height := i32(78*players[player_id].speed)
        w4.rect(4, 41+78-height, 2, u32(height))
        if players[player_id].health < 255 && time % 2 == 0 {
          if current_color == .Red {
            w4.DRAW_COLORS^ = 0x0004
          } else {
            w4.DRAW_COLORS^ = 0x0002
          }
          height := 78 - 78*i32(players[player_id].health) / 255
          w4.rect(3, 40+height, 4, 1)
        }
      }

      // PHYSIC BAR
      {
        w4.DRAW_COLORS^ = 0x0001
        w4.rect(w4.SCREEN_SIZE-3, 41, 2, 78)
        if time % 2 == 0 {
          if current_color == .Green {
            w4.DRAW_COLORS^ = 0x0004
          } else {
            w4.DRAW_COLORS^ = 0x0002
          }
          height := i32(78 - 78*100/255)
          w4.rect(w4.SCREEN_SIZE-4, 40+height, 4, 1)
        }
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

    // RESPAWN
    respawn_time := &players[player_id].respawn_time
    draw_respawn: if players[player_id].health == 0 {
      frag := Vary{ V3_ZERO, V3_ZERO }
      for y in 0..<w4.SCREEN_SIZE {
        for x in 0..<w4.SCREEN_SIZE {
          draw_fragment(x, y, frag, .Death, .Black)
        }
      }

      w4.DRAW_COLORS^ = 0x0003
      w4.text("You Are Dead", 84 - 6*8, 40)

      w4.text("rebuilding ship...", 84 - 9*8, 60)

      if respawn_time^ == 0 {
        w4.text("Press \x80 to Launch!", 84 - 9*8, 88)
      } else if respawn_time^ < 1550 {
        w4.text("Press \x80 to", 84 - 5*8, 84)
        w4.text("rebuild now for:", 80 - 8*8, 88)
        s := to_str(int(respawn_time^))
        w4.text(s, i32(76 - 8*len(s)), 96)
        w4.text("Physic", 88, 96)
      }
    }

    // SCORES
    {
      draw_score :: proc "contextless" (score : int, color : Color, right_side : bool) {
        s := to_str(score)
        x := i32(2)
        if right_side {
          x = i32(w4.SCREEN_SIZE - 2 - 8*len(s))
        }
        w4.DRAW_COLORS^ = 0x0001
        w4.text(s, x + 1, 3)
        w4.DRAW_COLORS^ = 0x0003
        w4.text(s, x, 2)
        if current_color == color {
          width := i32(8*len(s)) + 2
          if game_settings.pysic_to_win > 0 {
            width = 1 + i32(78 * score / int(100*game_settings.pysic_to_win))
          }
          if !right_side {
            w4.DRAW_COLORS^ = 0x0011
            w4.rect(0, 11, u32(width)+2, 3)
            w4.DRAW_COLORS^ = 0x0004
            w4.hline(1, 12, u32(width))
            w4.vline(1, 10, 3)
            if width >= i32(8*len(s)) + 2 {
              w4.vline(width, 10, 3)
            }
          } else {
            w4.DRAW_COLORS^ = 0x0011
            w4.rect(w4.SCREEN_SIZE-width-2, 11, u32(width)+2, 3)
            w4.DRAW_COLORS^ = 0x0004
            w4.hline(w4.SCREEN_SIZE-1-width, 12, u32(width))
            if width >= i32(8*len(s)) + 2 {
              w4.vline(w4.SCREEN_SIZE-width-1, 10, 3)
            }
            w4.vline(w4.SCREEN_SIZE-2, 10, 3)
          }
        }
      }

      draw_score(int(team_1.physic_collected), TEAM1_COLOR, false)
      draw_score(int(team_2.physic_collected), TEAM2_COLOR, true)
    }

    // TIMER
    draw_timer: if timer > 0 {
      if timer < 6*60 && timer/3 % 2 == 0 {
        break draw_timer
      }
      seconds := (timer+3)/6
      min := seconds/60
      seconds %= 60
      min_10 := int(min / 10)
      min_01 := int(min % 10)
      sec_10 := int(seconds / 10)
      sec_01 := int(seconds % 10)
      w4.DRAW_COLORS^ = 0x0001
      if min_10 > 0 {
        w4.text(to_str(min_10), 80-4-8-8+1, 2)
      }
      w4.text(to_str(min_01), 80-4-8+1, 2)
      w4.text(":", 80-4+1, 2)
      w4.text(to_str(sec_10), 80+4+1, 2)
      w4.text(to_str(sec_01), 80+4+8+1, 2)
      w4.DRAW_COLORS^ = 0x0003
      if min_10 > 0 {
        w4.text(to_str(min_10), 80-4-8-8, 1)
      }
      w4.text(to_str(min_01), 80-4-8, 1)
      w4.text(":", 80-4, 1)
      w4.text(to_str(sec_10), 80+4, 1)
      w4.text(to_str(sec_01), 80+4+8, 1)
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
  if sq_draw_dist(world_pos) > (75*75) || offscreen {
    clip_point.x = w4.SCREEN_SIZE * (0.5 * clamp(clip_point.x, -0.95, 0.94) + 0.5)
    clip_point.y = w4.SCREEN_SIZE * (1-(0.5 * clamp(clip_point.y, -0.925, 0.94) + 0.5))
    draw(iround(clip_point.x), iround(clip_point.y))
  }
}

sq_draw_dist :: proc "contextless" (draw_pos : V3) -> f32 {
  eye := dir(draw_pos, players[player_id].pos)
  return dot(eye, eye)
}
