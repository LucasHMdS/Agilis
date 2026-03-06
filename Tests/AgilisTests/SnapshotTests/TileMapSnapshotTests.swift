import Testing
@testable import Agilis

@Suite("TileMap Snapshots", .serialized)
struct TileMapSnapshotTests {

    /// Create a simple 2-tile checkerboard tileset texture.
    /// Tile 1 (left half): colorA, Tile 2 (right half): colorB.
    private static func createTilesetTexture(
        renderer: Renderer,
        tileSize: Int = 32,
        colorA: Color = Color(r: 100, g: 100, b: 200),
        colorB: Color = Color(r: 200, g: 100, b: 100)
    ) -> TextureHandle {
        let width = tileSize * 2  // 2 tiles side by side
        let height = tileSize
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let color = x < tileSize ? colorA : colorB
                let i = (y * width + x) * 4
                pixels[i]     = color.r
                pixels[i + 1] = color.g
                pixels[i + 2] = color.b
                pixels[i + 3] = color.a
            }
        }
        return renderer.loadTextureFromImage(
            ImageData(width: width, height: height, pixels: pixels)
        )
    }

    /// Build a basic TileMap with a given grid and tileset.
    private static func buildTileMap(
        width: Int, height: Int,
        tileSize: Int = 32,
        tileset: Tileset,
        tiles: [Tile],
        layerName: String = "main",
        opacity: Float = 1.0,
        visible: Bool = true
    ) -> TileMap {
        let layer = TileLayer(
            name: layerName,
            width: width, height: height,
            tiles: tiles,
            visible: visible,
            opacity: opacity
        )
        return TileMap(
            layers: [layer],
            tilesets: [tileset],
            tileWidth: tileSize, tileHeight: tileSize,
            width: width, height: height
        )
    }

    @Test("Basic 4x4 tilemap grid")
    func basicGrid() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = Self.createTilesetTexture(renderer: renderer, tileSize: 32)
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 2, firstGid: 1, tileCount: 2)

        // Alternating tile pattern
        var tiles = [Tile]()
        for row in 0..<4 {
            for col in 0..<4 {
                let tileId = ((row + col) % 2 == 0) ? 1 : 2
                tiles.append(Tile(id: tileId))
            }
        }

        let tileMap = Self.buildTileMap(
            width: 4, height: 4, tileset: tileset, tiles: tiles
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTileMap(tileMap, position: .zero, camera: Camera2D())
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "basic-grid")
    }

    @Test("Empty tiles show background")
    func emptyTiles() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = Self.createTilesetTexture(renderer: renderer, tileSize: 32)
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 2, firstGid: 1, tileCount: 2)

        // Some empty tiles (id=0)
        let tiles: [Tile] = [
            Tile(id: 1), Tile(id: 0), Tile(id: 1), Tile(id: 0),
            Tile(id: 0), Tile(id: 2), Tile(id: 0), Tile(id: 2),
            Tile(id: 1), Tile(id: 0), Tile(id: 1), Tile(id: 0),
            Tile(id: 0), Tile(id: 2), Tile(id: 0), Tile(id: 2),
        ]

        let tileMap = Self.buildTileMap(
            width: 4, height: 4, tileset: tileset, tiles: tiles
        )

        renderer.setBackgroundColor(Color(r: 40, g: 40, b: 40))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTileMap(tileMap, position: .zero, camera: Camera2D())
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "empty-tiles")
    }

    @Test("Tile flip X")
    func tileFlipX() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        // Use gradient texture for visible flip effect
        let tex = SnapshotTestUtilities.createGradientTexture(
            renderer: renderer, width: 32, height: 32,
            fromColor: Color(r: 255, g: 0, b: 0),
            toColor: Color(r: 0, g: 0, b: 255)
        )
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 1, firstGid: 1, tileCount: 1)

        let tiles: [Tile] = [
            Tile(id: 1, flipX: false), Tile(id: 1, flipX: true),
            Tile(id: 1, flipX: true),  Tile(id: 1, flipX: false),
        ]

        let tileMap = Self.buildTileMap(
            width: 2, height: 2, tileset: tileset, tiles: tiles
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTileMap(tileMap, position: Vector2(x: 80, y: 56), camera: Camera2D())
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "tile-flip-x")
    }

    @Test("Tile flip Y")
    func tileFlipY() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        // Vertical gradient
        let tex = SnapshotTestUtilities.createGradientTexture(
            renderer: renderer, width: 32, height: 32,
            fromColor: Color(r: 0, g: 255, b: 0),
            toColor: Color(r: 255, g: 0, b: 255)
        )
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 1, firstGid: 1, tileCount: 1)

        let tiles: [Tile] = [
            Tile(id: 1, flipY: false), Tile(id: 1, flipY: false),
            Tile(id: 1, flipY: true),  Tile(id: 1, flipY: true),
        ]

        let tileMap = Self.buildTileMap(
            width: 2, height: 2, tileset: tileset, tiles: tiles
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTileMap(tileMap, position: Vector2(x: 80, y: 56), camera: Camera2D())
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "tile-flip-y")
    }

    @Test("Layer with half opacity")
    func layerOpacity() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = Self.createTilesetTexture(renderer: renderer, tileSize: 32)
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 2, firstGid: 1, tileCount: 2)

        let tiles = [Tile](repeating: Tile(id: 1), count: 4)

        let tileMap = Self.buildTileMap(
            width: 2, height: 2, tileset: tileset, tiles: tiles, opacity: 0.5
        )

        renderer.setBackgroundColor(Color(r: 60, g: 60, b: 60))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTileMap(tileMap, position: Vector2(x: 80, y: 56), camera: Camera2D())
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "layer-opacity")
    }

    @Test("Hidden layer not rendered")
    func hiddenLayer() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = Self.createTilesetTexture(renderer: renderer, tileSize: 32)
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 2, firstGid: 1, tileCount: 2)

        let bottomTiles = [Tile](repeating: Tile(id: 1), count: 4)
        let topTiles = [Tile](repeating: Tile(id: 2), count: 4)

        let bottomLayer = TileLayer(name: "bottom", width: 2, height: 2,
                                    tiles: bottomTiles, visible: true)
        let topLayer = TileLayer(name: "top", width: 2, height: 2,
                                 tiles: topTiles, visible: false)

        let tileMap = TileMap(
            layers: [bottomLayer, topLayer],
            tilesets: [tileset],
            tileWidth: 32, tileHeight: 32,
            width: 2, height: 2
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTileMap(tileMap, position: Vector2(x: 80, y: 56), camera: Camera2D())
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "hidden-layer")
    }

    @Test("Camera culling on larger map")
    func cameraCulling() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = Self.createTilesetTexture(renderer: renderer, tileSize: 32)
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 2, firstGid: 1, tileCount: 2)

        // 10x10 map — larger than viewport at default zoom
        var tiles = [Tile]()
        for row in 0..<10 {
            for col in 0..<10 {
                tiles.append(Tile(id: ((row + col) % 2 == 0) ? 1 : 2))
            }
        }

        let tileMap = Self.buildTileMap(
            width: 10, height: 10, tileset: tileset, tiles: tiles
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.target = Vector2(x: 160, y: 120)
            camera.offset = Vector2(x: 160, y: 120)
            camera.zoom = 0.8
            r.beginCamera(camera)
            r.drawTileMap(tileMap, position: .zero, camera: camera)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "camera-culling")
    }

    @Test("Batched tilemap matches direct draw")
    func batchedTileMap() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = Self.createTilesetTexture(renderer: renderer, tileSize: 32)
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 2, firstGid: 1, tileCount: 2)

        var tiles = [Tile]()
        for row in 0..<4 {
            for col in 0..<4 {
                tiles.append(Tile(id: ((row + col) % 2 == 0) ? 1 : 2))
            }
        }

        let tileMap = Self.buildTileMap(
            width: 4, height: 4, tileset: tileset, tiles: tiles
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let batch = SpriteBatch(sortMode: .byLayer)
            r.batchTileMap(tileMap, into: batch, position: .zero, camera: Camera2D())
            batch.flush(to: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TileMap", name: "tilemap-batched")
    }
}
