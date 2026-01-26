// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Persistence", targets: ["Persistence"]),
    ],
    dependencies: [
        .package(path: "../Shared"),
    ],
    targets: [
        .target(name: "Persistence", dependencies: ["Shared"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
    ]
)

