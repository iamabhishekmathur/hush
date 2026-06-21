import Foundation

/// Critically-damped spring that eases the scroll position toward a moving
/// target with no overshoot and no jitter. Uses Ryan Juckett's analytic
/// solution, so it stays stable even at large dt (e.g. after a dropped frame).
///
/// `omega` is the angular frequency — higher is snappier. At 60 fps the default
/// settles a step in roughly a quarter second.
public struct SpringScroller: Sendable {
    public var position: Double
    public var velocity: Double
    public var omega: Double

    public init(position: Double = 0, velocity: Double = 0, omega: Double = 14) {
        self.position = position
        self.velocity = velocity
        self.omega = omega
    }

    /// Advance toward `target` by `dt` seconds; returns the new position.
    @discardableResult
    public mutating func step(to target: Double, dt: Double) -> Double {
        guard dt > 0 else { return position }
        let decay = Foundation.exp(-omega * dt)
        let x = position - target
        let temp = (velocity + omega * x) * dt
        position = target + (x + temp) * decay
        velocity = (velocity - omega * temp) * decay
        return position
    }

    /// Snap instantly (used when Reduce Motion is on, or to re-home).
    public mutating func snap(to value: Double) {
        position = value
        velocity = 0
    }
}
