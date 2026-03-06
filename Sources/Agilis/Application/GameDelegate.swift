/// Implement this protocol to receive game lifecycle callbacks.
public protocol GameDelegate: AnyObject {
    /// Called once after the engine is initialized.
    func gameDidStart(_ app: Application)

    /// Called each fixed-timestep tick for game logic.
    func gameDidUpdate(_ app: Application, deltaTime: Double)

    /// Called each frame for rendering. `interpolation` is the blend factor (0-1)
    /// between the previous and current logic state, for smooth rendering.
    func gameWillRender(_ app: Application, interpolation: Double)

    /// Called when the application is about to shut down.
    func gameWillStop(_ app: Application)
}

/// Default implementations so delegates only need to implement what they use.
public extension GameDelegate {
    func gameDidStart(_ app: Application) {}
    func gameDidUpdate(_ app: Application, deltaTime: Double) {}
    func gameWillRender(_ app: Application, interpolation: Double) {}
    func gameWillStop(_ app: Application) {}
}
