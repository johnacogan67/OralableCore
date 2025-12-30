// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OralableCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OralableCore",
            targets: ["OralableCore"]),
    ],
    dependencies: [
        // No external dependencies - keeping package lightweight
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OralableCore",
            dependencies: [],
            path: "Sources/OralableCore"
        ),
        .testTarget(
            name: "OralableCoreTests",
            dependencies: ["OralableCore"],
            path: "Tests/OralableCoreTests"
        ),
    ]
)
