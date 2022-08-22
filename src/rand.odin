package main

Rand :: struct {
  state: u64,
  inc:   u64,
  is_system: bool,
}

rand_create :: proc "contextless" (seed: u64) -> Rand {
  r: Rand
  r.state = 0
  r.inc = (seed << 1) | 1
  rand_uint32(&r)
  r.state += seed
  rand_uint32(&r)
  return r
}

rand_uint32 :: proc "contextless" (r: ^Rand) -> u32 {
  old_state := r.state
  r.state = old_state * 6364136223846793005 + (r.inc|1)
  xor_shifted := u32(((old_state>>18) ~ old_state) >> 27)
  rot := u32(old_state >> 59)
  return (xor_shifted >> rot) | (xor_shifted << ((-rot) & 31))
}

rand_float32 :: proc "contextless" (r: ^Rand = nil) -> f32 {
  return f32(rand_uint32(r)%(1<<24)) / (1<<24)
}
