// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "weave",
    products: [
        .library(name: "weave", targets: ["weave"])
    ],
    dependencies: [],
    targets: [
        // Targets define modules or test suites.
        .target(
            name: "weave",
            dependencies: []),
        .testTarget(
            name: "WeaveTests",
            dependencies: ["weave"])
    ]
)
