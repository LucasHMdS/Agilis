/// A game scene (e.g., menu, gameplay, game over).
public protocol Scene: AnyObject {
    /// Called when the scene becomes the active scene.
    func didEnter(app: Application)

    /// Called each fixed-timestep update while this scene is active.
    func update(app: Application, deltaTime: Double)

    /// Called each frame for rendering.
    func render(app: Application, interpolation: Double)

    /// Called when the scene is about to be replaced or removed.
    func willExit(app: Application)
}

public extension Scene {
    func didEnter(app _: Application) {}
    func update(app _: Application, deltaTime _: Double) {}
    func render(app _: Application, interpolation _: Double) {}
    func willExit(app _: Application) {}
}
