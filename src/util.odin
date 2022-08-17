package main

@(private="file")
internal_str_buffer := ((^[MEM_TRANSIENT_DATA_SIZE/size_of(u8)]u8)(uintptr(MEM_TRANSIENT_DATA)))

to_str :: proc{ int_to_str, f32_to_str }

int_to_str :: proc(#any_int num : int, str_buff : []u8 = nil) -> string {
  num := num
  str_buff := str_buff
  if str_buff == nil {
    str_buff = internal_str_buffer^[:]
  }

  neg := num < 0
  if neg {
    num = -num
  }
  digits : int = 1

  for i in 0..<len(str_buff) {
    digit := u8(num % 10)
    str_buff[len(str_buff)-1-i] = '0' + digit
    if digit > 0 {
      digits = i+1
    }
    num /= 10
  }

  if neg {
    if digits == len(str_buff) {
      digits -= 1
    }
    str_buff[len(str_buff)-1-digits] = '-'
    digits += 1
  }

  return string(str_buff[len(str_buff)-digits:])
}

f32_to_str :: proc(num : f32, decimals := 2, str_buff : []u8 = nil) -> string {
  f_num := num
  str_buff := str_buff
  if str_buff == nil {
    str_buff = internal_str_buffer^[:]
  }

  for i in 0..<decimals {
    f_num = 10 * f_num
  }
  num := int(f_num)
  neg := num < 0
  if neg {
    num = -num
  }
  digits : int = decimals + 2

  for i in 0..<len(str_buff) {
    if i == decimals {
      str_buff[len(str_buff)-1-i] = '.'
    } else {
      digit := u8(num % 10)
      str_buff[len(str_buff)-1-i] = '0' + digit
      if digit > 0 && i+1 > digits {
        digits = i+1
      }
      num /= 10
    }
  }

  if neg {
    if digits == len(str_buff) {
      digits -= 1
    }
    str_buff[len(str_buff)-1-digits] = '-'
    digits += 1
  }

  return string(str_buff[len(str_buff)-digits:])
}
