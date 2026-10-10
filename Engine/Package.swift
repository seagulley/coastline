// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoastlineEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CoastlineEngine", targets: ["CoastlineEngine"]),
    ],
    targets: [
        .target(name: "CoastlineEngine"),
        .testTarget(
            name: "CoastlineEngineTests",
            dependencies: ["CoastlineEngine"]
        ),
    ]
)
