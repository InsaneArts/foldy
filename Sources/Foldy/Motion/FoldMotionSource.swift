#if os(iOS) || os(watchOS)
import CoreMotion
import Observation
import simd
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Optional, calibrated device tilt. Sensors start only after an explicit `start()` call.
/// Use the owning window's interface orientation, and call `stop()` when the effect is hidden.
///
/// Set `onBump` to also receive discrete nudges. A bump is a short push of the phone along one
/// screen axis. The detector integrates user acceleration over a brief window, so a gentle but
/// deliberate move counts while hand tremor does not, and reports the direction the phone moved.
/// After a bump it waits for the phone to settle before it reports another.
///
/// Sampling follows the reference demo: 120 Hz gyro-only attitude, 40 ms of gyroscope prediction
/// to cover sensor and display latency, and a 0.7 per-sample smoothing factor.
/// On watchOS the screen is taken as upright with the crown on the right.
@MainActor @Observable
public final class FoldMotionSource: NSObject {
    /// The calibrated tilt of the device, updated at the sensor rate while running.
    public private(set) var tilt: FoldTilt = .zero
    /// Horizontal tilt, retained for single-axis callers.
    public var angle: Double { tilt.horizontal }
    /// True between `start()` and `stop()`, including the automatic stop on resigning active.
    public private(set) var isRunning = false
    /// False on the simulator and on devices without motion sensors.
    public var isAvailable: Bool { target.manager.isDeviceMotionAvailable }
    /// Called on the main actor for each detected nudge. Leave nil to skip detection.
    public var onBump: (@MainActor (FoldBump) -> Void)?
    /// Velocity change, in metres per second, that counts as a bump. The default responds to a
    /// small push of a few centimetres; raise it if ordinary handling triggers moves.
    public var bumpThreshold = 0.18
    #if os(iOS)
    /// The owning window scene's orientation. Changing it recalibrates the reference pose.
    public var orientation: UIInterfaceOrientation = .portrait {
        didSet { if orientation != oldValue { recalibrate() } }
    }
    #endif

    /// Fraction of the remaining error closed per sample. The attitude is already fused,
    /// and every extra frame of filtering is visible as lag between the hand and the screen.
    @ObservationIgnored private let smoothing = 0.7
    /// How far ahead to extrapolate with the gyroscope, in seconds.
    @ObservationIgnored private let predictionInterval = 0.04
    @ObservationIgnored private let target = MotionTarget()
    @ObservationIgnored private var reference: simd_double3x3?
    /// Whether `CMRotationMatrix` rows hold the device axes expressed in the reference frame.
    /// Resolved against the gravity vector on the first informative sample.
    @ObservationIgnored private var rowsAreDeviceAxes: Bool?
    @ObservationIgnored private var bumpArmed = true
    @ObservationIgnored private var lastBump: TimeInterval = 0
    /// Recent user acceleration along the screen axes, in g, with timestamps.
    @ObservationIgnored private var impulse: [(time: TimeInterval, across: Double, along: Double)] = []

    public override init() {
        super.init()
        target.owner = self
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(stop),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        #elseif os(watchOS)
        NotificationCenter.default.addObserver(self, selector: #selector(stop),
            name: WKExtension.applicationWillResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged),
            name: .WKAccessibilityReduceMotionStatusDidChange, object: nil)
        #endif
    }

    /// Starts sensors and captures the current pose as neutral. Requires an active app and no Reduce Motion.
    public func start() {
        guard !isRunning, isAvailable, !Self.systemReducesMotion, Self.isApplicationActive else { return }
        recalibrate()
        let target = target
        // Gyro-only reference frame: the magnetometer-corrected variants trade latency for
        // long-term yaw stability, and yaw is exactly the axis this effect tracks.
        target.manager.deviceMotionUpdateInterval = 1.0 / 120.0
        target.manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { motion, _ in
            guard let motion else { return }
            MainActor.assumeIsolated { target.deliver(motion) }
        }
        isRunning = true
    }

    @objc public func stop() {
        target.manager.stopDeviceMotionUpdates()
        isRunning = false
        recalibrate()
    }

    /// Makes the current pose the zero-tilt pose: the plane the interface stays in.
    public func recalibrate() {
        reference = nil
        tilt = .zero
    }

    private static var systemReducesMotion: Bool {
        #if os(iOS)
        UIAccessibility.isReduceMotionEnabled
        #else
        WKAccessibilityIsReduceMotionEnabled()
        #endif
    }

    private static var isApplicationActive: Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        WKApplication.shared().applicationState == .active
        #endif
    }

    /// Screen-space right and up axes of the interface, in device coordinates.
    private var axes: (x: SIMD3<Double>, y: SIMD3<Double>) {
        #if os(iOS)
        Self.screenAxes(for: orientation)
        #else
        (SIMD3(1, 0, 0), SIMD3(0, 1, 0))
        #endif
    }

    fileprivate func process(_ motion: CMDeviceMotion) {
        detectBump(motion)
        let deviceToReference = deviceToReferenceMatrix(motion)
        guard let reference else {
            self.reference = deviceToReference
            return
        }
        // Current device axes expressed in the calibrated device frame.
        let relative = reference.transpose * deviceToReference
        let normal = relative.columns.2
        let axes = axes
        let measured = Self.tilt(normal: normal, axes: axes)
        // Extrapolate along the rotation rate around each screen axis.
        let rate = SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
        let predicted = FoldTilt(horizontal: measured.horizontal + simd_dot(rate, axes.y) * predictionInterval,
                                 vertical: measured.vertical + simd_dot(rate, axes.x) * predictionInterval)
        tilt = FoldTilt(horizontal: tilt.horizontal + (predicted.horizontal - tilt.horizontal) * smoothing,
                        vertical: tilt.vertical + (predicted.vertical - tilt.vertical) * smoothing)
            .sanitized(fallback: tilt)
    }

    private func detectBump(_ motion: CMDeviceMotion) {
        guard onBump != nil else { return }
        let axes = axes
        let acceleration = SIMD3(motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z)
        let now = motion.timestamp
        impulse.append((now, simd_dot(acceleration, axes.x), simd_dot(acceleration, axes.y)))
        impulse.removeAll { now - $0.time > 0.16 }
        guard impulse.count >= 2 else { return }
        // Integrate acceleration over the window: a push shows up as a velocity change in one direction.
        var across = 0.0, along = 0.0
        for index in 1..<impulse.count {
            let dt = impulse[index].time - impulse[index - 1].time
            across += impulse[index].across * dt * 9.81
            along += impulse[index].along * dt * 9.81
        }
        let magnitude = max(abs(across), abs(along))
        if bumpArmed {
            guard magnitude >= bumpThreshold, now - lastBump > 0.45 else { return }
            let bump: FoldBump = abs(across) >= abs(along)
                ? (across > 0 ? .right : .left)
                : (along > 0 ? .up : .down)
            bumpArmed = false
            lastBump = now
            impulse.removeAll()
            onBump?(bump)
        } else if magnitude < bumpThreshold * 0.3, now - lastBump > 0.3 {
            bumpArmed = true
        }
    }

    /// Rotation taking device-frame vectors to reference-frame vectors (column-vector convention).
    private func deviceToReferenceMatrix(_ motion: CMDeviceMotion) -> simd_double3x3 {
        let m = motion.attitude.rotationMatrix
        let asRows = simd_double3x3(rows: [
            SIMD3(m.m11, m.m12, m.m13),
            SIMD3(m.m21, m.m22, m.m23),
            SIMD3(m.m31, m.m32, m.m33)
        ])
        if rowsAreDeviceAxes == nil {
            // Gravity is reported in the device frame and points down (-Z in a Z-vertical reference).
            // Compare it against what each convention predicts and latch the better match.
            let gravity = simd_normalize(SIMD3(motion.gravity.x, motion.gravity.y, motion.gravity.z))
            let down = SIMD3(0.0, 0.0, -1.0)
            let rowsScore = simd_dot(gravity, asRows * down)
            let columnsScore = simd_dot(gravity, asRows.transpose * down)
            if abs(rowsScore - columnsScore) > 0.2 {
                rowsAreDeviceAxes = rowsScore > columnsScore
                // A reference captured under the provisional convention would be inconsistent.
                reference = nil
            }
        }
        return (rowsAreDeviceAxes ?? true) ? asRows.transpose : asRows
    }

    #if os(iOS)
    /// Screen-space right and up axes of the interface, in device coordinates.
    static func screenAxes(for orientation: UIInterfaceOrientation) -> (x: SIMD3<Double>, y: SIMD3<Double>) {
        switch orientation {
        case .landscapeLeft: (SIMD3(0, 1, 0), SIMD3(-1, 0, 0))
        case .landscapeRight: (SIMD3(0, -1, 0), SIMD3(1, 0, 0))
        case .portraitUpsideDown: (SIMD3(-1, 0, 0), SIMD3(0, -1, 0))
        default: (SIMD3(1, 0, 0), SIMD3(0, 1, 0))
        }
    }

    static func tilt(normal: SIMD3<Double>, orientation: UIInterfaceOrientation) -> FoldTilt {
        tilt(normal: normal, axes: screenAxes(for: orientation))
    }
    #endif

    /// The pane hinges on the edge the screen normal leans toward, on both axes.
    /// A normal leaning right means the right edge is farther from the viewer; leaning up, the top edge.
    static func tilt(normal: SIMD3<Double>, axes: (x: SIMD3<Double>, y: SIMD3<Double>)) -> FoldTilt {
        let across = simd_dot(normal, axes.x)
        let along = simd_dot(normal, axes.y)
        return FoldTilt(horizontal: atan2(across, normal.z),
                        vertical: atan2(along, hypot(across, normal.z))).sanitized()
    }

    @objc private func reduceMotionChanged() {
        if Self.systemReducesMotion { stop() }
    }

    @MainActor private final class MotionTarget {
        weak var owner: FoldMotionSource?
        let manager = CMMotionManager()

        func deliver(_ motion: CMDeviceMotion) {
            guard let owner else {
                // Also stop sensors if the caller releases the source without calling stop().
                manager.stopDeviceMotionUpdates()
                return
            }
            owner.process(motion)
        }
    }
}
#else
import Foundation
import Observation

/// Device motion needs Core Motion, which macOS does not have. This stand-in keeps the API uniform:
/// `isAvailable` is false, `start()` does nothing, and `tilt` stays at zero.
@MainActor @Observable
public final class FoldMotionSource: NSObject {
    public private(set) var tilt: FoldTilt = .zero
    public var angle: Double { tilt.horizontal }
    public private(set) var isRunning = false
    public var isAvailable: Bool { false }
    public var onBump: (@MainActor (FoldBump) -> Void)?
    public var bumpThreshold = 0.18

    public func start() {}
    public func stop() {}
    public func recalibrate() {}
}
#endif
