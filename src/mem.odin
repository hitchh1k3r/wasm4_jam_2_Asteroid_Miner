package main

import w4 "wasm4"

MEM_START                       :: 0x0000

MEM_PALLET1_UNUSED              :: 0x0007 // 1 byte
MEM_PALLET2_UNUSED              :: 0x000B // 1 byte
MEM_PALLET3_UNUSED              :: 0x000F // 1 byte
MEM_PALLET4_UNUSED              :: 0x0013 // 1 byte
MEM_RESERVED                    :: 0x0021 // 127 bytes

MEM_STACK_LAST                  :: 0x1EDF // 7376 stack size, can overrun wasm4's memory
MEM_GLOBAL_MEMORY               :: 0x1EE0

MEM_PLAYERS                     :: MEM_ENTITIES - size_of([4]EntityPlayer)
MEM_ENTITIES                    :: MEM_DEPTH_BUFFER - size_of([1024]EntityAsteroid)

MEM_DEPTH_BUFFER                :: MEM_TRANSIENT_DATA - size_of([w4.SCREEN_SIZE*w4.SCREEN_SIZE]Depth)

MEM_TRANSIENT_DATA              :: MEM_END - MEM_TRANSIENT_DATA_SIZE
MEM_TRANSIENT_DATA_SIZE         :: 64

MEM_END                         :: 0xFFFF
