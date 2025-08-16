// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "weave",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "weave", targets: ["weave"])
    ],
    targets: [
        .target(
            name: "weave",
            path: "weave",
            exclude: ["ContentView.swift", "weaveApp.swift", "Assets.xcassets"]
        ),
        .testTarget(name: "weaveTests", dependencies: ["weave"], path: "weaveTests")
    ]
)
