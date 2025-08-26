// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "weave",
    platforms: [
        .iOS(.v17), .macOS(.v13)
    ],
    products: [
        .library(name: "weave", targets: ["weave"]),
        .executable(name: "weaveApp", targets: ["weaveApp"])
    ],
    targets: [
        .target(
            name: "weave",
            path: "weave",
            exclude: ["weaveApp.swift", "Assets.xcassets", "weave.entitlements"],
            sources: ["Kademlia.swift", "P2PManager.swift", "UPnPPortMapper.swift", "ContentView.swift"]
        ),
        .executableTarget(
            name: "weaveApp",
            dependencies: ["weave"],
            path: "weave",
            exclude: ["Kademlia.swift", "P2PManager.swift", "UPnPPortMapper.swift", "ContentView.swift"],
            sources: ["weaveApp.swift"],
            resources: [
                .process("Assets.xcassets"),
                .copy("weave.entitlements")
            ]
        ),
        .testTarget(name: "weaveTests", dependencies: ["weave"], path: "weaveTests")
    ]
)
