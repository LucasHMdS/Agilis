@testable import Agilis
import Foundation
import Testing

@Suite("Material2D")
struct Material2DTests {

    // MARK: - UniformValue

    @Test("UniformValue float stores value")
    func uniformFloat() {
        let value = UniformValue.float(3.14)
        #expect(value == .float(3.14))
    }

    @Test("UniformValue vec2 stores vector")
    func uniformVec2() {
        let value = UniformValue.vec2(Vector2(x: 1.0, y: 2.0))
        #expect(value == .vec2(Vector2(x: 1.0, y: 2.0)))
    }

    @Test("UniformValue vec3 stores components")
    func uniformVec3() {
        let value = UniformValue.vec3(x: 1.0, y: 2.0, z: 3.0)
        #expect(value == .vec3(x: 1.0, y: 2.0, z: 3.0))
    }

    @Test("UniformValue vec4 stores components")
    func uniformVec4() {
        let value = UniformValue.vec4(x: 1.0, y: 2.0, z: 3.0, w: 4.0)
        #expect(value == .vec4(x: 1.0, y: 2.0, z: 3.0, w: 4.0))
    }

    @Test("UniformValue int stores value")
    func uniformInt() {
        let value = UniformValue.int(42)
        #expect(value == .int(42))
    }

    @Test("UniformValue color stores RGBA")
    func uniformColor() {
        let color = Color(r: 255, g: 128, b: 64, a: 200)
        let value = UniformValue.color(color)
        #expect(value == .color(Color(r: 255, g: 128, b: 64, a: 200)))
    }

    @Test("UniformValue texture stores handle")
    func uniformTexture() {
        let handle = TextureHandle(id: 7)
        let value = UniformValue.texture(handle)
        #expect(value == .texture(TextureHandle(id: 7)))
    }

    @Test("UniformValue different cases are not equal")
    func uniformDifferentCases() {
        #expect(UniformValue.float(1.0) != .int(1))
        #expect(UniformValue.float(1.0) != .vec2(Vector2(x: 1.0, y: 0.0)))
    }

    // MARK: - Material2D Initialization

    @Test("Material2D default init with shader only")
    func defaultInit() {
        let mat = Material2D(shader: ShaderHandle(id: 5))
        #expect(mat.shader == ShaderHandle(id: 5))
        #expect(mat.uniforms.isEmpty)
        #expect(mat.blendMode == nil)
    }

    @Test("Material2D init with uniforms")
    func initWithUniforms() {
        let mat = Material2D(
            shader: ShaderHandle(id: 3),
            uniforms: [
                "time": .float(1.5),
                "color": .color(.red)
            ]
        )
        #expect(mat.shader == ShaderHandle(id: 3))
        #expect(mat.uniforms.count == 2)
        #expect(mat.uniforms["time"] == .float(1.5))
        #expect(mat.uniforms["color"] == .color(.red))
    }

    @Test("Material2D init with blend mode override")
    func initWithBlendMode() {
        let mat = Material2D(
            shader: ShaderHandle(id: 1),
            blendMode: .additive
        )
        #expect(mat.blendMode == .additive)
    }

    // MARK: - Sort Key

    @Test("Material2D sortKey equals shader id")
    func sortKeyMatchesShader() {
        let mat = Material2D(shader: ShaderHandle(id: 42))
        #expect(mat.sortKey == 42)
    }

    @Test("Materials with same shader have same sortKey regardless of uniforms")
    func sortKeySameShader() {
        let mat1 = Material2D(
            shader: ShaderHandle(id: 10),
            uniforms: ["a": .float(1.0)]
        )
        let mat2 = Material2D(
            shader: ShaderHandle(id: 10),
            uniforms: ["b": .float(2.0)]
        )
        #expect(mat1.sortKey == mat2.sortKey)
    }

    @Test("Materials with different shaders have different sortKeys")
    func sortKeyDifferentShaders() {
        let mat1 = Material2D(shader: ShaderHandle(id: 5))
        let mat2 = Material2D(shader: ShaderHandle(id: 6))
        #expect(mat1.sortKey != mat2.sortKey)
    }

    // MARK: - Equality

    @Test("Materials with same shader and uniforms are equal")
    func equalMaterials() {
        let mat1 = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["x": .float(1.0)],
            blendMode: .additive
        )
        let mat2 = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["x": .float(1.0)],
            blendMode: .additive
        )
        #expect(mat1 == mat2)
    }

    @Test("Materials with different uniforms are not equal")
    func differentUniforms() {
        let mat1 = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["x": .float(1.0)]
        )
        let mat2 = Material2D(
            shader: ShaderHandle(id: 1),
            uniforms: ["x": .float(2.0)]
        )
        #expect(mat1 != mat2)
    }

    @Test("Materials with different shaders are not equal")
    func differentShaders() {
        let mat1 = Material2D(shader: ShaderHandle(id: 1))
        let mat2 = Material2D(shader: ShaderHandle(id: 2))
        #expect(mat1 != mat2)
    }

    @Test("Materials with different blend modes are not equal")
    func differentBlendModes() {
        let mat1 = Material2D(shader: ShaderHandle(id: 1), blendMode: .alpha)
        let mat2 = Material2D(shader: ShaderHandle(id: 1), blendMode: .additive)
        #expect(mat1 != mat2)
    }

    // MARK: - Codable

    @Test("Material2D round-trips through JSON")
    func codableRoundTrip() throws {
        let original = Material2D(
            shader: ShaderHandle(id: 5),
            uniforms: [
                "time": .float(1.5),
                "offset": .vec2(Vector2(x: 10, y: 20)),
                "rgb": .vec3(x: 0.1, y: 0.2, z: 0.3),
                "rgba": .vec4(x: 0.1, y: 0.2, z: 0.3, w: 0.4),
                "count": .int(42)
            ],
            blendMode: .additive
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Material2D.self, from: data)

        #expect(decoded.shader == original.shader)
        #expect(decoded.blendMode == original.blendMode)
        #expect(decoded.uniforms.count == original.uniforms.count)
        #expect(decoded.uniforms["time"] == .float(1.5))
        #expect(decoded.uniforms["count"] == .int(42))
    }

    @Test("UniformValue color round-trips through JSON")
    func uniformColorCodable() throws {
        let original = UniformValue.color(Color(r: 100, g: 150, b: 200, a: 255))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UniformValue.self, from: data)
        #expect(decoded == original)
    }

    @Test("UniformValue texture round-trips through JSON")
    func uniformTextureCodable() throws {
        let original = UniformValue.texture(TextureHandle(id: 7))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UniformValue.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Sprite Integration

    @Test("Sprite has nil material by default")
    func spriteDefaultMaterial() {
        let sprite = Sprite(texture: TextureHandle(id: 1))
        #expect(sprite.material == nil)
    }

    @Test("Sprite can be initialized with material")
    func spriteInitWithMaterial() {
        let mat = Material2D(shader: ShaderHandle(id: 3))
        let sprite = Sprite(
            texture: TextureHandle(id: 1),
            material: mat
        )
        #expect(sprite.material != nil)
        #expect(sprite.material?.shader == ShaderHandle(id: 3))
    }

    @Test("Sprite material can be set after creation")
    func spriteSetMaterial() {
        var sprite = Sprite(texture: TextureHandle(id: 1))
        #expect(sprite.material == nil)

        sprite.material = Material2D(
            shader: ShaderHandle(id: 5),
            uniforms: ["flash": .float(1.0)]
        )
        #expect(sprite.material != nil)
        #expect(sprite.material?.uniforms["flash"] == .float(1.0))
    }

    @Test("Sprite material can be cleared")
    func spriteClearMaterial() {
        var sprite = Sprite(
            texture: TextureHandle(id: 1),
            material: Material2D(shader: ShaderHandle(id: 3))
        )
        #expect(sprite.material != nil)

        sprite.material = nil
        #expect(sprite.material == nil)
    }
}
