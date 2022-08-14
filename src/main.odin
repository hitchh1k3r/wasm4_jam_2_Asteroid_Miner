package main

import "core:math"
import "core:math/rand"
import glm "core:math/linalg/glsl"

import w4 "wasm4"

time : f32

@export
start :: proc "c" () {
  context = {}

  init_math()
  init_graphics()
}

@export
update :: proc "c" () {
  context = {}

  time += 1.0/60.0

  update_pallet()
  clear_depth_buffer()

  matrix_view =  glm.mat4Translate({ 0, 0, 10*sin(0.5*time)-12 }) * mat4Rotate(glm.vec3{ 1, 0, 0 }, math.TAU+0.5*sin(0.25*time)) * mat4Rotate(glm.vec3(V3_UP), 0.2*time)

  star_rand := rand.create(42)
  for star in 0..<100 {
    draw_star({ 2*rand.float32(&star_rand) - 1, 2*rand.float32(&star_rand) - 1, 2*rand.float32(&star_rand) - 1 })
  }

  draw_model(model_asteroid_01, { 0, 0, 0 }, quatAxisAngle(V3_UP, 0.5*time) * quatAxisAngle(V3_RIGHT, 0.3333*time))
}
