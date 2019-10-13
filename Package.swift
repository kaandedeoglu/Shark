// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shark",
    dependencies: [
        .package(url: "https://github.com/tuist/xcodeproj.git", .upToNextMajor(from: "7.1.0")),
        .package(url:  "https://github.com/apple/swift-tools-support-core.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "Shark",
            dependencies: ["SwiftToolsSupport", "XcodeProj"]),
        .testTarget(
            name: "SharkTests",
            dependencies: ["Shark"]),
    ]
)

