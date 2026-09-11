import SwiftUI

/// A transition between two stable view hierarchies, drawn with Metal where it exists and with
/// SwiftUI's own 3D rotation and blur on watchOS.
/// Animate `progress` with `withAnimation`, or drive it directly from a gesture.
/// The container fills its proposed size. Give cards an explicit frame.
public struct FoldTransition<Source: View, Destination: View>: View, Animatable {
    /// Zero shows the source, one the destination. Values between fold the source away.
    public nonisolated var progress: Double
    private let style: FoldStyle
    private let source: Source
    private let destination: Destination
    private let reducesMotion: Bool
    private var eventHandler: (@MainActor (FoldEvent) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Both closures are hosted for the container's whole life, so their state survives a fold.
    public init(progress: Double, style: FoldStyle = .frosted, reducesMotion: Bool = false,
                @ViewBuilder source: () -> Source, @ViewBuilder destination: () -> Destination) {
        self.progress = progress
        self.style = style
        self.source = source()
        self.destination = destination()
        self.reducesMotion = reducesMotion
    }

    public nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Called asynchronously on the main actor, outside SwiftUI's view update.
    public func onFoldEvent(_ handler: @escaping @MainActor (FoldEvent) -> Void) -> Self {
        var copy = self
        copy.eventHandler = handler
        return copy
    }

    public var body: some View {
        #if os(watchOS)
        FoldSoftwareTransition(source: source, destination: destination, progress: progress, style: style,
                               reduceMotion: reduceMotion || reducesMotion, isActive: scenePhase == .active,
                               eventHandler: eventHandler)
        #else
        FoldHost(source: source, destination: destination, value: progress, style: style,
                 isTransition: true, reduceMotion: reduceMotion || reducesMotion, isActive: scenePhase == .active,
                 eventHandler: eventHandler)
        #endif
    }
}

public extension View {
    /// A snapshot of this view viewed through a tilted frosted pane.
    /// Return to zero to refresh the snapshot. Positive angles hinge on the right edge.
    func foldEffect(angle: Angle, style: FoldStyle = .frosted, reducesMotion: Bool = false) -> some View {
        foldEffect(tilt: FoldTilt(horizontal: angle.radians), style: style, reducesMotion: reducesMotion)
    }

    /// Applies simultaneous horizontal and vertical tilt, such as `FoldMotionSource.tilt`.
    func foldEffect(tilt: FoldTilt, style: FoldStyle = .frosted, reducesMotion: Bool = false) -> some View {
        FoldTiltView(content: self, horizontal: tilt.horizontal, vertical: tilt.vertical,
                     style: style, reducesMotion: reducesMotion)
    }
}

private struct FoldTiltView<Content: View>: View, Animatable {
    let content: Content
    nonisolated var horizontal: Double
    nonisolated var vertical: Double
    let style: FoldStyle
    let reducesMotion: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(horizontal, vertical) }
        set { horizontal = newValue.first; vertical = newValue.second }
    }

    var body: some View {
        #if os(watchOS)
        content.modifier(FoldSoftwarePane(horizontal: horizontal, vertical: vertical, style: style,
                                          reduceMotion: reduceMotion || reducesMotion || scenePhase != .active))
        #else
        FoldHost(source: content, destination: EmptyView(), value: horizontal, style: style,
                 isTransition: false, reduceMotion: reduceMotion || reducesMotion, isActive: scenePhase == .active,
                 verticalAngle: vertical)
        #endif
    }
}

#if os(watchOS)
/// A two-view fold drawn with the software pane. Both hierarchies stay mounted, so their state
/// survives a fold, and the same events are reported as the Metal container reports.
private struct FoldSoftwareTransition<Source: View, Destination: View>: View {
    let source: Source
    let destination: Destination
    let progress: Double
    let style: FoldStyle
    let reduceMotion: Bool
    let isActive: Bool
    let eventHandler: (@MainActor (FoldEvent) -> Void)?
    @State private var state = FoldTransitionState()
    @State private var suppressed = false
    @State private var reportedFallback = false

    private struct Pose {
        var front = 0.0
        var back = 0.0
        var sourceOpacity = 1.0
        var showsDestination = false
        var resting: FoldEndpoint?
    }

    var body: some View {
        let value = finiteClamp(progress, 0...1, fallback: 0)
        let pose = pose(at: value)
        ZStack {
            destination
                .modifier(FoldSoftwarePane(horizontal: pose.back, vertical: 0, style: style, reduceMotion: reduceMotion))
                .opacity(pose.showsDestination ? 1 : 0)
                .allowsHitTesting(pose.resting == .destination)
            source
                .modifier(FoldSoftwarePane(horizontal: pose.front, vertical: 0, style: style, reduceMotion: reduceMotion))
                .opacity(pose.sourceOpacity)
                .allowsHitTesting(pose.resting == .source)
        }
        .onChange(of: value, initial: true) { _, next in update(next) }
        .onChange(of: isActive) { _, active in if !active { cancel() } }
    }

    /// At an endpoint, after a cancellation, or under Reduce Motion one view is shown flat and live.
    private func pose(at value: Double) -> Pose {
        let endpoint: FoldEndpoint? = value == 0 ? .source : value == 1 ? .destination : nil
        let reduced: FoldEndpoint? = reduceMotion ? (value < 0.5 ? .source : .destination) : nil
        if let shown = endpoint ?? (suppressed ? state.restingEndpoint : nil) ?? reduced {
            return Pose(sourceOpacity: shown == .source ? 1 : 0, showsDestination: shown == .destination, resting: shown)
        }
        let sign: Double = style.edge == .right ? 1 : -1
        let angle = value * .pi / 2
        switch style.choreography {
        case .reveal:
            return Pose(front: sign * angle, sourceOpacity: 1 - smoothstep(0.15, 1, value), showsDestination: true)
        case .pageTurn:
            return Pose(front: sign * angle, back: sign * (.pi / 2 - angle),
                        sourceOpacity: 1 - smoothstep(0.3, 0.7, value), showsDestination: true)
        }
    }

    private func update(_ next: Double) {
        let atEndpoint = next == 0 || next == 1
        if suppressed && !atEndpoint { return }
        let event = state.update(next)
        if atEndpoint {
            suppressed = false
            reportedFallback = false
        } else if reduceMotion && !reportedFallback {
            reportedFallback = true
            deliver(.fallback(.reduceMotion))
        }
        if let event { deliver(event) }
    }

    private func cancel() {
        guard let event = state.cancel() else { return }
        suppressed = true
        deliver(event)
    }

    private func deliver(_ event: FoldEvent) {
        guard let eventHandler else { return }
        Task { @MainActor in eventHandler(event) }
    }
}
#else
private struct FoldHost<Source: View, Destination: View>: UIViewControllerRepresentable {
    let source: Source
    let destination: Destination
    let value: Double
    let style: FoldStyle
    let isTransition: Bool
    let reduceMotion: Bool
    let isActive: Bool
    var verticalAngle: Double = 0
    var eventHandler: (@MainActor (FoldEvent) -> Void)?

    func makeUIViewController(context: Context) -> FoldHostController<Source, Destination> {
        FoldHostController(source: source, destination: destination, environment: context.environment,
                           isTransition: isTransition)
    }

    func updateUIViewController(_ controller: FoldHostController<Source, Destination>, context: Context) {
        // Preserve the actual hosting controllers and their @State throughout a session.
        let container = controller.container
        let atRest = isTransition ? value <= 0 || value >= 1 : FoldTilt(horizontal: value, vertical: verticalAngle).isAtRest
        if !container.isTransitioning || atRest {
            controller.source.rootView = FoldHostedContent(content: source, environment: context.environment)
            controller.destination?.rootView = FoldHostedContent(content: destination, environment: context.environment)
        }
        container.onEvent = { event in
            Task { @MainActor in eventHandler?(event) }
        }
        container.style = style
        container.reducesMotion = reduceMotion
        if !isActive {
            container.cancel()
        } else if isTransition {
            container.setProgress(value)
        } else {
            container.setTilt(FoldTilt(horizontal: value, vertical: verticalAngle))
        }
    }

    static func dismantleUIViewController(_ controller: FoldHostController<Source, Destination>, coordinator: ()) {
        controller.container.onEvent = nil
        controller.container.cancel()
    }
}

private struct FoldHostedContent<Content: View>: View {
    let content: Content
    let environment: EnvironmentValues

    var body: some View { content.environment(\.self, environment) }
}

private final class FoldHostController<Source: View, Destination: View>: UIViewController {
    let source: UIHostingController<FoldHostedContent<Source>>
    let destination: UIHostingController<FoldHostedContent<Destination>>?
    let container: FoldContainerView

    init(source: Source, destination: Destination, environment: EnvironmentValues, isTransition: Bool) {
        let first = UIHostingController(rootView: FoldHostedContent(content: source, environment: environment))
        first.view.backgroundColor = .clear
        self.source = first
        if isTransition {
            let second = UIHostingController(rootView: FoldHostedContent(content: destination, environment: environment))
            second.view.backgroundColor = .clear
            self.destination = second
            container = FoldContainerView(source: first.view, destination: second.view)
        } else {
            self.destination = nil
            container = FoldContainerView(content: first.view)
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(source:destination:isTransition:).") }

    override func loadView() {
        view = container
        addChild(source)
        source.didMove(toParent: self)
        if let destination {
            addChild(destination)
            destination.didMove(toParent: self)
        }
    }
}
#endif
