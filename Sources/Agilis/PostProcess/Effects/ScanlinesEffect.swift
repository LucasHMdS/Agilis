import AgilisCore

/// CRT scanline simulation with optional barrel distortion.
///
/// ```swift
/// let scanlines = ScanlinesEffect(lineIntensity: 0.2, curvature: 0.1)
/// postProcess.add(scanlines)
/// ```
public final class ScanlinesEffect: PostProcessEffect, @unchecked Sendable {
    public let name = "scanlines"
    public var isEnabled = true
    public var order: Int { 500 }

    /// Pixels between scanlines (default 2.0).
    public var lineSpacing: Float

    /// Darkness of scanlines (0 = invisible, 1 = fully black, default 0.15).
    public var lineIntensity: Float

    /// Barrel distortion amount (0 = flat, 0.1-0.3 = subtle CRT curve, default 0).
    public var curvature: Float

    private var shader: ShaderHandle = .invalid
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0

    public init(
        lineSpacing: Float = 2.0,
        lineIntensity: Float = 0.15,
        curvature: Float = 0
    ) {
        self.lineSpacing = lineSpacing
        self.lineIntensity = lineIntensity
        self.curvature = curvature
    }

    public func initialize(renderer: any RenderBackend) {
        shader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: PostProcessShaders.scanlinesFragment
        )
    }

    public func shutdown(renderer: any RenderBackend) {
        if shader != .invalid { renderer.destroyShader(shader) }
        shader = .invalid
    }

    public func resize(width: Int, height: Int, renderer: any RenderBackend) {
        currentWidth = width
        currentHeight = height
    }

    public func apply(
        input: RenderTargetHandle,
        output: RenderTargetHandle,
        renderer: any RenderBackend,
        deltaTime: Float
    ) {
        guard shader != .invalid else { return }

        renderer.setShaderFloat(shader, name: "lineSpacing", value: lineSpacing)
        renderer.setShaderFloat(shader, name: "lineIntensity", value: lineIntensity)
        renderer.setShaderFloat(shader, name: "curvature", value: curvature)
        renderer.setShaderVec2(shader, name: "resolution",
            value: Vector2(x: Float(currentWidth), y: Float(currentHeight)))

        let texture = renderer.renderTargetTexture(input)
        let size = renderer.renderTargetSize(input)

        renderer.beginRenderTarget(output)
        renderer.beginShader(shader)
        renderer.drawSprite(Sprite(
            texture: texture,
            sourceRect: Rect(x: 0, y: 0, width: size.width, height: size.height),
            tint: .white,
            flipY: true
        ))
        renderer.endShader()
        renderer.endRenderTarget()
    }
}
