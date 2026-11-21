# atlas-wasmtime

The [wasmtime](https://github.com/bytecodealliance/wasmtime) C API as a SwiftPM package.

Replace `VERSION` with the wasmtime release version without the `v` prefix.

```swift
.package(url: "https://github.com/AtlasEditor/atlas-wasmtime.git", exact: "VERSION")
```

The package version is the wasmtime version. It needs Swift 6.2 or later and macOS 15 or later. Also available on Linux and on Windows, where it needs Swift 6.4 or later.

## How it is built

The [release workflow](.github/workflows/release.yml) builds the library from the upstream tag on GitHub Actions, runs the tests in `Tests` with it on every platform, and publishes the SwiftPM artifact bundle as a release of this repository. It runs every Monday and releases the latest wasmtime version if it is new.

For the commands below, set the shell variable `VERSION` to the wasmtime version without the `v` prefix. To publish a version by hand, run this from the repository checkout.

```sh
gh workflow run release.yml -f version="$VERSION"
```

Each release has a build provenance attestation. Download the release zip and run this from the directory that contains it.

```sh
gh attestation verify "CWasmtime-${VERSION}.artifactbundle.zip" -R AtlasEditor/atlas-wasmtime
```

To build the library locally for Apple silicon, run this from the repository checkout. The script needs Git, Cargo with the Rust target installed, and CMake. Publish releases through GitHub Actions.

```sh
Tools/build-wasmtime.sh "$VERSION" aarch64-apple-darwin out
```

## License

wasmtime is licensed under Apache 2.0 with the LLVM exception. The bundle carries a copy of [LICENSE](LICENSE).
