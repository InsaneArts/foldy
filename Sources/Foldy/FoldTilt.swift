import Foundation

/// Rotation of the frosted pane in radians. Both axes can move together.
public struct FoldTilt: Sendable, Equatable {
    /// Positive values keep the right edge fixed; negative values keep the left edge fixed.
    public var horizontal: Double
    /// Positive values keep the top edge fixed; negative values keep the bottom edge fixed.
    public var vertical: Double

    /// Both values are radians and are limited to ±90 degrees when applied.
    public init(horizontal: Double = 0, vertical: Double = 0) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// No tilt: live content is shown and the next capture is refreshed.
    public static let zero = FoldTilt()

    var isAtRest: Bool { abs(horizontal) < 0.0001 && abs(vertical) < 0.0001 }

    func sanitized(fallback: FoldTilt = .zero) -> FoldTilt {
        FoldTilt(horizontal: finiteClamp(horizontal, -(.pi / 2)...(.pi / 2), fallback: fallback.horizontal),
                 vertical: finiteClamp(vertical, -(.pi / 2)...(.pi / 2), fallback: fallback.vertical))
    }
}
