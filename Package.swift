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
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.7.0")
    ],
    targets: [
        // Targets define modules or test suites.
        .executableTarget(
            name: "weave",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ]),
        .testTarget(
            name: "WeaveTests",
            dependencies: ["weave"])
    ]
)
