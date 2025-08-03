// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "weave",
    products: [
        .executable(name: "weave", targets: ["weave"])
    ],
    dependencies: [
        .package(url: "https://github.com/libp2p/swift-libp2p.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.7.0")
    ],
    targets: [
        // Targets define modules or test suites.
        .executableTarget(
            name: "weave",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                // Once released, this product will expose the libp2p host implementation.
                .product(name: "LibP2P", package: "swift-libp2p")
            ]),
        .testTarget(
            name: "WeaveTests",
            dependencies: ["weave"])
    ]
)
