

/// Adjusts brightness, contrast, saturation, gamma, and color tint of the scene.
///
/// ```swift
/// let grading = ColorGradingEffect(contrast: 1.2, saturation: 0.8)
/// postProcess.add(grading)
/// ```
public final class ColorGradingEffect: PostProcessEffect, @unchecked Sendable {
    public let name = "colorGrading"
    public var isEnabled = true
    public var order: Int { 300 }

    /// Additive brightness (-1 to 1, default 0).
    public var brightness: Float

    /// Contrast multiplier (0-2, default 1). Values > 1 increase contrast.
    public var contrast: Float

    /// Saturation multiplier (0-2, default 1). 0 = grayscale, > 1 = oversaturated.
    public var saturation: Float

    /// Gamma correction (0.1-3, default 1). < 1 = brighter midtones, > 1 = darker.
    public var gamma: Float

    /// Color tint multiplied with the scene (default white = no tint).
    public var tint: Color

    private var shader: ShaderHandle = .invalid

    public init(
        brightness: Float = 0,
        contrast: Float = 1,
        saturation: Float = 1,
        gamma: Float = 1,
        tint: Color = .white
    ) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.gamma = gamma
        self.tint = tint
    }

    public func initialize(renderer: Renderer) {
        shader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: PostProcessShaders.colorGradingFragment
        )
    }

    public func shutdown(renderer: Renderer) {
        if shader != .invalid { renderer.destroyShader(shader) }
        shader = .invalid
    }

    public func apply(
        input: RenderTargetHandle,
        output: RenderTargetHandle,
        renderer: Renderer,
        deltaTime: Float
    ) {
        guard shader != .invalid else { return }

        renderer.setShaderFloat(shader, name: "brightness", value: brightness)
        renderer.setShaderFloat(shader, name: "contrast", value: contrast)
        renderer.setShaderFloat(shader, name: "saturation", value: saturation)
        renderer.setShaderFloat(shader, name: "gamma", value: gamma)
        renderer.setShaderVec3(shader, name: "tint",
            x: Float(tint.r) / 255.0,
            y: Float(tint.g) / 255.0,
            z: Float(tint.b) / 255.0)

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
