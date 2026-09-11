import SwiftUI

/// The physical edge that stays attached to the content plane.
public enum FoldEdge: Sendable, CaseIterable {
    case left, right
}

/// How a two-view transition moves its panes.
public enum FoldChoreography: Sendable, CaseIterable {
    /// The source folds away over a stationary destination.
    case reveal
    /// The destination unfolds around the same hinge while the source folds away, like turning a page.
    case pageTurn
}

/// The material of the pane. Each appearance sets its own blur and darkening and adds a look:
/// frost speckle, a specular sheen, ink that bleeds into the fold, or none of these.
public enum FoldAppearance: Sendable, CaseIterable {
    /// The reference demo's frosted glass: heavy blur that darkens with distance.
    case frosted
    /// Optically clear glass: the same projection with no blur and no darkening.
    case clear
    /// Sanded glass with visible grain and a light diffusion.
    case grain
    /// Polished glass with a highlight that sweeps across the pane as it tilts.
    case gloss
    /// Ink on paper: the fold stays sharp and a shadow bleeds outward from the crease.
    case ink
    /// Night mode: cool, dark, and heavily diffused.
    case midnight
}

/// Optical parameters for the frosted pane. Distances are in points.
/// Defaults reproduce the reference demo's hand-held model: an eye 320 mm from the screen at 6 pt/mm.
public struct FoldStyle: Sendable, Equatable {
    /// The edge that stays attached to the content plane while the pane lifts.
    public var edge: FoldEdge
    /// Distance from the eye to the untilted screen, in points. Values below 200 are clamped.
    public var eyeDistance: Double
    /// Blur radius per point of separation from the content plane.
    public var blur: Double
    /// Fraction of light lost per point of blur radius.
    public var darkening: Double
    /// How a two-view transition moves its panes.
    public var choreography: FoldChoreography
    /// The pane's material. Setting it does not change `blur` or `darkening`; use `FoldStyle(appearance:)`
    /// to start from the appearance's own optics.
    public var appearance: FoldAppearance
    /// Liquid ripple, from zero to one. The glass wobbles as it lifts, like a surface disturbed by
    /// the fold, strongest far from the hinge. Zero is rigid glass.
    public var ripple: Double
    /// Where the viewer's eye sits over the pane, in unit coordinates. Keep the default for one pane.
    /// When several panes compose one surface, give each the shared eye so their projections agree:
    /// the top half of a display folded at its middle uses `UnitPoint(x: 0.5, y: 1)`, the bottom half `(0.5, 0)`.
    public var viewpoint: UnitPoint

    /// The reference demo's optics: an eye 1920 points away (320 mm at 6 pt/mm), frosted glass.
    public init(edge: FoldEdge = .right, eyeDistance: Double = 1920,
                blur: Double = 0.12, darkening: Double = 0.015,
                choreography: FoldChoreography = .reveal, viewpoint: UnitPoint = .center,
                appearance: FoldAppearance = .frosted, ripple: Double = 0) {
        self.edge = edge
        self.eyeDistance = eyeDistance
        self.blur = blur
        self.darkening = darkening
        self.choreography = choreography
        self.viewpoint = viewpoint
        self.appearance = appearance
        self.ripple = ripple
    }

    /// A style whose blur and darkening come from the appearance itself.
    public init(appearance: FoldAppearance, edge: FoldEdge = .right, choreography: FoldChoreography = .reveal) {
        let optics = appearance.optics
        self.init(edge: edge, blur: optics.blur, darkening: optics.darkening,
                  choreography: choreography, appearance: appearance)
    }

    /// The default style: frosted glass hinged on the right, with the reveal choreography.
    public static let frosted = FoldStyle()

    var sanitized: FoldStyle {
        FoldStyle(edge: edge,
                  eyeDistance: finiteClamp(eyeDistance, 200...20000, fallback: 1920),
                  blur: finiteClamp(blur, 0...0.5, fallback: 0.12),
                  darkening: finiteClamp(darkening, 0...0.1, fallback: 0.015),
                  choreography: choreography,
                  viewpoint: UnitPoint(x: finiteClamp(viewpoint.x, -4...5, fallback: 0.5),
                                       y: finiteClamp(viewpoint.y, -4...5, fallback: 0.5)),
                  appearance: appearance,
                  ripple: finiteClamp(ripple, 0...1, fallback: 0))
    }
}

extension FoldAppearance {
    /// Blur radius per point of gap and light lost per point of blur radius.
    public var optics: (blur: Double, darkening: Double) {
        switch self {
        case .frosted: (0.12, 0.015)
        case .clear: (0, 0)
        case .grain: (0.05, 0.012)
        case .gloss: (0.03, 0.006)
        case .ink: (0, 0.03)
        case .midnight: (0.2, 0.03)
        }
    }

    /// The shader's material index; keep in step with `Fold.metal`.
    var materialIndex: Float {
        switch self {
        case .frosted: 0
        case .clear: 1
        case .grain: 2
        case .gloss: 3
        case .ink: 4
        case .midnight: 5
        }
    }
}

func finiteClamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
    value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
}

/// An endpoint reached by an interactive or timed transition.
public enum FoldEndpoint: Sendable, Equatable {
    case source, destination

    var progress: Double { self == .source ? 0 : 1 }
}

/// Reasons the container displayed an endpoint without a Metal effect.
public enum FoldFallbackReason: Error, Sendable, Equatable {
    case reduceMotion, captureFailed, metalUnavailable, renderingFailed
}

/// Events are delivered on the main actor. Fallback is a diagnostic; an endpoint may follow it.
public enum FoldEvent: Sendable, Equatable {
    case completed(FoldEndpoint)
    case cancelled
    case fallback(FoldFallbackReason)
}
