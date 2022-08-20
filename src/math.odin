package main

import "core:math"
import glm "core:math/linalg/glsl"
import la "core:math/linalg"

// Generic /////////////////////////////////////////////////////////////////////////////////////////

RAD_PER_DEG :: math.RAD_PER_DEG
tan :: math.tan_f32
sqrt :: math.sqrt_f32
remap :: math.remap
round :: math.round_f32
to_v3 :: proc{ h3_to_v3 }
to_h3 :: proc{ v3_to_h3 }
add :: proc{ add_v3 }
mul :: proc{ quat_mul_v3, quat_mul_quat, scale_v3, mat_mul_v4, mat_mul_mat }
to_mat :: proc{ quat_to_mat }

// Vectors /////////////////////////////////////////////////////////////////////////////////////////

V2 :: glm.vec2
V3 :: glm.vec3
V4 :: glm.vec4
// Half precision fixed point number (if world is 200x200x200 we have a resolution of 0.0031)
H3 :: [3]u16

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

h3_to_v3 :: proc "contextless" (v : H3) -> V3 {
  H_TO_WORLD :: WORLD_SIZE / f32(max(u16))
  res : V3
  res.x = f32(v.x) * H_TO_WORLD - WORLD_SIZE/2
  res.y = f32(v.y) * H_TO_WORLD - WORLD_SIZE/2
  res.z = f32(v.z) * H_TO_WORLD - WORLD_SIZE/2
  return res
}

v3_to_h3 :: proc "contextless" (v : V3) -> H3 {
  WORLD_TO_H :: f32(max(u16)) / WORLD_SIZE
  res : H3
  res.x = u16((v.x + WORLD_SIZE/2) * WORLD_TO_H)
  res.y = u16((v.y + WORLD_SIZE/2) * WORLD_TO_H)
  res.z = u16((v.z + WORLD_SIZE/2) * WORLD_TO_H)
  return res
}

add_v3 :: proc "contextless" (a, b : V3) -> V3 {
  res := a
  res.x += b.x
  res.y += b.y
  res.z += b.z
  return res
}

scale_v3 :: proc "contextless" (s : f32, v : V3) -> V3 {
  v := v
  v.x *= s
  v.y *= s
  v.z *= s
  return v
}

cross :: proc "contextless" (a, b : V3) -> V3 {
  res : V3
  res.x = a.y*b.z - b.y*a.z
  res.y = a.z*b.x - b.z*a.x
  res.z = a.x*b.y - b.x*a.y
  return res
}

dir :: proc "contextless" (a, b : V3) -> V3 {
  res := b
  res.x -= a.x
  res.y -= a.y
  res.z -= a.z
  return res
}

norm_v3 :: proc "contextless" (v : V3) -> V3 {
  return mul(1.0/sqrt(dot(v, v)), v)
}

dot :: proc "contextless" (a, b : V3) -> f32 {
  return a.x*b.x + a.y*b.y + a.z*b.z
}

// Quaternions /////////////////////////////////////////////////////////////////////////////////////

Quat :: glm.quat

Quat_ID : Quat

quat_euler :: proc "contextless" (euler : V3) -> (q : Quat) {
  cx, sx := cos(euler.x*0.5), sin(euler.x*0.5)
  cy, sy := cos(euler.y*0.5), sin(euler.y*0.5)
  cz, sz := cos(euler.z*0.5), sin(euler.z*0.5)

  q.x = (sx*cy*cz - cx*sy*sz)
  q.y = (cx*sy*cz + sx*cy*sz)
  q.z = (cx*cy*sz - sx*sy*cz)
  q.w = (cx*cy*cz + sx*sy*sz)
  q = norm_quat(q)
  return
}

quat_mul_v3 :: proc "contextless" (q : Quat, v : V3) -> V3 {
  _Q4_IJK_R :: struct { ijk: V3, r : f32 }
  q := transmute(_Q4_IJK_R)(norm_quat(q))

  t := cross(mul(2.0, q.ijk), v)
  return V3(add(v, add(mul(q.r, t), cross(q.ijk, t))))
}

quat_mul_quat :: proc "contextless" (lhs, rhs : Quat) -> Quat {
  return norm_quat(lhs * rhs)
}

norm_quat :: proc "contextless" (q : Quat) -> Quat {
  q := q
  mag := abs(q)
  if mag != 0 {
    q.x /= mag
    q.y /= mag
    q.z /= mag
    q.w /= mag
  } else {
    q.x = 0
    q.y = 0
    q.z = 0
    q.w = 1
  }
  return q
}

// Matrix //////////////////////////////////////////////////////////////////////////////////////////

Matrix :: glm.mat4

mat_scale :: proc "contextless" (scale : V3) -> (m : Matrix) {
  m[0, 0] = scale.x
  m[1, 1] = scale.y
  m[2, 2] = scale.z
  m[3, 3] = 1
  return
}

// TODO (hitch) 2022-08-20 remove this!
mat_translate :: proc "contextless" (translate : V3) -> (m : Matrix) {
  m[0, 0] = 1
  m[1, 1] = 1
  m[2, 2] = 1
  m[0, 3] = translate.x
  m[1, 3] = translate.y
  m[2, 3] = translate.z
  m[3, 3] = 1
  return
}

mat_look :: proc "contextless" (eye, center, up: V3) -> (m : Matrix) {
  f := norm_v3(dir(eye, center))
  s := norm_v3(cross(f, up))
  u := cross(s, f)

  fe := dot(f, eye)

  m[0, 0] =  s.x
  m[1, 0] =  u.x
  m[2, 0] = -f.x
  m[0, 1] =  s.y
  m[1, 1] =  u.y
  m[2, 1] = -f.y
  m[0, 2] =  s.z
  m[1, 2] =  u.z
  m[2, 2] = -f.z
  m[0, 3] = -dot(s, eye)
  m[1, 3] = -dot(u, eye)
  m[2, 3] =  fe
  m[3, 3] =  1
  return
}

mat_mul_v4 :: proc "contextless" (m : Matrix, v : V4) -> V4 {
  return V4{
      v.x*m[0, 0] + v.y*m[0, 1] + v.z*m[0, 2] + v.w*m[0, 3],
      v.x*m[1, 0] + v.y*m[1, 1] + v.z*m[1, 2] + v.w*m[1, 3],
      v.x*m[2, 0] + v.y*m[2, 1] + v.z*m[2, 2] + v.w*m[2, 3],
      v.x*m[3, 0] + v.y*m[3, 1] + v.z*m[3, 2] + v.w*m[3, 3],
    }
}

quat_to_mat :: glm.mat4FromQuat

mat_mul_mat :: proc "contextless" (lhs, rhs : Matrix) -> (m : Matrix) {
  for r in 0..<4 {
    for c in 0..<4 {
      m[r, c] = lhs[r, 0]*rhs[0, c] + lhs[r, 1]*rhs[1, c] + lhs[r, 2]*rhs[2, c] + lhs[r, 3]*rhs[3, c]
    }
  }
  return
}

// Triangles ///////////////////////////////////////////////////////////////////////////////////////

RotationDirection :: enum u8 {
  None,
  Clockwise,
  Counter_Clockwise,
}

triangle_direction :: proc "contextless" (a, b, c : V2) -> RotationDirection {
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

init_math :: proc "contextless" () {
  Quat_ID.w = 1
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

iround :: proc "contextless" (v : f32) -> int {
  return int(round(v))
}

sin :: proc "contextless" (angle : f32) -> f32 {
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

cos :: proc "contextless" (angle : f32) -> f32 {
  return sin(angle + 0.25*math.TAU)
}

ease_quad_out :: proc "contextless" (num : f32) -> f32 {
  num := 1-num
  return 1 - num*num
}
