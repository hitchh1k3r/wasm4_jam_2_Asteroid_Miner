// WASM-4: https://wasm4.org/docs
package wasm4

foreign import wasm4 "env"

#assert(size_of(int) == size_of(u32))

// Platform Constants //////////////////////////////////////////////////////////////////////////////

SCREEN_SIZE :: 160

Palette :: distinct [4]u32

ButtonSet :: distinct bit_set[Button; u8]
Button :: enum u8 {
  A     = 0,
  B     = 1,
  _     = 2,
  _     = 3,
  Left  = 4,
  Right = 5,
  Uo    = 6,
  Down  = 7,
}

MouseButtonSet :: distinct bit_set[MouseButton; u8]
MouseButton :: enum u8 {
  Left   = 0,
  Right  = 1,
  Middle = 2,
}

SystemFlagSet :: distinct bit_set[SystemFlag; u8]
SystemFlag :: enum u8 {
  PreserveFramebuffer = 0,
  HideGamepadOverlay  = 1,
}

NetPlay :: enum u8 {
  Offline = 0b000,
  Player1 = 0b100,
  Player2 = 0b101,
  Player3 = 0b110,
  Player4 = 0b111,
}

PALLET        := (^Palette)(uintptr(0x04))
DRAW_COLORS   := (^u16)(uintptr(0x14))
GAMEPAD1      := (^ButtonSet)(uintptr(0x16))
GAMEPAD2      := (^ButtonSet)(uintptr(0x17))
GAMEPAD3      := (^ButtonSet)(uintptr(0x18))
GAMEPAD4      := (^ButtonSet)(uintptr(0x19))
MOUSE_X       := (^i16)(uintptr(0x1a))
MOUSE_Y       := (^i16)(uintptr(0x1c))
MOUSE_BUTTONS := (^MouseButtonSet)(uintptr(0x1e))
SYSTEM_FLAGS  := (^SystemFlagSet)(uintptr(0x1f))
NETPLAY       := (^NetPlay)(uintptr(0x20))
FRAMEBUFFER   := (^[6400]u8)(uintptr(0xa0))

// Drawing Functions ///////////////////////////////////////////////////////////////////////////////

BlitFlagSet :: distinct bit_set[BlitFlag; u32]
BlitFlag :: enum u32 {
  Use_2BPP      = 0,
  FlipX         = 1,
  FlipY         = 2,
  Rotate_CCW_90 = 3,
}

@(default_calling_convention="c")
foreign wasm4 {

  blit :: proc(sprite : [^]u8, #any_int x, y : i32, #any_int width, height : u32, flags : BlitFlagSet = nil) ---

  @(link_name="blitSub")
  blit_sub :: proc(sprite : [^]u8, #any_int x, y : i32, #any_int width, height : u32, #any_int src_x, src_y : u32, #any_int stride : int, flags : BlitFlagSet = nil) ---

  line :: proc(#any_int x1, y1, x2, y2 : i32) ---

  hline :: proc(#any_int x, y : i32, #any_int width : u32) ---

  vline :: proc(#any_int x, y : i32, #any_int height : u32) ---

  oval :: proc(#any_int x, y : i32, #any_int width, height : u32) ---

  rect :: proc(#any_int x, y : i32, #any_int width, height : u32) ---

  @(link_name="textUtf8")
  text :: proc(text : string, #any_int x, y : i32) ---

}

// Sound Functions /////////////////////////////////////////////////////////////////////////////////

ToneChannel :: enum u32 {
  Pulse1   = 0,
  Pulse2   = 1,
  Triangle = 2,
  Noise    = 3,
}

ToneDutyCycle :: enum u32 {
  Mode1 = 0,  // 1/8
  Mode2 = 4,  // 1/4
  Mode3 = 8,  // 1/2
  Mode4 = 12, // 3/4
}

TonePan :: enum u32 {
  Center = 0,
  Left   = 16,
  Right  = 32,
}

ToneFrequency :: struct {
  start_hz : u8,
  end_hz :   u8,
}

ToneVolume :: struct {
  sustain : u8,
  peak :    u8,
}

ToneADSR :: struct {
  attack :  u8,
  decay :   u8,
  sustain : u8,
  release : u8,
}

@(private)
foreign wasm4 {

  @(link_name="tone")
  internal_tone :: proc(freq_hz : u32, adsr : u32, volume : u32, flags : u32) ---

}

tone :: proc{ tone_simple, tone_packed, tone_unpacked }

tone_simple :: proc "c" (channel : ToneChannel,
                         #any_int freq_hz : u32,
                         #any_int duration : u32,
                         #any_int volume : u32,
                         duty_cycle := ToneDutyCycle.Mode3,
                         pan := TonePan.Center) {
  flags := u32(channel) | u32(duty_cycle) | u32(pan)
  internal_tone(freq_hz, duration, volume, flags)
}

tone_packed :: proc "c" (channel : ToneChannel,
                         freq : ToneFrequency,
                         adsr : ToneADSR,
                         volume := ToneVolume{ sustain = 100, peak = 0 },
                         duty_cycle := ToneDutyCycle.Mode3,
                         pan := TonePan.Center) {
  flags := u32(channel) | u32(duty_cycle) | u32(pan)
  freq := u32(freq.start_hz) | u32(freq.end_hz)<<16
  adsr := u32(adsr.attack)<<24 | u32(adsr.decay)<<16 | u32(adsr.release)<<8 | u32(adsr.sustain)
  volume := u32(volume.sustain) | u32(volume.peak << 8)
  internal_tone(freq, adsr, volume, flags)
}

tone_unpacked :: proc "c" (channel : ToneChannel,
                           #any_int freq_start_hz, freq_end_hz : u32,
                           #any_int attack_ticks, decay_ticks, sustain_ticks, release_ticks : u32,
                           #any_int sustain_volume, peak_volume : u32,
                           duty_cycle := ToneDutyCycle.Mode3,
                           pan := TonePan.Center) {
  flags := u32(channel) | u32(duty_cycle) | u32(pan)
  freq := freq_start_hz | freq_end_hz<<16
  adsr := attack_ticks<<24 | decay_ticks<<16 | release_ticks<<8 | sustain_ticks
  volume := sustain_volume | peak_volume<< 8
  internal_tone(freq, adsr, volume, flags)
}

// Storage Functions ///////////////////////////////////////////////////////////////////////////////

@(default_calling_convention="c")
foreign wasm4 {

  diskr :: proc(dst : rawptr, size : int) -> int ---

  diskw :: proc(src : rawptr, size : int) -> int ---

}

// Other Functions /////////////////////////////////////////////////////////////////////////////////

@(default_calling_convention="c")
foreign wasm4 {

  @(link_name="traceUtf8")
  trace :: proc(text : string) ---

  /*
    %c: Character
    %d: Decimal
    %f: Float (Cast ints to float with f64(your_int))
    %s: String
    %x: Hex
  */
  tracef :: proc(fmt : cstring, #c_vararg args : ..any) ---

}
