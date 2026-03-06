/// Configuration for the application window and engine.
public struct WindowConfig: Sendable {
    /// Window title.
    public var title: String

    /// Initial window width in pixels.
    public var width: Int

    /// Initial window height in pixels.
    public var height: Int

    /// Target FPS (0 = uncapped).
    public var targetFPS: Int

    /// Whether the window is resizable.
    public var resizable: Bool

    /// Whether VSync is enabled.
    public var vsync: Bool

    /// Fixed timestep for game logic updates (in seconds).
    public var fixedTimestep: Double

    /// Maximum frame time to prevent spiral of death (in seconds).
    public var maxFrameTime: Double

    public init(
        title: String = "Agilis",
        width: Int = 800,
        height: Int = 600,
        targetFPS: Int = 60,
        resizable: Bool = true,
        vsync: Bool = true,
        fixedTimestep: Double = 1.0 / 60.0,
        maxFrameTime: Double = 0.25
    ) {
        self.title = title
        self.width = width
        self.height = height
        self.targetFPS = targetFPS
        self.resizable = resizable
        self.vsync = vsync
        self.fixedTimestep = fixedTimestep
        self.maxFrameTime = maxFrameTime
    }
}
