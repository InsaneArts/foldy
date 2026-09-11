import XCTest
import UIKit
@testable import Foldy

final class FoldMotionTests: XCTestCase {
    @MainActor
    func testCalibratedNormalIsNeutralInEveryOrientation() {
        for orientation: UIInterfaceOrientation in [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown] {
            XCTAssertEqual(FoldMotionSource.tilt(normal: SIMD3(0, 0, 1), orientation: orientation), .zero)
        }
    }

    @MainActor
    func testBothAxesAreMappedIntoTheOwningScreenOrientation() {
        // A normal leaning right and down means the right and bottom edges are farther away.
        let portrait = FoldMotionSource.tilt(normal: SIMD3(0.3, -0.4, 0.866), orientation: .portrait)
        XCTAssertGreaterThan(portrait.horizontal, 0)
        XCTAssertLessThan(portrait.vertical, 0)
        let rotated = FoldMotionSource.tilt(normal: SIMD3(0.3, -0.4, 0.866), orientation: .landscapeLeft)
        XCTAssertLessThan(rotated.horizontal, 0)
        XCTAssertLessThan(rotated.vertical, 0)
        let reverse = FoldMotionSource.tilt(normal: SIMD3(-0.3, 0.4, 0.866), orientation: .portrait)
        XCTAssertEqual(portrait.horizontal, -reverse.horizontal, accuracy: 0.0001)
        XCTAssertEqual(portrait.vertical, -reverse.vertical, accuracy: 0.0001)
    }

    @MainActor
    func testBumpsAreOffUntilRequestedAndStyleOpticsFollowAppearance() {
        let motion = FoldMotionSource()
        XCTAssertNil(motion.onBump)
        XCTAssertEqual(motion.bumpThreshold, 0.18)
        let clear = FoldStyle(appearance: .clear)
        XCTAssertEqual(clear.blur, 0)
        XCTAssertEqual(clear.darkening, 0)
        XCTAssertEqual(FoldStyle(appearance: .frosted).blur, FoldStyle.frosted.blur)
        var custom = FoldStyle(blur: 0.3)
        custom.appearance = .ink
        XCTAssertEqual(custom.blur, 0.3, "Setting the appearance alone must not rewrite optics")
    }

    func testBothAxesMustBeAtRestAndNonfiniteInputsStaySafe() {
        XCTAssertFalse(FoldTilt(vertical: 0.2).isAtRest)
        XCTAssertTrue(FoldTilt.zero.isAtRest)
        XCTAssertEqual(FoldTilt(horizontal: .nan, vertical: .infinity).sanitized(), .zero)
    }
}
