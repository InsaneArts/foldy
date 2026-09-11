// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Foldy",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [.library(name: "Foldy", targets: ["Foldy"])],
    targets: [
        // The Metal library ships precompiled. watchOS has no Metal, so it never builds this target.
        .target(name: "FoldyShaders", resources: [.process("Shaders")]),
        .target(name: "Foldy", dependencies: [
            .target(name: "FoldyShaders", condition: .when(platforms: [.iOS]))
        ]),
        .testTarget(name: "FoldyTests", dependencies: ["Foldy"])
    ]
)
