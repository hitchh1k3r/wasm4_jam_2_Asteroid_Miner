package main

// Half precision fixed point number (if world is 200x200x200 we have a resolution of 0.0031)
H3 :: [3]u16

players : [4]EntityPlayer
// TODO (hitch) 2022-08-17 Quad tree for collisions (and improved culling)
asteroids := (^[500]EntityAsteroid)(uintptr(MEM_ASTEROIDS))

EntityPlayer :: struct { // 56 bytes
  speed : f32,           //    4 bytes
  pos : V3,              //   12 bytes
  rotation : Q,          //   16 bytes
  pos_velocity : V3,     //   12
  rot_velocity : V3,     //   12
}

EntityAsteroid :: struct { // 8 bytes
  pos : H3,                //   6 bytes
  variant : u8,            //   1 byte   ///   0b__VVSSTTTT M=model  S=size  T=rotation time offset
  health : u8,             //   1 byte
}
