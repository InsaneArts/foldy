#if !os(watchOS)
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Supplies a prepared snapshot for content that the system cannot capture, such as video.
/// Called synchronously on the main actor, once at the start of each session.
public typealias FoldSnapshotProvider = @MainActor (_ view: FoldPlatformView) throws -> FoldPlatformImage

@MainActor
enum FoldCapture {
    static func image(of view: FoldPlatformView, scale: CGFloat, provider: FoldSnapshotProvider?) throws -> CGImage {
        #if canImport(UIKit)
        if let provider {
            let supplied = try provider(view)
            guard supplied.size.width > 0, supplied.size.height > 0 else { throw FoldFallbackReason.captureFailed }
            // Normalize orientation and color format, including CIImage-backed UIImages.
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.preferredRange = .standard
            let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
                supplied.draw(in: CGRect(origin: .zero, size: view.bounds.size))
            }
            guard let cgImage = image.cgImage else { throw FoldFallbackReason.captureFailed }
            return cgImage
        }
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        format.preferredRange = .standard
        var complete = false
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in
            complete = view.drawHierarchy(in: CGRect(origin: .zero, size: view.bounds.size), afterScreenUpdates: true)
        }
        guard complete, let cgImage = image.cgImage else { throw FoldFallbackReason.captureFailed }
        return cgImage
        #else
        let size = view.bounds.size
        if let provider {
            let supplied = try provider(view)
            guard supplied.size.width > 0, supplied.size.height > 0 else { throw FoldFallbackReason.captureFailed }
            return try draw(size: size, scale: scale) { supplied.draw(in: CGRect(origin: .zero, size: size)) }
        }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw FoldFallbackReason.captureFailed }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let native = rep.cgImage else { throw FoldFallbackReason.captureFailed }
        // The cache is at the window's backing scale; resample to the scale the renderer asked for.
        let image = NSImage(cgImage: native, size: size)
        return try draw(size: size, scale: scale) { image.draw(in: CGRect(origin: .zero, size: size)) }
        #endif
    }

    #if canImport(AppKit)
    /// Draws into a premultiplied BGRA bitmap of `size` at `scale` pixels per point.
    private static func draw(size: CGSize, scale: CGFloat, _ body: () -> Void) throws -> CGImage {
        let width = Int((size.width * scale).rounded()), height = Int((size.height * scale).rounded())
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else {
            throw FoldFallbackReason.captureFailed
        }
        context.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        body()
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { throw FoldFallbackReason.captureFailed }
        return image
    }
    #endif
}
#endif
