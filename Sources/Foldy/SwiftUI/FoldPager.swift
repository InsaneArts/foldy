import SwiftUI
import UIKit

/// Pages between items with a fold. Moving to a later item folds the current page away around the
/// right edge and unfolds the next one behind it, like turning a page; moving back hinges on the left.
/// With `columns` above one the items form a grid, and moves by a whole row hinge on alternating
/// edges so consecutive vertical moves do not look identical.
///
/// Swipes are built in: a swipe left goes to the next item, right to the previous, up to the row
/// below, and down to the row above. Give the pager a `FoldMotionSource` to also move on a nudge
/// of the phone toward an edge. Set `selection` to turn a page from code.
///
/// ```swift
/// FoldPager(items: places, columns: 3, selection: $index, motion: motion) { place in
///     PlaceCard(place)
/// }
/// ```
public struct FoldPager<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let columns: Int
    @Binding private var selection: Int
    private let style: FoldStyle
    private let duration: TimeInterval
    private let reducesMotion: Bool
    private let motion: FoldMotionSource?
    private let content: (Item) -> Content
    /// The page at progress zero, and the page loaded behind it while a move is in flight.
    @State private var shown: Int?
    @State private var target: Int?
    @State private var progress = 0.0
    @State private var edge = FoldEdge.right

    public init(items: [Item], columns: Int = 1, selection: Binding<Int>, style: FoldStyle = .frosted,
                duration: TimeInterval = 0.8, reducesMotion: Bool = false, motion: FoldMotionSource? = nil,
                @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.columns = max(columns, 1)
        _selection = selection
        self.style = style
        self.duration = duration
        self.reducesMotion = reducesMotion
        self.motion = motion
        self.content = content
    }

    public var body: some View {
        // One container lives for the pager's whole life, so swipes always have a UIKit target and
        // the current page keeps its state between moves.
        FoldTransition(progress: progress, style: moveStyle, reducesMotion: reducesMotion) {
            page(shown ?? current)
        } destination: {
            page(target ?? shown ?? current)
        }
        .onFoldEvent { event in
            if case .completed(.destination) = event { finish() }
        }
        .background { FoldPagerSwipe { step($0) } }
        .onAppear {
            shown = current
            motion?.onBump = { bump in step(bump) }
            motion?.start()
        }
        .onDisappear {
            if motion?.onBump != nil { motion?.onBump = nil }
        }
        .onChange(of: selection) { _, next in
            if target == nil, let index = shown, next != index { begin(from: index, to: next) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Next")) { step(.right) }
        .accessibilityAction(named: Text("Previous")) { step(.left) }
    }

    @ViewBuilder private func page(_ index: Int?) -> some View {
        if let index, items.indices.contains(index) { content(items[index]) }
    }

    private var current: Int? { items.indices.contains(selection) ? selection : nil }

    private var moveStyle: FoldStyle {
        var style = style
        style.choreography = .pageTurn
        style.edge = edge
        return style
    }

    /// A bump or swipe toward an edge brings in the item on that side.
    private func step(_ bump: FoldBump) {
        guard target == nil, let index = shown else { return }
        let next: Int = switch bump {
        case .left: index - 1
        case .right: index + 1
        case .up: index - columns
        case .down: index + columns
        }
        guard items.indices.contains(next) else { return }
        // Horizontal moves stay within their row.
        if (bump == .left || bump == .right) && next / columns != index / columns { return }
        selection = next
    }

    private func begin(from: Int, to: Int) {
        let delta = to - from
        edge = abs(delta) < columns ? (delta > 0 ? .right : .left) : ((to / columns).isMultiple(of: 2) ? .right : .left)
        target = to
        // Give the destination one layout pass before the capture that starts the fold.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: duration)) { progress = 1 }
        }
    }

    /// The destination becomes the new resting page. Setting progress back to zero directly is an
    /// immediate endpoint change, and both slots now hold the same page, so nothing visibly changes.
    private func finish() {
        guard let target else { return }
        shown = target
        self.target = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { progress = 0 }
        if selection != target { begin(from: target, to: selection) }
    }
}

/// A pan on the pager's fold container. A swipe left reports `.right`, the way paging works.
private struct FoldPagerSwipe: UIViewRepresentable {
    let onSwipe: (FoldBump) -> Void

    func makeUIView(context: Context) -> SwipeView {
        let view = SwipeView(attachesToContainer: true)
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: SwipeView, context: Context) { view.onSwipe = onSwipe }

    @MainActor
    final class SwipeView: FoldPanHost {
        var onSwipe: ((FoldBump) -> Void)?

        override func panEnded(_ translation: CGPoint, velocity: CGPoint, in size: CGSize) {
            let dx = translation.x + velocity.x * 0.1, dy = translation.y + velocity.y * 0.1
            guard max(abs(dx), abs(dy)) > 40 else { return }
            onSwipe?(abs(dx) >= abs(dy) ? (dx < 0 ? .right : .left) : (dy < 0 ? .down : .up))
        }
    }
}
