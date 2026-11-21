#!/bin/sh
# Builds the wasmtime C API as a static library for one Rust target and installs the library and
# its headers into <output>/lib and <output>/include.
#
# Usage: Tools/build-wasmtime.sh <version> <rust target> <output>
# Needs: git, cargo with the Rust target installed, cmake.
set -eu

version=${1:?usage: build-wasmtime.sh <version> <rust target> <output>}
target=${2:?usage: build-wasmtime.sh <version> <rust target> <output>}
output=${3:?usage: build-wasmtime.sh <version> <rust target> <output>}
work=${WORK:-$(mktemp -d)}
source="$work/wasmtime-$version"

if [ ! -d "$source" ]; then
    git clone --quiet --depth 1 --branch "v$version" --recurse-submodules --shallow-submodules \
        https://github.com/bytecodealliance/wasmtime.git "$source"
fi

# LTO with one codegen unit gives a smaller library.
export CARGO_PROFILE_RELEASE_LTO=fat
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
export CARGO_PROFILE_RELEASE_STRIP=debuginfo

# Only what tree-sitter grammars need: Cranelift and the null garbage collector. Epoch
# interruption and store limits are part of the core and need no feature.
cmake -S "$source/crates/c-api" -B "$work/build-$target" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_INSTALL_PREFIX="$output" \
    -DWASMTIME_TARGET="$target" \
    -DWASMTIME_DISABLE_ALL_FEATURES=ON \
    -DWASMTIME_FEATURE_CRANELIFT=ON \
    -DWASMTIME_FEATURE_GC=ON \
    -DWASMTIME_FEATURE_GC_NULL=ON \
    -DWASMTIME_FEATURE_DISABLE_LOGGING=ON
cmake --build "$work/build-$target" --config Release
cmake --install "$work/build-$target"

# Only the C headers and the static library are shipped.
find "$output/include" \( -name '*.hh' -o -name 'doc-*.h' \) -delete
find "$output/include" -type d -empty -delete
rm -rf "$output/bin" "$output"/lib/*.dylib "$output"/lib/*.so "$output"/lib/*.dll*
