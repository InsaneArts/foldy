import XCTest
import UIKit
@testable import Foldy

final class FoldContainerTests: XCTestCase {
    @MainActor
    private func fixture() throws -> (UIWindow, FoldContainerView) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let source = UIView()
        source.backgroundColor = .red
        let destination = UIView()
        destination.backgroundColor = .blue
        let container = FoldContainerView(source: source, destination: destination)
        controller.view.addSubview(container)
        container.frame = CGRect(x: 0, y: 80, width: 240, height: 300)
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        container.layoutIfNeeded()
        return (window, container)
    }

    @MainActor
    func testCapturesOnceAndRestoresLiveViewsAtEndpoints() throws {
        let (window, container) = try fixture()
        defer { window.isHidden = true }
        var events: [FoldEvent] = []
        container.onEvent = { events.append($0) }
        container.setProgress(0.2)
        XCTAssertTrue(container.isTransitioning, "Events: \(events)")
        container.setProgress(0.7)
        container.setProgress(0.3)
        XCTAssertEqual(container.captureCount, 1)
        XCTAssertGreaterThanOrEqual(container.submittedFrames, 1, "The first frame of a session is immediate")
        XCTAssertTrue(container.sourceView.isHidden)
        // Later poses are drawn on the display link, coalesced to one frame per refresh.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertGreaterThanOrEqual(container.submittedFrames, 2)
        container.setProgress(1)
        XCTAssertFalse(container.isTransitioning)
        XCTAssertFalse(try XCTUnwrap(container.destinationView).isHidden)
        XCTAssertEqual(events, [.completed(.destination)])
        let frames = container.submittedFrames
        container.setProgress(1)
        container.layoutIfNeeded()
        XCTAssertEqual(container.submittedFrames, frames, "Idle containers must not submit GPU frames")
        XCTAssertEqual(events.count, 1)
    }

    @MainActor
    func testResizeCancelsAndDoesNotRecaptureUntilRest() throws {
        let (window, container) = try fixture()
        defer { window.isHidden = true }
        var events: [FoldEvent] = []
        container.onEvent = { events.append($0) }
        container.setProgress(0.5)
        container.frame.size.width = 200
        container.layoutIfNeeded()
        XCTAssertFalse(container.isTransitioning)
        XCTAssertFalse(container.sourceView.isHidden)
        XCTAssertEqual(events, [.cancelled])
        container.setProgress(0.6)
        XCTAssertEqual(container.captureCount, 1)
        container.cancel()
        XCTAssertEqual(events, [.cancelled], "Ignored progress must not start another session")
        container.setProgress(0)
        container.setProgress(0.2)
        XCTAssertEqual(container.captureCount, 2)
    }

    @MainActor
    func testCaptureFailureReportsFallbackAndKeepsContentVisible() throws {
        let (window, container) = try fixture()
        defer { window.isHidden = true }
        container.sourceSnapshot = { _ in throw FoldFallbackReason.captureFailed }
        var events: [FoldEvent] = []
        container.onEvent = { events.append($0) }
        container.setProgress(0.6)
        container.setProgress(0.7)
        XCTAssertEqual(events, [.fallback(.captureFailed)])
        XCTAssertFalse(try XCTUnwrap(container.destinationView).isHidden)
        XCTAssertFalse(container.isTransitioning)
        XCTAssertEqual(container.submittedFrames, 0)
    }

    @MainActor
    func testReducedMotionSkipsCaptureAndGPUWork() throws {
        let (window, container) = try fixture()
        defer { window.isHidden = true }
        container.reducesMotion = true
        container.setProgress(0.4)
        XCTAssertFalse(container.sourceView.isHidden)
        container.setProgress(0.7)
        XCTAssertFalse(try XCTUnwrap(container.destinationView).isHidden)
        container.setProgress(0.2)
        XCTAssertFalse(container.sourceView.isHidden)
        container.setProgress(1)
        XCTAssertEqual(container.captureCount, 0)
        XCTAssertEqual(container.submittedFrames, 0)
        XCTAssertFalse(try XCTUnwrap(container.destinationView).isHidden)
    }

    @MainActor
    func testSuppliedSnapshotsAreOnlyRequestedOncePerSession() throws {
        let (window, container) = try fixture()
        defer { window.isHidden = true }
        var requests = 0
        container.sourceSnapshot = { view in
            requests += 1
            return UIGraphicsImageRenderer(size: view.bounds.size).image { context in
                UIColor.green.setFill()
                context.fill(view.bounds)
            }
        }
        container.setProgress(0.2)
        container.setProgress(0.8)
        XCTAssertEqual(requests, 1)
        container.cancel()
        XCTAssertFalse(container.sourceView.isHidden)
    }

    @MainActor
    func testDetachingStopsAnimationAndReleasesContainer() throws {
        let (window, container) = try fixture()
        defer { window.isHidden = true }
        container.setProgress(0.4)
        container.animate(to: .destination)
        container.removeFromSuperview()
        XCTAssertFalse(container.isTransitioning)
        XCTAssertEqual(container.progress, 0)
    }

    @MainActor
    func testMissingMetalDeviceFailsExplicitly() {
        XCTAssertThrowsError(try FoldRenderer(device: nil)) { error in
            XCTAssertEqual(error as? FoldFallbackReason, .metalUnavailable)
        }
    }

    @MainActor
    func testMotionSourceDoesNotStartOnInitialization() {
        let motion = FoldMotionSource()
        XCTAssertFalse(motion.isRunning)
        XCTAssertEqual(motion.angle, 0)
        motion.stop()
        XCTAssertFalse(motion.isRunning)
    }

    @MainActor
    func testSingleViewTiltReusesSnapshotAndRefreshesAfterZero() throws {
        let (window, _) = try fixture()
        defer { window.isHidden = true }
        let content = UILabel()
        content.text = "A live label"
        let effect = FoldContainerView(content: content)
        effect.frame = CGRect(x: 0, y: 60, width: 200, height: 240)
        window.rootViewController?.view.addSubview(effect)
        effect.layoutIfNeeded()
        effect.setAngle(0.4)
        effect.setAngle(-0.4)
        XCTAssertTrue(effect.isTransitioning)
        XCTAssertEqual(effect.captureCount, 1)
        effect.setAngle(0)
        XCTAssertFalse(effect.isTransitioning)
        XCTAssertFalse(content.isHidden)
        content.text = "Updated label"
        effect.setAngle(0.2)
        XCTAssertEqual(effect.captureCount, 2)
    }
}
