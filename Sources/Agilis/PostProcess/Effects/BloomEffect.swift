

/// Glow effect that extracts bright pixels, blurs them, and adds them back.
///
/// Uses a two-pass approach:
/// 1. Extract bright pixels + horizontal Gaussian blur
/// 2. Vertical Gaussian blur + additive composite with original scene
///
/// ```swift
/// let bloom = BloomEffect(threshold: 0.7, intensity: 1.2)
/// postProcess.add(bloom)
/// ```
public final class BloomEffect: PostProcessEffect, @unchecked Sendable {
    public let name = "bloom"
    public var isEnabled = true
    public var order: Int { 100 }

    /// Brightness threshold for pixel extraction (0-1, default 0.8).
    /// Only pixels brighter than this contribute to the bloom.
    public var threshold: Float

    /// Bloom strength multiplier (default 1.0). Higher = more glow.
    public var intensity: Float

    private var extractShader: ShaderHandle = .invalid
    private var compositeShader: ShaderHandle = .invalid
    private var intermediateRT: RenderTargetHandle = .invalid
    private var currentWidth: Int = 0
    private var currentHeight: Int = 0

    public init(
        threshold: Float = 0.8,
        intensity: Float = 1.0
    ) {
        self.threshold = threshold
        self.intensity = intensity
    }

    public func initialize(renderer: any RenderBackend) {
        extractShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: PostProcessShaders.bloomExtractFragment
        )
        compositeShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: PostProcessShaders.bloomCompositeFragment
        )
    }

    public func shutdown(renderer: any RenderBackend) {
        if extractShader != .invalid { renderer.destroyShader(extractShader) }
        if compositeShader != .invalid { renderer.destroyShader(compositeShader) }
        if intermediateRT != .invalid { renderer.destroyRenderTarget(intermediateRT) }
        extractShader = .invalid
        compositeShader = .invalid
        intermediateRT = .invalid
    }

    public func resize(width: Int, height: Int, renderer: any RenderBackend) {
        currentWidth = width
        currentHeight = height

        // Recreate intermediate RT at new size
        if intermediateRT != .invalid {
            renderer.destroyRenderTarget(intermediateRT)
        }
        intermediateRT = renderer.createRenderTarget(width: width, height: height)
    }

    public func apply(
        input: RenderTargetHandle,
        output: RenderTargetHandle,
        renderer: any RenderBackend,
        deltaTime: Float
    ) {
        guard extractShader != .invalid,
              compositeShader != .invalid,
              intermediateRT != .invalid else { return }

        let resolution = Vector2(x: Float(currentWidth), y: Float(currentHeight))
        let inputTexture = renderer.renderTargetTexture(input)
        let inputSize = renderer.renderTargetSize(input)

        // Pass 1: Extract bright pixels + horizontal blur → intermediateRT
        renderer.setShaderFloat(extractShader, name: "threshold", value: threshold)
        renderer.setShaderVec2(extractShader, name: "resolution", value: resolution)

        renderer.beginRenderTarget(intermediateRT)
        renderer.beginShader(extractShader)
        renderer.drawSprite(Sprite(
            texture: inputTexture,
            sourceRect: Rect(x: 0, y: 0, width: inputSize.width, height: inputSize.height),
            tint: .white,
            flipY: true
        ))
        renderer.endShader()
        renderer.endRenderTarget()

        // Pass 2: Vertical blur + composite with original scene → output
        let intermediateTexture = renderer.renderTargetTexture(intermediateRT)
        let intermediateSize = renderer.renderTargetSize(intermediateRT)

        renderer.setShaderFloat(compositeShader, name: "intensity", value: intensity)
        renderer.setShaderVec2(compositeShader, name: "resolution", value: resolution)
        renderer.setShaderTexture(compositeShader, name: "sceneTexture", texture: inputTexture)

        renderer.beginRenderTarget(output)
        renderer.beginShader(compositeShader)
        renderer.drawSprite(Sprite(
            texture: intermediateTexture,
            sourceRect: Rect(x: 0, y: 0, width: intermediateSize.width, height: intermediateSize.height),
            tint: .white,
            flipY: true
        ))
        renderer.endShader()
        renderer.endRenderTarget()
    }
}
