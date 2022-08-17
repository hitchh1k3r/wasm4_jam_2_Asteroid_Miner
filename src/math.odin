package main

import "core:math"
import glm "core:math/linalg/glsl"

// TODO (hitch) 2022-08-17 Rewrite all the glsl functions to not use array math!

// Vectors /////////////////////////////////////////////////////////////////////////////////////////

V2 :: glm.vec2
V3 :: glm.vec3
V4 :: glm.vec4

V2_ZERO    :: V2{  0,  0 }
V2_ONE     :: V2{  1,  1 }
V2_UP      :: V2{  0,  1 }
V2_DOWN    :: V2{  0, -1 }
V2_RIGHT   :: V2{  1,  0 }
V2_LEFT    :: V2{ -1,  0 }

V3_ZERO    :: V3{  0,  0,  0 }
V3_ONE     :: V3{  1,  1,  1 }
V3_UP      :: V3{  0,  1,  0 }
V3_DOWN    :: V3{  0, -1,  0 }
V3_RIGHT   :: V3{  1,  0,  0 }
V3_LEFT    :: V3{ -1,  0,  0 }
V3_FORWARD :: V3{  0,  0, -1 }
V3_BACK    :: V3{  0,  0,  1 }

to_v3 :: proc{ h3_to_v3 }

h3_to_v3 :: proc(v : H3) -> V3 {
  H_TO_WORLD :: 200.0 / f32(max(u16))
  res : V3
  res.x = f32(v.x) * H_TO_WORLD - 100.0
  res.y = f32(v.y) * H_TO_WORLD - 100.0
  res.z = f32(v.z) * H_TO_WORLD - 100.0
  return res
}

// Quaternions /////////////////////////////////////////////////////////////////////////////////////

Q  :: glm.quat

Q_ID       : Q

quat_euler :: proc(euler : V3) -> Q {
  cx, sx := cos(euler.x*0.5), sin(euler.x*0.5)
  cy, sy := cos(euler.y*0.5), sin(euler.y*0.5)
  cz, sz := cos(euler.z*0.5), sin(euler.z*0.5)

  q : Q

  q.x = sx*cy*cz - cx*sy*sz
  q.y = cx*sy*cz + sx*cy*sz
  q.z = cx*cy*sz - sx*sy*cz
  q.w = cx*cy*cz + sx*sy*sz

  return q
}

quat_axis_angle :: proc(axis : V3, radians : f32) -> Q {
  q : Q
  t := radians*0.5
  v := glm.normalize(axis) * sin(t)
  q.x = v.x
  q.y = v.y
  q.z = v.z
  q.w = cos(t)
  return q
}

// Matrix //////////////////////////////////////////////////////////////////////////////////////////

mat4_rotate :: proc(v : glm.vec3, radians : f32) -> glm.mat4 {
  c := cos(radians)
  s := sin(radians)

  a := glm.normalize(v)
  t := a * (1-c)

  rot := glm.mat4(1)

  rot[0, 0] = c + t[0]*a[0]
  rot[1, 0] = 0 + t[0]*a[1] + s*a[2]
  rot[2, 0] = 0 + t[0]*a[2] - s*a[1]
  rot[3, 0] = 0

  rot[0, 1] = 0 + t[1]*a[0] - s*a[2]
  rot[1, 1] = c + t[1]*a[1]
  rot[2, 1] = 0 + t[1]*a[2] + s*a[0]
  rot[3, 1] = 0

  rot[0, 2] = 0 + t[2]*a[0] + s*a[1]
  rot[1, 2] = 0 + t[2]*a[1] - s*a[0]
  rot[2, 2] = c + t[2]*a[2]
  rot[3, 2] = 0

  return rot
}

// Triangles ///////////////////////////////////////////////////////////////////////////////////////

RotationDirection :: enum u8 {
  None,
  Clockwise,
  Counter_Clockwise,
}

triangle_direction :: proc(a, b, c : V2) -> RotationDirection {
  lhs := b.x*a.y + c.x*b.y + a.x*c.y
  rhs := a.x*b.y + b.x*c.y + c.x*a.y

  if lhs > rhs {
    return .Counter_Clockwise
  } else if lhs < rhs {
    return .Clockwise
  } else {
    return .None
  }
}

// Math Functions //////////////////////////////////////////////////////////////////////////////////

SIN_COUNT :: 32
sin_lookup : [SIN_COUNT]f32

init_math :: proc() {
  Q_ID.w = 1
  sin_lookup[0] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(0))
  sin_lookup[1] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(1))
  sin_lookup[2] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(2))
  sin_lookup[3] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(3))
  sin_lookup[4] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(4))
  sin_lookup[5] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(5))
  sin_lookup[6] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(6))
  sin_lookup[7] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(7))
  sin_lookup[8] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(8))
  sin_lookup[9] =  math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(9))
  sin_lookup[10] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(10))
  sin_lookup[11] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(11))
  sin_lookup[12] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(12))
  sin_lookup[13] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(13))
  sin_lookup[14] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(14))
  sin_lookup[15] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(15))
  sin_lookup[16] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(16))
  sin_lookup[17] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(17))
  sin_lookup[18] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(18))
  sin_lookup[19] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(19))
  sin_lookup[20] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(20))
  sin_lookup[21] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(21))
  sin_lookup[22] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(22))
  sin_lookup[23] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(23))
  sin_lookup[24] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(24))
  sin_lookup[25] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(25))
  sin_lookup[26] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(26))
  sin_lookup[27] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(27))
  sin_lookup[28] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(28))
  sin_lookup[29] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(29))
  sin_lookup[30] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(30))
  sin_lookup[31] = math.sin_f32(0.25*math.TAU / SIN_COUNT * f32(31))
}

iround :: proc(v : f32) -> int {
  return int(math.round(v))
}

sin :: proc(angle : f32) -> f32 {
  angle_norm := math.mod(angle, math.TAU)
  if angle_norm < 0 {
    angle_norm += math.TAU
  }
  angle_norm /= math.TAU
  TOTAL_SAMPLE_POINTS :: 4*(SIN_COUNT-1)
  prev_idx := int(TOTAL_SAMPLE_POINTS * angle_norm)
  next_idx := (prev_idx + 1) % TOTAL_SAMPLE_POINTS
  prev_mul := f32(((prev_idx / (2*(SIN_COUNT-1))) % 2) == 1 ? -1 : 1)
  next_mul := f32(((next_idx / (2*(SIN_COUNT-1))) % 2) == 1 ? -1 : 1)

  if ((prev_idx / (SIN_COUNT-1)) % 2) == 1 {
    prev_idx %= (SIN_COUNT-1)
    prev_idx = SIN_COUNT-1 - (prev_idx % (SIN_COUNT-1))
  } else {
    prev_idx %= (SIN_COUNT-1)
  }

  if ((next_idx / (SIN_COUNT-1)) % 2) == 1 {
    next_idx %= (SIN_COUNT-1)
    next_idx = SIN_COUNT-1 - next_idx
  } else {
    next_idx %= (SIN_COUNT-1)
  }

  fract := f32(math.mod(TOTAL_SAMPLE_POINTS * angle_norm, 1))

  return (1-fract)*prev_mul*sin_lookup[prev_idx] + fract*next_mul*sin_lookup[next_idx]
}

cos :: proc(angle : f32) -> f32 {
  return sin(angle + 0.25*math.TAU)
}
