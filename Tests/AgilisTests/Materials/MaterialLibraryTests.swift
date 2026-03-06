import Testing
import Foundation
@testable import Agilis

/// A mock renderer that tracks shader operations for testing MaterialLibrary.
private final class MockShaderRenderer: @unchecked Sendable, Renderer {
    var loadedShaders: [UInt32: String] = [:]  // id -> fragment source
    var nextId: UInt32 = 1
    var destroyedShaders: [UInt32] = []
    var lastSetUniforms: [String: UniformValue] = [:]

    func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle {
        let id = nextId
        nextId += 1
        loadedShaders[id] = fragmentSource
        return ShaderHandle(id: id)
    }

    func destroyShader(_ handle: ShaderHandle) {
        destroyedShaders.append(handle.id)
        loadedShaders.removeValue(forKey: handle.id)
    }

    // Stub all required Renderer methods
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

@Suite("MaterialLibrary")
struct MaterialLibraryTests {

    // MARK: - Lifecycle

    @Test("initialize loads all 6 built-in shaders")
    func initializeLoadsShaders() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        #expect(renderer.loadedShaders.count == 6)
        #expect(library.isInitialized)
    }

    @Test("shutdown destroys all cached shaders")
    func shutdownDestroysShaders() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        #expect(renderer.loadedShaders.count == 6)

        library.shutdown()

        #expect(renderer.destroyedShaders.count == 6)
        #expect(!library.isInitialized)
    }

    @Test("factory methods return invalid shader when not initialized")
    func factoryWithoutInit() {
        let library = MaterialLibrary()
        let mat = library.flash()
        #expect(mat.shader == .invalid)
    }

    // MARK: - Flash

    @Test("flash returns material with correct defaults")
    func flashDefaults() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.flash()
        #expect(mat.shader != .invalid)
        #expect(mat.uniforms["flashColor"] == .color(.white))
        #expect(mat.uniforms["flashAmount"] == .float(1.0))
        #expect(mat.uniforms.count == 2)
        #expect(mat.blendMode == nil)
    }

    @Test("flash accepts custom color and amount")
    func flashCustom() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.flash(color: .red, amount: 0.5)
        #expect(mat.uniforms["flashColor"] == .color(.red))
        #expect(mat.uniforms["flashAmount"] == .float(0.5))
    }

    // MARK: - Grayscale

    @Test("grayscale returns material with correct defaults")
    func grayscaleDefaults() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.grayscale()
        #expect(mat.shader != .invalid)
        #expect(mat.uniforms["amount"] == .float(1.0))
        #expect(mat.uniforms.count == 1)
    }

    @Test("grayscale accepts custom amount")
    func grayscaleCustom() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.grayscale(amount: 0.3)
        #expect(mat.uniforms["amount"] == .float(0.3))
    }

    // MARK: - Dissolve

    @Test("dissolve returns material with correct uniforms")
    func dissolveDefaults() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.dissolve(threshold: 0.5)
        #expect(mat.shader != .invalid)
        #expect(mat.uniforms["threshold"] == .float(0.5))
        #expect(mat.uniforms["edgeWidth"] == .float(0.05))
        #expect(mat.uniforms["edgeColor"] == .color(.white))
        #expect(mat.uniforms.count == 3)
    }

    @Test("dissolve accepts custom parameters")
    func dissolveCustom() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.dissolve(threshold: 0.8, edgeWidth: 0.1, edgeColor: .yellow)
        #expect(mat.uniforms["threshold"] == .float(0.8))
        #expect(mat.uniforms["edgeWidth"] == .float(0.1))
        #expect(mat.uniforms["edgeColor"] == .color(.yellow))
    }

    // MARK: - Outline

    @Test("outline returns material with correct uniforms")
    func outlineDefaults() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.outline(textureSize: Vector2(x: 64, y: 64))
        #expect(mat.shader != .invalid)
        #expect(mat.uniforms["outlineColor"] == .color(.white))
        #expect(mat.uniforms["outlineWidth"] == .float(1.0))
        #expect(mat.uniforms["textureSize"] == .vec2(Vector2(x: 64, y: 64)))
        #expect(mat.uniforms.count == 3)
    }

    @Test("outline accepts custom parameters")
    func outlineCustom() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.outline(color: .green, width: 2.0, textureSize: Vector2(x: 128, y: 128))
        #expect(mat.uniforms["outlineColor"] == .color(.green))
        #expect(mat.uniforms["outlineWidth"] == .float(2.0))
        #expect(mat.uniforms["textureSize"] == .vec2(Vector2(x: 128, y: 128)))
    }

    // MARK: - Color Replace

    @Test("colorReplace returns material with correct uniforms")
    func colorReplaceDefaults() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.colorReplace(target: .red, replacement: .blue)
        #expect(mat.shader != .invalid)
        #expect(mat.uniforms["tolerance"] == .float(0.1))
        #expect(mat.uniforms.count == 3)

        // Check target color is normalized
        if case .vec3(let x, let y, let z) = mat.uniforms["targetColor"] {
            #expect(abs(x - 1.0) < 0.01)  // red = 255 -> 1.0
            #expect(abs(y - 0.0) < 0.01)
            #expect(abs(z - 0.0) < 0.01)
        } else {
            Issue.record("targetColor should be .vec3")
        }

        if case .vec3(let x, let y, let z) = mat.uniforms["replacementColor"] {
            #expect(abs(x - 0.0) < 0.01)
            #expect(abs(y - 0.0) < 0.01)
            #expect(abs(z - 1.0) < 0.01)  // blue = 255 -> 1.0
        } else {
            Issue.record("replacementColor should be .vec3")
        }
    }

    // MARK: - Wave

    @Test("wave returns material with correct uniforms")
    func waveDefaults() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.wave(time: 2.5)
        #expect(mat.shader != .invalid)
        #expect(mat.uniforms["time"] == .float(2.5))
        #expect(mat.uniforms["amplitude"] == .float(0.01))
        #expect(mat.uniforms["frequency"] == .float(10.0))
        #expect(mat.uniforms["speed"] == .float(3.0))
        #expect(mat.uniforms.count == 4)
    }

    @Test("wave accepts custom parameters")
    func waveCustom() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat = library.wave(time: 1.0, amplitude: 0.05, frequency: 20.0, speed: 5.0)
        #expect(mat.uniforms["time"] == .float(1.0))
        #expect(mat.uniforms["amplitude"] == .float(0.05))
        #expect(mat.uniforms["frequency"] == .float(20.0))
        #expect(mat.uniforms["speed"] == .float(5.0))
    }

    // MARK: - Shader Caching

    @Test("factory methods reuse cached shaders")
    func shaderCaching() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let mat1 = library.flash()
        let mat2 = library.flash(color: .red, amount: 0.5)

        // Same shader (flash), different uniforms
        #expect(mat1.shader == mat2.shader)
        #expect(mat1.uniforms != mat2.uniforms)
    }

    @Test("different effects use different shaders")
    func differentEffectsDifferentShaders() {
        let renderer = MockShaderRenderer()
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let flash = library.flash()
        let grayscale = library.grayscale()
        let dissolve = library.dissolve(threshold: 0.5)

        #expect(flash.shader != grayscale.shader)
        #expect(grayscale.shader != dissolve.shader)
        #expect(flash.shader != dissolve.shader)
    }
}
