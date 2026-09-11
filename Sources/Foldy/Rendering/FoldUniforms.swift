#if !os(watchOS)
import Foundation

struct FoldUniforms {
    var geometry: SIMD4<Float>
    var optics: SIMD4<Float>
    var output: SIMD4<Float>
    var viewpoint: SIMD4<Float>

    init(size: CGSize, angle: Double, progress: Double, style: FoldStyle, isTransition: Bool,
         verticalAngle: Double = 0) {
        let style = style.sanitized
        // The eye must stay beyond the farthest point the rotated pane can reach.
        let eye = max(style.eyeDistance, hypot(size.width, size.height) * 1.1)
        geometry = SIMD4(Float(size.width), Float(size.height),
                         Float(finiteClamp(abs(angle), 0...(.pi / 2), fallback: 0)), Float(eye))
        optics = SIMD4(Float(style.blur), Float(style.darkening), style.edge == .right ? 1 : 0,
                       Float(finiteClamp(progress, 0...1, fallback: 0)))
        let pitch = finiteClamp(verticalAngle, -(.pi / 2)...(.pi / 2), fallback: 0)
        output = SIMD4(isTransition ? 1 : 0, Float(pitch),
                       style.choreography == .pageTurn ? 1 : 0, Float(style.ripple))
        // The ripple travels with the fold, so its phase follows the tilt rather than a clock.
        viewpoint = SIMD4(Float(style.viewpoint.x * size.width), Float(style.viewpoint.y * size.height),
                          style.appearance.materialIndex, Float((geometry.z + Float(abs(pitch))) * 9))
    }
}
#endif
