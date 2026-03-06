import Testing
import Foundation
@testable import Agilis

// MARK: - BlendMode Enum

@Suite("BlendMode")
struct BlendModeTests {

    @Test("All cases have distinct raw values")
    func distinctRawValues() {
        let values: Set<Int> = [
            BlendMode.alpha.rawValue,
            BlendMode.additive.rawValue,
            BlendMode.multiplied.rawValue,
            BlendMode.premultiplied.rawValue,
        ]
        #expect(values.count == 4)
    }

    @Test("Alpha is the default (raw value 0)")
    func alphaIsDefault() {
        #expect(BlendMode.alpha.rawValue == 0)
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() throws {
        let modes: [BlendMode] = [.alpha, .additive, .multiplied, .premultiplied]
        let data = try JSONEncoder().encode(modes)
        let decoded = try JSONDecoder().decode([BlendMode].self, from: data)
        #expect(decoded == modes)
    }

    @Test("Equatable works correctly")
    func equatable() {
        #expect(BlendMode.alpha == BlendMode.alpha)
        #expect(BlendMode.additive == BlendMode.additive)
        #expect(BlendMode.alpha != BlendMode.additive)
        #expect(BlendMode.multiplied != BlendMode.premultiplied)
    }
}

// MARK: - Sprite BlendMode

@Suite("Sprite BlendMode")
struct SpriteBlendModeTests {

    @Test("Default blend mode is alpha")
    func defaultBlendMode() {
        let sprite = Sprite(texture: TextureHandle(id: 1))
        #expect(sprite.blendMode == BlendMode.alpha)
    }

    @Test("Blend mode can be set in init")
    func initWithBlendMode() {
        let sprite = Sprite(texture: TextureHandle(id: 1), blendMode: .additive)
        #expect(sprite.blendMode == BlendMode.additive)
    }

    @Test("Blend mode is mutable")
    func mutableBlendMode() {
        var sprite = Sprite(texture: TextureHandle(id: 1))
        sprite.blendMode = .multiplied
        #expect(sprite.blendMode == BlendMode.multiplied)
    }

    @Test("Sprite Codable preserves blend mode")
    func codablePreservesBlendMode() throws {
        let sprite = Sprite(
            texture: TextureHandle(id: 5),
            position: Vector2(x: 10, y: 20),
            blendMode: .additive
        )
        let data = try JSONEncoder().encode(sprite)
        let decoded = try JSONDecoder().decode(Sprite.self, from: data)
        #expect(decoded.blendMode == BlendMode.additive)
        #expect(decoded.texture.id == 5)
        #expect(decoded.position.x == 10)
    }

    @Test("Sprite Codable round-trip preserves alpha default")
    func codableDefaultAlpha() throws {
        let sprite = Sprite(texture: TextureHandle(id: 1))
        let data = try JSONEncoder().encode(sprite)
        let decoded = try JSONDecoder().decode(Sprite.self, from: data)
        #expect(decoded.blendMode == BlendMode.alpha)
    }
}

// MARK: - Renderer Default BlendMode Implementation

@Suite("Renderer BlendMode Defaults")
struct RendererBlendModeDefaultTests {

    final class BlendMinimalRenderer: @unchecked Sendable, Renderer {
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
        var screenSize: Size { Size(width: 800, height: 600) }
    }

    @Test("Default beginBlendMode and endBlendMode do not crash")
    func defaultImplementation() {
        let renderer = BlendMinimalRenderer()
        renderer.beginBlendMode(.additive)
        renderer.endBlendMode()
        renderer.beginBlendMode(.multiplied)
        renderer.endBlendMode()
    }
}

// MARK: - SpriteBatch Blend Mode Sorting

private let blendTexA = TextureHandle(id: 1)
private let blendTexB = TextureHandle(id: 2)

private func blendSprite(_ tex: TextureHandle, x: Float = 0, blend: BlendMode = .alpha) -> Sprite {
    Sprite(texture: tex, position: Vector2(x: x, y: 0), blendMode: blend)
}

/// Records drawn sprites for blend mode tests.
private final class BlendSpyRenderer: @unchecked Sendable, Renderer {
    var drawnSprites: [Sprite] = []

    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}

    func drawSprite(_ sprite: Sprite) {
        drawnSprites.append(sprite)
    }

    func drawSprites(_ sprites: [Sprite]) {
        drawnSprites.append(contentsOf: sprites)
    }

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
    var screenSize: Size { Size(width: 800, height: 600) }
}

@Suite("SpriteBatch Blend Mode Sorting")
struct SpriteBatchBlendModeSortTests {

    @Test("byTexture groups by blend mode then texture")
    func sortByTextureGroupsBlendMode() {
        let batch = SpriteBatch(sortMode: .byTexture)
        let renderer = BlendSpyRenderer()

        // Add: alpha-texB, additive-texA, alpha-texA, additive-texB
        batch.add(blendSprite(blendTexB, x: 1, blend: .alpha))
        batch.add(blendSprite(blendTexA, x: 2, blend: .additive))
        batch.add(blendSprite(blendTexA, x: 3, blend: .alpha))
        batch.add(blendSprite(blendTexB, x: 4, blend: .additive))
        batch.flush(to: renderer)

        // Expected order: alpha group (texA, texB), additive group (texA, texB)
        let blendModes = renderer.drawnSprites.map(\.blendMode)
        let textureIds = renderer.drawnSprites.map(\.texture.id)

        #expect(blendModes == [BlendMode.alpha, .alpha, .additive, .additive])
        #expect(textureIds == [blendTexA.id, blendTexB.id, blendTexA.id, blendTexB.id])
    }

    @Test("byLayer groups by layer, then blend mode, then texture")
    func sortByLayerGroupsBlendMode() {
        let batch = SpriteBatch(sortMode: .byLayer)
        let renderer = BlendSpyRenderer()

        // Layer 0: additive-texB, alpha-texA
        // Layer 1: alpha-texA
        batch.add(blendSprite(blendTexB, x: 1, blend: .additive), layer: 0)
        batch.add(blendSprite(blendTexA, x: 2, blend: .alpha), layer: 0)
        batch.add(blendSprite(blendTexA, x: 3, blend: .alpha), layer: 1)
        batch.flush(to: renderer)

        // Expected: layer0 alpha-texA, layer0 additive-texB, layer1 alpha-texA
        let positions = renderer.drawnSprites.map(\.position.x)
        #expect(positions == [2, 1, 3])
    }

    @Test("State changes count includes blend mode transitions")
    func stateChangesCountBlendMode() {
        let batch = SpriteBatch(sortMode: .byTexture)

        // Same texture but different blend modes -> 2 state changes
        batch.add(blendSprite(blendTexA, blend: .alpha))
        batch.add(blendSprite(blendTexA, blend: .additive))
        batch.flush(to: BlendSpyRenderer())

        #expect(batch.lastDrawCallCount == 2)
    }

    @Test("Same blend mode and texture counts as 1 state change")
    func sameBlendAndTexture() {
        let batch = SpriteBatch(sortMode: .byTexture)

        batch.add(blendSprite(blendTexA, blend: .additive))
        batch.add(blendSprite(blendTexA, blend: .additive))
        batch.add(blendSprite(blendTexA, blend: .additive))
        batch.flush(to: BlendSpyRenderer())

        #expect(batch.lastDrawCallCount == 1)
    }

    @Test("None mode preserves insertion order regardless of blend mode")
    func noneModePreservesOrder() {
        let batch = SpriteBatch(sortMode: .none)
        let renderer = BlendSpyRenderer()

        batch.add(blendSprite(blendTexA, x: 1, blend: .additive))
        batch.add(blendSprite(blendTexB, x: 2, blend: .alpha))
        batch.add(blendSprite(blendTexA, x: 3, blend: .multiplied))
        batch.flush(to: renderer)

        let blendModes = renderer.drawnSprites.map(\.blendMode)
        #expect(blendModes == [BlendMode.additive, .alpha, .multiplied])
    }
}
