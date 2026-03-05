/// A plugin extends the engine with additional functionality.
public protocol Plugin: AnyObject {
    /// Human-readable name.
    var name: String { get }

    /// Called when the plugin is installed. Use this to register systems, loaders, etc.
    func install(in app: Application)

    /// Called each fixed-timestep update.
    func update(deltaTime: Double)

    /// Called when the application shuts down.
    func uninstall()
}

public extension Plugin {
    func update(deltaTime: Double) {}
    func uninstall() {}
}
