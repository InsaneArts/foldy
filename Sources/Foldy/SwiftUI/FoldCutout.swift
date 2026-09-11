import SwiftUI

/// The Dynamic Island or notch, in points from the top-left of a portrait window.
///
/// iOS does not expose this frame. These values were measured on the iOS 26 simulator with
/// device-masked screenshots, paired with the safe-area inset each window reports:
///
/// | Device               | Safe top | Cutout                        |
/// | -------------------- | -------- | ----------------------------- |
/// | iPhone 17, 17 Pro    | 62       | island 125.3 × 36.7 at y 14   |
/// | iPhone 17 Pro Max    | 62       | island 125.3 × 36.7 at y 14   |
/// | iPhone Air           | 68       | island 125.3 × 36.7 at y 20   |
/// | iPhone 16e           | 47       | notch 170.7 × 33.7 at y 0     |
///
/// The island is centered and sits 48 points above the safe-area inset on every measured phone.
/// Notch widths for older phones are approximated.
public struct FoldCutout: Equatable, Sendable {
    public enum Kind: Sendable { case island, notch }
    public let kind: Kind
    public let frame: CGRect

    public static let islandSize = CGSize(width: 125.3, height: 36.7)

    public init(kind: Kind, frame: CGRect) {
        self.kind = kind
        self.frame = frame
    }

    /// The cutout for a window with this safe-area top inset, or nil for screens without one.
    public static func detect(safeAreaTop: CGFloat, screenWidth: CGFloat) -> FoldCutout? {
        if safeAreaTop >= 54 {
            return FoldCutout(kind: .island, frame: CGRect(x: (screenWidth - islandSize.width) / 2, y: safeAreaTop - 48,
                                                           width: islandSize.width, height: islandSize.height))
        }
        if safeAreaTop >= 44 {
            let width: CGFloat = safeAreaTop >= 47 ? 170.7 : 209
            return FoldCutout(kind: .notch, frame: CGRect(x: (screenWidth - width) / 2, y: 0,
                                                          width: width, height: safeAreaTop - 13.3))
        }
        return nil
    }

    /// An island-sized target near the top for screens without a cutout, so an effect still has a goal.
    public static func placeholder(screenWidth: CGFloat) -> FoldCutout {
        FoldCutout(kind: .island, frame: CGRect(x: (screenWidth - islandSize.width) / 2, y: 11,
                                                width: islandSize.width, height: islandSize.height))
    }
}

/// Magnetic settling for a scroll view whose rows share one height: a scroll never rests with a row
/// half inside the cutout. Past a third of the way the row finishes being pulled in; before that it
/// returns to the list.
public struct FoldCutoutSnap: ScrollTargetBehavior {
    /// The first row's top in content coordinates.
    public var firstRowTop: CGFloat
    /// Row height plus spacing.
    public var period: CGFloat
    public var rows: Int
    /// Where a row starts folding, and where it is fully inside the cutout, both in window points.
    public var foldStart: CGFloat
    public var eaten: CGFloat

    public init(firstRowTop: CGFloat, period: CGFloat, rows: Int, foldStart: CGFloat, eaten: CGFloat) {
        self.firstRowTop = firstRowTop
        self.period = period
        self.rows = rows
        self.foldStart = foldStart
        self.eaten = eaten
    }

    public func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let offset = target.rect.origin.y
        for row in 0..<rows {
            let contentTop = firstRowTop + CGFloat(row) * period
            let top = contentTop - offset
            guard top > eaten, top < foldStart else { continue }
            let progress = (foldStart - top) / (foldStart - eaten)
            // Rest clear of the zone on both sides: well inside the cutout, or back at the row's
            // natural place. A target on the zone's edge would re-enter it on the next update.
            let restingTop = progress > 0.33 ? eaten - period * 0.5 : foldStart + 8
            target.rect.origin.y = min(max(contentTop - restingTop, 0), max(context.contentSize.height - context.containerSize.height, 0))
            return
        }
    }
}

/// Pulls a view from `start` into the cutout as `progress` goes from zero to one: it folds around its
/// bottom edge, frosts, shrinks to the cutout's size, converges on its center, and fades just before
/// it would show around the edges. Both frames are in the coordinate space the view is positioned in.
///
/// With `liquid`, the glass ripples as it lifts and a black goo layer under the view stretches toward
/// the cutout and merges with it, so the view is swallowed like liquid. The cutout reacts too: a bulge
/// reaches toward the view and ripples run around its outline as the view closes in. `settle`, from
/// zero to one, plays a decaying oscillation around the cutout once the view is inside; a
/// `FoldCutoutGhost` drives it after the pull. The goo is a blurred-and-thresholded silhouette, the
/// metaball technique, drawn in the cutout's own color.
public struct FoldCutoutPull: ViewModifier, Animatable {
    public nonisolated var progress: Double
    public nonisolated var settle: Double
    public var start: CGRect
    public var target: CGRect
    public var style: FoldStyle
    public var reducesMotion: Bool
    public var liquid: Bool

    public init(progress: Double, start: CGRect, target: CGRect, style: FoldStyle = FoldStyle(darkening: 0.05),
                reducesMotion: Bool = false, liquid: Bool = false, settle: Double = 0) {
        self.progress = progress
        self.settle = settle
        self.start = start
        self.target = target
        self.style = style
        self.reducesMotion = reducesMotion
        self.liquid = liquid
    }

    public nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, settle) }
        set { progress = newValue.first; settle = newValue.second }
    }

    public func body(content: Content) -> some View {
        let value = min(max(progress, 0), 1)
        let frame = frame(at: value)
        content
            .foldEffect(tilt: FoldTilt(vertical: -value * 1.3), style: paneStyle, reducesMotion: reducesMotion)
            .frame(width: start.width, height: start.height)
            .scaleEffect(x: frame.width / max(start.width, 1), y: frame.height / max(start.height, 1))
            .opacity(value < 0.8 ? 1 : max(0, 1 - (value - 0.8) / 0.2))
            .position(x: frame.midX, y: frame.midY)
            .background {
                if liquid && (value > 0.01 || settle > 0) && !reducesMotion {
                    goo(value: value, current: frame)
                }
            }
    }

    /// Where the view is at `value`. Its top edge is clamped to the cutout's mouth, so it never rises
    /// above the pill; from there it shrinks into the pill's width and is drawn inside it.
    private func frame(at value: Double) -> CGRect {
        let eased = value * value * (3 - 2 * value)
        let width = start.width + (target.width - start.width) * value
        let height = start.height + (target.height - start.height) * value
        let midX = start.midX + (target.midX - start.midX) * eased
        let top = max(start.minY + (target.midY - height / 2 - start.minY) * value, target.midY - height / 2)
        return CGRect(x: midX - width / 2, y: top, width: width, height: height)
    }

    /// The pane's style, rippling when the pull is liquid.
    private var paneStyle: FoldStyle {
        var paneStyle = style
        if liquid { paneStyle.ripple = 1 }
        return paneStyle
    }

    /// Liquid between the view and the cutout, blurred and thresholded so the parts bridge and merge.
    /// The view's lifted top edge dissolves into a band that travels with it; beads between the band
    /// and the cutout stay below the threshold while far apart and join into a tendril as the view
    /// closes in. The cutout reacts with a mouth that bulges toward the view and ripples around its
    /// outline, then rings down. Everything but the cutout itself fades with the view.
    private func goo(value: Double, current: CGRect) -> some View {
        Canvas { context, _ in
            context.addFilter(.alphaThreshold(min: 0.5, color: .black))
            context.addFilter(.blur(radius: 12))
            context.drawLayer { layer in
                let pill = target.insetBy(dx: 1, dy: 1)
                layer.fill(Path(roundedRect: pill, cornerRadius: pill.height / 2), with: .color(.black))
                // The view fades over the last fifth of the pull; its liquid must go with it.
                let presence = value < 0.8 ? 1.0 : max(0, 1 - (value - 0.8) / 0.2)
                let mouthX = min(max(current.midX, pill.minX + pill.height / 2), pill.maxX - pill.height / 2)
                let mouthY = pill.maxY
                // The band and beads only make sense near the island: they fade in over the last
                // 90 points of approach and are absent while the view is a plain card in the list.
                let nearness = min(max(1 - (current.minY - mouthY) / 90, 0), 1) * presence
                if nearness > 0.02 {
                    let bandHeight = min(max(10, current.height * 0.16), 22) * nearness
                    let inset = 8 + (1 - nearness) * current.width * 0.45
                    let band = CGRect(x: current.minX + inset, y: current.minY + 2,
                                      width: max(current.width - inset * 2, 4), height: max(bandHeight, 1))
                    layer.fill(Path(roundedRect: band, cornerRadius: band.height / 2), with: .color(.black))
                    let from = CGPoint(x: band.midX, y: band.minY)
                    let gap = max(from.y - mouthY, 0)
                    if gap > 4 {
                        let need = min(gap / 70, 1) * nearness
                        for bead in 1...4 {
                            let f = Double(bead) / 5
                            let sway = sin(value * 9 + Double(bead) * 1.7) * 6 * (1 - value)
                            let center = CGPoint(x: from.x + (mouthX - from.x) * f + sway, y: from.y + (mouthY - from.y) * f)
                            let radius = (3 + 13 * value * value) * need
                            guard radius > 1 else { continue }
                            layer.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                              width: radius * 2, height: radius * 2)), with: .color(.black))
                        }
                    }
                }
                let approach = value * value * (1 - settle) * presence
                let ring = sin(settle * 3 * .pi) * (1 - settle)
                let mouth = pill.height * (0.15 + 0.4 * approach) + 5 * ring
                layer.fill(Path(ellipseIn: CGRect(x: mouthX - mouth, y: mouthY - mouth * 0.9,
                                                  width: mouth * 2, height: mouth * 2)), with: .color(.black))
                let amplitude = 4.5 * approach + 6 * ring
                if amplitude > 0.2 {
                    let phase = value * 10 + settle * 7
                    let radiusY = pill.height / 2
                    let radiusX = pill.width / 2 - radiusY
                    for step in 0..<12 {
                        let f = Double(step) / 12
                        let angle = f * 2 * .pi
                        let point = CGPoint(x: pill.midX + (radiusX + radiusY * 0.75) * cos(angle),
                                            y: pill.midY + radiusY * 0.85 * sin(angle))
                        let bump = amplitude * (1 + sin(f * 6 * .pi + phase)) / 2 + 2
                        layer.fill(Path(ellipseIn: CGRect(x: point.x - bump, y: point.y - bump, width: bump * 2, height: bump * 2)),
                                   with: .color(.black))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A stand-in for a list row while the cutout pulls it in. Its visual progress is the slower of the
/// scroll position and a timed pull that starts when it appears, so a flick still shows the fold.
/// Pass `startsFolded` for a row returning from inside the cutout, so its first frame is not unfolded;
/// with `liquid`, such a row is born from the cutout, which winds up and pushes it out.
public struct FoldCutoutGhost<Content: View>: View {
    private let startsFolded: Bool
    private let scroll: Double
    private let start: CGRect
    private let target: CGRect
    private let style: FoldStyle
    private let reducesMotion: Bool
    private let liquid: Bool
    private let pull: TimeInterval
    private let content: Content
    @State private var time = 0.0
    @State private var settle = 0.0
    @State private var appeared = Date()

    public init(startsFolded: Bool, scroll: Double, start: CGRect, target: CGRect,
                style: FoldStyle = FoldStyle(darkening: 0.05), reducesMotion: Bool = false,
                liquid: Bool = false, pull: TimeInterval = 0.7, @ViewBuilder content: () -> Content) {
        self.startsFolded = startsFolded
        self.scroll = scroll
        self.start = start
        self.target = target
        self.style = style
        self.reducesMotion = reducesMotion
        self.liquid = liquid
        self.pull = pull
        self.content = content()
    }

    public var body: some View {
        content
            .modifier(FoldCutoutPull(progress: min(scroll, startsFolded ? 1 : time), start: start, target: target,
                                     style: style, reducesMotion: reducesMotion, liquid: liquid, settle: settle))
            .onAppear {
                appeared = Date()
                if startsFolded {
                    // Born from the cutout: the settle runs backwards, so the island winds up, its mouth
                    // bulges out, and the view emerges on a thick tendril that thins as it descends.
                    settle = 1
                    if liquid { withAnimation(.smooth(duration: 0.9)) { settle = 0 } }
                } else {
                    withAnimation(.smooth(duration: pull)) { time = 1 }
                }
            }
            .onChange(of: scroll >= 1) { _, inside in
                guard liquid else { return }
                guard inside else {
                    // Released again before it was removed: wind up and push it back out.
                    withAnimation(.easeOut(duration: 0.9)) { settle = 0 }
                    return
                }
                // Ring down once the timed pull has also finished.
                let remaining = startsFolded ? 0 : max(0, pull - Date().timeIntervalSince(appeared))
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
                    guard scroll >= 1 else { return }
                    withAnimation(.easeOut(duration: 0.9)) { settle = 1 }
                }
            }
    }
}
