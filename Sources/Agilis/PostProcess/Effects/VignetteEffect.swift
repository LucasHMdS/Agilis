/// Darkens the edges of the screen for a cinematic look.
///
/// ```swift
/// let vignette = VignetteEffect(intensity: 0.5, radius: 0.75)
/// postProcess.add(vignette)
/// ```
public final class VignetteEffect: PostProcessEffect, @unchecked Sendable {
    public let name = "vignette"
    public var isEnabled = true
    public var order: Int { 400 }

    /// How dark the edges get (0 = no effect, 1 = fully black).
    public var intensity: Float

    /// Distance from center where the vignette starts (0 = center, 1 = edges).
    public var radius: Float

    /// Width of the falloff transition.
    public var softness: Float

    private var shader: ShaderHandle = .invalid

    public init(
        intensity: Float = 0.5,
        radius: Float = 0.75,
        softness: Float = 0.45
    ) {
        self.intensity = intensity
        self.radius = radius
        self.softness = softness
    }

    public func initialize(renderer: any RenderBackend) {
        shader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: PostProcessShaders.vignetteFragment
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

        renderer.setShaderFloat(shader, name: "intensity", value: intensity)
        renderer.setShaderFloat(shader, name: "radius", value: radius)
        renderer.setShaderFloat(shader, name: "softness", value: softness)

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
