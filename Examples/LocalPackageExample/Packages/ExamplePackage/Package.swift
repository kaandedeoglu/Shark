// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExamplePackage",
    products: [
        .library(name: "ExamplePackage", targets: ["ExamplePackage"]),
    ],
    targets: [
        .target(name: "ExamplePackage"),
    ]
)
