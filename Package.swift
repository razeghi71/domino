// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Domino",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Domino",
            path: "Sources/Domino",
            resources: [.process("Resources")]
        ),
    ]
)
