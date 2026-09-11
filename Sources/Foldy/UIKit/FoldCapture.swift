import UIKit

/// Supplies a prepared snapshot for content that UIKit cannot capture, such as video.
/// Called synchronously on the main actor, once at the start of each session.
public typealias FoldSnapshotProvider = @MainActor (_ view: UIView) throws -> UIImage

@MainActor
enum FoldCapture {
    static func image(of view: UIView, scale: CGFloat, provider: FoldSnapshotProvider?) throws -> CGImage {
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
    }
}
