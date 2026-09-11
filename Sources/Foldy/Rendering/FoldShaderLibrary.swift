#if !os(watchOS)
import Foundation
import Metal
import FoldyShaders

/// The Metal library from the `FoldyShaders` target, which only Metal platforms depend on.
/// Xcode compiles the shader into `default.metallib`; a plain `swift build` copies the source instead,
/// so it is compiled on first use and kept for the process.
@MainActor
enum FoldShaderLibrary {
    static var bundle: Bundle { FoldyShaderLibrary.bundle }
    private static var compiled: (any MTLLibrary)?

    static func makeLibrary(device: any MTLDevice) throws -> any MTLLibrary {
        if let library = try? device.makeDefaultLibrary(bundle: bundle) { return library }
        if let compiled { return compiled }
        guard let url = bundle.url(forResource: "Fold", withExtension: "metal") else {
            throw FoldFallbackReason.metalUnavailable
        }
        let library = try device.makeLibrary(source: try String(contentsOf: url, encoding: .utf8), options: nil)
        compiled = library
        return library
    }
}
#endif
