// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "weave",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "weave", targets: ["weave"])
    ],
    dependencies: [
        // Swift libp2p implementation providing the `Host` we wrap in
        // `LibP2PNode`.
        .package(url: "https://github.com/swift-libp2p/swift-libp2p.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.13.3"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2")
    ],
    targets: [
        // Targets define modules or test suites.
        .executableTarget(
            name: "weave",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                // Once released, this product will expose the libp2p host implementation.
                .product(name: "LibP2P", package: "swift-libp2p"),
                .product(name: "LibP2PKademlia", package: "swift-libp2p"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .testTarget(
            name: "WeaveTests",
            dependencies: ["weave"])
    ]
)
