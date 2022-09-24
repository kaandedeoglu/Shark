// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shark",
    platforms: [
        .macOS("10.15"),
        .iOS("12.0"),
        .tvOS("12.0"),
        .watchOS("12.0"),
    ],
    products: [
        .executable(name: "Shark", targets: ["Shark"]),
        .plugin(name: "CreateResourceFile", targets: ["CreateResourceFile"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/xcodeproj.git", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.1"),
    ],
    targets: [
        .executableTarget(
            name: "Shark",
            dependencies: [
                .product(name: "XcodeProj", package: "xcodeproj"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .plugin(
            name: "CreateResourceFile",
            capability: .buildTool(),
            dependencies: ["Shark"]
        ),
        .testTarget(
            name: "SharkTests",
            dependencies: ["Shark"]),
    ]
)
