import Testing
@testable import Agilis

// MARK: - Spy Renderer

/// Records drawSprite calls for tilemap rendering verification.
private final class TileSpyRenderer: @unchecked Sendable, Renderer {
    var drawnSprites: [Sprite] = []

    func drawSprite(_ sprite: Sprite) {
        drawnSprites.append(sprite)
    }

    // Unused Renderer stubs
    func drawSprites(_ sprites: [Sprite]) { for s in sprites { drawSprite(s) } }
    func drawRect(_ rect: Rect, color: Color) {}
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {}
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {}
    func drawCircle(center: Vector2, radius: Float, color: Color) {}
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {}
    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func loadDefaultFont() -> FontHandle { .invalid }
    func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
    func destroyFont(_ handle: FontHandle) {}
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {}
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size { .zero }
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { _screenSize }
    var _screenSize: Size = Size(width: 800, height: 600)
}

// MARK: - Test Helpers

/// Create a simple 3x2 tilemap for tests.
private func makeTestTileMap() -> TileMap {
    let tex = TextureHandle(id: 1)
    let tileset = Tileset(
        texture: tex,
        tileWidth: 16,
        tileHeight: 16,
        columns: 10,
        firstGid: 1,
        tileCount: 100
    )
    let tiles = [
        Tile(id: 1), Tile(id: 2), Tile(id: 3),
        Tile(id: 4), Tile(id: 0), Tile(id: 6),
    ]
    let layer = TileLayer(name: "ground", width: 3, height: 2, tiles: tiles)
    return TileMap(
        layers: [layer],
        tilesets: [tileset],
        tileWidth: 16,
        tileHeight: 16,
        width: 3,
        height: 2
    )
}

// MARK: - TileMap Drawing Tests

@Suite("TileMap Drawing Tests")
struct TileMapDrawingTests {

    @Test("Draws correct number of sprites for small map")
    func drawsCorrectSpriteCount() {
        let renderer = TileSpyRenderer()
        let tileMap = makeTestTileMap()

        renderer.drawTileMap(tileMap)

        // 3x2 = 6 tiles, but tile at (1,1) is empty (id=0) → 5 sprites
        #expect(renderer.drawnSprites.count == 5)
    }

    @Test("Empty tiles are skipped")
    func emptyTilesSkipped() {
        let renderer = TileSpyRenderer()
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 16, tileHeight: 16, columns: 10, firstGid: 1
        )
        let tiles = [Tile(id: 0), Tile(id: 0), Tile(id: 0), Tile(id: 0)]
        let layer = TileLayer(name: "empty", width: 2, height: 2, tiles: tiles)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset],
                              tileWidth: 16, tileHeight: 16, width: 2, height: 2)

        renderer.drawTileMap(tileMap)

        #expect(renderer.drawnSprites.count == 0)
    }

    @Test("Tile position matches grid coordinates")
    func tilePositionMatchesGrid() {
        let renderer = TileSpyRenderer()
        let tileMap = makeTestTileMap()

        renderer.drawTileMap(tileMap)

        // First tile (0,0) should be at (0,0)
        let first = renderer.drawnSprites[0]
        #expect(first.position == Vector2(x: 0, y: 0))

        // Second tile (1,0) should be at (16,0)
        let second = renderer.drawnSprites[1]
        #expect(second.position == Vector2(x: 16, y: 0))
    }

    @Test("Correct sourceRect from tileset")
    func correctSourceRect() {
        let renderer = TileSpyRenderer()
        let tileMap = makeTestTileMap()

        renderer.drawTileMap(tileMap)

        // Tile id=1 → localId=0 → col 0, row 0 → sourceRect (0, 0, 16, 16)
        let first = renderer.drawnSprites[0]
        #expect(first.sourceRect == Rect(x: 0, y: 0, width: 16, height: 16))

        // Tile id=2 → localId=1 → col 1, row 0 → sourceRect (16, 0, 16, 16)
        let second = renderer.drawnSprites[1]
        #expect(second.sourceRect == Rect(x: 16, y: 0, width: 16, height: 16))
    }

    @Test("Tile flip flags passed to sprite")
    func tileFlipFlags() {
        let renderer = TileSpyRenderer()
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 16, tileHeight: 16, columns: 10, firstGid: 1
        )
        let tiles = [Tile(id: 1, flipX: true, flipY: false), Tile(id: 2, flipX: false, flipY: true)]
        let layer = TileLayer(name: "test", width: 2, height: 1, tiles: tiles)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset],
                              tileWidth: 16, tileHeight: 16, width: 2, height: 1)

        renderer.drawTileMap(tileMap)

        #expect(renderer.drawnSprites[0].flipX == true)
        #expect(renderer.drawnSprites[0].flipY == false)
        #expect(renderer.drawnSprites[1].flipX == false)
        #expect(renderer.drawnSprites[1].flipY == true)
    }

    @Test("Layer opacity applied to tint alpha")
    func layerOpacityApplied() {
        let renderer = TileSpyRenderer()
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 16, tileHeight: 16, columns: 10, firstGid: 1
        )
        let tiles = [Tile(id: 1)]
        let layer = TileLayer(name: "test", width: 1, height: 1, tiles: tiles, opacity: 0.5)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset],
                              tileWidth: 16, tileHeight: 16, width: 1, height: 1)

        renderer.drawTileMap(tileMap)

        #expect(renderer.drawnSprites.count == 1)
        // 255 * 0.5 = 127.5 → UInt8(127)
        #expect(renderer.drawnSprites[0].tint.a == 127)
    }

    @Test("Invisible layers are skipped")
    func invisibleLayersSkipped() {
        let renderer = TileSpyRenderer()
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 16, tileHeight: 16, columns: 10, firstGid: 1
        )
        let tiles = [Tile(id: 1)]
        let visible = TileLayer(name: "visible", width: 1, height: 1, tiles: tiles, visible: true)
        let hidden = TileLayer(name: "hidden", width: 1, height: 1, tiles: tiles, visible: false)
        let tileMap = TileMap(layers: [visible, hidden], tilesets: [tileset],
                              tileWidth: 16, tileHeight: 16, width: 1, height: 1)

        renderer.drawTileMap(tileMap)

        // Only the visible layer's tile should be drawn
        #expect(renderer.drawnSprites.count == 1)
    }

    @Test("Map position offset applied")
    func positionOffsetApplied() {
        let renderer = TileSpyRenderer()
        let tileMap = makeTestTileMap()

        renderer.drawTileMap(tileMap, position: Vector2(x: 100, y: 50))

        let first = renderer.drawnSprites[0]
        #expect(first.position == Vector2(x: 100, y: 50))

        let second = renderer.drawnSprites[1]
        #expect(second.position == Vector2(x: 116, y: 50))
    }

    @Test("Multiple tilesets resolved by GID range")
    func multipleTilesets() {
        let renderer = TileSpyRenderer()
        let tex1 = TextureHandle(id: 1)
        let tex2 = TextureHandle(id: 2)
        let tileset1 = Tileset(texture: tex1, tileWidth: 16, tileHeight: 16,
                               columns: 10, firstGid: 1, tileCount: 10)
        let tileset2 = Tileset(texture: tex2, tileWidth: 16, tileHeight: 16,
                               columns: 10, firstGid: 11, tileCount: 10)
        let tiles = [Tile(id: 5), Tile(id: 15)]
        let layer = TileLayer(name: "test", width: 2, height: 1, tiles: tiles)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset1, tileset2],
                              tileWidth: 16, tileHeight: 16, width: 2, height: 1)

        renderer.drawTileMap(tileMap)

        #expect(renderer.drawnSprites.count == 2)
        #expect(renderer.drawnSprites[0].texture == tex1) // id=5 → tileset1
        #expect(renderer.drawnSprites[1].texture == tex2) // id=15 → tileset2
    }
}

// MARK: - TileMap Culling Tests

@Suite("TileMap Culling Tests")
struct TileMapCullingTests {

    @Test("No camera draws all tiles for small map")
    func noCameraDrawsAll() {
        let renderer = TileSpyRenderer()
        renderer._screenSize = Size(width: 800, height: 600)
        let tileMap = makeTestTileMap() // 3x2 at 16px = 48x32, fits in 800x600

        renderer.drawTileMap(tileMap)

        #expect(renderer.drawnSprites.count == 5) // 6 tiles - 1 empty
    }

    @Test("Camera viewport culls tiles outside view")
    func cameraCullsTiles() {
        let renderer = TileSpyRenderer()
        renderer._screenSize = Size(width: 32, height: 32)

        // Large 10x10 map
        let tileset = Tileset(texture: TextureHandle(id: 1),
                              tileWidth: 16, tileHeight: 16, columns: 10, firstGid: 1)
        var tiles: [Tile] = []
        for i in 0..<100 { tiles.append(Tile(id: i + 1)) }
        let layer = TileLayer(name: "ground", width: 10, height: 10, tiles: tiles)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset],
                              tileWidth: 16, tileHeight: 16, width: 10, height: 10)

        // Camera centered at (24, 24) with screen 32x32 at zoom 1
        // Viewport: x=24-16=8, y=24-16=8, w=32, h=32 → covers 8..40, 8..40
        // Tile range: col 0..2, row 0..2 → 3x3 = 9 tiles
        let camera = Camera2D(
            target: Vector2(x: 24, y: 24),
            offset: Vector2(x: 16, y: 16),
            zoom: 1.0
        )

        renderer.drawTileMap(tileMap, camera: camera)

        #expect(renderer.drawnSprites.count == 9)
    }

    @Test("Camera zoom affects visible tile count")
    func cameraZoomAffectsCulling() {
        let renderer = TileSpyRenderer()
        renderer._screenSize = Size(width: 32, height: 32)

        let tileset = Tileset(texture: TextureHandle(id: 1),
                              tileWidth: 16, tileHeight: 16, columns: 10, firstGid: 1)
        var tiles: [Tile] = []
        for i in 0..<100 { tiles.append(Tile(id: i + 1)) }
        let layer = TileLayer(name: "ground", width: 10, height: 10, tiles: tiles)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset],
                              tileWidth: 16, tileHeight: 16, width: 10, height: 10)

        // Zoom 2.0 → viewport is 16x16 pixels in world space → fewer visible tiles
        let camera = Camera2D(
            target: Vector2(x: 24, y: 24),
            offset: Vector2(x: 16, y: 16),
            zoom: 2.0
        )

        renderer.drawTileMap(tileMap, camera: camera)

        let zoomedCount = renderer.drawnSprites.count

        // Zoom 0.5 → viewport is 64x64 pixels → more visible tiles
        renderer.drawnSprites.removeAll()
        let camera2 = Camera2D(
            target: Vector2(x: 24, y: 24),
            offset: Vector2(x: 16, y: 16),
            zoom: 0.5
        )

        renderer.drawTileMap(tileMap, camera: camera2)

        #expect(renderer.drawnSprites.count > zoomedCount)
    }

    @Test("Map completely outside viewport draws nothing")
    func mapOutsideViewport() {
        let renderer = TileSpyRenderer()
        renderer._screenSize = Size(width: 100, height: 100)
        let tileMap = makeTestTileMap()

        // Position the map far off-screen
        renderer.drawTileMap(tileMap, position: Vector2(x: 5000, y: 5000))

        #expect(renderer.drawnSprites.count == 0)
    }
}

// MARK: - TileMap Batch Tests

@Suite("TileMap Batch Tests")
struct TileMapBatchTests {

    @Test("batchTileMap adds sprites to SpriteBatch")
    func batchAddsSprites() {
        let renderer = TileSpyRenderer()
        let tileMap = makeTestTileMap()
        let batch = SpriteBatch(sortMode: .byTexture)

        renderer.batchTileMap(tileMap, into: batch)

        // 5 non-empty tiles added to batch
        #expect(batch.count == 5)
    }

    @Test("batchTileLayer adds correct sprite count")
    func batchLayerAddsCorrectCount() {
        let renderer = TileSpyRenderer()
        let tileMap = makeTestTileMap()
        let batch = SpriteBatch(sortMode: .none)

        renderer.batchTileLayer(
            tileMap.layers[0],
            tilesets: tileMap.tilesets,
            tileWidth: tileMap.tileWidth,
            tileHeight: tileMap.tileHeight,
            into: batch
        )

        #expect(batch.count == 5)
    }

    @Test("Batch layer parameter passed through")
    func batchLayerParameter() {
        let renderer = TileSpyRenderer()
        let tileMap = makeTestTileMap()
        let batch = SpriteBatch(sortMode: .byLayer)

        renderer.batchTileMap(tileMap, into: batch, baseLayer: 10)

        // Flush and verify sprites were added (count check)
        #expect(batch.count == 5)
    }

    @Test("Empty map adds nothing to batch")
    func emptyMapBatch() {
        let renderer = TileSpyRenderer()
        let tileset = Tileset(texture: TextureHandle(id: 1),
                              tileWidth: 16, tileHeight: 16, columns: 10, firstGid: 1)
        let layer = TileLayer(name: "empty", width: 2, height: 2,
                              tiles: [.empty, .empty, .empty, .empty])
        let tileMap = TileMap(layers: [layer], tilesets: [tileset],
                              tileWidth: 16, tileHeight: 16, width: 2, height: 2)
        let batch = SpriteBatch()

        renderer.batchTileMap(tileMap, into: batch)

        #expect(batch.count == 0)
    }

    @Test("Multiple tilesets in batch resolved correctly")
    func multipleTilesetsBatch() {
        let renderer = TileSpyRenderer()
        let tex1 = TextureHandle(id: 1)
        let tex2 = TextureHandle(id: 2)
        let tileset1 = Tileset(texture: tex1, tileWidth: 16, tileHeight: 16,
                               columns: 10, firstGid: 1)
        let tileset2 = Tileset(texture: tex2, tileWidth: 16, tileHeight: 16,
                               columns: 10, firstGid: 11)
        let tiles = [Tile(id: 3), Tile(id: 15)]
        let layer = TileLayer(name: "test", width: 2, height: 1, tiles: tiles)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset1, tileset2],
                              tileWidth: 16, tileHeight: 16, width: 2, height: 1)
        let batch = SpriteBatch(sortMode: .none)

        renderer.batchTileMap(tileMap, into: batch)

        #expect(batch.count == 2)

        // Flush to verify textures are correct
        batch.flush(to: renderer)
        #expect(renderer.drawnSprites[0].texture == tex1)
        #expect(renderer.drawnSprites[1].texture == tex2)
    }
}
