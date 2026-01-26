// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Audio",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Audio", targets: ["Audio"]),
    ],
    dependencies: [
        .package(path: "../Shared")
    ],
    targets: [
        .target(name: "Audio", dependencies: [
            .product(name: "Shared", package: "Shared")
        ]),
        .testTarget(name: "AudioTests", dependencies: ["Audio", .product(name: "Shared", package: "Shared")]),
    ]
)

