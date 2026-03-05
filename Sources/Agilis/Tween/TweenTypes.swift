import AgilisCore

// MARK: - Tween Play State

/// Internal state of a tween's lifecycle.
internal enum TweenPlayState: Sendable {
    /// Waiting for delay to elapse before starting.
    case waiting
    /// Actively interpolating.
    case running
    /// Temporarily halted by user.
    case paused
    /// Finished, pending removal.
    case completed
}

// MARK: - Tween (Internal Runtime State)

/// Internal runtime state for an active tween.
///
/// Not exposed publicly — accessed via `TweenHandle` through `TweenSystem`.
internal struct Tween: @unchecked Sendable {
    let handle: TweenHandle
    let entity: Entity
    var target: TweenTarget
    let duration: Float
    let easing: EasingFunction
    let delay: Float

    // Runtime state
    var elapsed: Float = 0
    var state: TweenPlayState
    var delayRemaining: Float

    // Repeat / yoyo
    var repeatCount: Int           // 0 = play once, -1 = infinite
    var remainingRepeats: Int
    var yoyo: Bool                 // If true, plays forward then backward
    var isReversing: Bool = false  // Currently in yoyo reverse phase

    // Callbacks
    var onStart: (@Sendable () -> Void)?
    var onUpdate: (@Sendable (Float) -> Void)?
    var onComplete: (@Sendable () -> Void)?

    // Sequence membership (nil = standalone)
    var sequenceId: UInt32?

    init(
        handle: TweenHandle,
        entity: Entity,
        target: TweenTarget,
        duration: Float,
        easing: EasingFunction,
        delay: Float,
        repeatCount: Int = 0,
        yoyo: Bool = false
    ) {
        self.handle = handle
        self.entity = entity
        self.target = target
        self.duration = max(duration, 0)
        self.easing = easing
        self.delay = max(delay, 0)
        self.delayRemaining = max(delay, 0)
        self.state = delay > 0 ? .waiting : .running
        self.repeatCount = repeatCount
        self.remainingRepeats = repeatCount
        self.yoyo = yoyo
    }
}

// MARK: - Tween Sequence (Internal)

/// Internal state for an active tween sequence.
///
/// Steps play one after another. When one completes, the next starts.
internal struct TweenSequence: @unchecked Sendable {
    let id: UInt32
    let entity: Entity
    var steps: [TweenStep]
    var currentIndex: Int = 0
    var currentTween: TweenHandle = .invalid
    var repeatCount: Int = 0
    var remainingRepeats: Int = 0
    var onComplete: (@Sendable () -> Void)?
}

// MARK: - Tween Completed Event

/// Event emitted when a tween completes.
///
/// Subscribe via `world.on(TweenCompleted.self)` for decoupled tween tracking.
///
/// ## Usage
/// ```swift
/// world.on(TweenCompleted.self) { event in
///     print("Tween \(event.handle.id) on entity \(event.entity.index) finished")
/// }
/// ```
public struct TweenCompleted: Event {
    /// The handle of the completed tween.
    public let handle: TweenHandle
    /// The entity the tween was animating.
    public let entity: Entity
}
