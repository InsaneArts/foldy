#if !os(watchOS)
import Foundation
import FoldyShaders

/// The precompiled Metal library, built by the `FoldyShaders` target that only Metal platforms depend on.
enum FoldShaderLibrary {
    static var bundle: Bundle { FoldyShaderLibrary.bundle }
}
#endif
