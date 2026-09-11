import XCTest
import Metal
import SwiftUI
@testable import Foldy

final class FoldShaderTests: XCTestCase {
    @MainActor
    func testPackagedShaderRendersExactTransitionEndpoints() throws {
        let start = try render(angle: 0, progress: 0)
        XCTAssertEqual(Array(start[0..<4]), [0, 0, 255, 255])
        let end = try render(angle: .pi / 2, progress: 1)
        XCTAssertEqual(Array(end[0..<4]), [255, 0, 0, 255])
    }

    @MainActor
    func testMidpointContainsBothScreens() throws {
        let pixels = try render(angle: .pi / 4, progress: 0.5)
        let center = (16 * 32 + 16) * 4
        XCTAssertGreaterThan(pixels[center], 0, "Destination blue must be visible")
        XCTAssertGreaterThan(pixels[center + 2], 0, "Source red must remain visible")
        XCTAssertEqual(pixels[center + 3], 255)
    }

    @MainActor
    func testPageTurnMidpointShowsBothPanesAndEndsOnTheDestination() throws {
        let turning = FoldStyle(choreography: .pageTurn)
        let pixels = try render(angle: .pi / 4, progress: 0.5, style: turning)
        let center = (16 * 32 + 16) * 4
        XCTAssertGreaterThan(pixels[center], 0, "Destination blue must be visible")
        XCTAssertGreaterThan(pixels[center + 2], 0, "Source red must remain visible")
        let end = try render(angle: .pi / 2, progress: 1, style: turning)
        XCTAssertEqual(Array(end[0..<4]), [255, 0, 0, 255])
    }

    @MainActor
    func testViewpointMovesTheEyeOnlyWhenTilted() throws {
        let onHinge = FoldStyle(viewpoint: UnitPoint(x: 0.5, y: 0))
        let centered = try render(angle: 0, progress: 0, isTransition: false, verticalAngle: 0.6, gradientSource: true)
        let moved = try render(angle: 0, progress: 0, isTransition: false, verticalAngle: 0.6, style: onHinge, gradientSource: true)
        XCTAssertNotEqual(centered, moved, "A different eye position must change the projection")
        let flat = try render(angle: 0, progress: 0, isTransition: false, gradientSource: true)
        let flatMoved = try render(angle: 0, progress: 0, isTransition: false, style: onHinge, gradientSource: true)
        XCTAssertEqual(flat, flatMoved, "At rest the eye position has no effect")
    }

    @MainActor
    func testAppearancesDifferOnlyWhenTilted() throws {
        var tilted: [FoldAppearance: [UInt8]] = [:]
        for appearance in FoldAppearance.allCases {
            let style = FoldStyle(appearance: appearance)
            let flat = try render(angle: 0, progress: 0, isTransition: false, style: style, gradientSource: true)
            let reference = try render(angle: 0, progress: 0, isTransition: false, gradientSource: true)
            XCTAssertEqual(flat, reference, "\(appearance) must be invisible at rest")
            tilted[appearance] = try render(angle: 0.7, progress: 0, isTransition: false, style: style, gradientSource: true)
        }
        XCTAssertNotEqual(tilted[.frosted], tilted[.clear])
        XCTAssertNotEqual(tilted[.frosted], tilted[.grain])
        XCTAssertNotEqual(tilted[.frosted], tilted[.gloss])
        XCTAssertNotEqual(tilted[.frosted], tilted[.ink])
        XCTAssertNotEqual(tilted[.frosted], tilted[.midnight])
    }

    @MainActor
    func testRippleWobblesOnlyWhenTilted() throws {
        let liquid = FoldStyle(ripple: 1)
        let rigid = try render(angle: 0, progress: 0, isTransition: false, verticalAngle: 0.7, gradientSource: true)
        let wobbly = try render(angle: 0, progress: 0, isTransition: false, verticalAngle: 0.7, style: liquid, gradientSource: true)
        XCTAssertNotEqual(rigid, wobbly, "A ripple must displace the tilted projection")
        let flat = try render(angle: 0, progress: 0, isTransition: false, gradientSource: true)
        let flatLiquid = try render(angle: 0, progress: 0, isTransition: false, style: liquid, gradientSource: true)
        XCTAssertEqual(flat, flatLiquid, "At rest the ripple is invisible")
    }

    @MainActor
    func testSinglePanePreservesPremultipliedTransparency() throws {
        let pixels = try render(angle: 0, progress: 0, isTransition: false, sourceAlpha: 128)
        XCTAssertEqual(Array(pixels[0..<4]), [0, 0, 128, 128])
    }

    @MainActor
    func testVerticalTiltChangesPixelsAndReversesTheHinge() throws {
        let down = try render(angle: 0, progress: 0, isTransition: false, verticalAngle: 0.6)
        let up = try render(angle: 0, progress: 0, isTransition: false, verticalAngle: -0.6)
        let top = (2 * 32 + 16) * 4 + 2
        let bottom = (29 * 32 + 16) * 4 + 2
        XCTAssertGreaterThan(down[top], down[bottom])
        XCTAssertLessThan(up[top], up[bottom])
        let diagonal = try render(angle: 0.4, progress: 0, isTransition: false, verticalAngle: 0.4)
        XCTAssertNotEqual(diagonal, down)
    }

    @MainActor
    private func render(angle: Double, progress: Double, isTransition: Bool = true,
                        sourceAlpha: UInt8 = 255, verticalAngle: Double = 0,
                        style: FoldStyle = .frosted, gradientSource: Bool = false) throws -> [UInt8] {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        // The shader bundle is internal to Foldy and visible through @testable import.
        let library = try FoldShaderLibrary.makeLibrary(device: device)
        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.vertexFunction = library.makeFunction(name: "foldVertex")
        pipeline.fragmentFunction = library.makeFunction(name: "foldFragment")
        pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm
        let state = try device.makeRenderPipelineState(descriptor: pipeline)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: 32, height: 32, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .renderTarget]
        let source = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let destination = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let output = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        // Rows brighten downward when a gradient is requested, so a shifted sample reads differently.
        let red: [UInt8] = (0..<1024).flatMap { index -> [UInt8] in
            gradientSource ? [0, 0, UInt8(8 * (index / 32)), 255] : [0, 0, sourceAlpha, sourceAlpha]
        }
        let blue: [UInt8] = Array(repeating: [255, 0, 0, 255], count: 1024).flatMap { $0 }
        red.withUnsafeBytes { source.replace(region: MTLRegionMake2D(0, 0, 32, 32), mipmapLevel: 0,
                                            withBytes: $0.baseAddress!, bytesPerRow: 128) }
        blue.withUnsafeBytes { destination.replace(region: MTLRegionMake2D(0, 0, 32, 32), mipmapLevel: 0,
                                                   withBytes: $0.baseAddress!, bytesPerRow: 128) }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let command = try XCTUnwrap(queue.makeCommandBuffer())
        let encoder = try XCTUnwrap(command.makeRenderCommandEncoder(descriptor: pass))
        var uniforms = FoldUniforms(size: CGSize(width: 32, height: 32), angle: angle,
            progress: progress, style: style, isTransition: isTransition, verticalAngle: verticalAngle)
        encoder.setRenderPipelineState(state)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentTexture(destination, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FoldUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        XCTAssertEqual(command.status, .completed)
        var pixels = [UInt8](repeating: 0, count: 4096)
        pixels.withUnsafeMutableBytes { output.getBytes($0.baseAddress!, bytesPerRow: 128,
            from: MTLRegionMake2D(0, 0, 32, 32), mipmapLevel: 0) }
        return pixels
    }
}
