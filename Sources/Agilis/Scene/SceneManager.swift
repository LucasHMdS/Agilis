import AgilisCore

/// Manages a stack of scenes with push/pop/replace operations.
///
/// Supports both instant scene changes and animated transitions:
/// ```swift
/// // Instant (existing behavior)
/// app.sceneManager.replace(with: nextScene, app: app)
///
/// // With transition
/// app.sceneManager.replace(with: nextScene, transition: .fade(), app: app)
/// ```
public final class SceneManager: @unchecked Sendable {
    private var sceneStack: [Scene] = []
    private var activeTransition: TransitionState?

    public init() {}

    /// The currently active scene (top of stack).
    public var currentScene: Scene? {
        sceneStack.last
    }

    /// Whether a transition is currently animating.
    public var isTransitioning: Bool {
        activeTransition != nil
    }

    // MARK: - Instant Operations (unchanged)

    /// Push a new scene onto the stack. The previous scene remains underneath.
    public func push(_ scene: Scene, app: Application) {
        sceneStack.append(scene)
        scene.didEnter(app: app)
    }

    /// Pop the current scene. The previous scene becomes active.
    @discardableResult
    public func pop(app: Application) -> Scene? {
        guard let scene = sceneStack.popLast() else { return nil }
        scene.willExit(app: app)
        return scene
    }

    /// Replace the current scene with a new one.
    public func replace(with scene: Scene, app: Application) {
        if let current = sceneStack.popLast() {
            current.willExit(app: app)
        }
        sceneStack.append(scene)
        scene.didEnter(app: app)
    }

    /// Replace all scenes with a single new scene.
    public func replaceAll(with scene: Scene, app: Application) {
        for s in sceneStack.reversed() {
            s.willExit(app: app)
        }
        sceneStack.removeAll()
        sceneStack.append(scene)
        scene.didEnter(app: app)
    }

    // MARK: - Transition Operations

    /// Push a new scene with a transition effect.
    public func push(_ scene: Scene, transition: SceneTransition, app: Application) {
        beginTransition(transition, operation: .push(scene), app: app)
    }

    /// Pop the current scene with a transition effect.
    public func pop(transition: SceneTransition, app: Application) {
        beginTransition(transition, operation: .pop, app: app)
    }

    /// Replace the current scene with a transition effect.
    public func replace(with scene: Scene, transition: SceneTransition, app: Application) {
        beginTransition(transition, operation: .replace(scene), app: app)
    }

    /// Replace all scenes with a transition effect.
    public func replaceAll(with scene: Scene, transition: SceneTransition, app: Application) {
        beginTransition(transition, operation: .replaceAll(scene), app: app)
    }

    // MARK: - Transition Update (called by Application)

    /// Advance the transition state machine. Called once per fixed-timestep tick.
    internal func updateTransition(deltaTime: Float, app: Application) {
        guard var state = activeTransition else { return }

        state.elapsed += deltaTime

        switch state.phase {
        case .fadeOut:
            if state.elapsed >= state.halfDuration {
                // Execute the scene swap at the midpoint
                executeOperation(state.operation, app: app)
                state.transition.onMidpoint?()
                // Advance to fadeIn
                state.phase = .fadeIn
                state.elapsed = 0
            }

        case .fadeIn:
            if state.elapsed >= state.halfDuration {
                // Transition complete
                activeTransition = nil
                return
            }
        }

        activeTransition = state
    }

    /// Render the transition overlay on top of the current scene.
    /// Called after scene render, before endFrame.
    internal func renderTransitionOverlay(renderer: RenderBackend) {
        guard let state = activeTransition else { return }
        let alpha = state.overlayAlpha
        guard alpha > 0 else { return }

        let size = renderer.screenSize
        let color = Color(
            r: state.transition.color.r,
            g: state.transition.color.g,
            b: state.transition.color.b,
            a: alpha
        )
        renderer.drawRect(
            Rect(x: 0, y: 0, width: size.width, height: size.height),
            color: color
        )
    }

    // MARK: - Private Transition Helpers

    private func beginTransition(
        _ transition: SceneTransition,
        operation: TransitionOperation,
        app: Application
    ) {
        // Duration 0 → execute immediately (existing instant behavior)
        guard transition.duration > 0 else {
            executeOperation(operation, app: app)
            transition.onMidpoint?()
            return
        }

        // If already transitioning, force-complete the current one
        if activeTransition != nil {
            forceCompleteTransition(app: app)
        }

        activeTransition = TransitionState(
            transition: transition,
            operation: operation,
            phase: .fadeOut,
            elapsed: 0
        )
    }

    private func executeOperation(_ operation: TransitionOperation, app: Application) {
        switch operation {
        case .push(let scene):
            sceneStack.append(scene)
            scene.didEnter(app: app)

        case .pop:
            if let scene = sceneStack.popLast() {
                scene.willExit(app: app)
            }

        case .replace(let scene):
            if let current = sceneStack.popLast() {
                current.willExit(app: app)
            }
            sceneStack.append(scene)
            scene.didEnter(app: app)

        case .replaceAll(let scene):
            for s in sceneStack.reversed() {
                s.willExit(app: app)
            }
            sceneStack.removeAll()
            sceneStack.append(scene)
            scene.didEnter(app: app)
        }
    }

    private func forceCompleteTransition(app: Application) {
        guard let state = activeTransition else { return }

        // If we haven't swapped scenes yet, do it now
        if case .fadeOut = state.phase {
            executeOperation(state.operation, app: app)
            state.transition.onMidpoint?()
        }

        activeTransition = nil
    }

    // MARK: - Private Types

    private enum TransitionPhase {
        case fadeOut  // Overlay alpha increasing (old scene visible)
        case fadeIn   // Overlay alpha decreasing (new scene visible)
    }

    private enum TransitionOperation {
        case push(Scene)
        case pop
        case replace(Scene)
        case replaceAll(Scene)
    }

    private struct TransitionState {
        let transition: SceneTransition
        let operation: TransitionOperation
        var phase: TransitionPhase
        var elapsed: Float

        var halfDuration: Float {
            transition.duration / 2
        }

        var phaseProgress: Float {
            guard halfDuration > 0 else { return 1.0 }
            return clamp(elapsed / halfDuration, min: 0, max: 1)
        }

        var overlayAlpha: UInt8 {
            switch phase {
            case .fadeOut:
                let eased = transition.fadeOutEasing.apply(phaseProgress)
                return UInt8(clamp(eased * 255, min: 0, max: 255))
            case .fadeIn:
                let eased = transition.fadeInEasing.apply(phaseProgress)
                return UInt8(clamp((1.0 - eased) * 255, min: 0, max: 255))
            }
        }
    }
}
