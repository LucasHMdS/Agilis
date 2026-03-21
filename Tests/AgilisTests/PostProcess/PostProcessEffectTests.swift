@testable import Agilis
import Foundation
import Testing

/// A mock renderer for testing individual effects.
private final class EffectMockRenderer: @unchecked Sendable, RenderBackend {
    deinit {}

    var nextRTId: UInt32 = 100
    var nextShaderId: UInt32 = 1
    var loadedShaders: [UInt32] = []
    var destroyedShaders: [UInt32] = []
    var createdRTs: [UInt32] = []
    var destroyedRTs: [UInt32] = []
    var floatUniforms: [(shader: UInt32, name: String, value: Float)] = []
    var vec2Uniforms: [(shader: UInt32, name: String, value: Vector2)] = []
    var vec3Uniforms: [(shader: UInt32, name: String, x: Float, y: Float, z: Float)] = []
    var textureUniforms: [(shader: UInt32, name: String, texture: UInt32)] = []
    var shaderBegins: [UInt32] = []
    var shaderEnds: Int = 0
    var rtBegins: [UInt32] = []
    var rtEnds: Int = 0
    var spritesDrawn: [Sprite] = []
    var _screenSize = Size(width: 800, height: 600)

    func loadShader(vertexSource _: String?, fragmentSource _: String) -> ShaderHandle {
        let id = nextShaderId
        nextShaderId += 1
        loadedShaders.append(id)
        return ShaderHandle(id: id)
    }

    func destroyShader(_ handle: ShaderHandle) {
        destroyedShaders.append(handle.id)
    }

    func createRenderTarget(width _: Int, height _: Int) -> RenderTargetHandle {
        let id = nextRTId
        nextRTId += 1
        createdRTs.append(id)
        return RenderTargetHandle(id: id)
    }

    func destroyRenderTarget(_ handle: RenderTargetHandle) {
        destroyedRTs.append(handle.id)
    }

    func beginRenderTarget(_ handle: RenderTargetHandle) {
        rtBegins.append(handle.id)
    }

    func endRenderTarget() { rtEnds += 1 }

    func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle {
        TextureHandle(id: handle.id + 1_000)
    }

    func renderTargetSize(_: RenderTargetHandle) -> Size { _screenSize }
    func beginShader(_ handle: ShaderHandle) { shaderBegins.append(handle.id) }
    func endShader() { shaderEnds += 1 }
    func drawSprite(_ sprite: Sprite) { spritesDrawn.append(sprite) }

    func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float) {
        floatUniforms.append((handle.id, name, value))
    }

    func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2) {
        vec2Uniforms.append((handle.id, name, value))
    }

    func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float) {
        vec3Uniforms.append((handle.id, name, x, y, z))
    }

    func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle) {
        textureUniforms.append((handle.id, name, texture.id))
    }

    func setShaderVec4(_: ShaderHandle, name _: String, x _: Float, y _: Float, z _: Float, w _: Float) {}
    func setShaderInt(_: ShaderHandle, name _: String, value _: Int32) {}

    func initialize(config _: WindowConfig) {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_: Color) {}
    func loadTexture(from _: String) -> TextureHandle { .invalid }
    func textureSize(_: TextureHandle) -> Size { .zero }
    func destroyTexture(_: TextureHandle) {}
    func drawRect(_: Rect, color _: Color) {}
    func drawRectOutline(_: Rect, color _: Color, thickness _: Float) {}
    func drawLine(from _: Vector2, to _: Vector2, color _: Color, thickness _: Float) {}
    func drawCircle(center _: Vector2, radius _: Float, color _: Color) {}
    func drawCircleOutline(center _: Vector2, radius _: Float, color _: Color, thickness _: Float) {}
    func loadDefaultFont() -> FontHandle { .invalid }
    func loadFont(from _: String, size _: Int) -> FontHandle { .invalid }
    func destroyFont(_: FontHandle) {}
    func drawText(_: String, position _: Vector2, font _: FontHandle, size _: Float, color _: Color) {}
    func measureText(_: String, font _: FontHandle, size _: Float) -> Size { .zero }
    func beginClip(_: Rect) {}
    func endClip() {}
    func beginCamera(_: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { _screenSize }
}

@Suite("PostProcessEffects")
struct PostProcessEffectTests {

    // MARK: - Vignette

    @Test("VignetteEffect has correct defaults")
    func vignetteDefaults() {
        let vignette = VignetteEffect()
        #expect(vignette.name == "vignette")
        #expect(vignette.isEnabled)
        #expect(vignette.order == 400)
        #expect(abs(vignette.intensity - 0.5) < 0.001)
        #expect(abs(vignette.radius - 0.75) < 0.001)
        #expect(abs(vignette.softness - 0.45) < 0.001)
    }

    @Test("VignetteEffect custom init")
    func vignetteCustom() {
        let vignette = VignetteEffect(intensity: 0.8, radius: 0.5, softness: 0.3)
        #expect(abs(vignette.intensity - 0.8) < 0.001)
        #expect(abs(vignette.radius - 0.5) < 0.001)
        #expect(abs(vignette.softness - 0.3) < 0.001)
    }

    @Test("VignetteEffect loads shader on init")
    func vignetteShaderLoad() {
        let renderer = EffectMockRenderer()
        let vignette = VignetteEffect()
        vignette.initialize(renderer: renderer)

        #expect(renderer.loadedShaders.count == 1)
    }

    @Test("VignetteEffect destroys shader on shutdown")
    func vignetteShutdown() {
        let renderer = EffectMockRenderer()
        let vignette = VignetteEffect()
        vignette.initialize(renderer: renderer)
        vignette.shutdown(renderer: renderer)

        #expect(renderer.destroyedShaders.count == 1)
    }

    @Test("VignetteEffect sets uniforms on apply")
    func vignetteApplyUniforms() {
        let renderer = EffectMockRenderer()
        let vignette = VignetteEffect(intensity: 0.7, radius: 0.6, softness: 0.4)
        vignette.initialize(renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        vignette.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        let intensityU = renderer.floatUniforms.first(where: { $0.name == "intensity" })
        let radiusU = renderer.floatUniforms.first(where: { $0.name == "radius" })
        let softnessU = renderer.floatUniforms.first(where: { $0.name == "softness" })
        #expect(intensityU != nil)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(intensityU!.value - 0.7) < 0.001)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(radiusU!.value - 0.6) < 0.001)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(softnessU!.value - 0.4) < 0.001)
    }

    // MARK: - Chromatic Aberration

    @Test("ChromaticAberrationEffect has correct defaults")
    func chromaticDefaults() {
        let effect = ChromaticAberrationEffect()
        #expect(effect.name == "chromaticAberration")
        #expect(effect.isEnabled)
        #expect(effect.order == 200)
        #expect(abs(effect.amount - 0.003) < 0.0001)
    }

    @Test("ChromaticAberrationEffect sets uniform on apply")
    func chromaticApply() {
        let renderer = EffectMockRenderer()
        let effect = ChromaticAberrationEffect(amount: 0.005)
        effect.initialize(renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        let amountU = renderer.floatUniforms.first(where: { $0.name == "amount" })
        #expect(amountU != nil)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(amountU!.value - 0.005) < 0.0001)
    }

    // MARK: - Color Grading

    @Test("ColorGradingEffect has correct defaults")
    func colorGradingDefaults() {
        let effect = ColorGradingEffect()
        #expect(effect.name == "colorGrading")
        #expect(effect.isEnabled)
        #expect(effect.order == 300)
        #expect(abs(effect.brightness) < 0.001)
        #expect(abs(effect.contrast - 1.0) < 0.001)
        #expect(abs(effect.saturation - 1.0) < 0.001)
        #expect(abs(effect.gamma - 1.0) < 0.001)
    }

    @Test("ColorGradingEffect sets all uniforms")
    func colorGradingApply() {
        let renderer = EffectMockRenderer()
        let effect = ColorGradingEffect(
            brightness: 0.1,
            contrast: 1.5,
            saturation: 0.8,
            gamma: 1.2,
            tint: .red
        )
        effect.initialize(renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        let brightnessU = renderer.floatUniforms.first(where: { $0.name == "brightness" })
        let contrastU = renderer.floatUniforms.first(where: { $0.name == "contrast" })
        let saturationU = renderer.floatUniforms.first(where: { $0.name == "saturation" })
        let gammaU = renderer.floatUniforms.first(where: { $0.name == "gamma" })
        let tintU = renderer.vec3Uniforms.first(where: { $0.name == "tint" })

        // swiftlint:disable:next force_unwrapping
        #expect(abs(brightnessU!.value - 0.1) < 0.001)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(contrastU!.value - 1.5) < 0.001)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(saturationU!.value - 0.8) < 0.001)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(gammaU!.value - 1.2) < 0.001)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(tintU!.x - 1.0) < 0.01) // red = 255/255
    }

    // MARK: - Scanlines

    @Test("ScanlinesEffect has correct defaults")
    func scanlinesDefaults() {
        let effect = ScanlinesEffect()
        #expect(effect.name == "scanlines")
        #expect(effect.isEnabled)
        #expect(effect.order == 500)
        #expect(abs(effect.lineSpacing - 2.0) < 0.001)
        #expect(abs(effect.lineIntensity - 0.15) < 0.001)
        #expect(abs(effect.curvature) < 0.001)
    }

    @Test("ScanlinesEffect tracks screen size from resize")
    func scanlinesResize() {
        let renderer = EffectMockRenderer()
        let effect = ScanlinesEffect()
        effect.initialize(renderer: renderer)
        effect.resize(width: 1_920, height: 1_080, renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        let resU = renderer.vec2Uniforms.first(where: { $0.name == "resolution" })
        #expect(resU != nil)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(resU!.value.x - 1_920) < 0.1)
        // swiftlint:disable:next force_unwrapping
        #expect(abs(resU!.value.y - 1_080) < 0.1)
    }

    // MARK: - Pixelate

    @Test("PixelateEffect has correct defaults")
    func pixelateDefaults() {
        let effect = PixelateEffect()
        #expect(effect.name == "pixelate")
        #expect(effect.isEnabled)
        #expect(effect.order == 600)
        #expect(abs(effect.pixelSize - 4.0) < 0.001)
    }

    @Test("PixelateEffect sets uniforms on apply")
    func pixelateApply() {
        let renderer = EffectMockRenderer()
        let effect = PixelateEffect(pixelSize: 8.0)
        effect.initialize(renderer: renderer)
        effect.resize(width: 800, height: 600, renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        let pixelU = renderer.floatUniforms.first(where: { $0.name == "pixelSize" })
        // swiftlint:disable:next force_unwrapping
        #expect(abs(pixelU!.value - 8.0) < 0.001)
    }

    // MARK: - Bloom

    @Test("BloomEffect has correct defaults")
    func bloomDefaults() {
        let effect = BloomEffect()
        #expect(effect.name == "bloom")
        #expect(effect.isEnabled)
        #expect(effect.order == 100)
        #expect(abs(effect.threshold - 0.8) < 0.001)
        #expect(abs(effect.intensity - 1.0) < 0.001)
    }

    @Test("BloomEffect loads two shaders")
    func bloomShaderLoad() {
        let renderer = EffectMockRenderer()
        let effect = BloomEffect()
        effect.initialize(renderer: renderer)

        #expect(renderer.loadedShaders.count == 2)
    }

    @Test("BloomEffect creates intermediate RT on resize")
    func bloomResize() {
        let renderer = EffectMockRenderer()
        let effect = BloomEffect()
        effect.initialize(renderer: renderer)
        effect.resize(width: 800, height: 600, renderer: renderer)

        #expect(renderer.createdRTs.count == 1)
    }

    @Test("BloomEffect destroys all resources on shutdown")
    func bloomShutdown() {
        let renderer = EffectMockRenderer()
        let effect = BloomEffect()
        effect.initialize(renderer: renderer)
        effect.resize(width: 800, height: 600, renderer: renderer)
        effect.shutdown(renderer: renderer)

        #expect(renderer.destroyedShaders.count == 2)
        #expect(renderer.destroyedRTs.count == 1)
    }

    @Test("BloomEffect uses two render passes")
    func bloomTwoPasses() {
        let renderer = EffectMockRenderer()
        let effect = BloomEffect()
        effect.initialize(renderer: renderer)
        effect.resize(width: 800, height: 600, renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        // Two passes: extract→intermediate, composite→output
        #expect(renderer.rtBegins.count == 2)
        #expect(renderer.rtEnds == 2)
        #expect(renderer.shaderBegins.count == 2)
        #expect(renderer.shaderEnds == 2)
        #expect(renderer.spritesDrawn.count == 2)
    }

    @Test("BloomEffect sets sceneTexture uniform for composite pass")
    func bloomSceneTexture() {
        let renderer = EffectMockRenderer()
        let effect = BloomEffect()
        effect.initialize(renderer: renderer)
        effect.resize(width: 800, height: 600, renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        let sceneTexU = renderer.textureUniforms.first(where: { $0.name == "sceneTexture" })
        #expect(sceneTexU != nil)
    }

    // MARK: - General Pattern

    @Test("All effects draw a fullscreen sprite with flipY")
    func allEffectsFlipY() {
        let renderer = EffectMockRenderer()
        let effects: [any PostProcessEffect] = [
            VignetteEffect(),
            ChromaticAberrationEffect(),
            ColorGradingEffect(),
            PixelateEffect()
        ]

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)

        for effect in effects {
            effect.initialize(renderer: renderer)
            effect.resize(width: 800, height: 600, renderer: renderer)
            effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)
        }

        // Each single-pass effect draws 1 sprite; all should have flipY
        for sprite in renderer.spritesDrawn {
            #expect(sprite.flipY, "Effect sprite should be Y-flipped for RT rendering")
        }
    }

    @Test("All effects write to the output render target")
    func allEffectsWriteToOutput() {
        let renderer = EffectMockRenderer()
        let effect = VignetteEffect()
        effect.initialize(renderer: renderer)

        let input = RenderTargetHandle(id: 10)
        let output = RenderTargetHandle(id: 20)
        effect.apply(input: input, output: output, renderer: renderer, deltaTime: 0.016)

        // The output RT should be the one begun
        #expect(renderer.rtBegins.contains(output.id))
        #expect(!renderer.rtBegins.contains(input.id))
    }
}
