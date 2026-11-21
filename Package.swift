// swift-tools-version: 6.2
import PackageDescription

let version = "51.0.0"
let checksum = "7a7b67aa93824f46e82687cf5868b4bd9e06662563ed0abc5afe59774faddcb8"

let package = Package(
    name: "CWasmtime",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CWasmtime", targets: ["CWasmtime"]),
    ],
    targets: [
        .binaryTarget(
            name: "CWasmtime",
            url: "https://github.com/AtlasEditor/atlas-wasmtime/releases/download/\(version)/CWasmtime-\(version).artifactbundle.zip",
            checksum: checksum
        ),
    ]
)
