import Testing
import Foundation
@testable import Agilis

@Suite("MaterialTemplate")
struct MaterialTemplateTests {

    // MARK: - Creation

    @Test("Template stores name, shader, and defaults")
    func templateCreation() {
        let template = MaterialTemplate(
            name: "test",
            shader: ShaderHandle(id: 5),
            defaults: ["amount": .float(0.5)]
        )

        #expect(template.name == "test")
        #expect(template.shader == ShaderHandle(id: 5))
        #expect(template.defaults["amount"] == .float(0.5))
        #expect(template.blendMode == nil)
    }

    @Test("Template with blend mode")
    func templateWithBlendMode() {
        let template = MaterialTemplate(
            name: "glow",
            shader: ShaderHandle(id: 1),
            blendMode: .additive
        )

        #expect(template.blendMode == .additive)
    }

    // MARK: - Instance Creation

    @Test("Instance with default values")
    func instanceDefaults() {
        let template = MaterialTemplate(
            name: "test",
            shader: ShaderHandle(id: 5),
            defaults: [
                "amount": .float(0.5),
                "color": .color(.red),
            ]
        )

        let mat = template.instance()

        #expect(mat.shader == ShaderHandle(id: 5))
        #expect(mat.uniforms["amount"] == .float(0.5))
        #expect(mat.uniforms["color"] == .color(.red))
        #expect(mat.uniforms.count == 2)
    }

    @Test("Instance with overrides replaces matching defaults")
    func instanceOverrides() {
        let template = MaterialTemplate(
            name: "test",
            shader: ShaderHandle(id: 5),
            defaults: [
                "amount": .float(0.5),
                "speed": .float(1.0),
            ]
        )

        let mat = template.instance(overrides: ["amount": .float(0.9)])

        #expect(mat.uniforms["amount"] == .float(0.9))
        #expect(mat.uniforms["speed"] == .float(1.0)) // preserved
    }

    @Test("Instance with overrides can add new uniforms")
    func instanceOverridesAddNew() {
        let template = MaterialTemplate(
            name: "test",
            shader: ShaderHandle(id: 5),
            defaults: ["amount": .float(0.5)]
        )

        let mat = template.instance(overrides: ["extra": .float(42.0)])

        #expect(mat.uniforms["amount"] == .float(0.5))
        #expect(mat.uniforms["extra"] == .float(42.0))
        #expect(mat.uniforms.count == 2)
    }

    @Test("Instance inherits blend mode from template")
    func instanceBlendMode() {
        let template = MaterialTemplate(
            name: "glow",
            shader: ShaderHandle(id: 1),
            blendMode: .additive
        )

        let mat = template.instance()
        #expect(mat.blendMode == .additive)
    }

    @Test("Different instances from same template are independent")
    func instancesIndependent() {
        let template = MaterialTemplate(
            name: "test",
            shader: ShaderHandle(id: 5),
            defaults: ["amount": .float(0.5)]
        )

        var mat1 = template.instance()
        let mat2 = template.instance()

        mat1.uniforms["amount"] = .float(0.9)
        #expect(mat2.uniforms["amount"] == .float(0.5)) // unchanged
    }

    @Test("Instance from empty defaults creates empty uniforms")
    func instanceEmptyDefaults() {
        let template = MaterialTemplate(
            name: "test",
            shader: ShaderHandle(id: 5)
        )

        let mat = template.instance()
        #expect(mat.uniforms.isEmpty)
    }

    // MARK: - MaterialLibrary Templates

    @Test("MaterialLibrary provides templates for all built-in effects")
    func libraryTemplatesAllEffects() {
        // Create a mock renderer that returns valid shader handles
        let renderer = TemplateMockRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        for effect in MaterialLibrary.BuiltinEffect.allCases {
            let template = library.template(for: effect)
            #expect(template.name == effect.rawValue)
            #expect(template.shader != .invalid)
            #expect(!template.defaults.isEmpty)
        }
    }

    @Test("MaterialLibrary template shares shader with factory method")
    func templateSharesShader() {
        let renderer = TemplateMockRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let template = library.template(for: .flash)
        let factoryMat = library.flash()

        #expect(template.shader == factoryMat.shader)
    }

    @Test("MaterialLibrary template instance has correct defaults")
    func templateInstanceDefaults() {
        let renderer = TemplateMockRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let template = library.template(for: .dissolve)
        let mat = template.instance()

        #expect(mat.uniforms["threshold"] == .float(0.0))
        #expect(mat.uniforms["edgeWidth"] == .float(0.05))
        #expect(mat.uniforms["edgeColor"] == .color(.white))
    }

    @Test("MaterialLibrary context has sensible defaults")
    func libraryContextDefaults() {
        let library = MaterialLibrary()
        #expect(abs(library.context.time) < 0.001)
        #expect(library.context.resolution == .zero)
        #expect(abs(library.context.deltaTime) < 0.001)
    }

    @Test("BuiltinEffect enum has all 6 cases")
    func builtinEffectCases() {
        #expect(MaterialLibrary.BuiltinEffect.allCases.count == 6)
    }
}

// MARK: - MaterialContext Tests

@Suite("MaterialContext")
struct MaterialContextTests {

    @Test("MaterialContext default init")
    func defaultInit() {
        let ctx = MaterialContext()
        #expect(abs(ctx.time) < 0.001)
        #expect(ctx.resolution == .zero)
        #expect(abs(ctx.deltaTime) < 0.001)
    }

    @Test("MaterialContext custom init")
    func customInit() {
        let ctx = MaterialContext(
            time: 5.0,
            resolution: Vector2(x: 800, y: 600),
            deltaTime: 0.016
        )
        #expect(abs(ctx.time - 5.0) < 0.001)
        #expect(ctx.resolution == Vector2(x: 800, y: 600))
        #expect(abs(ctx.deltaTime - 0.016) < 0.001)
    }

    @Test("applyMaterial with context sets standard uniforms")
    func applyWithContext() {
        let renderer = ContextSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 5),
            uniforms: ["userParam": .float(42.0)]
        )
        let ctx = MaterialContext(
            time: 3.0,
            resolution: Vector2(x: 800, y: 600),
            deltaTime: 0.016
        )

        renderer.applyMaterial(mat, context: ctx)

        // Check standard uniforms were set
        let timeU = renderer.floatUniforms.first(where: { $0.name == "_time" })
        let dtU = renderer.floatUniforms.first(where: { $0.name == "_deltaTime" })
        let resU = renderer.vec2Uniforms.first(where: { $0.name == "_resolution" })
        let userU = renderer.floatUniforms.first(where: { $0.name == "userParam" })

        #expect(timeU != nil)
        #expect(abs(timeU!.value - 3.0) < 0.001)
        #expect(abs(dtU!.value - 0.016) < 0.001)
        #expect(resU != nil)
        #expect(resU!.value == Vector2(x: 800, y: 600))
        #expect(abs(userU!.value - 42.0) < 0.001)
    }

    @Test("applyMaterial with context applies user uniforms after standard ones")
    func contextOrderMatters() {
        let renderer = ContextSpyRenderer()
        // User uniform with same name as standard uniform
        let mat = Material2D(
            shader: ShaderHandle(id: 5),
            uniforms: ["_time": .float(999.0)]
        )
        let ctx = MaterialContext(time: 3.0)

        renderer.applyMaterial(mat, context: ctx)

        // Standard _time is set first (3.0), then user _time overrides (999.0)
        let timeUniforms = renderer.floatUniforms.filter { $0.name == "_time" }
        #expect(timeUniforms.count == 2)
        #expect(abs(timeUniforms[0].value - 3.0) < 0.001)   // standard
        #expect(abs(timeUniforms[1].value - 999.0) < 0.001)  // user override
    }
}

// MARK: - Mock Renderers

private final class TemplateMockRenderer: @unchecked Sendable, RenderBackend {
    var nextId: UInt32 = 1

    func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle {
        let id = nextId
        nextId += 1
        return ShaderHandle(id: id)
    }

    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func drawSprite(_ sprite: Sprite) {}
    func drawRect(_ rect: Rect, color: Color) {}
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {}
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {}
    func drawCircle(center: Vector2, radius: Float, color: Color) {}
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {}
    func loadDefaultFont() -> FontHandle { .invalid }
    func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
    func destroyFont(_ handle: FontHandle) {}
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {}
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size { .zero }
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    func destroyShader(_ handle: ShaderHandle) {}
    var screenSize: Size { .zero }
}

private final class ContextSpyRenderer: @unchecked Sendable, RenderBackend {
    var floatUniforms: [(shader: UInt32, name: String, value: Float)] = []
    var vec2Uniforms: [(shader: UInt32, name: String, value: Vector2)] = []

    func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float) {
        floatUniforms.append((handle.id, name, value))
    }

    func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2) {
        vec2Uniforms.append((handle.id, name, value))
    }

    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func drawSprite(_ sprite: Sprite) {}
    func drawRect(_ rect: Rect, color: Color) {}
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {}
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {}
    func drawCircle(center: Vector2, radius: Float, color: Color) {}
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {}
    func loadDefaultFont() -> FontHandle { .invalid }
    func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
    func destroyFont(_ handle: FontHandle) {}
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {}
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size { .zero }
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { .zero }
}
