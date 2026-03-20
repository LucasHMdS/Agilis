// MARK: - AnimationSystem

/// ECS system that advances sprite animations each tick.
///
/// Iterates all entities with both `SpriteAnimator` and `Sprite` components,
/// advances the animator's frame timer, selects the correct frame based on
/// the playback mode, and writes the frame's `sourceRect` into the entity's `Sprite`.
///
/// ## Usage
/// ```swift
/// let animationSystem = AnimationSystem()   // default priority 50
/// world.addSystem(animationSystem)
/// ```
///
/// ## Event Handling
/// ```swift
/// animationSystem.onAnimationEvent = { entity, event in
///     switch event {
///     case .looped:
///         print("\(entity) animation looped")
///     case .completed:
///         print("\(entity) animation finished")
///     }
/// }
/// ```
///
/// ## Pipeline Order
/// The default priority of 50 places animation between typical gameplay
/// systems (priority 0) and physics (priority 100). Gameplay systems set
/// clips and control playback, then AnimationSystem resolves frames,
/// then physics runs on the updated state.
public final class AnimationSystem: System, @unchecked Sendable {

    deinit {}

    // MARK: - System Conformance

    public var priority: Int { _priority }
    private let _priority: Int

    /// Writes SpriteAnimator/Sprite (advances frame time, updates sourceRect).
    /// Runs at priority 50, after AnimStateMachineSystem (45) which sets the active clip.
    /// Runs before PhysicsWorld2D (100).
    public var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [],
            writes: [SpriteAnimator.self, Sprite.self]
        )
    }

    // MARK: - Callbacks

    /// Called when an animation event occurs (loop or completion).
    /// Fires during the system update, after the frame has been resolved.
    public var onAnimationEvent: ((Entity, AnimationEvent) -> Void)?

    // MARK: - Init

    /// Creates an animation system.
    ///
    /// - Parameter priority: Execution priority (lower runs first). Default: 50.
    public init(priority: Int = 50) {
        self._priority = priority
    }

    // MARK: - Update

    public func update(context: SystemContext) {
        let world = context.world
        let dt = Float(context.deltaTime)

        world.forEach { (entity: Entity, animator: inout SpriteAnimator, sprite: inout Sprite) in
            // Clear event from previous tick
            animator.lastEvent = nil

            // Always write the current source rect, even when paused
            sprite.sourceRect = animator.currentSourceRect

            guard animator.isPlaying else { return }
            guard !animator.clip.frames.isEmpty else { return }

            // Advance time
            animator.frameTime += dt * animator.speed

            // Consume elapsed time, advancing frames as needed
            var event: AnimationEvent?
            while animator.currentFrameIndex < animator.clip.frames.count &&
                  animator.frameTime >= animator.clip.frames[animator.currentFrameIndex].duration {
                animator.frameTime -= animator.clip.frames[animator.currentFrameIndex].duration

                // Clamp negative frameTime from floating-point drift
                if animator.frameTime < 0 { animator.frameTime = 0 }

                event = self.advanceFrame(&animator)
                if event != nil { break }
            }

            // Write resolved source rect
            sprite.sourceRect = animator.currentSourceRect

            // Fire event if one occurred
            if let event = event {
                animator.lastEvent = event
                self.onAnimationEvent?(entity, event)
            }
        }
    }

    // MARK: - Frame Advancement

    /// Advances the frame index by one step according to the playback mode.
    /// Returns an event if a loop or completion boundary was crossed.
    private func advanceFrame(_ animator: inout SpriteAnimator) -> AnimationEvent? {
        let frameCount = animator.clip.frames.count
        guard frameCount > 0 else { return nil }

        switch animator.clip.mode {
        case .forward:
            animator.currentFrameIndex += 1
            if animator.currentFrameIndex >= frameCount {
                animator.currentFrameIndex = 0
                return .looped
            }

        case .reverse:
            animator.currentFrameIndex -= 1
            if animator.currentFrameIndex < 0 {
                animator.currentFrameIndex = frameCount - 1
                return .looped
            }

        case .pingPong:
            animator.currentFrameIndex += animator.pingPongDirection
            if animator.currentFrameIndex >= frameCount {
                // Hit the end — reverse direction, skip duplicate endpoint
                animator.pingPongDirection = -1
                animator.currentFrameIndex = max(frameCount - 2, 0)
                return .looped
            } else if animator.currentFrameIndex < 0 {
                // Hit the start — reverse direction, skip duplicate endpoint
                animator.pingPongDirection = 1
                animator.currentFrameIndex = min(1, frameCount - 1)
                return .looped
            }

        case .oneShot:
            animator.currentFrameIndex += 1
            if animator.currentFrameIndex >= frameCount {
                animator.currentFrameIndex = frameCount - 1
                animator.isPlaying = false
                return .completed
            }
        }

        return nil
    }
}
