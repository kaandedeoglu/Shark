// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shark",
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.1.0"),
        .package(url: "https://github.com/tuist/xcodeproj.git", .upToNextMajor(from: "6.6.0")),
    ],
    targets: [
        .target(
            name: "Shark",
            dependencies: ["Utility", "xcodeproj"]),
        .testTarget(
            name: "SharkTests",
            dependencies: ["Shark"]),
    ]
)
