/// Offsets RGB color channels radially from the screen center for a lens distortion look.
///
/// ```swift
/// let chromatic = ChromaticAberrationEffect(amount: 0.003)
/// postProcess.add(chromatic)
/// ```
public final class ChromaticAberrationEffect: PostProcessEffect, @unchecked Sendable {
    deinit {}

    public let name = "chromaticAberration"
    public var isEnabled = true
    public var order: Int { 200 }

    /// Offset amount in UV space. Small values like 0.002-0.005 are typical.
    public var amount: Float

    private var shader: ShaderHandle = .invalid

    public init(amount: Float = 0.003) {
        self.amount = amount
    }

    public func initialize(renderer: any RenderBackend) {
        shader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: PostProcessShaders.chromaticAberrationFragment
        )
    }

    public func shutdown(renderer: any RenderBackend) {
        if shader != .invalid { renderer.destroyShader(shader) }
        shader = .invalid
    }

    public func apply(
        input: RenderTargetHandle,
        output: RenderTargetHandle,
        renderer: any RenderBackend,
        deltaTime _: Float
    ) {
        guard shader != .invalid else { return }

        renderer.setShaderFloat(shader, name: "amount", value: amount)

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
