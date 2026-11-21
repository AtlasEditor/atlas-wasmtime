# atlas-wasmtime

The [wasmtime](https://github.com/bytecodealliance/wasmtime) C API as a SwiftPM package.

```swift
.package(url: "https://github.com/AtlasEditor/atlas-wasmtime.git", exact: "51.0.0")
```

The package version is the wasmtime version. It needs Swift 6.2 or later and macOS 15 or later. Also available on Linux and on Windows, where it needs Swift 6.4 or later.

## How it is built

The [release workflow](.github/workflows/release.yml) builds the library from the upstream tag on GitHub Actions, runs the tests in `Tests` with it on every platform, and publishes the SwiftPM artifact bundle as a release of this repository. It runs every Monday and releases the latest wasmtime version if it is new.

Each release has a build provenance attestation, so you can check that the zip came from this workflow:

```sh
gh attestation verify CWasmtime-51.0.0.artifactbundle.zip -R AtlasEditor/atlas-wasmtime
```

To build the library for one target locally, run `Tools/build-wasmtime.sh 51.0.0 aarch64-apple-darwin out`. It needs cargo and cmake.

## License

wasmtime is licensed under Apache 2.0 with the LLVM exception. The bundle carries a copy of [LICENSE](LICENSE).
