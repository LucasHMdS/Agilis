import Testing
@testable import Agilis

// MARK: - Spy Renderer

/// Records drawn sprites for verification.
final class SpyRenderer: @unchecked Sendable, RenderBackend {
    var drawnSprites: [Sprite] = []
    var drawSpriteCallCount: Int = 0
    var drawSpritesCallCount: Int = 0

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
        drawSpriteCallCount += 1
    }

    func drawSprites(_ sprites: [Sprite]) {
        drawnSprites.append(contentsOf: sprites)
        drawSpritesCallCount += 1
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

// MARK: - Helpers

private let texA = TextureHandle(id: 1)
private let texB = TextureHandle(id: 2)
private let texC = TextureHandle(id: 3)

private func sprite(_ tex: TextureHandle, x: Float = 0) -> Sprite {
    Sprite(texture: tex, position: Vector2(x: x, y: 0))
}

// MARK: - SpriteBatch Basics

@Suite("SpriteBatch Basics")
struct SpriteBatchBasicsTests {

    @Test("Empty batch flushes without drawing")
    func emptyFlush() {
        let batch = SpriteBatch()
        let renderer = SpyRenderer()
        batch.flush(to: renderer)

        #expect(renderer.drawnSprites.isEmpty)
        #expect(batch.lastSpriteCount == 0)
        #expect(batch.lastDrawCallCount == 0)
    }

    @Test("Single sprite flushes correctly")
    func singleSprite() {
        let batch = SpriteBatch()
        let renderer = SpyRenderer()

        batch.add(sprite(texA, x: 10))
        batch.flush(to: renderer)

        #expect(renderer.drawnSprites.count == 1)
        #expect(renderer.drawnSprites[0].position.x == 10)
        #expect(batch.lastSpriteCount == 1)
        #expect(batch.lastDrawCallCount == 1)
    }

    @Test("Count and isEmpty reflect queued sprites")
    func countAndIsEmpty() {
        let batch = SpriteBatch()
        #expect(batch.isEmpty)
        #expect(batch.count == 0)

        batch.add(sprite(texA))
        #expect(!batch.isEmpty)
        #expect(batch.count == 1)

        batch.add(sprite(texB))
        #expect(batch.count == 2)
    }

    @Test("Flush clears the batch")
    func flushClears() {
        let batch = SpriteBatch()
        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.flush(to: SpyRenderer())

        #expect(batch.isEmpty)
        #expect(batch.count == 0)
    }

    @Test("Clear discards without drawing")
    func clearDiscards() {
        let batch = SpriteBatch()
        let renderer = SpyRenderer()

        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.clear()

        #expect(batch.isEmpty)
        batch.flush(to: renderer)
        #expect(renderer.drawnSprites.isEmpty)
    }

    @Test("Add array adds all sprites")
    func addArray() {
        let batch = SpriteBatch()
        let sprites = [sprite(texA, x: 1), sprite(texB, x: 2), sprite(texC, x: 3)]
        batch.add(sprites)

        #expect(batch.count == 3)
    }

    @Test("Sequential flushes work independently")
    func sequentialFlushes() {
        let batch = SpriteBatch()
        let renderer = SpyRenderer()

        batch.add(sprite(texA))
        batch.flush(to: renderer)
        #expect(renderer.drawnSprites.count == 1)
        #expect(batch.lastSpriteCount == 1)

        batch.add(sprite(texB))
        batch.add(sprite(texC))
        batch.flush(to: renderer)
        #expect(renderer.drawnSprites.count == 3) // cumulative in spy
        #expect(batch.lastSpriteCount == 2)
    }
}

// MARK: - Sort Modes

@Suite("SpriteBatch Sort Modes")
struct SpriteBatchSortModeTests {

    @Test("byTexture groups sprites by texture ID")
    func sortByTexture() {
        let batch = SpriteBatch(sortMode: .byTexture)
        let renderer = SpyRenderer()

        // Add interleaved: A, B, A, C, B
        batch.add(sprite(texA, x: 1))
        batch.add(sprite(texB, x: 2))
        batch.add(sprite(texA, x: 3))
        batch.add(sprite(texC, x: 4))
        batch.add(sprite(texB, x: 5))
        batch.flush(to: renderer)

        // Should be grouped: A, A, B, B, C
        let textureIds = renderer.drawnSprites.map(\.texture.id)
        #expect(textureIds == [1, 1, 2, 2, 3])
    }

    @Test("byTexture preserves insertion order within same texture (stable sort)")
    func stableSortWithinTexture() {
        let batch = SpriteBatch(sortMode: .byTexture)
        let renderer = SpyRenderer()

        batch.add(sprite(texA, x: 10))
        batch.add(sprite(texB, x: 20))
        batch.add(sprite(texA, x: 30))
        batch.flush(to: renderer)

        // texA sprites should keep their insertion order: x=10, x=30
        let texASprites = renderer.drawnSprites.filter { $0.texture.id == texA.id }
        #expect(texASprites[0].position.x == 10)
        #expect(texASprites[1].position.x == 30)
    }

    @Test("byLayer sorts by layer then texture within layer")
    func sortByLayer() {
        let batch = SpriteBatch(sortMode: .byLayer)
        let renderer = SpyRenderer()

        // Layer 1: texB, texA → should sort to texA, texB
        // Layer 0: texC → stays as-is
        batch.add(sprite(texB, x: 1), layer: 1)
        batch.add(sprite(texC, x: 2), layer: 0)
        batch.add(sprite(texA, x: 3), layer: 1)
        batch.flush(to: renderer)

        // Expected: layer 0 (texC), layer 1 (texA, texB)
        let textureIds = renderer.drawnSprites.map(\.texture.id)
        #expect(textureIds == [texC.id, texA.id, texB.id])
    }

    @Test("none preserves insertion order exactly")
    func sortNone() {
        let batch = SpriteBatch(sortMode: .none)
        let renderer = SpyRenderer()

        batch.add(sprite(texC, x: 1))
        batch.add(sprite(texA, x: 2))
        batch.add(sprite(texB, x: 3))
        batch.flush(to: renderer)

        let positions = renderer.drawnSprites.map(\.position.x)
        #expect(positions == [1, 2, 3])

        let textureIds = renderer.drawnSprites.map(\.texture.id)
        #expect(textureIds == [texC.id, texA.id, texB.id])
    }

    @Test("none mode calls drawSprite individually, not drawSprites")
    func noneModeUsesDrawSprite() {
        let batch = SpriteBatch(sortMode: .none)
        let renderer = SpyRenderer()

        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.flush(to: renderer)

        #expect(renderer.drawSpriteCallCount == 2)
        #expect(renderer.drawSpritesCallCount == 0)
    }

    @Test("byTexture mode calls drawSprites batch method")
    func byTextureModeUsesDrawSprites() {
        let batch = SpriteBatch(sortMode: .byTexture)
        let renderer = SpyRenderer()

        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.flush(to: renderer)

        #expect(renderer.drawSpritesCallCount == 1)
        #expect(renderer.drawSpriteCallCount == 0)
    }
}

// MARK: - Statistics

@Suite("SpriteBatch Statistics")
struct SpriteBatchStatsTests {

    @Test("lastSpriteCount matches total sprites")
    func spriteCount() {
        let batch = SpriteBatch()
        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.add(sprite(texC))
        batch.flush(to: SpyRenderer())

        #expect(batch.lastSpriteCount == 3)
    }

    @Test("lastDrawCallCount matches texture group count")
    func drawCallCount() {
        let batch = SpriteBatch(sortMode: .byTexture)

        // A, B, A, C → sorted: A, A, B, C → 3 texture groups
        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.add(sprite(texA))
        batch.add(sprite(texC))
        batch.flush(to: SpyRenderer())

        #expect(batch.lastDrawCallCount == 3)
    }

    @Test("All same texture counts as 1 draw call")
    func sameTexture() {
        let batch = SpriteBatch(sortMode: .byTexture)
        batch.add(sprite(texA))
        batch.add(sprite(texA))
        batch.add(sprite(texA))
        batch.flush(to: SpyRenderer())

        #expect(batch.lastDrawCallCount == 1)
        #expect(batch.lastSpriteCount == 3)
    }

    @Test("Draw call count with none mode reflects actual texture changes")
    func drawCallCountNoneMode() {
        let batch = SpriteBatch(sortMode: .none)

        // A, B, A → 3 texture changes (A→B, B→A = 3 groups)
        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.add(sprite(texA))
        batch.flush(to: SpyRenderer())

        #expect(batch.lastDrawCallCount == 3)
    }

    @Test("Stats reset on each flush")
    func statsReset() {
        let batch = SpriteBatch()

        batch.add(sprite(texA))
        batch.add(sprite(texB))
        batch.flush(to: SpyRenderer())
        #expect(batch.lastSpriteCount == 2)

        // Empty flush should reset stats
        batch.flush(to: SpyRenderer())
        #expect(batch.lastSpriteCount == 0)
        #expect(batch.lastDrawCallCount == 0)
    }
}

// MARK: - Default drawSprites Implementation

@Suite("RenderBackend drawSprites Default")
struct DrawSpritesDefaultTests {

    /// A renderer that does NOT override drawSprites, using the default extension.
    final class MinimalRenderer: @unchecked Sendable, RenderBackend {
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
        func drawSprite(_ sprite: Sprite) { drawnSprites.append(sprite) }
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

    @Test("Default drawSprites calls drawSprite for each sprite")
    func defaultFallback() {
        let renderer = MinimalRenderer()
        let sprites = [sprite(texA, x: 1), sprite(texB, x: 2), sprite(texC, x: 3)]

        renderer.drawSprites(sprites)

        #expect(renderer.drawnSprites.count == 3)
        #expect(renderer.drawnSprites[0].position.x == 1)
        #expect(renderer.drawnSprites[1].position.x == 2)
        #expect(renderer.drawnSprites[2].position.x == 3)
    }
}
