/// Protocol for screen-space post-processing effects.
///
/// Each effect processes a fullscreen render target with a fragment shader.
/// Effects are managed by `PostProcessPipeline`, which handles render target
/// ping-pong buffering and effect ordering.
///
/// ## Implementing a Custom Effect
/// ```swift
/// final class MyEffect: PostProcessEffect, @unchecked Sendable {
///     let name = "myEffect"
///     var isEnabled = true
///     var order: Int { 250 }
///
///     private var shader: ShaderHandle = .invalid
///
///     func initialize(renderer: any RenderBackend) {
///         shader = renderer.loadShader(vertexSource: nil, fragmentSource: myGLSL)
///     }
///
///     func shutdown(renderer: any RenderBackend) {
///         if shader != .invalid { renderer.destroyShader(shader) }
///         shader = .invalid
///     }
///
///     func apply(input: RenderTargetHandle, output: RenderTargetHandle,
///                renderer: any RenderBackend, deltaTime: Float) {
///         renderer.setShaderFloat(shader, name: "myParam", value: 0.5)
///         renderer.beginRenderTarget(output)
///         renderer.beginShader(shader)
///         let texture = renderer.renderTargetTexture(input)
///         let size = renderer.renderTargetSize(input)
///         renderer.drawSprite(Sprite(
///             texture: texture,
///             sourceRect: Rect(x: 0, y: 0, width: size.width, height: size.height),
///             tint: .white,
///             flipY: true
///         ))
///         renderer.endShader()
///         renderer.endRenderTarget()
///     }
/// }
/// ```
public protocol PostProcessEffect: AnyObject, Sendable {
    /// Human-readable name for debugging and identification.
    var name: String { get }

    /// Whether this effect is currently active. Disabled effects are skipped
    /// in the pipeline with zero cost (no render target ping-pong).
    var isEnabled: Bool { get set }

    /// Priority for ordering in the pipeline (lower runs first).
    ///
    /// Standard effect orders:
    /// - Bloom: 100
    /// - Chromatic aberration: 200
    /// - Color grading: 300
    /// - Vignette: 400
    /// - Scanlines: 500
    /// - Pixelate: 600
    var order: Int { get }

    /// Called once when the effect is added to an initialized pipeline,
    /// or when the pipeline is initialized. Load shaders and allocate
    /// GPU resources here.
    func initialize(renderer: any RenderBackend)

    /// Called when the pipeline is shut down or the effect is removed.
    /// Free GPU resources here.
    func shutdown(renderer: any RenderBackend)

    /// Called when the screen size changes. Recreate size-dependent resources
    /// (e.g., intermediate render targets for multi-pass effects).
    func resize(width: Int, height: Int, renderer: any RenderBackend)

    /// Apply the effect. Read from `input` render target, write to `output`.
    ///
    /// The pipeline handles ping-pong buffer management. A typical implementation:
    /// 1. Set shader uniforms
    /// 2. `renderer.beginRenderTarget(output)`
    /// 3. `renderer.beginShader(shader)`
    /// 4. Draw the input texture as a fullscreen sprite (with `flipY: true`)
    /// 5. `renderer.endShader()`
    /// 6. `renderer.endRenderTarget()`
    ///
    /// - Parameters:
    ///   - input: The render target containing the image to process.
    ///   - output: The render target to write the processed image to.
    ///   - renderer: The render backend.
    ///   - deltaTime: Frame delta time in seconds (for animated effects).
    func apply(
        input: RenderTargetHandle,
        output: RenderTargetHandle,
        renderer: any RenderBackend,
        deltaTime: Float
    )
}

// MARK: - Default Implementations

extension PostProcessEffect {
    public func shutdown(renderer _: any RenderBackend) {}
    public func resize(width _: Int, height _: Int, renderer _: any RenderBackend) {}
}
