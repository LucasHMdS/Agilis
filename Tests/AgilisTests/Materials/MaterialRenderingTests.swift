import Testing
import Foundation
@testable import Agilis

/// A mock renderer that records uniform set calls for verifying applyMaterial behavior.
private final class UniformSpyRenderer: @unchecked Sendable, RenderBackend {
    var floatUniforms: [(shader: UInt32, name: String, value: Float)] = []
    var vec2Uniforms: [(shader: UInt32, name: String, value: Vector2)] = []
    var vec3Uniforms: [(shader: UInt32, name: String, x: Float, y: Float, z: Float)] = []
    var vec4Uniforms: [(shader: UInt32, name: String, x: Float, y: Float, z: Float, w: Float)] = []
    var intUniforms: [(shader: UInt32, name: String, value: Int32)] = []
    var textureUniforms: [(shader: UInt32, name: String, texture: UInt32)] = []
    var shaderBegins: [UInt32] = []
    var shaderEnds: Int = 0
    var spritesDrawn: [Sprite] = []

    func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float) {
        floatUniforms.append((handle.id, name, value))
    }

    func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2) {
        vec2Uniforms.append((handle.id, name, value))
    }

    func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float) {
        vec3Uniforms.append((handle.id, name, x, y, z))
    }

    func setShaderVec4(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float, w: Float) {
        vec4Uniforms.append((handle.id, name, x, y, z, w))
    }

    func setShaderInt(_ handle: ShaderHandle, name: String, value: Int32) {
        intUniforms.append((handle.id, name, value))
    }

    func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle) {
        textureUniforms.append((handle.id, name, texture.id))
    }

    func beginShader(_ handle: ShaderHandle) {
        shaderBegins.append(handle.id)
    }

    func endShader() {
        shaderEnds += 1
    }

    func drawSprite(_ sprite: Sprite) {
        spritesDrawn.append(sprite)
    }

    // Stub all other required Renderer methods
    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
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

@Suite("MaterialRendering")
struct MaterialRenderingTests {

    // MARK: - applyMaterial

    @Test("applyMaterial dispatches float uniform")
    func applyFloat() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 5),
            uniforms: ["time": .float(3.14)]
        )

        renderer.applyMaterial(mat)

        #expect(renderer.floatUniforms.count == 1)
        #expect(renderer.floatUniforms[0].shader == 5)
        #expect(renderer.floatUniforms[0].name == "time")
        #expect(abs(renderer.floatUniforms[0].value - 3.14) < 0.001)
    }

    @Test("applyMaterial dispatches vec2 uniform")
    func applyVec2() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["offset": .vec2(Vector2(x: 10, y: 20))]
        )

        renderer.applyMaterial(mat)

        #expect(renderer.vec2Uniforms.count == 1)
        #expect(renderer.vec2Uniforms[0].name == "offset")
        #expect(renderer.vec2Uniforms[0].value == Vector2(x: 10, y: 20))
    }

    @Test("applyMaterial dispatches vec3 uniform")
    func applyVec3() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["rgb": .vec3(x: 0.1, y: 0.2, z: 0.3)]
        )

        renderer.applyMaterial(mat)

        #expect(renderer.vec3Uniforms.count == 1)
        #expect(renderer.vec3Uniforms[0].name == "rgb")
        #expect(abs(renderer.vec3Uniforms[0].x - 0.1) < 0.001)
        #expect(abs(renderer.vec3Uniforms[0].y - 0.2) < 0.001)
        #expect(abs(renderer.vec3Uniforms[0].z - 0.3) < 0.001)
    }

    @Test("applyMaterial dispatches vec4 uniform")
    func applyVec4() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["rgba": .vec4(x: 0.1, y: 0.2, z: 0.3, w: 0.4)]
        )

        renderer.applyMaterial(mat)

        #expect(renderer.vec4Uniforms.count == 1)
        #expect(renderer.vec4Uniforms[0].name == "rgba")
    }

    @Test("applyMaterial dispatches int uniform")
    func applyInt() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["count": .int(42)]
        )

        renderer.applyMaterial(mat)

        #expect(renderer.intUniforms.count == 1)
        #expect(renderer.intUniforms[0].name == "count")
        #expect(renderer.intUniforms[0].value == 42)
    }

    @Test("applyMaterial converts color to normalized vec4")
    func applyColor() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["tint": .color(Color(r: 255, g: 128, b: 0, a: 200))]
        )

        renderer.applyMaterial(mat)

        // Color should be dispatched as vec4 with normalized values
        #expect(renderer.vec4Uniforms.count == 1)
        #expect(renderer.vec4Uniforms[0].name == "tint")
        #expect(abs(renderer.vec4Uniforms[0].x - 1.0) < 0.01)      // 255/255
        #expect(abs(renderer.vec4Uniforms[0].y - 0.502) < 0.01)    // 128/255
        #expect(abs(renderer.vec4Uniforms[0].z - 0.0) < 0.01)      // 0/255
        #expect(abs(renderer.vec4Uniforms[0].w - 0.784) < 0.01)    // 200/255
    }

    @Test("applyMaterial dispatches texture uniform")
    func applyTexture() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["noiseMap": .texture(TextureHandle(id: 7))]
        )

        renderer.applyMaterial(mat)

        #expect(renderer.textureUniforms.count == 1)
        #expect(renderer.textureUniforms[0].name == "noiseMap")
        #expect(renderer.textureUniforms[0].texture == 7)
    }

    @Test("applyMaterial dispatches multiple uniforms")
    func applyMultiple() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: [
                "time": .float(1.5),
                "offset": .vec2(Vector2(x: 10, y: 20)),
                "count": .int(5),
            ]
        )

        renderer.applyMaterial(mat)

        #expect(renderer.floatUniforms.count == 1)
        #expect(renderer.vec2Uniforms.count == 1)
        #expect(renderer.intUniforms.count == 1)
    }

    @Test("applyMaterial with empty uniforms does nothing")
    func applyEmpty() {
        let renderer = UniformSpyRenderer()
        let mat = Material2D(shader: ShaderHandle(id: 1))

        renderer.applyMaterial(mat)

        #expect(renderer.floatUniforms.isEmpty)
        #expect(renderer.vec2Uniforms.isEmpty)
        #expect(renderer.vec3Uniforms.isEmpty)
        #expect(renderer.vec4Uniforms.isEmpty)
        #expect(renderer.intUniforms.isEmpty)
        #expect(renderer.textureUniforms.isEmpty)
    }

    // MARK: - SpriteBatch Material Sorting

    @Test("SpriteBatch groups sprites by material shader")
    func batchMaterialSorting() {
        let renderer = UniformSpyRenderer()

        let shader1 = ShaderHandle(id: 1)
        let shader2 = ShaderHandle(id: 2)

        var spriteA = Sprite(texture: TextureHandle(id: 10))
        spriteA.material = Material2D(shader: shader2)

        var spriteB = Sprite(texture: TextureHandle(id: 10))
        spriteB.material = Material2D(shader: shader1)

        var spriteC = Sprite(texture: TextureHandle(id: 10))
        spriteC.material = Material2D(shader: shader2)

        let batch = SpriteBatch(sortMode: .byTexture)
        batch.add(spriteA)  // shader 2
        batch.add(spriteB)  // shader 1
        batch.add(spriteC)  // shader 2

        batch.flush(to: renderer)

        // After sorting by material, shader 1 should come before shader 2
        // (lower sortKey first), so spriteB should be drawn first
        #expect(batch.lastSpriteCount == 3)
        // Two state change groups: shader1 group, shader2 group
        #expect(batch.lastDrawCallCount == 2)
    }

    @Test("SpriteBatch sorts no-material sprites before material sprites")
    func batchNoMaterialFirst() {
        let renderer = UniformSpyRenderer()

        var spriteWithMat = Sprite(texture: TextureHandle(id: 10))
        spriteWithMat.material = Material2D(shader: ShaderHandle(id: 5))

        let spriteWithout = Sprite(texture: TextureHandle(id: 10))

        let batch = SpriteBatch(sortMode: .byTexture)
        batch.add(spriteWithMat)  // material with sortKey 5
        batch.add(spriteWithout)   // no material, sortKey 0

        batch.flush(to: renderer)

        // sortKey 0 (no material) should sort before sortKey 5
        #expect(batch.lastDrawCallCount == 2)
    }
}
