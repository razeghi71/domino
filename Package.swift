// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MindMap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MindMap",
            path: "Sources/MindMap"
        ),
    ]
)
