// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CWasmtimeTests",
    platforms: [.macOS(.v15)],
    targets: [
        .binaryTarget(name: "CWasmtime", path: "CWasmtime.artifactbundle"),
        .testTarget(
            name: "CWasmtimeTests",
            dependencies: ["CWasmtime"],
            path: "CWasmtimeTests",
            exclude: ["Modules/arithmetic.wat", "Modules/host.wat", "Modules/memory.wat"],
            resources: [.copy("Modules/arithmetic.wasm"), .copy("Modules/host.wasm"), .copy("Modules/memory.wasm")]
        ),
    ]
)
