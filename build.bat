@echo OFF

call vcvarsall amd64 1> NUL 2> NUL

..\..\Odin\odin build src -out:game_comp.wasm -disable-assert -no-bounds-check -o:size -target:freestanding_wasm32 -ignore-vs-search -no-crt -no-entry-point -extra-linker-flags:"--import-memory -zstack-size=19200 --initial-memory=65536 --max-memory=65536 --stack-first --lto-O3 --gc-sections --strip-all"
wasm-opt -Oz --zero-filled-memory --strip-producers game_comp.wasm -o game.wasm