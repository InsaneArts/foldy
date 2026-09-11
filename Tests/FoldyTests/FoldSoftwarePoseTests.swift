import XCTest
@testable import Foldy

final class FoldSoftwarePoseTests: XCTestCase {
    private let size = CGSize(width: 400, height: 800)

    func testRestIsFlatSharpAndBright() {
        let pose = FoldSoftwarePose(size: size, horizontal: 0, vertical: 0, style: .frosted)
        XCTAssertEqual(pose.angle, 0)
        XCTAssertEqual(pose.blurRadius, 0)
        XCTAssertEqual(pose.attenuation, 1)
    }

    func testBlurAndDarkeningFollowTheStyleOpticsAsTheShaderDoes() {
        let pose = FoldSoftwarePose(size: size, horizontal: .pi / 4, vertical: 0, style: .frosted)
        let gap = 400 * sin(Double.pi / 4) / 2
        XCTAssertEqual(pose.blurRadius, 0.12 * gap / 2, accuracy: 0.001)
        XCTAssertEqual(pose.attenuation, 1 - 0.015 * 0.12 * gap, accuracy: 0.001)
        let clear = FoldSoftwarePose(size: size, horizontal: .pi / 4, vertical: 0, style: FoldStyle(appearance: .clear))
        XCTAssertEqual(clear.blurRadius, 0)
        XCTAssertEqual(clear.attenuation, 1)
    }

    func testPerspectiveComesFromTheEyeDistanceAndInputsAreSanitized() {
        let pose = FoldSoftwarePose(size: size, horizontal: 0.3, vertical: -0.2, style: FoldStyle(eyeDistance: 1600))
        XCTAssertEqual(pose.perspective, 800 / 1600, accuracy: 0.0001)
        XCTAssertEqual(pose.pitch, -0.2)
        let wild = FoldSoftwarePose(size: size, horizontal: .nan, vertical: 9, style: FoldStyle(blur: .infinity))
        XCTAssertEqual(wild.angle, 0)
        XCTAssertEqual(wild.pitch, .pi / 2)
        XCTAssertTrue(wild.blurRadius.isFinite)
    }
}
