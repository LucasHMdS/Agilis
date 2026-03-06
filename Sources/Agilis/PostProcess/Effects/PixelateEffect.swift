

/// Reduces effective resolution for a retro pixelation look.
///
/// ```swift
/// let pixelate = PixelateEffect(pixelSize: 4.0)
/// postProcess.add(pixelate)
/// ```
public final class PixelateEffect: PostProcessEffect, @unchecked Sendable {
    public let name = "pixelate"
    public var isEnabled = true
    public var order: Int { 600 }

    /// Virtual pixel size in screen pixels. Higher = more pixelated.
    public var pixelSize: Float

    private var shader: ShaderHandle = .invalid
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0

    public init(pixelSize: Float = 4.0) {
        self.pixelSize = pixelSize
    }

    public func initialize(renderer: any RenderBackend) {
        shader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: PostProcessShaders.pixelateFragment
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

        renderer.setShaderFloat(shader, name: "pixelSize", value: pixelSize)
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
