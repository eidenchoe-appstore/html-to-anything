// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "HTMLToAnything",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HTMLToAnything", targets: ["HTMLToAnything"])
    ],
    targets: [
        .target(
            name: "HTMLToAnythingCore",
            path: "Sources/HTMLToAnythingCore"
        ),
        .executableTarget(
            name: "HTMLToAnything",
            dependencies: ["HTMLToAnythingCore"],
            path: "Sources/HTMLToAnything"
        ),
        .testTarget(
            name: "HTMLToAnythingCoreTests",
            dependencies: ["HTMLToAnythingCore"],
            path: "Tests/HTMLToAnythingCoreTests"
        )
    ]
)
