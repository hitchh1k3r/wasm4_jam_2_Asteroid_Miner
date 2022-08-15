package main

import glm "core:math/linalg/glsl"

// Half precision fixed point number (if world is 200x200x200 we have a resolution of 0.0031)
H3 :: [3]u16

// 24 byte limit, so we can fit an estimated 500 entities in 12000 bytes
#assert(size_of(Entity) <= 24)
// entities : [500]Entity
players : [4]EntityPlayer

Entity :: union {
  EntityComet,
}

EntityPlayer :: struct { // 28 bytes
  pos : V3,              //   12 bytes
  rotation : glm.quat,   //   16 bytes
}

EntityComet :: struct {  // 8 bytes
  pos : H3,              //   6 bytes
  animation_offset : u8, //   1 byte
  size : u8,             //   1 byte
}
