import AgilisCore

// MARK: - Animation State Machine System

/// ECS system that evaluates animation state machine transitions each tick.
///
/// Runs at priority 45 (before `AnimationSystem` at 50) so that clip
/// switches happen before frame advancement. The system reads
/// `SpriteAnimator.lastEvent` and `.isFinished` from the previous tick
/// to drive event-based transitions.
///
/// ## Setup
/// ```swift
/// let smSystem = AnimationStateMachineSystem()
/// let animSystem = AnimationSystem()
/// world.addSystem(smSystem)    // priority 45
/// world.addSystem(animSystem)  // priority 50
/// ```
///
/// ## Pipeline Order
/// 1. Gameplay systems (priority 0) set parameters on `AnimationStateMachine`
/// 2. `AnimationStateMachineSystem` (45) evaluates transitions, switches clips
/// 3. `AnimationSystem` (50) advances frames on the new/current clip
public final class AnimationStateMachineSystem: System, @unchecked Sendable {

    // MARK: - System Conformance

    public var priority: Int { _priority }
    private let _priority: Int

    /// Reads SpriteAnimator, writes AnimStateMachine/SpriteAnimator, emits AnimationStateChanged.
    /// Runs at priority 45, after TweenSystem (25) and before AnimationSystem (50).
    /// Sets the active clip on SpriteAnimator; AnimationSystem then advances frames.
    public var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [SpriteAnimator.self],
            writes: [AnimationStateMachine.self, SpriteAnimator.self],
            emitsEvents: true
        )
    }

    // MARK: - Callbacks

    /// Called when a state machine transitions. Parameters: entity, fromState, toState.
    public var onStateChanged: ((Entity, String, String) -> Void)?

    // MARK: - Init

    /// Creates an animation state machine system.
    ///
    /// - Parameter priority: Execution priority (lower runs first). Default: 45.
    public init(priority: Int = 45) {
        self._priority = priority
    }

    // MARK: - Update

    public func update(context: SystemContext) {
        let world = context.world
        let dt = Float(context.deltaTime)

        world.forEach { (entity: Entity, sm: inout AnimationStateMachine, animator: inout SpriteAnimator) in

            // --- Initialization ---
            if sm.needsInitialization {
                if let state = sm.states[sm.currentStateName] {
                    animator.forceSetClip(state.clip)
                    animator.speed = state.speed
                }
                sm.needsInitialization = false
            }

            // --- Advance time in state ---
            sm.timeInState += dt

            // --- Find matching transition ---
            if let transition = self.findMatchingTransition(&sm, animator: animator) {
                let fromState = sm.currentStateName
                let toState = transition.to

                // Validate destination state exists before applying transition
                guard let state = sm.states[toState] else { return }

                // Apply transition
                sm.previousStateName = fromState
                sm.currentStateName = toState
                sm.timeInState = 0

                // Switch clip
                animator.forceSetClip(state.clip)
                animator.speed = state.speed

                // Emit event
                world.emit(AnimationStateChanged(
                    entity: entity,
                    from: fromState,
                    to: toState
                ))
                self.onStateChanged?(entity, fromState, toState)
            }
        }
    }

    // MARK: - Transition Evaluation

    /// Find the first matching transition, checking any-state transitions first.
    private func findMatchingTransition(
        _ sm: inout AnimationStateMachine,
        animator: SpriteAnimator
    ) -> AnimationTransition? {
        // Check any-state transitions first (skip if destination == current)
        for transition in sm.anyStateTransitions {
            guard transition.to != sm.currentStateName else { continue }
            if checkTransition(transition, sm: &sm, animator: animator) {
                return transition
            }
        }

        // Check per-state transitions (from == current state)
        for transition in sm.transitions {
            guard transition.from == sm.currentStateName else { continue }
            if checkTransition(transition, sm: &sm, animator: animator) {
                return transition
            }
        }

        return nil
    }

    /// Check if a transition's exit time and all conditions pass.
    /// Triggers are only consumed if ALL conditions pass (two-pass evaluation).
    private func checkTransition(
        _ transition: AnimationTransition,
        sm: inout AnimationStateMachine,
        animator: SpriteAnimator
    ) -> Bool {
        // Exit time gate
        if let exitTime = transition.exitTime {
            guard animator.progress >= exitTime else { return false }
        }

        // Two-pass evaluation for trigger safety:
        // Pass 1: Check all conditions without consuming triggers
        var triggerNames: [String] = []

        for condition in transition.conditions {
            switch condition {
            case .trigger(let name):
                // Just verify the trigger is set, don't consume yet
                guard sm.checkTrigger(name) else { return false }
                triggerNames.append(name)
            default:
                if !evaluateCondition(condition, sm: sm, animator: animator) {
                    return false
                }
            }
        }

        // Pass 2: All conditions passed — consume triggers
        for name in triggerNames {
            sm.consumeTrigger(name)
        }

        return true
    }

    /// Evaluate a single non-trigger condition.
    private func evaluateCondition(
        _ condition: TransitionCondition,
        sm: AnimationStateMachine,
        animator: SpriteAnimator
    ) -> Bool {
        switch condition {
        case .boolEquals(let name, let expected):
            return sm.getBool(name) == expected
        case .floatGreater(let name, let threshold):
            return sm.getFloat(name) > threshold
        case .floatLess(let name, let threshold):
            return sm.getFloat(name) < threshold
        case .intEquals(let name, let expected):
            return sm.getInt(name) == expected
        case .trigger:
            // Handled in checkTransition's two-pass logic
            return true
        case .animationFinished:
            return animator.isFinished
        case .animationLooped:
            return animator.lastEvent == .looped
        case .afterTime(let seconds):
            return sm.timeInState >= seconds
        }
    }
}
