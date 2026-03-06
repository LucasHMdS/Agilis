

/// Manages a chain of screen-space post-processing effects.
///
/// The pipeline captures the scene into a render target, processes it
/// through an ordered chain of enabled effects using ping-pong buffers,
/// and composites the result to the screen.
///
/// ## Usage
/// ```swift
/// // Setup (in Scene.didEnter)
/// let postProcess = PostProcessPipeline()
/// postProcess.add(BloomEffect(intensity: 1.2))
/// postProcess.add(VignetteEffect())
/// postProcess.initialize(renderer: app.renderer)
///
/// // In Scene.render():
/// postProcess.beginCapture(renderer: app.renderer)
/// app.renderer.beginCamera(camera)
/// // ... draw entire scene (sprites, tilemaps, particles, lighting) ...
/// app.renderer.endCamera()
/// lighting.renderLightMap(renderer: app.renderer, camera: camera)
/// lighting.compositeLightMap(renderer: app.renderer)
/// postProcess.endCaptureAndApply(renderer: app.renderer, deltaTime: dt)
///
/// // Cleanup (in Scene.willExit)
/// postProcess.shutdown(renderer: app.renderer)
/// ```
public final class PostProcessPipeline: @unchecked Sendable {
    private var effects: [any PostProcessEffect] = []
    private var sceneRT: RenderTargetHandle = .invalid
    private var pingRT: RenderTargetHandle = .invalid
    private var pongRT: RenderTargetHandle = .invalid
    private var width: Int = 0
    private var height: Int = 0
    private var _isInitialized = false

    public init() {}

    // MARK: - Effect Management

    /// Add an effect to the pipeline. Effects are sorted by `order` (lower runs first).
    ///
    /// If the pipeline is already initialized, the effect is initialized immediately.
    public func add(_ effect: any PostProcessEffect) {
        effects.append(effect)
        effects.sort { $0.order < $1.order }

        if _isInitialized, let renderer = cachedRenderer {
            effect.initialize(renderer: renderer)
            if width > 0 && height > 0 {
                effect.resize(width: width, height: height, renderer: renderer)
            }
        }
    }

    /// Remove an effect by name.
    ///
    /// If the pipeline is initialized, the effect's `shutdown` is called.
    @discardableResult
    public func remove(named name: String) -> Bool {
        guard let index = effects.firstIndex(where: { $0.name == name }) else {
            return false
        }
        let effect = effects.remove(at: index)
        if _isInitialized, let renderer = cachedRenderer {
            effect.shutdown(renderer: renderer)
        }
        return true
    }

    /// Get an effect by type for runtime parameter tweaking.
    ///
    /// ```swift
    /// if let vignette = postProcess.effect(ofType: VignetteEffect.self) {
    ///     vignette.intensity = 0.8
    /// }
    /// ```
    public func effect<T: PostProcessEffect>(ofType type: T.Type) -> T? {
        effects.first(where: { $0 is T }) as? T
    }

    /// Get an effect by name.
    public func effect(named name: String) -> (any PostProcessEffect)? {
        effects.first(where: { $0.name == name })
    }

    /// All effects in pipeline order.
    public var allEffects: [any PostProcessEffect] { effects }

    /// Number of effects in the pipeline.
    public var effectCount: Int { effects.count }

    // MARK: - Lifecycle

    /// Whether the pipeline has been initialized with GPU resources.
    public var isInitialized: Bool { _isInitialized }

    /// Initialize GPU resources (render targets). Call once after the renderer
    /// is initialized, typically in `Scene.didEnter`.
    ///
    /// Also initializes all currently added effects.
    public func initialize(renderer: Renderer) {
        guard !_isInitialized else { return }
        cachedRenderer = renderer

        let screen = renderer.screenSize
        width = max(1, Int(screen.width))
        height = max(1, Int(screen.height))

        createRenderTargets(renderer: renderer)

        for effect in effects {
            effect.initialize(renderer: renderer)
            effect.resize(width: width, height: height, renderer: renderer)
        }

        _isInitialized = true
    }

    /// Free all GPU resources. Call during teardown (e.g., `Scene.willExit`).
    ///
    /// Also shuts down all effects.
    public func shutdown(renderer: Renderer) {
        for effect in effects {
            effect.shutdown(renderer: renderer)
        }

        destroyRenderTargets(renderer: renderer)
        _isInitialized = false
        cachedRenderer = nil
    }

    // MARK: - Render Integration

    /// Begin capturing scene rendering into the internal render target.
    ///
    /// All draw calls after this are redirected to an off-screen buffer instead
    /// of the screen. Call `endCaptureAndApply` when scene rendering is complete.
    public func beginCapture(renderer: Renderer) {
        guard _isInitialized else { return }

        // Check for screen resize
        let screen = renderer.screenSize
        let newWidth = max(1, Int(screen.width))
        let newHeight = max(1, Int(screen.height))
        if newWidth != width || newHeight != height {
            width = newWidth
            height = newHeight
            destroyRenderTargets(renderer: renderer)
            createRenderTargets(renderer: renderer)
            for effect in effects {
                effect.resize(width: width, height: height, renderer: renderer)
            }
        }

        renderer.beginRenderTarget(sceneRT)
    }

    /// Stop capturing, run the effect chain, and composite the result to the screen.
    ///
    /// - Parameters:
    ///   - renderer: The render backend.
    ///   - deltaTime: Frame delta time in seconds (passed to animated effects).
    public func endCaptureAndApply(
        renderer: Renderer,
        deltaTime: Float = 0
    ) {
        guard _isInitialized else { return }
        renderer.endRenderTarget()

        let enabledEffects = effects.filter { $0.isEnabled }

        guard !enabledEffects.isEmpty else {
            // No effects enabled -- draw scene RT directly to screen
            drawFullscreen(handle: sceneRT, renderer: renderer)
            return
        }

        // Ping-pong between buffers
        var currentInput = sceneRT
        var usesPing = true

        for effect in enabledEffects {
            let currentOutput = usesPing ? pingRT : pongRT
            effect.apply(
                input: currentInput,
                output: currentOutput,
                renderer: renderer,
                deltaTime: deltaTime
            )
            currentInput = currentOutput
            usesPing = !usesPing
        }

        // Blit final result to screen
        drawFullscreen(handle: currentInput, renderer: renderer)
    }

    // MARK: - Private

    /// Weak reference to the renderer for late-adding effects.
    private weak var cachedRenderer: (Renderer)?

    private func createRenderTargets(renderer: Renderer) {
        sceneRT = renderer.createRenderTarget(width: width, height: height)
        pingRT = renderer.createRenderTarget(width: width, height: height)
        pongRT = renderer.createRenderTarget(width: width, height: height)
    }

    private func destroyRenderTargets(renderer: Renderer) {
        if sceneRT != .invalid { renderer.destroyRenderTarget(sceneRT) }
        if pingRT != .invalid { renderer.destroyRenderTarget(pingRT) }
        if pongRT != .invalid { renderer.destroyRenderTarget(pongRT) }
        sceneRT = .invalid
        pingRT = .invalid
        pongRT = .invalid
    }

    private func drawFullscreen(handle: RenderTargetHandle, renderer: Renderer) {
        let texture = renderer.renderTargetTexture(handle)
        guard texture != .invalid else { return }
        let size = renderer.renderTargetSize(handle)
        guard size.width > 0 && size.height > 0 else { return }

        let screen = renderer.screenSize
        renderer.drawSprite(Sprite(
            texture: texture,
            sourceRect: Rect(x: 0, y: 0, width: size.width, height: size.height),
            scale: Vector2(
                x: screen.width / size.width,
                y: screen.height / size.height
            ),
            tint: .white,
            flipY: true
        ))
    }
}
