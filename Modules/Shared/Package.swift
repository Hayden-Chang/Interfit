// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
    ],
    targets: [
        .target(name: "Shared"),
        .testTarget(name: "SharedTests", dependencies: ["Shared"]),
    ]
)

