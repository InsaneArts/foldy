import XCTest
@testable import Foldy

final class FoldSwipeTrackerTests: XCTestCase {
    private let size = CGSize(width: 200, height: 400)

    func testShortTouchIsNotASwipeAndDoesNotSettle() {
        var tracker = FoldSwipeTracker()
        XCTAssertNil(tracker.changed(CGPoint(x: 5, y: 3), in: size, progress: 0))
        XCTAssertNil(tracker.ended(CGPoint(x: 5, y: 3), velocity: .zero, in: size, progress: 0))
    }

    func testAnyDirectionFoldsTowardTheFarEndpointAndReversesAlongTheSameLine() {
        var tracker = FoldSwipeTracker()
        let left = tracker.changed(CGPoint(x: -80, y: 0), in: size, progress: 0)
        XCTAssertEqual(left ?? 0, 0.5, accuracy: 0.001)
        // Moving back along the axis reduces progress; the axis was fixed by the first movement.
        XCTAssertEqual(tracker.changed(CGPoint(x: -40, y: 0), in: size, progress: 0.5) ?? 0, 0.25, accuracy: 0.001)
        XCTAssertEqual(tracker.ended(CGPoint(x: -40, y: 0), velocity: .zero, in: size, progress: 0.25), 0)
        var down = FoldSwipeTracker()
        XCTAssertEqual(down.changed(CGPoint(x: 0, y: 160), in: size, progress: 0) ?? 0, 0.5, accuracy: 0.001)
        var back = FoldSwipeTracker()
        XCTAssertEqual(back.changed(CGPoint(x: 80, y: 0), in: size, progress: 1) ?? 1, 0.5, accuracy: 0.001)
    }

    func testReleaseVelocityProjectsTheSettleTarget() {
        var tracker = FoldSwipeTracker()
        _ = tracker.changed(CGPoint(x: -30, y: 0), in: size, progress: 0)
        XCTAssertEqual(tracker.ended(CGPoint(x: -30, y: 0), velocity: CGPoint(x: -600, y: 0), in: size, progress: 0.19), 1)
        var slow = FoldSwipeTracker()
        _ = slow.changed(CGPoint(x: -30, y: 0), in: size, progress: 0)
        XCTAssertEqual(slow.ended(CGPoint(x: -30, y: 0), velocity: .zero, in: size, progress: 0.19), 0)
    }

    func testPagingReadsTheDominantAxisAgainstTheSwipe() {
        XCTAssertEqual(FoldSwipeTracker.page(CGPoint(x: -60, y: 5), velocity: .zero), .right)
        XCTAssertEqual(FoldSwipeTracker.page(CGPoint(x: 60, y: 5), velocity: .zero), .left)
        XCTAssertEqual(FoldSwipeTracker.page(CGPoint(x: 5, y: -60), velocity: .zero), .down)
        XCTAssertEqual(FoldSwipeTracker.page(CGPoint(x: 5, y: 60), velocity: .zero), .up)
        XCTAssertNil(FoldSwipeTracker.page(CGPoint(x: 20, y: 20), velocity: .zero))
        XCTAssertEqual(FoldSwipeTracker.page(CGPoint(x: 20, y: 0), velocity: CGPoint(x: 300, y: 0)), .left)
    }
}
