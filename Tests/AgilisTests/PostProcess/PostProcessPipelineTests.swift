@testable import Agilis
import Foundation
import Testing

/// A mock renderer that tracks render target and shader operations for pipeline testing.
private final class PipelineMockRenderer: @unchecked Sendable, RenderBackend {
    deinit {}

    var nextRTId: UInt32 = 1
    var createdRTs: [UInt32] = []
    var destroyedRTs: [UInt32] = []
    var rtBegins: [UInt32] = []
    var rtEnds: Int = 0
    var nextShaderId: UInt32 = 1
    var loadedShaders: [UInt32] = []
    var destroyedShaders: [UInt32] = []
    var shaderBegins: [UInt32] = []
    var shaderEnds: Int = 0
    var spritesDrawn: [Sprite] = []
    var floatUniforms: [(shader: UInt32, name: String, value: Float)] = []
    var vec2Uniforms: [(shader: UInt32, name: String, value: Vector2)] = []
    var _screenSize = Size(width: 800, height: 600)

    func createRenderTarget(width _: Int, height _: Int) -> RenderTargetHandle {
        let id = nextRTId
        nextRTId += 1
        createdRTs.append(id)
        return RenderTargetHandle(id: id)
    }

    func beginRenderTarget(_ handle: RenderTargetHandle) {
        rtBegins.append(handle.id)
    }

    func endRenderTarget() {
        rtEnds += 1
    }

    func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle {
        TextureHandle(id: handle.id + 100)
    }

    func renderTargetSize(_: RenderTargetHandle) -> Size {
        _screenSize
    }

    func destroyRenderTarget(_ handle: RenderTargetHandle) {
        destroyedRTs.append(handle.id)
    }

    func loadShader(vertexSource _: String?, fragmentSource _: String) -> ShaderHandle {
        let id = nextShaderId
        nextShaderId += 1
        loadedShaders.append(id)
        return ShaderHandle(id: id)
    }

    func beginShader(_ handle: ShaderHandle) {
        shaderBegins.append(handle.id)
    }

    func endShader() {
        shaderEnds += 1
    }

    func destroyShader(_ handle: ShaderHandle) {
        destroyedShaders.append(handle.id)
    }

    func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float) {
        floatUniforms.append((handle.id, name, value))
    }

    func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2) {
        vec2Uniforms.append((handle.id, name, value))
    }

    func drawSprite(_ sprite: Sprite) {
        spritesDrawn.append(sprite)
    }

    // Stub remaining Renderer methods
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
    func setShaderVec3(_: ShaderHandle, name _: String, x _: Float, y _: Float, z _: Float) {}
    func setShaderVec4(_: ShaderHandle, name _: String, x _: Float, y _: Float, z _: Float, w _: Float) {}
    func setShaderInt(_: ShaderHandle, name _: String, value _: Int32) {}
    func setShaderTexture(_: ShaderHandle, name _: String, texture _: TextureHandle) {}
    var screenSize: Size { _screenSize }
}

/// A minimal test effect that records its lifecycle calls.
private final class SpyEffect: PostProcessEffect, @unchecked Sendable {
    deinit {}

    let name: String
    var isEnabled: Bool = true
    let order: Int

    var initialized = false
    var shutdownCalled = false
    var resizeCount = 0
    var lastResizeWidth = 0
    var lastResizeHeight = 0
    var applyCount = 0
    var lastDeltaTime: Float = 0

    private var shader: ShaderHandle = .invalid

    init(name: String, order: Int = 0) {
        self.name = name
        self.order = order
    }

    func initialize(renderer: any RenderBackend) {
        initialized = true
        shader = renderer.loadShader(vertexSource: nil, fragmentSource: "// test")
    }

    func shutdown(renderer: any RenderBackend) {
        shutdownCalled = true
        if shader != .invalid { renderer.destroyShader(shader) }
        shader = .invalid
    }

    func resize(width: Int, height: Int, renderer _: any RenderBackend) {
        resizeCount += 1
        lastResizeWidth = width
        lastResizeHeight = height
    }

    func apply(
        input: RenderTargetHandle,
        output: RenderTargetHandle,
        renderer: any RenderBackend,
        deltaTime: Float
    ) {
        applyCount += 1
        lastDeltaTime = deltaTime

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

@Suite("PostProcessPipeline")
struct PostProcessPipelineTests {

    // MARK: - Lifecycle

    @Test("Pipeline starts uninitialized")
    func startsUninitialized() {
        let pipeline = PostProcessPipeline()
        #expect(!pipeline.isInitialized)
        #expect(pipeline.effectCount == 0)
    }

    @Test("Pipeline initializes render targets")
    func initializeCreatesRTs() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        pipeline.initialize(renderer: renderer)

        #expect(pipeline.isInitialized)
        // 3 render targets: scene, ping, pong
        #expect(renderer.createdRTs.count == 3)
    }

    @Test("Pipeline shutdown destroys render targets")
    func shutdownDestroysRTs() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        pipeline.initialize(renderer: renderer)
        pipeline.shutdown(renderer: renderer)

        #expect(!pipeline.isInitialized)
        #expect(renderer.destroyedRTs.count == 3)
    }

    @Test("Pipeline initializes effects on init")
    func initializesEffects() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "test")
        pipeline.add(effect)

        #expect(!effect.initialized)
        pipeline.initialize(renderer: renderer)
        #expect(effect.initialized)
        #expect(effect.resizeCount == 1)
    }

    @Test("Pipeline shuts down effects on shutdown")
    func shutsDownEffects() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "test")
        pipeline.add(effect)
        pipeline.initialize(renderer: renderer)
        pipeline.shutdown(renderer: renderer)

        #expect(effect.shutdownCalled)
    }

    @Test("Double initialize is no-op")
    func doubleInit() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        pipeline.initialize(renderer: renderer)
        pipeline.initialize(renderer: renderer)

        #expect(renderer.createdRTs.count == 3)
    }

    // MARK: - Effect Management

    @Test("Effects sorted by order")
    func effectSorting() {
        let pipeline = PostProcessPipeline()
        let effectC = SpyEffect(name: "c", order: 300)
        let effectA = SpyEffect(name: "a", order: 100)
        let effectB = SpyEffect(name: "b", order: 200)

        pipeline.add(effectC)
        pipeline.add(effectA)
        pipeline.add(effectB)

        let names = pipeline.allEffects.map { $0.name }
        #expect(names == ["a", "b", "c"])
    }

    @Test("Effect retrieval by type")
    func retrieveByType() {
        let pipeline = PostProcessPipeline()
        let vignette = VignetteEffect(intensity: 0.7)
        pipeline.add(vignette)

        let retrieved = pipeline.effect(ofType: VignetteEffect.self)
        #expect(retrieved != nil)
        #expect(retrieved?.intensity == 0.7)
    }

    @Test("Effect retrieval by name")
    func retrieveByName() {
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "myEffect")
        pipeline.add(effect)

        let retrieved = pipeline.effect(named: "myEffect")
        #expect(retrieved != nil)
        #expect(retrieved?.name == "myEffect")
    }

    @Test("Remove effect by name")
    func removeByName() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "removable")
        pipeline.add(effect)
        pipeline.initialize(renderer: renderer)

        let removed = pipeline.remove(named: "removable")
        #expect(removed)
        #expect(pipeline.effectCount == 0)
        #expect(effect.shutdownCalled)
    }

    @Test("Remove nonexistent effect returns false")
    func removeNonexistent() {
        let pipeline = PostProcessPipeline()
        let removed = pipeline.remove(named: "nope")
        #expect(!removed)
    }

    @Test("Late-added effects are initialized when pipeline is already initialized")
    func lateAddEffect() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        pipeline.initialize(renderer: renderer)

        let effect = SpyEffect(name: "late")
        pipeline.add(effect)

        #expect(effect.initialized)
        #expect(effect.resizeCount == 1)
    }

    // MARK: - Rendering

    @Test("Empty pipeline draws scene directly")
    func emptyPipeline() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        pipeline.initialize(renderer: renderer)

        pipeline.beginCapture(renderer: renderer)
        // Draw something...
        pipeline.endCaptureAndApply(renderer: renderer, deltaTime: 0.016)

        // Should draw scene RT to screen (1 sprite for the fullscreen blit)
        #expect(renderer.spritesDrawn.count == 1)
        // No shaders activated (no effects)
        #expect(renderer.shaderBegins.isEmpty)
    }

    @Test("Disabled effects are skipped")
    func disabledEffects() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "disabled")
        effect.isEnabled = false
        pipeline.add(effect)
        pipeline.initialize(renderer: renderer)

        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer, deltaTime: 0.016)

        #expect(effect.applyCount == 0)
        // Should still draw scene directly (no enabled effects)
        #expect(renderer.spritesDrawn.count == 1)
    }

    @Test("Single enabled effect is applied")
    func singleEffect() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "test")
        pipeline.add(effect)
        pipeline.initialize(renderer: renderer)

        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer, deltaTime: 0.016)

        #expect(effect.applyCount == 1)
        #expect(abs(effect.lastDeltaTime - 0.016) < 0.001)
    }

    @Test("Multiple effects are applied in order")
    func multipleEffects() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effectA = SpyEffect(name: "a", order: 100)
        let effectB = SpyEffect(name: "b", order: 200)
        let effectC = SpyEffect(name: "c", order: 300)
        pipeline.add(effectC)
        pipeline.add(effectA)
        pipeline.add(effectB)
        pipeline.initialize(renderer: renderer)

        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer, deltaTime: 0.016)

        #expect(effectA.applyCount == 1)
        #expect(effectB.applyCount == 1)
        #expect(effectC.applyCount == 1)
    }

    @Test("BeginCapture redirects to render target")
    func beginCaptureRedirects() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        pipeline.initialize(renderer: renderer)

        pipeline.beginCapture(renderer: renderer)

        // Should have begun a render target
        #expect(renderer.rtBegins.count == 1)
    }

    @Test("Screen resize recreates render targets")
    func screenResize() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "test")
        pipeline.add(effect)
        pipeline.initialize(renderer: renderer)

        // Change screen size
        renderer._screenSize = Size(width: 1_024, height: 768)

        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer)

        // Old RTs destroyed (3) + new RTs created (3)
        #expect(renderer.destroyedRTs.count == 3)
        #expect(renderer.createdRTs.count == 6) // 3 initial + 3 recreated

        // Effect should have been resized
        #expect(effect.resizeCount == 2) // once on init, once on resize
        #expect(effect.lastResizeWidth == 1_024)
        #expect(effect.lastResizeHeight == 768)
    }

    @Test("Uninitialized pipeline operations are no-ops")
    func uninitializedNoOps() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()

        // These should not crash
        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer)

        #expect(renderer.rtBegins.isEmpty)
        #expect(renderer.spritesDrawn.isEmpty)
    }

    @Test("Effects can be toggled at runtime")
    func runtimeToggle() {
        let renderer = PipelineMockRenderer()
        let pipeline = PostProcessPipeline()
        let effect = SpyEffect(name: "toggleable")
        pipeline.add(effect)
        pipeline.initialize(renderer: renderer)

        // Frame 1: enabled
        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer)
        #expect(effect.applyCount == 1)

        // Disable
        effect.isEnabled = false

        // Frame 2: disabled
        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer)
        #expect(effect.applyCount == 1) // unchanged

        // Re-enable
        effect.isEnabled = true

        // Frame 3: enabled again
        pipeline.beginCapture(renderer: renderer)
        pipeline.endCaptureAndApply(renderer: renderer)
        #expect(effect.applyCount == 2)
    }
}
