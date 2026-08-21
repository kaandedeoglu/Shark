// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shark",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Shark", targets: ["Shark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "9.12.0")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.5.0")),
    ],
    targets: [
        .target(
            name: "SharkKit",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "Shark",
            dependencies: [
                "SharkKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SharkTests",
            dependencies: ["SharkKit"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
