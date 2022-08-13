@echo OFF

call vcvarsall amd64 1> NUL 2> NUL
..\..\Odin\odin build src -out:game.wasm -o:size -target:freestanding_wasm32 -ignore-vs-search -no-crt -no-entry-point -extra-linker-flags:"--import-memory -zstack-size=14752 --initial-memory=65536 --max-memory=65536 --stack-first --lto-O3 --gc-sections --strip-all"
