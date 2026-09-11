#if os(macOS)
import XCTest
import AppKit
@testable import Foldy

final class FoldContainerMacTests: XCTestCase {
    @MainActor
    private func window(width: CGFloat = 320, height: CGFloat = 400) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.orderFrontRegardless()
        return window
    }

    @MainActor
    private func colorView(_ color: NSColor, size: CGSize = CGSize(width: 240, height: 300)) -> NSView {
        let view = NSView(frame: CGRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        return view
    }

    @MainActor
    private func fixture() throws -> (NSWindow, FoldContainerView) {
        let window = window()
        let container = FoldContainerView(source: colorView(.red), destination: colorView(.blue))
        container.frame = NSRect(x: 0, y: 0, width: 240, height: 300)
        try XCTUnwrap(window.contentView).addSubview(container)
        container.layoutSubtreeIfNeeded()
        return (window, container)
    }

    @MainActor
    func testCapturesOnceAndRestoresLiveViewsAtEndpoints() throws {
        let (window, container) = try fixture()
        defer { window.orderOut(nil) }
        var events: [FoldEvent] = []
        container.onEvent = { events.append($0) }
        container.setProgress(0.2)
        XCTAssertTrue(container.isTransitioning, "Events: \(events)")
        container.setProgress(0.7)
        container.setProgress(0.3)
        XCTAssertEqual(container.captureCount, 1)
        XCTAssertGreaterThanOrEqual(container.submittedFrames, 1, "The first frame of a session is immediate")
        XCTAssertTrue(container.sourceView.isHidden)
        container.setProgress(1)
        XCTAssertFalse(container.isTransitioning)
        XCTAssertFalse(try XCTUnwrap(container.destinationView).isHidden)
        XCTAssertEqual(events, [.completed(.destination)])
        let frames = container.submittedFrames
        container.setProgress(1)
        container.layoutSubtreeIfNeeded()
        XCTAssertEqual(container.submittedFrames, frames, "Idle containers must not submit GPU frames")
    }

    @MainActor
    func testResizeCancelsAndDoesNotRecaptureUntilRest() throws {
        let (window, container) = try fixture()
        defer { window.orderOut(nil) }
        var events: [FoldEvent] = []
        container.onEvent = { events.append($0) }
        container.setProgress(0.5)
        container.setFrameSize(NSSize(width: 200, height: 300))
        container.layoutSubtreeIfNeeded()
        XCTAssertFalse(container.isTransitioning)
        XCTAssertFalse(container.sourceView.isHidden)
        XCTAssertEqual(events, [.cancelled])
        container.setProgress(0.6)
        XCTAssertEqual(container.captureCount, 1, "Ignored progress must not start another session")
        container.setProgress(0)
        container.setProgress(0.2)
        XCTAssertEqual(container.captureCount, 2)
    }

    @MainActor
    func testReducedMotionSkipsCaptureAndGPUWork() throws {
        let (window, container) = try fixture()
        defer { window.orderOut(nil) }
        container.reducesMotion = true
        container.setProgress(0.4)
        XCTAssertFalse(container.sourceView.isHidden)
        container.setProgress(0.7)
        XCTAssertFalse(try XCTUnwrap(container.destinationView).isHidden)
        container.setProgress(1)
        XCTAssertEqual(container.captureCount, 0)
        XCTAssertEqual(container.submittedFrames, 0)
    }

    @MainActor
    func testSingleViewTiltReusesSnapshotAndRefreshesAfterZero() throws {
        let window = window()
        defer { window.orderOut(nil) }
        let content = colorView(.green, size: CGSize(width: 200, height: 240))
        let effect = FoldContainerView(content: content)
        effect.frame = NSRect(x: 0, y: 0, width: 200, height: 240)
        try XCTUnwrap(window.contentView).addSubview(effect)
        effect.layoutSubtreeIfNeeded()
        effect.setAngle(0.4)
        effect.setAngle(-0.4)
        XCTAssertTrue(effect.isTransitioning)
        XCTAssertEqual(effect.captureCount, 1)
        effect.setAngle(0)
        XCTAssertFalse(effect.isTransitioning)
        XCTAssertFalse(content.isHidden)
        effect.setAngle(0.2)
        XCTAssertEqual(effect.captureCount, 2)
    }

    @MainActor
    func testHierarchyCaptureIsUprightAtTheRequestedScale() throws {
        let window = window(width: 100, height: 100)
        defer { window.orderOut(nil) }
        let view = colorView(.blue, size: CGSize(width: 40, height: 40))
        // AppKit's origin is bottom-left, so this red strip is the top half of the view.
        let strip = colorView(.red, size: CGSize(width: 40, height: 20))
        strip.frame.origin.y = 20
        view.addSubview(strip)
        try XCTUnwrap(window.contentView).addSubview(view)
        let image = try FoldCapture.image(of: view, scale: 2, provider: nil)
        XCTAssertEqual(image.width, 80)
        XCTAssertEqual(image.height, 80)
        let pixel = try pixels(of: image)
        XCTAssertGreaterThan(pixel(40, 8).red, 200, "The top rows must be the red strip")
        XCTAssertLessThan(pixel(40, 8).blue, 60)
        XCTAssertGreaterThan(pixel(40, 72).blue, 200, "The bottom rows must be the blue base")
        XCTAssertLessThan(pixel(40, 72).red, 60)
    }

    @MainActor
    func testSuppliedSnapshotIsResampledToTheView() throws {
        let view = colorView(.blue, size: CGSize(width: 40, height: 40))
        let image = try FoldCapture.image(of: view, scale: 1) { _ in
            NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
                NSColor.green.setFill()
                rect.fill()
                return true
            }
        }
        XCTAssertEqual(image.width, 40)
        XCTAssertEqual(image.height, 40)
        let pixel = try pixels(of: image)
        XCTAssertGreaterThan(pixel(20, 20).green, 200)
        XCTAssertLessThan(pixel(20, 20).red, 60)
    }

    /// RGBA samples of `image`, addressed by column and row from the top-left.
    private func pixels(of image: CGImage) throws -> (Int, Int) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let width = image.width, height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        try buffer.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return { x, y in
            let index = (y * width + x) * 4
            return (buffer[index], buffer[index + 1], buffer[index + 2])
        }
    }
}
#endif
