// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shark",
    products: [
        .executable(name: "Shark", targets: ["Shark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/xcodeproj.git", .upToNextMajor(from: "8.27.3")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.5.0")),
    ],
    targets: [
        .target(
            name: "Shark",
            dependencies: ["XcodeProj", "ArgumentParser"]),
        .testTarget(
            name: "SharkTests",
            dependencies: ["Shark"]),
    ]
)
