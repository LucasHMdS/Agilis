import AgilisCore

/// Manages the lifecycle and storage of active tweens.
///
/// Follows the `JointStore` pattern: centralized handle-keyed dictionary
/// with a reverse entity-to-tweens map for efficient entity cleanup.
/// Used internally by `TweenSystem`.
internal final class TweenStore: @unchecked Sendable {

    /// All active tweens, keyed by handle ID.
    private var tweens: [UInt32: Tween] = [:]

    /// Next handle ID to assign (0 is reserved for `.invalid`).
    private var nextId: UInt32 = 1

    /// Reverse map from entity index to the set of tween handle IDs targeting it.
    private var entityToTweens: [UInt32: Set<UInt32>] = [:]

    // MARK: - Creation

    /// Create a tween and return its handle.
    func create(
        entity: Entity,
        target: TweenTarget,
        duration: Float,
        easing: EasingFunction,
        delay: Float,
        repeatCount: Int,
        yoyo: Bool
    ) -> TweenHandle {
        var id = nextId
        nextId &+= 1
        if nextId == 0 { nextId = 1 } // skip invalid sentinel

        // If ID collides with an active tween, scan forward for a free slot
        var attempts = 0
        while tweens[id] != nil && attempts < 100 {
            id &+= 1
            if id == 0 { id = 1 }
            attempts += 1
        }
        guard tweens[id] == nil else { return .invalid }

        let handle = TweenHandle(id: id)

        let tween = Tween(
            handle: handle,
            entity: entity,
            target: target,
            duration: duration,
            easing: easing,
            delay: delay,
            repeatCount: repeatCount,
            yoyo: yoyo
        )

        tweens[id] = tween
        entityToTweens[entity.index, default: []].insert(id)

        return handle
    }

    // MARK: - Destruction

    /// Cancel a tween by handle. No-op if invalid or already removed.
    func cancel(handle: TweenHandle) {
        guard let tween = tweens.removeValue(forKey: handle.id) else { return }
        removeTweenFromEntityMap(tween)
    }

    /// Cancel all tweens targeting a specific entity.
    func cancelAll(for entityIndex: UInt32) {
        guard let tweenIds = entityToTweens.removeValue(forKey: entityIndex) else { return }
        for id in tweenIds {
            tweens.removeValue(forKey: id)
        }
    }

    // MARK: - Pause / Resume

    /// Pause a tween by handle.
    func pause(handle: TweenHandle) {
        guard var tween = tweens[handle.id] else { return }
        guard tween.state == .running || tween.state == .waiting else { return }
        tween.state = .paused
        tweens[handle.id] = tween
    }

    /// Resume a paused tween by handle.
    func resume(handle: TweenHandle) {
        guard var tween = tweens[handle.id] else { return }
        guard tween.state == .paused else { return }
        tween.state = tween.delayRemaining > 0 ? .waiting : .running
        tweens[handle.id] = tween
    }

    /// Pause all tweens targeting a specific entity.
    func pauseAll(for entityIndex: UInt32) {
        guard let tweenIds = entityToTweens[entityIndex] else { return }
        for id in tweenIds {
            guard var tween = tweens[id] else { continue }
            guard tween.state == .running || tween.state == .waiting else { continue }
            tween.state = .paused
            tweens[id] = tween
        }
    }

    /// Resume all paused tweens targeting a specific entity.
    func resumeAll(for entityIndex: UInt32) {
        guard let tweenIds = entityToTweens[entityIndex] else { return }
        for id in tweenIds {
            guard var tween = tweens[id] else { continue }
            guard tween.state == .paused else { continue }
            tween.state = tween.delayRemaining > 0 ? .waiting : .running
            tweens[id] = tween
        }
    }

    // MARK: - Modification

    /// Mutate a tween in-place. No-op if handle is invalid.
    func modifyTween(_ handle: TweenHandle, _ body: (inout Tween) -> Void) {
        guard var tween = tweens[handle.id] else { return }
        body(&tween)
        tweens[handle.id] = tween
    }

    // MARK: - Access

    /// Get a tween by handle for read access.
    func tween(for handle: TweenHandle) -> Tween? {
        tweens[handle.id]
    }

    /// Total number of active tweens.
    var count: Int { tweens.count }

    /// Iterate all tweens mutably.
    ///
    /// Snapshots keys first to avoid issues with Dictionary.Keys iterator
    /// during mutation and to avoid per-frame lazy sequence allocation.
    func forEachTween(_ body: (inout Tween) -> Void) {
        let keys = Array(tweens.keys)
        for key in keys {
            if var tween = tweens[key] {
                body(&tween)
                tweens[key] = tween
            }
        }
    }

    /// Remove all completed tweens and return them (for callback firing).
    func removeCompleted() -> [Tween] {
        var completed: [Tween] = []
        var toRemove: [UInt32] = []

        for (key, tween) in tweens {
            if tween.state == .completed {
                completed.append(tween)
                toRemove.append(key)
            }
        }

        for id in toRemove {
            if let tween = tweens.removeValue(forKey: id) {
                removeTweenFromEntityMap(tween)
            }
        }

        return completed
    }

    /// Clear all tweens.
    func clear() {
        tweens.removeAll()
        entityToTweens.removeAll()
    }

    // MARK: - Private Helpers

    private func removeTweenFromEntityMap(_ tween: Tween) {
        entityToTweens[tween.entity.index]?.remove(tween.handle.id)
        if entityToTweens[tween.entity.index]?.isEmpty == true {
            entityToTweens.removeValue(forKey: tween.entity.index)
        }
    }
}
