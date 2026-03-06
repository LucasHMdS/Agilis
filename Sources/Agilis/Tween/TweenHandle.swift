/// An opaque handle to an active tween. Created by `TweenSystem` methods.
///
/// Use this handle to cancel, pause, query, or attach callbacks to tweens.
///
/// ## Usage
/// ```swift
/// let handle = tweens.moveTo(entity, target: pos, duration: 0.5, in: world)
/// tweens.onComplete(handle) { print("Done!") }
/// tweens.cancel(handle)
/// ```
public struct TweenHandle: Sendable, Hashable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    /// Sentinel value representing an invalid or unassigned handle.
    public static let invalid = TweenHandle(id: 0)
}
