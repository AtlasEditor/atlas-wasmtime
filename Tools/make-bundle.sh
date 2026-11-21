#!/bin/sh
# Packs the libraries that build-wasmtime.sh built for every target into one SwiftPM artifact
# bundle, zips it and prints the checksum of the zip.
#
# Usage: Tools/make-bundle.sh <version> <directory with one build-wasmtime.sh output per target> <output>
# Needs: lipo, zip, swift. Writes <output>/CWasmtime.artifactbundle and
# <output>/CWasmtime-<version>.artifactbundle.zip.
set -eu

version=${1:?usage: make-bundle.sh <version> <builds> <output>}
builds=${2:?usage: make-bundle.sh <version> <builds> <output>}
output=${3:?usage: make-bundle.sh <version> <builds> <output>}
root=$(cd "$(dirname "$0")/.." && pwd)
bundle="$output/CWasmtime.artifactbundle"

rm -rf "$bundle"
mkdir -p "$bundle/modules"

# The headers are the same for every target, because they depend only on the enabled features.
cp -R "$builds/aarch64-apple-darwin/include" "$bundle/include"
cp "$root/LICENSE" "$bundle/LICENSE"

# Without these, wasm.h declares every function __declspec(dllimport) on Windows.
cat > "$bundle/include/CWasmtime.h" <<'EOF'
#define WASM_API_EXTERN
#define WASI_API_EXTERN
#include "wasmtime.h"
EOF

# The system libraries are the ones wasmtime's own CMake file links with the static library.
module_map() {
    printf 'module CWasmtime {\n    header "../include/CWasmtime.h"\n'
    for library in "$@"; do printf '    link %s\n' "$library"; done
    printf '    export *\n}\n'
}

module_map 'framework "CoreFoundation"' > "$bundle/modules/macos.modulemap"
module_map '"pthread"' '"dl"' '"m"' > "$bundle/modules/linux.modulemap"
module_map '"ws2_32"' '"advapi32"' '"userenv"' '"ntdll"' '"shell32"' '"ole32"' '"bcrypt"' \
    > "$bundle/modules/windows.modulemap"

variants=""

# Usage: add_variant <directory> <library file> <module map> <Swift triple>...
add_variant() {
    directory=$1
    library=$2
    module_map=$3
    shift 3
    triples=$(printf '"%s", ' "$@")

    variants="$variants${variants:+,}
        {
          \"path\": \"$directory/$library\",
          \"supportedTriples\": [${triples%, }],
          \"staticLibraryMetadata\": {\"headerPaths\": [\"include\"], \"moduleMapPath\": \"modules/$module_map\"}
        }"
}

mkdir -p "$bundle/macos"
lipo -create \
    "$builds/aarch64-apple-darwin/lib/libwasmtime.a" \
    "$builds/x86_64-apple-darwin/lib/libwasmtime.a" \
    -output "$bundle/macos/libwasmtime.a"
add_variant macos libwasmtime.a macos.modulemap arm64-apple-macosx x86_64-apple-macosx

for arch in x86_64 aarch64; do
    mkdir -p "$bundle/linux-$arch" "$bundle/windows-$arch"
    cp "$builds/$arch-unknown-linux-gnu/lib/libwasmtime.a" "$bundle/linux-$arch/"
    cp "$builds/$arch-pc-windows-msvc/lib/wasmtime.lib" "$bundle/windows-$arch/"
    add_variant "linux-$arch" libwasmtime.a linux.modulemap "$arch-unknown-linux-gnu"
    add_variant "windows-$arch" wasmtime.lib windows.modulemap "$arch-unknown-windows-msvc"
done

cat > "$bundle/info.json" <<EOF
{
  "schemaVersion": "1.0",
  "artifacts": {
    "CWasmtime": {
      "type": "staticLibrary",
      "version": "$version",
      "variants": [$variants
      ]
    }
  }
}
EOF

zip="$output/CWasmtime-$version.artifactbundle.zip"
rm -f "$zip"
(cd "$output" && zip -qry "$zip" CWasmtime.artifactbundle)
swift package compute-checksum "$zip"
