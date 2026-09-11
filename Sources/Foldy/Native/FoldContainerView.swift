#if !os(watchOS)
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Hosts live content at rest and frozen Metal snapshots during a fold.
/// Add gesture recognizers to this container, not to the temporarily hidden content views.
/// A `UIView` on iOS and an `NSView` on macOS, where its origin is top-left like UIKit's.
@MainActor
public final class FoldContainerView: FoldPlatformView {
    /// Shown at progress zero. Foldy owns its frame and visibility.
    public let sourceView: FoldPlatformView
    /// Shown at progress one; nil for a single-view tilt.
    public let destinationView: FoldPlatformView?
    /// Changing the style during a fold redraws the current frame without recapturing.
    public var style: FoldStyle = .frosted {
        didSet { if style != oldValue { renderIfNeeded() } }
    }
    /// Supplies a prepared image instead of capturing the hierarchy, for web views, video, or camera content.
    public var sourceSnapshot: FoldSnapshotProvider?
    /// The destination's counterpart to `sourceSnapshot`.
    public var destinationSnapshot: FoldSnapshotProvider?
    /// Endpoint completions, cancellations, and fallback diagnostics, delivered on the main actor.
    public var onEvent: (@MainActor (FoldEvent) -> Void)?
    /// The system setting always takes precedence. This flag also allows per-view reduction.
    public var reducesMotion = false {
        didSet { if reducesMotion && !oldValue { reduceMotionChanged() } }
    }
    /// The current position between source (zero) and destination (one).
    public var progress: Double { state.progress }
    /// True while frozen snapshots are on screen instead of the live views.
    public var isTransitioning: Bool { hasSnapshots }

    private var state = FoldTransitionState()
    private var renderer: FoldRenderer?
    private var hasSnapshots = false
    private enum Suppression { case cancelled, fallback }
    private var suppression: Suppression?
    private var fallbackReason: FoldFallbackReason?
    private var reportedFallback = false
    /// A capture can fail while the hierarchy is momentarily hidden, and a frame can be skipped while
    /// layout is settling; later updates try again. Missing Metal and Reduce Motion do not retry.
    private var canRetryCapture: Bool {
        suppression == .fallback && (fallbackReason == .captureFailed || fallbackReason == .renderingFailed)
    }
    private var tilt: FoldTilt = .zero
    private var capturedSize: CGSize = .zero
    private var animator: FoldAnimator?
    private var isRendering = false
    // Internal counters support lifecycle tests without exposing renderer details as public API.
    private(set) var captureCount = 0
    var submittedFrames: Int { renderer?.submittedFrames ?? 0 }

    /// Creates a two-view transition. Drive it with `setProgress(_:)` or `animate(to:)`.
    public init(source: FoldPlatformView, destination: FoldPlatformView) {
        precondition(source !== destination, "Source and destination must be distinct views.")
        sourceView = source
        destinationView = destination
        super.init(frame: .zero)
        configure()
    }

    /// Creates a single-view effect. Drive it with `setAngle(_:)` in radians.
    public init(content: FoldPlatformView) {
        sourceView = content
        destinationView = nil
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(source:destination:) or init(content:).") }

    private func configure() {
        #if canImport(AppKit)
        wantsLayer = true
        #endif
        clipsToBounds = true
        if let destinationView {
            addSubview(destinationView)
            destinationView.isHidden = true
        }
        addSubview(sourceView)
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        #else
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
            name: NSApplication.didHideNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reduceMotionChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        #endif
    }

    #if canImport(UIKit)
    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutContent()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        windowChanged()
    }
    #else
    /// Top-left origin, like UIKit, so frames and gesture translations read the same on both platforms.
    public override var isFlipped: Bool { true }

    public override func layout() {
        super.layout()
        layoutContent()
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowChanged()
    }
    #endif

    private func layoutContent() {
        sourceView.frame = bounds
        destinationView?.frame = bounds
        renderer?.view.frame = bounds
        if hasSnapshots && capturedSize != bounds.size {
            cancel()
        } else {
            renderIfNeeded()
        }
    }

    private func windowChanged() {
        guard window != nil else { cancel(); return }
        #if canImport(UIKit)
        setNeedsLayout()
        #else
        needsLayout = true
        #endif
    }

    /// Updates an interactive transition. Zero is the source; one is the destination.
    /// Nonfinite inputs keep the previous progress. A direct endpoint change is immediate.
    public func setProgress(_ value: Double) {
        animator?.stop()
        animator = nil
        applyProgress(value)
    }

    private func applyProgress(_ value: Double) {
        guard destinationView != nil else { return }
        let value = finiteClamp(value, 0...1, fallback: progress)
        guard suppression != .cancelled || value == 0 || value == 1 else { return }
        let event = state.update(value)
        if progress == 0 || progress == 1 {
            endSession()
            show(state.restingEndpoint)
            if let event { onEvent?(event) }
        } else if suppression == .fallback {
            if canRetryCapture { renderIfNeeded() }
            if suppression == .fallback { show(progress < 0.5 ? .source : .destination) }
        } else {
            renderIfNeeded()
        }
    }

    /// Applies the original single-pane effect. Positive angles hinge on the right; negative on the left.
    /// Content is captured when leaving zero and stays frozen until the angle returns to zero.
    public func setAngle(_ radians: Double) {
        setTilt(FoldTilt(horizontal: radians))
    }

    /// Applies horizontal and vertical tilt together. Return both axes to zero to refresh content.
    public func setTilt(_ value: FoldTilt) {
        guard destinationView == nil else { return }
        let next = value.sanitized(fallback: tilt)
        guard suppression == nil || canRetryCapture || next.isAtRest else { return }
        tilt = next
        if tilt.isAtRest {
            tilt = .zero
            endSession()
            show(.source)
        } else {
            renderIfNeeded()
        }
    }

    /// Animates from the current progress. Calling again retargets without recapturing content.
    public func animate(to endpoint: FoldEndpoint, duration: TimeInterval = 0.65) {
        guard destinationView != nil else { return }
        animator?.stop()
        let duration = finiteClamp(duration, 0...10, fallback: 0.65)
        guard duration > 0, !motionIsReduced, progress != endpoint.progress else {
            setProgress(endpoint.progress)
            return
        }
        let start = progress
        animator = FoldAnimator(duration: duration) { [weak self] fraction in
            self?.applyProgress(start + (endpoint.progress - start) * fraction)
        }
        animator?.start()
    }

    /// Restores the endpoint where this session started and ignores updates until the next endpoint.
    public func cancel() {
        animator?.stop()
        animator = nil
        let wasActive = hasSnapshots || state.isActive || !tilt.isAtRest
        _ = state.cancel()
        tilt = .zero
        endSession()
        if wasActive { suppression = .cancelled }
        show(state.restingEndpoint)
        if wasActive { onEvent?(.cancelled) }
    }

    /// Clears per-session state at an endpoint, at rest, or on cancellation.
    private func endSession() {
        suppression = nil
        fallbackReason = nil
        reportedFallback = false
        releaseSnapshots()
    }

    private var motionIsReduced: Bool {
        #if canImport(UIKit)
        reducesMotion || UIAccessibility.isReduceMotionEnabled
        #else
        reducesMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    /// Pixels per point of the screen showing this view.
    private var nativeScale: CGFloat {
        #if canImport(UIKit)
        window?.screen.scale ?? traitCollection.displayScale
        #else
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        #endif
    }

    private func bringToFront(_ view: FoldPlatformView) {
        #if canImport(UIKit)
        bringSubviewToFront(view)
        #else
        addSubview(view, positioned: .above, relativeTo: nil)
        #endif
    }

    private func renderIfNeeded() {
        guard !isRendering, suppression == nil || canRetryCapture, window != nil,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0,
              destinationView == nil ? !tilt.isAtRest : state.isActive else { return }
        isRendering = true
        defer { isRendering = false }
        if motionIsReduced {
            fallback(.reduceMotion)
            return
        }
        do {
            if renderer == nil {
                do { renderer = try FoldRenderer() }
                catch { throw FoldFallbackReason.metalUnavailable }
            }
            guard let renderer else { throw FoldFallbackReason.metalUnavailable }
            if !hasSnapshots {
                // Both views are unhidden for capture. Keep the visible endpoint on top so the other
                // one cannot flash for a frame before the pane covers them.
                if let destinationView, state.restingEndpoint == .destination {
                    bringToFront(destinationView)
                } else {
                    bringToFront(sourceView)
                }
                sourceView.isHidden = false
                destinationView?.isHidden = false
                // Bound temporary memory on large displays; preserve native scale on ordinary phones.
                let scale = min(nativeScale, 2048 / max(bounds.width, bounds.height))
                let source = try FoldCapture.image(of: sourceView, scale: scale, provider: sourceSnapshot)
                let destination = try destinationView.map {
                    try FoldCapture.image(of: $0, scale: scale, provider: destinationSnapshot)
                }
                try renderer.prepare(source: source, destination: destination)
                renderer.view.frame = bounds
                renderer.setScale(scale)
                renderer.setDrawableSize(bounds: bounds.size, scale: scale)
                addSubview(renderer.view)
                #if canImport(UIKit)
                renderer.view.layoutIfNeeded()
                #else
                renderer.view.layoutSubtreeIfNeeded()
                #endif
                capturedSize = bounds.size
                hasSnapshots = true
                captureCount += 1
            }
            var resolvedStyle = style
            if destinationView == nil { resolvedStyle.edge = tilt.horizontal >= 0 ? .right : .left }
            let uniforms = FoldUniforms(size: bounds.size,
                angle: destinationView == nil ? abs(tilt.horizontal) : progress * .pi / 2,
                progress: progress, style: resolvedStyle, isTransition: destinationView != nil,
                verticalAngle: destinationView == nil ? tilt.vertical : 0)
            guard renderer.draw(uniforms) else { throw FoldFallbackReason.renderingFailed }
            suppression = nil
            fallbackReason = nil
            sourceView.isHidden = true
            destinationView?.isHidden = true
        } catch {
            fallback((error as? FoldFallbackReason) ?? .captureFailed)
        }
    }

    private func fallback(_ reason: FoldFallbackReason) {
        suppression = .fallback
        fallbackReason = reason
        releaseSnapshots()
        show(destinationView == nil || progress < 0.5 ? .source : .destination)
        guard !reportedFallback else { return }
        reportedFallback = true
        onEvent?(.fallback(reason))
    }

    private func show(_ endpoint: FoldEndpoint) {
        sourceView.isHidden = endpoint == .destination
        destinationView?.isHidden = endpoint == .source
    }

    private func releaseSnapshots() {
        renderer?.view.removeFromSuperview()
        renderer?.releaseSnapshots()
        hasSnapshots = false
    }

    @objc private func backgrounded() { cancel() }

    @objc private func reduceMotionChanged() {
        guard motionIsReduced, hasSnapshots else { return }
        fallback(.reduceMotion)
    }
}
#endif
