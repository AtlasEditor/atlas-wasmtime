// swift-tools-version: 6.2
import PackageDescription

let version = "51.0.0"
let checksum = "0000000000000000000000000000000000000000000000000000000000000000"

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
