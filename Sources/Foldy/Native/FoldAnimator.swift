#if !os(watchOS)
import QuartzCore

/// The run loop retains the link; the link's target holds only a weak reference to its owner.
@MainActor
final class FoldAnimator {
    private var link: CADisplayLink?
    private var startTime: CFTimeInterval?
    private let duration: TimeInterval
    private let update: (Double) -> Void

    init(duration: TimeInterval, update: @escaping (Double) -> Void) {
        self.duration = duration
        self.update = update
    }

    func start() {
        let target = Target()
        target.owner = self
        guard let link = FoldDisplayLink.make(target: target, selector: #selector(Target.tick(_:)), view: nil) else {
            // No screen to pace against: finish now.
            update(1)
            return
        }
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() { link?.invalidate(); link = nil }

    private func tick(_ link: CADisplayLink) {
        if startTime == nil { startTime = link.timestamp }
        let fraction = min((link.targetTimestamp - (startTime ?? link.timestamp)) / duration, 1)
        let eased = fraction * fraction * (3 - 2 * fraction)
        if fraction >= 1 { stop() }
        update(eased)
    }

    @MainActor private final class Target: NSObject {
        weak var owner: FoldAnimator?
        @objc func tick(_ link: CADisplayLink) {
            guard let owner else { link.invalidate(); return }
            owner.tick(link)
        }
    }
}
#endif
