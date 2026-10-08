#!/bin/bash
# Builds Azahar for RG DS (RK3568, Cortex-A55) inside the azahar-rgds-build image.
# Usage: MODE=release|pgo-gen|pgo-use ./build.sh
#   release : -O3 + LTO                          -> build/bin/Release/azahar
#   pgo-gen : instrumented, writes .gcda to /storage/pgo on the device -> build-pgo/...
#   pgo-use : uses profiles copied to ./pgo-data (same build dir as pgo-gen) -> build-pgo/...
# The unstripped binary is kept as <build>/bin/Release/azahar.debug (for perf symbols).
set -e
cd "$(dirname "$0")"
MODE=${MODE:-release}
FLAGS='-O3 -mcpu=cortex-a55+crc+crypto+rcpc -fno-stack-protector -fno-plt'
BUILD=build
case "$MODE" in
  release) ;;
  pgo-gen) BUILD=build-pgo; FLAGS="$FLAGS -g1 -fprofile-generate=/storage/pgo -fprofile-update=single" ;;
  pgo-use) BUILD=build-pgo; FLAGS="$FLAGS -g1 -fprofile-use=/w/pgo-data -fprofile-partial-training -fprofile-correction -Wno-missing-profile -Wno-error=coverage-mismatch" ;;
  *) echo "unknown MODE $MODE"; exit 1 ;;
esac
docker run --rm -v "$PWD":/w -v "$PWD/.ccache":/ccache -e CCACHE_DIR=/ccache -w /w azahar-rgds-build bash -c "
  set -e
  cmake -S src -B $BUILD -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS_RELEASE='$FLAGS -DNDEBUG' -DCMAKE_CXX_FLAGS_RELEASE='$FLAGS -DNDEBUG' \
    -DCMAKE_EXE_LINKER_FLAGS='$FLAGS' \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DENABLE_LTO=ON -DENABLE_NATIVE_OPTIMIZATION=OFF -DCITRA_WARNINGS_AS_ERRORS=OFF \
    -DENABLE_QT=ON -DENABLE_QT_TRANSLATION=OFF -DENABLE_ROOM=OFF -DENABLE_TESTS=OFF \
    -DENABLE_SDL2=ON -DENABLE_OPENGL=ON -DENABLE_VULKAN=ON -DENABLE_LIBUSB=OFF \
    -DENABLE_OPENAL=OFF -DUSE_DISCORD_PRESENCE=OFF
  cmake --build $BUILD -j\$(nproc)
  cp $BUILD/bin/Release/azahar $BUILD/bin/Release/azahar.debug
  strip $BUILD/bin/Release/azahar
"
