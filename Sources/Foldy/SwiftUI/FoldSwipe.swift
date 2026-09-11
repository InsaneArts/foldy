import SwiftUI
import UIKit

/// Where a fold swipe listens for touches.
public enum FoldSwipePlacement: Sendable {
    /// A pan on the nearest fold container. Content underneath stays tappable. This is the
    /// placement for a `FoldTransition`, a `FoldPager`, or any view that contains one.
    case container
    /// A transparent surface over the view. Use it for views that have no fold container, such as
    /// several `foldEffect` panes composed by hand; content underneath does not receive touches.
    case surface
}

public extension View {
    /// Lets a swipe drive a fold.
    ///
    /// From an endpoint, a swipe in any direction folds toward the other endpoint; moving back along
    /// the same line reverses it, and release settles on the nearer endpoint with `settle`.
    func foldSwipe(progress: Binding<Double>, placement: FoldSwipePlacement = .container,
                   settle: Animation = .easeOut(duration: 0.5)) -> some View {
        modifier(FoldSwipeModifier(progress: progress, placement: placement, settle: settle))
    }
}

private struct FoldSwipeModifier: ViewModifier {
    let progress: Binding<Double>
    let placement: FoldSwipePlacement
    let settle: Animation

    func body(content: Content) -> some View {
        switch placement {
        case .container:
            content.background { FoldSwipeRepresentable(progress: progress, settle: settle, attachesToContainer: true) }
        case .surface:
            content.overlay { FoldSwipeRepresentable(progress: progress, settle: settle, attachesToContainer: false) }
        }
    }
}

private struct FoldSwipeRepresentable: UIViewRepresentable {
    let progress: Binding<Double>
    let settle: Animation
    let attachesToContainer: Bool

    func makeUIView(context: Context) -> FoldSwipeView {
        let view = FoldSwipeView(attachesToContainer: attachesToContainer)
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: FoldSwipeView, context: Context) {
        view.progress = progress
        view.settle = settle
    }
}

/// Finds the nearest fold container and attaches a pan recognizer there, or hosts the pan itself.
@MainActor
final class FoldSwipeView: FoldPanHost {
    var progress: Binding<Double>?
    var settle: Animation = .easeOut(duration: 0.5)
    private var origin: Double?
    private var axis: CGVector?

    override func panChanged(_ translation: CGPoint, in size: CGSize) {
        guard let progress else { return }
        let start = origin ?? progress.wrappedValue
        origin = start
        guard let axis = axis ?? Self.axis(for: translation) else { return }
        self.axis = axis
        progress.wrappedValue = min(max(start + Self.delta(translation, along: axis, from: start, in: size), 0), 1)
    }

    override func panEnded(_ translation: CGPoint, velocity: CGPoint, in size: CGSize) {
        guard let progress else { return }
        let start = origin ?? progress.wrappedValue
        let projected = CGPoint(x: translation.x + velocity.x * 0.15, y: translation.y + velocity.y * 0.15)
        let axis = axis ?? Self.axis(for: projected)
        origin = nil
        self.axis = nil
        guard let axis else { return }
        let target = start + Self.delta(projected, along: axis, from: start, in: size)
        withAnimation(settle) { progress.wrappedValue = target >= 0.5 ? 1 : 0 }
    }

    private static func axis(for translation: CGPoint) -> CGVector? {
        let length = hypot(translation.x, translation.y)
        guard length >= 14 else { return nil }
        return CGVector(dx: translation.x / length, dy: translation.y / length)
    }

    /// Distance along the swipe axis, as a fraction of the target's extent along that axis.
    private static func delta(_ translation: CGPoint, along axis: CGVector, from origin: Double, in size: CGSize) -> Double {
        let along = Double(translation.x * axis.dx + translation.y * axis.dy)
        let extent = Double(abs(axis.dx) * size.width + abs(axis.dy) * size.height)
        let toward: Double = origin < 0.5 ? 1 : -1
        return toward * along / max(extent, 1) * 1.25
    }
}

/// A UIKit view that owns one pan recognizer. With `attachesToContainer` it waits for the nearest
/// `FoldContainerView` to appear in the hierarchy and attaches the pan there; otherwise the pan is
/// on this view itself, which must then be on top of the content it serves.
@MainActor
class FoldPanHost: UIView, UIGestureRecognizerDelegate {
    private let attachesToContainer: Bool
    private weak var recognizer: UIPanGestureRecognizer?

    init(attachesToContainer: Bool) {
        self.attachesToContainer = attachesToContainer
        super.init(frame: .zero)
        if !attachesToContainer { attach(to: self) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(attachesToContainer:).") }

    func panChanged(_ translation: CGPoint, in size: CGSize) {}
    func panEnded(_ translation: CGPoint, velocity: CGPoint, in size: CGSize) {}

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfNeeded()
    }

    /// The container is added to the hierarchy after this view, so keep trying on layout passes.
    override func layoutSubviews() {
        super.layoutSubviews()
        attachIfNeeded()
    }

    private func attachIfNeeded() {
        guard attachesToContainer, window != nil, recognizer == nil, let container = nearestContainer() else { return }
        attach(to: container)
    }

    private func attach(to target: UIView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        target.addGestureRecognizer(pan)
        recognizer = pan
    }

    /// Search each ancestor's subtree, skipping any container that contains this view: that would be
    /// an outer fold, such as a gallery folding into the page that owns this swipe.
    private func nearestContainer() -> FoldContainerView? {
        var ancestor = superview
        while let view = ancestor {
            if let found = firstContainer(in: view) { return found }
            ancestor = view.superview
        }
        return nil
    }

    private func firstContainer(in view: UIView) -> FoldContainerView? {
        for subview in view.subviews {
            if let container = subview as? FoldContainerView, !isDescendant(of: container) { return container }
            if let found = firstContainer(in: subview) { return found }
        }
        return nil
    }

    @objc private func handle(_ pan: UIPanGestureRecognizer) {
        guard let view = pan.view else { return }
        let translation = pan.translation(in: view)
        switch pan.state {
        case .changed: panChanged(translation, in: view.bounds.size)
        case .ended, .cancelled, .failed: panEnded(translation, velocity: pan.velocity(in: view), in: view.bounds.size)
        default: break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
