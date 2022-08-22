package main

import w4 "wasm4"

SoundEffect :: enum u8 {
  Player_Death,
  Player_Laser,
  Mine_Place,
  Mine_Activate,
  Mine_Explode,
}

Note :: enum u8 {
  C2, Cs2, D2, Ds2, E2, F2, Fs2, G2, Gs2, A2, As2, B2,
  C3, Cs3, D3, Ds3, E3, F3, Fs3, G3, Gs3, A3, As3, B3,
  C4, Cs4, D4, Ds4, E4, F4, Fs4, G4, Gs4, A4, As4, B4,
  C5, Cs5, D5, Ds5, E5, F5, Fs5, G5, Gs5, A5, As5, B5,
  C6, Cs6, D6, Ds6, E6, F6, Fs6, G6, Gs6, A6, As6, B6,
}

frequencies := [Note]u16{
  .C2 =  65, .Cs2 =  69, .D2 =  73, .Ds2 =  78, .E2 =  82, .F2 =  87, .Fs2 =  92, .G2 =  98, .Gs2 = 104, .A2 = 110, .As2 = 117, .B2 = 123,
  .C3 = 131, .Cs3 = 139, .D3 = 147, .Ds3 = 156, .E3 = 165, .F3 = 175, .Fs3 = 185, .G3 = 196, .Gs3 = 208, .A3 = 220, .As3 = 233, .B3 = 247,
  .C4 = 262, .Cs4 = 277, .D4 = 294, .Ds4 = 311, .E4 = 330, .F4 = 349, .Fs4 = 370, .G4 = 392, .Gs4 = 415, .A4 = 440, .As4 = 466, .B4 = 494,
  .C5 = 418, .Cs5 = 554, .D5 = 587, .Ds5 = 622, .E5 = 659, .F5 = 698, .Fs5 = 740, .G5 = 784, .Gs5 = 831, .A5 = 880, .As5 = 932, .B5 = 988,
  .C6 = 836, .Cs6 = 1108, .D6 = 1174, .Ds6 = 1244, .E6 = 1318, .F6 = 1396, .Fs6 = 1480, .G6 = 1568, .Gs6 = 1662, .A6 = 1760, .As6 = 1864, .B6 = 1976,
}

Song :: []struct {
  note : Note,
  length : u8,
}

song_oh_shenandhoah := Song{
  { .C3,  4 },

  { .F3,  2 },
  { .F3,  2 },
  { .F3,  6 },
  { .G3,  2 },
  { .A3,  2 },
  { .As3, 2 },

  { .D4,  2 },
  { .C4,  6 },
  { .F4,  2 },
  { .E4,  2 },

  { .D4,  6 },
  { .C4,  2 },
  { .D4,  2 },
  { .C4,  2 },

  { .A3,  2 },
  { .C4,  6 },
  { .C4,  4 },

  { .D4,  2 },
  { .D4,  2 },
  { .D4,  6 },
  { .A3,  2 },
  { .C4,  2 },
  { .A3,  2 },

  { .G3,  2 },
  { .F3,  6 },
  { .G3,  4 },

  { .A3,  6 },
  { .F3,  2 },
  { .A3,  3 },
  { .D4,  1 },

  { .C4,  8 },
  { .F3,  3 },
  { .G3,  1 },

  { .A3,  6 },
  { .F3,  2 },

  { .G3,  4 },
  { .F3,  4 },
}

playback : struct {
  song : ^Song,
  play_idx : u8,
  play_delay : u16,
  current_note : Note,
  arp_index : u8,
  time_scale : u16,
  transpose : i16,
  effect_delay : [4]u16,
  effect_volume : [4]u8,
}

init_sound :: proc "contextless" () {
  using playback

  song = &song_oh_shenandhoah
}

update_sound :: proc "contextless" () {
  using playback

  transpose = i16(remap(f32(players[player_id].physic), 0, 255, 8, -12))
  time_scale = u16(remap(f32(players[player_id].health), 0, 255, 3, 30))

  for c in 0..<4 {
    if playback.effect_delay[c] > 0 {
      playback.effect_delay[c] -= 1
    }
    if playback.effect_volume[c] > 0 {
      playback.effect_volume[c] -= 1
    }
  }

  if !game_settings.music_mute {
    if play_delay <= 1 {
      if int(play_idx) < len(song) {
        play_delay = u16(song[play_idx].length)*time_scale
        current_note = song[play_idx].note
        play_note(2, Note(i16(current_note)+transpose), play_delay)
      }
      play_idx = u8(int(play_idx+1) % len(song))
    } else {
      play_delay -= 1
    }

    arp_time := u16(remap(players[player_id].speed, 0, 1, 20, 3))
    if time % u32(arp_time) == 0 {
      note := ((i16(current_note) + transpose) % 12) + 4*i16(arp_index % 9) + 24
      if (arp_index / 9) % 2 == 1 {
        note += 8
      }
      if (arp_index % 9) < 5 {
        play_note(0, Note(note), arp_time+1, players[player_id].speed)
      }
      arp_index = (arp_index+1) % 18
    }
  }
}

play_note :: proc "contextless" (channel : u32, note : Note, length : u16, volume_scale := f32(1)) {
  using playback

  if effect_delay[channel] <= 0 {
    volume : u32 = 10
    if channel == 2 {
      volume = 100
    } else if channel == 3 {
      volume = 1
    }
    volume = u32(volume_scale*f32(volume))
    decay : u16 = 2
    if decay > length {
      decay = length
    }
    w4.tone_unpacked(w4.ToneChannel(channel), u32(frequencies[note]), 0, 0, 0, u32(length-decay), u32(decay), volume, 0, channel == 3 ? .Mode1 : .Mode3)
  }
}

play_sound_effect :: proc "contextless" (sound : SoundEffect, pos : V3, volume : f32) {
  volume := volume / min(0.001*sq_draw_dist(pos), 1)
  volume_byte := u8(clamp(255*volume, 0, 255))
  // TODO (hitch) 2022-08-21 NOT PARTIAL
  #partial switch sound {
    case .Player_Death:
      if volume > 0.01 && (playback.effect_delay[3] <= 0 || volume_byte >= playback.effect_volume[3]) {
        w4.tone_unpacked(.Noise, 130, 1000, 6, 74, 48, 0, u32(6*volume), u32(50*volume))
        playback.effect_delay[3] = 6 + 74
        playback.effect_volume[3] = volume_byte
      }
    case .Player_Laser:
      if volume > 0.01 && (playback.effect_delay[1] <= 0 || volume_byte >= playback.effect_volume[1]) {
        w4.tone_unpacked(.Pulse2, 620, 160, 5, 5, 0, 0, u32(20*volume), u32(50*volume))
        playback.effect_delay[1] = 5 + 5
        playback.effect_volume[1] = volume_byte
      }
  }
}
