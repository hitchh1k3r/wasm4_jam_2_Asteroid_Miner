package main

import "core:os"
import "core:fmt"
import stbi "vendor:stb/image"

main :: proc() {
  size : [2]i32
  channels : i32
  bytes := stbi.load("noise_16.png", &size.x, &size.y, &channels, 1)
  os.write_entire_file("blue_noise_void_cluster_16.bytes", bytes[:size.x*size.y])

  bytes = stbi.load("noise_32.png", &size.x, &size.y, &channels, 1)
  os.write_entire_file("blue_noise_void_cluster_32.bytes", bytes[:size.x*size.y])

  bytes = stbi.load("noise_64.png", &size.x, &size.y, &channels, 1)
  os.write_entire_file("blue_noise_void_cluster_64.bytes", bytes[:size.x*size.y])
}
