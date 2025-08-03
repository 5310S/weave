// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "weave",
    products: [
        .executable(name: "weave", targets: ["weave"])
    ],
    dependencies: [
        // TODO: Add libp2p dependency when available.
    ],
    targets: [
        // Targets define modules or test suites.
        .executableTarget(
            name: "weave",
            dependencies: []),
        .testTarget(
            name: "WeaveTests",
            dependencies: ["weave"])
    ]
)
