/// Pure lifecycle bookkeeping, independent of UIKit and frame timing.
struct FoldTransitionState {
    private(set) var progress: Double = 0
    private(set) var isActive = false
    private(set) var restingEndpoint: FoldEndpoint = .source

    mutating func update(_ value: Double) -> FoldEvent? {
        let next = finiteClamp(value, 0...1, fallback: progress)
        let changed = next != progress
        progress = next
        guard next == 0 || next == 1 else {
            isActive = true
            return nil
        }
        let endpoint: FoldEndpoint = next == 0 ? .source : .destination
        let shouldNotify = isActive || (changed && endpoint != restingEndpoint)
        isActive = false
        restingEndpoint = endpoint
        return shouldNotify ? .completed(endpoint) : nil
    }

    mutating func cancel() -> FoldEvent? {
        guard isActive else { return nil }
        progress = restingEndpoint.progress
        isActive = false
        return .cancelled
    }
}
