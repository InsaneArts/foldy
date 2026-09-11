// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Foldy",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Foldy", targets: ["Foldy"])],
    targets: [
        .target(name: "Foldy", resources: [.process("Shaders")]),
        .testTarget(name: "FoldyTests", dependencies: ["Foldy"])
    ]
)
