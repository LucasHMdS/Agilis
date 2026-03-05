import AgilisCore

/// ECS system that updates all active tweens each tick.
///
/// Advances tween timers, applies eased interpolation to component properties,
/// handles delay periods, yoyo/repeat logic, and entity death cleanup.
///
/// The default priority of 25 places tweens between gameplay systems (0)
/// and animation (50) / physics (100).
///
/// ## Usage
/// ```swift
/// let tweens = TweenSystem()
/// world.addSystem(tweens)
///
/// // Animate an entity's position
/// tweens.moveTo(player, target: Vector2(x: 300, y: 200),
///               duration: 0.5, easing: .cubicOut, in: world)
///
/// // Fade out a sprite
/// tweens.fadeOut(enemy, duration: 0.3, easing: .quadIn, in: world)
///
/// // Chain animations in a sequence
/// tweens.sequence(player, steps: [
///     .moveTo(target: Vector2(x: 300, y: 200), duration: 0.3, easing: .cubicOut),
///     .wait(duration: 0.1),
///     .fadeOut(duration: 0.2, easing: .quadIn)
/// ], in: world)
/// ```
public final class TweenSystem: System, @unchecked Sendable {

    public var priority: Int { _priority }
    private let _priority: Int

    /// Writes Transform2D/Sprite, emits TweenCompleted events.
    /// Runs at priority 25, after gameplay (0) and before AnimStateMachine (45)/AnimationSystem (50).
    public var componentAccess: ComponentAccess {
        ComponentAccess(
            writes: [Transform2D.self, Sprite.self],
            emitsEvents: true
        )
    }

    private let store = TweenStore()

    // Sequence management
    private var sequences: [UInt32: TweenSequence] = [:]
    private var nextSequenceId: UInt32 = 1

    /// System-level callback fired when any tween completes.
    ///
    /// Also emits a `TweenCompleted` event on the world's event bus.
    public var onTweenCompleted: ((TweenHandle, Entity) -> Void)?

    /// Create a tween system.
    ///
    /// - Parameter priority: Execution order (lower runs first). Default 25.
    public init(priority: Int = 25) {
        self._priority = priority
    }

    // MARK: - System Update

    public func update(context: SystemContext) {
        let world = context.world
        let dt = Float(context.deltaTime)

        store.forEachTween { tween in
            // Entity death check
            guard world.isAlive(tween.entity) else {
                tween.state = .completed
                // Clear onComplete so dead entity tweens don't fire callbacks
                tween.onComplete = nil
                return
            }

            // Skip paused and completed tweens
            guard tween.state != .paused && tween.state != .completed else { return }

            // Handle delay
            if tween.state == .waiting {
                tween.delayRemaining -= dt
                if tween.delayRemaining > 0 { return }
                tween.state = .running
                tween.elapsed = -tween.delayRemaining  // carry over excess time
                tween.onStart?()
            } else {
                tween.elapsed += dt
            }

            // Compute normalized time
            let rawT: Float
            if tween.duration > 0 {
                rawT = clamp(tween.elapsed / tween.duration, min: 0, max: 1)
            } else {
                rawT = 1.0  // instant tween
            }

            // Apply yoyo direction
            let directedT = tween.isReversing ? (1.0 - rawT) : rawT

            // Apply easing
            let easedT = tween.easing.apply(directedT)

            // Apply to component
            self.applyTween(tween, easedT: easedT, world: world)

            // Fire update callback
            tween.onUpdate?(easedT)

            // Check completion
            if rawT >= 1.0 {
                if tween.yoyo && !tween.isReversing {
                    // Start reverse phase
                    tween.isReversing = true
                    tween.elapsed = 0
                } else if tween.remainingRepeats != 0 {
                    // Restart
                    if tween.remainingRepeats > 0 { tween.remainingRepeats -= 1 }
                    tween.elapsed = 0
                    tween.isReversing = false
                } else {
                    tween.state = .completed
                }
            }
        }

        // Remove completed tweens and fire callbacks
        let completed = store.removeCompleted()
        for tween in completed {
            tween.onComplete?()
            onTweenCompleted?(tween.handle, tween.entity)
            world.emit(TweenCompleted(handle: tween.handle, entity: tween.entity))

            // Advance sequences
            if let seqId = tween.sequenceId {
                advanceSequence(seqId, world: world)
            }
        }

        // Clean up finished sequences (in-place removal avoids rebuilding the dictionary)
        let finishedKeys = sequences.compactMap { key, seq -> UInt32? in
            (seq.currentIndex >= seq.steps.count && seq.currentTween == .invalid) ? key : nil
        }
        for key in finishedKeys {
            sequences.removeValue(forKey: key)
        }
    }

    // MARK: - Apply Tween

    private func applyTween(_ tween: Tween, easedT: Float, world: World) {
        switch tween.target {
        case .position(let from, let to):
            let value = from.interpolated(to: to, t: easedT)
            world.updateComponent(Transform2D.self, on: tween.entity) { t in
                t.position = value
            }
        case .rotation(let from, let to):
            let value = from.interpolated(to: to, t: easedT)
            world.updateComponent(Transform2D.self, on: tween.entity) { t in
                t.rotation = value
            }
        case .scale(let from, let to):
            let value = from.interpolated(to: to, t: easedT)
            world.updateComponent(Transform2D.self, on: tween.entity) { t in
                t.scale = value
            }
        case .spriteColor(let from, let to):
            let value = from.interpolated(to: to, t: easedT)
            world.updateComponent(Sprite.self, on: tween.entity) { s in
                s.tint = value
            }
        case .spriteAlpha(let from, let to):
            let value = from.interpolated(to: to, t: easedT)
            world.updateComponent(Sprite.self, on: tween.entity) { s in
                s.tint = Color(r: s.tint.r, g: s.tint.g, b: s.tint.b,
                               a: UInt8(clamp(value, min: 0, max: 255)))
            }
        case .custom(let apply):
            apply(world, tween.entity, easedT)
        }
    }

    // MARK: - Sequence Management

    private func advanceSequence(_ sequenceId: UInt32, world: World) {
        guard var seq = sequences[sequenceId] else { return }

        // Entity death check — stop the sequence entirely
        guard world.isAlive(seq.entity) else {
            sequences.removeValue(forKey: sequenceId)
            return
        }

        seq.currentIndex += 1

        // Skip callback and instant steps
        while seq.currentIndex < seq.steps.count {
            let step = seq.steps[seq.currentIndex]
            switch step {
            case .callback(let fn):
                fn()
                seq.currentIndex += 1
                continue
            default:
                break
            }
            break
        }

        if seq.currentIndex >= seq.steps.count {
            // Sequence complete — check for repeat
            if seq.remainingRepeats != 0 {
                if seq.remainingRepeats > 0 { seq.remainingRepeats -= 1 }
                seq.currentIndex = 0
                sequences[sequenceId] = seq
                startSequenceStep(sequenceId: sequenceId, world: world)
            } else {
                seq.onComplete?()
                sequences.removeValue(forKey: sequenceId)
            }
            return
        }

        sequences[sequenceId] = seq
        startSequenceStep(sequenceId: sequenceId, world: world)
    }

    private func startSequenceStep(sequenceId: UInt32, world: World) {
        guard var seq = sequences[sequenceId] else { return }
        guard seq.currentIndex < seq.steps.count else { return }
        guard world.isAlive(seq.entity) else {
            sequences.removeValue(forKey: sequenceId)
            return
        }

        let step = seq.steps[seq.currentIndex]
        let handle: TweenHandle

        switch step {
        case .moveTo(let target, let duration, let easing):
            let current = world.getComponent(Transform2D.self, from: seq.entity)?.position ?? .zero
            handle = store.create(entity: seq.entity,
                                  target: .position(from: current, to: target),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .rotateTo(let target, let duration, let easing):
            let current = world.getComponent(Transform2D.self, from: seq.entity)?.rotation ?? 0
            handle = store.create(entity: seq.entity,
                                  target: .rotation(from: current, to: target),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .scaleTo(let target, let duration, let easing):
            let current = world.getComponent(Transform2D.self, from: seq.entity)?.scale ?? .one
            handle = store.create(entity: seq.entity,
                                  target: .scale(from: current, to: target),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .tintTo(let target, let duration, let easing):
            let current = world.getComponent(Sprite.self, from: seq.entity)?.tint ?? .white
            handle = store.create(entity: seq.entity,
                                  target: .spriteColor(from: current, to: target),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .fadeTo(let alpha, let duration, let easing):
            let current = Float(world.getComponent(Sprite.self, from: seq.entity)?.tint.a ?? 255)
            handle = store.create(entity: seq.entity,
                                  target: .spriteAlpha(from: current, to: alpha),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .fadeOut(let duration, let easing):
            let current = Float(world.getComponent(Sprite.self, from: seq.entity)?.tint.a ?? 255)
            handle = store.create(entity: seq.entity,
                                  target: .spriteAlpha(from: current, to: 0),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .fadeIn(let duration, let easing):
            let current = Float(world.getComponent(Sprite.self, from: seq.entity)?.tint.a ?? 0)
            handle = store.create(entity: seq.entity,
                                  target: .spriteAlpha(from: current, to: 255),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .wait(let duration):
            // Create a dummy position tween that doesn't move — just waits
            let pos = world.getComponent(Transform2D.self, from: seq.entity)?.position ?? .zero
            handle = store.create(entity: seq.entity,
                                  target: .position(from: pos, to: pos),
                                  duration: duration, easing: .linear, delay: 0,
                                  repeatCount: 0, yoyo: false)

        case .callback(let fn):
            fn()
            // Advance immediately
            seq.currentIndex += 1
            sequences[sequenceId] = seq
            if seq.currentIndex < seq.steps.count {
                startSequenceStep(sequenceId: sequenceId, world: world)
            } else {
                advanceSequence(sequenceId, world: world)
            }
            return

        case .custom(let duration, let easing, let apply):
            handle = store.create(entity: seq.entity,
                                  target: .custom(apply: apply),
                                  duration: duration, easing: easing, delay: 0,
                                  repeatCount: 0, yoyo: false)
        }

        // Tag the tween with its sequence ID
        store.modifyTween(handle) { tween in
            tween.sequenceId = sequenceId
        }

        seq.currentTween = handle
        sequences[sequenceId] = seq
    }
}

// MARK: - Tween Creation API

extension TweenSystem {

    /// Animate an entity's position from its current value to a target.
    ///
    /// - Parameters:
    ///   - entity: The entity to animate (must have `Transform2D`).
    ///   - target: Target position in world space.
    ///   - duration: Animation duration in seconds.
    ///   - easing: Easing function (default `.linear`).
    ///   - delay: Seconds to wait before starting (default 0).
    ///   - world: The ECS world.
    /// - Returns: A handle to the created tween, or `.invalid` if entity has no `Transform2D`.
    @discardableResult
    public func moveTo(
        _ entity: Entity,
        target: Vector2,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        guard let transform = world.getComponent(Transform2D.self, from: entity) else {
            return .invalid
        }
        return store.create(entity: entity,
                            target: .position(from: transform.position, to: target),
                            duration: duration, easing: easing, delay: delay,
                            repeatCount: 0, yoyo: false)
    }

    /// Animate an entity's position from a specific start to end value.
    ///
    /// Unlike `moveTo`, this does not read the current position — useful when
    /// you want an exact start value regardless of the entity's current state.
    @discardableResult
    public func moveFromTo(
        _ entity: Entity,
        from: Vector2,
        to: Vector2,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0
    ) -> TweenHandle {
        store.create(entity: entity,
                     target: .position(from: from, to: to),
                     duration: duration, easing: easing, delay: delay,
                     repeatCount: 0, yoyo: false)
    }

    /// Animate an entity's rotation from its current value to a target (radians).
    @discardableResult
    public func rotateTo(
        _ entity: Entity,
        target: Float,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        guard let transform = world.getComponent(Transform2D.self, from: entity) else {
            return .invalid
        }
        return store.create(entity: entity,
                            target: .rotation(from: transform.rotation, to: target),
                            duration: duration, easing: easing, delay: delay,
                            repeatCount: 0, yoyo: false)
    }

    /// Animate an entity's scale from its current value to a target.
    @discardableResult
    public func scaleTo(
        _ entity: Entity,
        target: Vector2,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        guard let transform = world.getComponent(Transform2D.self, from: entity) else {
            return .invalid
        }
        return store.create(entity: entity,
                            target: .scale(from: transform.scale, to: target),
                            duration: duration, easing: easing, delay: delay,
                            repeatCount: 0, yoyo: false)
    }

    /// Animate an entity's scale uniformly from its current value.
    ///
    /// Convenience that converts a single `Float` target to `Vector2(x: target, y: target)`.
    @discardableResult
    public func scaleUniformTo(
        _ entity: Entity,
        target: Float,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        scaleTo(entity, target: Vector2(x: target, y: target),
                duration: duration, easing: easing, delay: delay, in: world)
    }

    /// Animate an entity's sprite tint color from its current value to a target.
    @discardableResult
    public func tintTo(
        _ entity: Entity,
        target: Color,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        guard let sprite = world.getComponent(Sprite.self, from: entity) else {
            return .invalid
        }
        return store.create(entity: entity,
                            target: .spriteColor(from: sprite.tint, to: target),
                            duration: duration, easing: easing, delay: delay,
                            repeatCount: 0, yoyo: false)
    }

    /// Animate an entity's sprite alpha from its current value to a target (0–255).
    @discardableResult
    public func fadeTo(
        _ entity: Entity,
        alpha: Float,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        guard let sprite = world.getComponent(Sprite.self, from: entity) else {
            return .invalid
        }
        return store.create(entity: entity,
                            target: .spriteAlpha(from: Float(sprite.tint.a), to: alpha),
                            duration: duration, easing: easing, delay: delay,
                            repeatCount: 0, yoyo: false)
    }

    /// Fade an entity's sprite to fully transparent (alpha 0).
    @discardableResult
    public func fadeOut(
        _ entity: Entity,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        fadeTo(entity, alpha: 0, duration: duration, easing: easing, delay: delay, in: world)
    }

    /// Fade an entity's sprite to fully opaque (alpha 255).
    @discardableResult
    public func fadeIn(
        _ entity: Entity,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        fadeTo(entity, alpha: 255, duration: duration, easing: easing, delay: delay, in: world)
    }

    /// Create a custom tween with a user-provided apply closure.
    ///
    /// The closure receives the world, entity, and eased `t` value each tick.
    ///
    /// ```swift
    /// tweens.custom(entity, duration: 1.0, easing: .cubicOut) { world, entity, t in
    ///     world.updateComponent(Health.self, on: entity) { h in
    ///         h.current = lerp(0, 100, t: t)
    ///     }
    /// }
    /// ```
    @discardableResult
    public func custom(
        _ entity: Entity,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        apply: @escaping @Sendable (World, Entity, Float) -> Void
    ) -> TweenHandle {
        store.create(entity: entity,
                     target: .custom(apply: apply),
                     duration: duration, easing: easing, delay: delay,
                     repeatCount: 0, yoyo: false)
    }
}

// MARK: - Tween Modifiers

extension TweenSystem {

    /// Set the repeat count on a tween. Use -1 for infinite repeat.
    ///
    /// A count of 2 means the tween plays 3 times total (1 original + 2 repeats).
    @discardableResult
    public func setRepeat(_ handle: TweenHandle, count: Int) -> TweenHandle {
        store.modifyTween(handle) { tween in
            tween.repeatCount = count
            tween.remainingRepeats = count
        }
        return handle
    }

    /// Enable or disable yoyo mode (play forward then backward).
    ///
    /// When combined with repeat, the tween ping-pongs: forward, backward, forward, ...
    @discardableResult
    public func setYoyo(_ handle: TweenHandle, enabled: Bool = true) -> TweenHandle {
        store.modifyTween(handle) { tween in
            tween.yoyo = enabled
        }
        return handle
    }

    /// Set the onStart callback. Fires when the delay ends and interpolation begins.
    @discardableResult
    public func onStart(_ handle: TweenHandle, _ callback: @escaping @Sendable () -> Void) -> TweenHandle {
        store.modifyTween(handle) { tween in
            tween.onStart = callback
        }
        return handle
    }

    /// Set the onUpdate callback. Fires every tick with the eased `t` value.
    @discardableResult
    public func onUpdate(_ handle: TweenHandle, _ callback: @escaping @Sendable (Float) -> Void) -> TweenHandle {
        store.modifyTween(handle) { tween in
            tween.onUpdate = callback
        }
        return handle
    }

    /// Set the onComplete callback. Fires once when the tween finishes (after all repeats).
    @discardableResult
    public func onComplete(_ handle: TweenHandle, _ callback: @escaping @Sendable () -> Void) -> TweenHandle {
        store.modifyTween(handle) { tween in
            tween.onComplete = callback
        }
        return handle
    }
}

// MARK: - Sequence API

extension TweenSystem {

    /// Create a sequence of tween steps that play one after another.
    ///
    /// Each step reads the current component value when it starts, enabling
    /// relative chaining (e.g., move to A, then from A to B).
    ///
    /// ```swift
    /// tweens.sequence(player, steps: [
    ///     .moveTo(target: Vector2(x: 300, y: 200), duration: 0.3, easing: .cubicOut),
    ///     .wait(duration: 0.1),
    ///     .fadeOut(duration: 0.2, easing: .quadIn),
    ///     .callback { print("Done!") }
    /// ], in: world)
    /// ```
    @discardableResult
    public func sequence(
        _ entity: Entity,
        steps: [TweenStep],
        repeatCount: Int = 0,
        in world: World
    ) -> TweenHandle {
        guard !steps.isEmpty else { return .invalid }

        let seqId = nextSequenceId
        nextSequenceId += 1

        var seq = TweenSequence(id: seqId, entity: entity, steps: steps)
        seq.repeatCount = repeatCount
        seq.remainingRepeats = repeatCount
        sequences[seqId] = seq

        // Start the first step
        startSequenceStep(sequenceId: seqId, world: world)

        // Return a synthetic handle for the sequence (high bit set)
        return TweenHandle(id: seqId | 0x8000_0000)
    }

    /// Set the onComplete callback for a sequence.
    @discardableResult
    public func onSequenceComplete(
        _ handle: TweenHandle,
        _ callback: @escaping @Sendable () -> Void
    ) -> TweenHandle {
        let seqId = handle.id & 0x7FFF_FFFF
        if var seq = sequences[seqId] {
            seq.onComplete = callback
            sequences[seqId] = seq
        }
        return handle
    }
}

// MARK: - Lifecycle Control

extension TweenSystem {

    /// Cancel a tween immediately. The onComplete callback is NOT fired.
    public func cancel(_ handle: TweenHandle) {
        // Check if this is a sequence handle
        if handle.id & 0x8000_0000 != 0 {
            let seqId = handle.id & 0x7FFF_FFFF
            if let seq = sequences.removeValue(forKey: seqId) {
                store.cancel(handle: seq.currentTween)
            }
            return
        }
        store.cancel(handle: handle)
    }

    /// Cancel all tweens on an entity. No onComplete callbacks fire.
    public func cancelAll(on entity: Entity) {
        store.cancelAll(for: entity.index)
        // Also cancel sequences targeting this entity
        let seqIds = sequences.filter { $0.value.entity.index == entity.index }.map { $0.key }
        for seqId in seqIds {
            sequences.removeValue(forKey: seqId)
        }
    }

    /// Pause a tween.
    public func pause(_ handle: TweenHandle) {
        store.pause(handle: handle)
    }

    /// Resume a paused tween.
    public func resume(_ handle: TweenHandle) {
        store.resume(handle: handle)
    }

    /// Pause all tweens on an entity.
    public func pauseAll(on entity: Entity) {
        store.pauseAll(for: entity.index)
    }

    /// Resume all tweens on an entity.
    public func resumeAll(on entity: Entity) {
        store.resumeAll(for: entity.index)
    }

    /// Number of active tweens (not including sequence metadata).
    public var tweenCount: Int { store.count }

    /// Check if a tween handle is still active.
    public func isActive(_ handle: TweenHandle) -> Bool {
        if handle.id & 0x8000_0000 != 0 {
            let seqId = handle.id & 0x7FFF_FFFF
            return sequences[seqId] != nil
        }
        return store.tween(for: handle) != nil
    }

    /// Remove all tweens and sequences.
    public func removeAll() {
        store.clear()
        sequences.removeAll()
    }

    // MARK: - Debug

    /// Get debug information for all active tweens.
    ///
    /// Returns a snapshot of each tween's entity, target type, progress, and target
    /// position (for position tweens). Use with `renderer.drawTweenDebug(infos:...)`.
    public func debugTweenInfo(world: World) -> [TweenDebugInfo] {
        var result: [TweenDebugInfo] = []
        store.forEachTween { tween in
            guard tween.state == .running || tween.state == .waiting else { return }

            let targetType: String
            var targetPos: Vector2? = nil

            switch tween.target {
            case .position(_, let to):
                targetType = "pos"
                targetPos = to
            case .rotation:
                targetType = "rot"
            case .scale:
                targetType = "scale"
            case .spriteColor:
                targetType = "color"
            case .spriteAlpha:
                targetType = "alpha"
            case .custom:
                targetType = "custom"
            }

            let progress = tween.duration > 0 ? tween.elapsed / tween.duration : 1.0
            result.append(TweenDebugInfo(
                entity: tween.entity,
                targetType: targetType,
                progress: min(progress, 1.0),
                targetPosition: targetPos
            ))
        }
        return result
    }
}
