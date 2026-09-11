import XCTest
import SwiftUI
@testable import Foldy

final class FoldSoftwarePaneTests: XCTestCase {
    /// The shader compresses content toward the hinge, so the software pane's free edge must recede:
    /// it is drawn shorter than the hinge edge, whichever side the hinge is on.
    @MainActor
    func testFreeEdgeRecedesOnBothHinges() throws {
        let hingedRight = try edgeHeights(angle: 0.9)
        XCTAssertLessThan(hingedRight.left, hingedRight.right, "Hinged right, the left edge is free")
        let hingedLeft = try edgeHeights(angle: -0.9)
        XCTAssertGreaterThan(hingedLeft.left, hingedLeft.right, "Hinged left, the right edge is free")
        let flat = try edgeHeights(angle: 0)
        XCTAssertEqual(flat.left, flat.right)
        XCTAssertEqual(flat.left, 120, accuracy: 2)
    }

    /// Heights in pixels of the leftmost and rightmost red columns of a 120-point red card.
    @MainActor
    private func edgeHeights(angle: Double) throws -> (left: Int, right: Int) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let content = Color.red
            .frame(width: 120, height: 120)
            .modifier(FoldSoftwarePane(horizontal: angle, vertical: 0, style: FoldStyle(appearance: .clear),
                                       reduceMotion: false))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea()
        let host = UIHostingController(rootView: content)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        let bounds = host.view.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            host.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        func redRows(at x: Int) -> Int {
            (0..<height).filter { y in
                let index = (y * width + x) * 4
                return pixels[index] > 128 && pixels[index + 1] < 80
            }.count
        }
        let columns = (0..<width).filter { redRows(at: $0) > 0 }
        let first = try XCTUnwrap(columns.first), last = try XCTUnwrap(columns.last)
        return (redRows(at: first + 2), redRows(at: last - 2))
    }
}
