import XCTest
@testable import Foldy

final class FoldStateTests: XCTestCase {
    func testInteractiveCompletionIsDeliveredOnce() {
        var state = FoldTransitionState()
        XCTAssertNil(state.update(0))
        XCTAssertNil(state.update(0.4))
        XCTAssertNil(state.update(0.2))
        XCTAssertEqual(state.update(1), .completed(.destination))
        XCTAssertNil(state.update(1))
    }

    func testCancellationRestoresTheStartingEndpointInBothDirections() {
        var state = FoldTransitionState()
        _ = state.update(0.6)
        XCTAssertEqual(state.cancel(), .cancelled)
        XCTAssertEqual(state.progress, 0)
        XCTAssertNil(state.cancel())
        _ = state.update(1)
        _ = state.update(0.3)
        XCTAssertEqual(state.cancel(), .cancelled)
        XCTAssertEqual(state.progress, 1)
    }

    func testNonfiniteProgressDoesNotCorruptActiveSession() {
        var state = FoldTransitionState()
        _ = state.update(0.3)
        XCTAssertNil(state.update(.nan))
        XCTAssertNil(state.update(.infinity))
        XCTAssertEqual(state.progress, 0.3)
        XCTAssertEqual(state.update(-2), .completed(.source))
    }

    func testOpticsStayFiniteAndEyeStaysBeyondThePane() {
        let style = FoldStyle(eyeDistance: 0, blur: .infinity, darkening: 2)
        let uniforms = FoldUniforms(size: CGSize(width: 400, height: 800), angle: .infinity,
                                    progress: 0.5, style: style, isTransition: true)
        XCTAssertGreaterThan(uniforms.geometry.w, uniforms.geometry.x)
        XCTAssertTrue(uniforms.geometry.z.isFinite)
        XCTAssertEqual(uniforms.optics.y, 0.1)
        XCTAssertEqual(MemoryLayout<FoldUniforms>.stride, 64)
    }
}
