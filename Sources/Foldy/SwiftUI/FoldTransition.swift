import SwiftUI

/// A Metal transition between two stable view hierarchies.
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
        FoldHost(source: source, destination: destination, value: progress, style: style,
                 isTransition: true, reduceMotion: reduceMotion || reducesMotion, isActive: scenePhase == .active,
                 eventHandler: eventHandler)
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
        FoldHost(source: content, destination: EmptyView(), value: horizontal, style: style,
                 isTransition: false, reduceMotion: reduceMotion || reducesMotion, isActive: scenePhase == .active,
                 verticalAngle: vertical)
    }
}

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
