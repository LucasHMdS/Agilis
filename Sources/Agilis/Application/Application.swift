import AgilisCore

/// The main application class. Owns the game loop and all engine subsystems.
public final class Application: @unchecked Sendable {
    public let config: WindowConfig
    public let renderer: RenderBackend
    public let audio: AudioBackend
    public let audioManager: AudioManager
    public let input: InputManager
    public let world: World
    public let sceneManager: SceneManager
    public let assets: AssetManager

    private let clock = Clock()
    private var running = false
    private var plugins: [Plugin] = []

    /// Time scale multiplier for game logic. Default `1.0`.
    ///
    /// Controls how fast game time passes relative to real time:
    /// - `0` — paused (rendering continues, audio stays real-time)
    /// - `0.5` — slow motion (half speed)
    /// - `1.0` — normal speed (default)
    /// - `2.0` — fast forward (double speed)
    ///
    /// Affects all fixed-timestep systems (physics, animation, particles,
    /// scene transitions, plugins). Does **not** affect audio fading,
    /// input polling, or rendering. Negative values are clamped to 0.
    public var timeScale: Double = 1.0

    /// Current frames per second (updated each frame).
    public private(set) var fps: Int = 0
    /// Duration of the last frame in seconds.
    public private(set) var frameTime: Double = 0
    private var fpsAccumulator: Double = 0
    private var fpsFrameCount: Int = 0

    public weak var delegate: GameDelegate?

    public init(
        config: WindowConfig,
        renderer: RenderBackend,
        audio: AudioBackend,
        inputBackend: InputBackend
    ) {
        self.config = config
        self.renderer = renderer
        self.audio = audio
        self.audioManager = AudioManager(backend: audio)
        self.input = InputManager(backend: inputBackend)
        self.world = World()
        self.sceneManager = SceneManager()
        self.assets = AssetManager()
    }

    // MARK: - Plugins

    /// Install a plugin. Call before `run()`.
    public func install(_ plugin: Plugin) {
        plugins.append(plugin)
        plugin.install(in: self)
    }

    // MARK: - Main Loop

    /// Start the game loop. This blocks until the window is closed.
    public func run() throws {
        try renderer.initialize(config: config)
        try audio.initialize()

        delegate?.gameDidStart(self)
        sceneManager.currentScene?.didEnter(app: self)

        running = true
        var accumulator: Double = 0
        let fixedDT = config.fixedTimestep

        // Prime the clock so the first elapsed() call returns ~0
        _ = clock.elapsed()

        while running && !renderer.shouldClose() {
            let elapsed = clock.elapsed()
            let frameTime = min(elapsed, config.maxFrameTime)
            self.frameTime = elapsed
            accumulator += frameTime * max(timeScale, 0)
            updateFPSCounter(elapsed: elapsed)

            // Poll input once per frame
            input.update()

            // Advance audio fades and update music streams
            audioManager.update(deltaTime: Float(elapsed))

            // Fixed-timestep logic updates
            while accumulator >= fixedDT {
                sceneManager.currentScene?.update(app: self, deltaTime: fixedDT)
                delegate?.gameDidUpdate(self, deltaTime: fixedDT)
                world.update(deltaTime: fixedDT)

                for plugin in plugins {
                    plugin.update(deltaTime: fixedDT)
                }

                // Advance scene transitions after all updates
                sceneManager.updateTransition(deltaTime: Float(fixedDT), app: self)

                accumulator -= fixedDT
            }

            let interpolation = accumulator / fixedDT

            // Render
            renderer.beginFrame()
            sceneManager.currentScene?.render(app: self, interpolation: interpolation)
            delegate?.gameWillRender(self, interpolation: interpolation)
            sceneManager.renderTransitionOverlay(renderer: renderer)
            renderer.endFrame()
        }

        shutdown()
    }

    /// Async game loop. Enables parallel system scheduling when
    /// `world.parallelSchedulingEnabled` is true.
    ///
    /// All raylib/GPU calls remain on the calling thread (which must be the main thread).
    /// `TaskGroup` inside `world.updateParallel` dispatches system work to the
    /// cooperative thread pool.
    public func runAsync() async throws {
        try renderer.initialize(config: config)
        try audio.initialize()

        delegate?.gameDidStart(self)
        sceneManager.currentScene?.didEnter(app: self)

        running = true
        var accumulator: Double = 0
        let fixedDT = config.fixedTimestep

        _ = clock.elapsed()

        while running && !renderer.shouldClose() {
            let elapsed = clock.elapsed()
            let frameTime = min(elapsed, config.maxFrameTime)
            self.frameTime = elapsed
            accumulator += frameTime * max(timeScale, 0)
            updateFPSCounter(elapsed: elapsed)

            input.update()
            audioManager.update(deltaTime: Float(elapsed))

            while accumulator >= fixedDT {
                sceneManager.currentScene?.update(app: self, deltaTime: fixedDT)
                delegate?.gameDidUpdate(self, deltaTime: fixedDT)

                if world.parallelSchedulingEnabled {
                    await world.updateParallel(deltaTime: fixedDT)
                } else {
                    world.update(deltaTime: fixedDT)
                }

                for plugin in plugins {
                    plugin.update(deltaTime: fixedDT)
                }

                sceneManager.updateTransition(deltaTime: Float(fixedDT), app: self)

                accumulator -= fixedDT
            }

            let interpolation = accumulator / fixedDT

            renderer.beginFrame()
            sceneManager.currentScene?.render(app: self, interpolation: interpolation)
            delegate?.gameWillRender(self, interpolation: interpolation)
            sceneManager.renderTransitionOverlay(renderer: renderer)
            renderer.endFrame()
        }

        shutdown()
    }

    /// Request the application to stop.
    public func quit() {
        running = false
    }

    // MARK: - Private

    private func updateFPSCounter(elapsed: Double) {
        fpsAccumulator += elapsed
        fpsFrameCount += 1
        if fpsAccumulator >= 1.0 {
            fps = fpsFrameCount
            fpsFrameCount = 0
            fpsAccumulator -= 1.0
        }
    }

    private func shutdown() {
        delegate?.gameWillStop(self)
        sceneManager.currentScene?.willExit(app: self)

        for plugin in plugins.reversed() {
            plugin.uninstall()
        }

        audio.shutdown()
        renderer.shutdown()
    }
}
