import SwiftUI

/// Draws a fold with SwiftUI alone. The pane turns in three dimensions around its hinge, its free
/// edge receding the way the shader's projection compresses content there, and it blurs and darkens
/// with its lift. watchOS has no Metal, so every fold there is drawn this way; the content stays live.
struct FoldSoftwarePane: ViewModifier, Animatable {
    nonisolated var horizontal: Double
    nonisolated var vertical: Double
    var style: FoldStyle
    var reduceMotion: Bool

    @State private var size = CGSize.zero

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(horizontal, vertical) }
        set { horizontal = newValue.first; vertical = newValue.second }
    }

    func body(content: Content) -> some View {
        let pose = FoldSoftwarePose(size: size, horizontal: reduceMotion ? 0 : horizontal,
                                    vertical: reduceMotion ? 0 : vertical, style: style)
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .blur(radius: pose.blurRadius)
            .colorMultiply(Color(white: pose.attenuation))
            .rotation3DEffect(.radians(-pose.pitch), axis: (x: 1, y: 0, z: 0),
                              anchor: pose.pitch >= 0 ? .top : .bottom, perspective: pose.perspective)
            .rotation3DEffect(.radians(-pose.angle), axis: (x: 0, y: 1, z: 0),
                              anchor: pose.angle >= 0 ? .trailing : .leading, perspective: pose.perspective)
    }
}

/// The pose of a software pane, derived the way `FoldUniforms` derives the shader's.
struct FoldSoftwarePose: Equatable {
    /// Signed horizontal tilt in radians; positive hinges on the right edge.
    var angle: Double
    /// Signed vertical tilt in radians; positive hinges on the top edge.
    var pitch: Double
    /// Gaussian radius in points for the whole pane.
    var blurRadius: Double
    /// Fraction of light that passes the glass.
    var attenuation: Double
    /// SwiftUI's relative vanishing point, from the style's eye distance.
    var perspective: Double

    init(size: CGSize, horizontal: Double, vertical: Double, style: FoldStyle) {
        let style = style.sanitized
        let tilt = FoldTilt(horizontal: horizontal, vertical: vertical).sanitized()
        angle = tilt.horizontal
        pitch = tilt.vertical
        // The gap between glass and plane grows from nothing at the hinge to the pane's extent times
        // the sine of the tilt at the free edge. The mean gap sets one blur for the whole pane.
        let gap = (size.width * sin(abs(angle)) + size.height * sin(abs(pitch))) / 2
        let radius = style.blur * gap
        // A disc of radius r has the spread of a Gaussian with sigma r / 2.
        blurRadius = radius / 2
        attenuation = max(1 - style.darkening * radius, 0)
        let eye = max(style.eyeDistance, hypot(size.width, size.height) * 1.1)
        perspective = max(size.width, size.height) / eye
    }
}

func smoothstep(_ lower: Double, _ upper: Double, _ value: Double) -> Double {
    let t = min(max((value - lower) / (upper - lower), 0), 1)
    return t * t * (3 - 2 * t)
}
