@testable import Agilis
import Testing

@Suite("Tile Tests")
struct TileTests {
    @Test func emptyTile() {
        let tile = Tile.empty
        #expect(tile.id == 0)
        #expect(!tile.flipX)
        #expect(!tile.flipY)
    }

    @Test func tileWithFlip() {
        let tile = Tile(id: 5, flipX: true, flipY: false)
        #expect(tile.id == 5)
        #expect(tile.flipX)
        #expect(!tile.flipY)
    }

    @Test func tileHashable() {
        let a = Tile(id: 1)
        let b = Tile(id: 1)
        let c = Tile(id: 2)
        #expect(a == b)
        #expect(a != c)

        let set: Set<Tile> = [a, b, c]
        #expect(set.count == 2)
    }
}

@Suite("Tileset Tests")
struct TilesetTests {
    @Test func sourceRectFirstTile() {
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 16,
            tileHeight: 16,
            columns: 10,
            firstGid: 1
        )

        let rect = tileset.sourceRect(for: 1) // first tile
        #expect(rect.x == 0)
        #expect(rect.y == 0)
        #expect(rect.width == 16)
        #expect(rect.height == 16)
    }

    @Test func sourceRectNthTile() {
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 16,
            tileHeight: 16,
            columns: 10,
            firstGid: 1
        )

        // Tile 12 = localId 11 = row 1, col 1
        let rect = tileset.sourceRect(for: 12)
        #expect(rect.x == 16)  // col 1 * 16
        #expect(rect.y == 16)  // row 1 * 16
    }

    @Test func sourceRectWithOffset() {
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 32,
            tileHeight: 32,
            columns: 4,
            firstGid: 50
        )

        // Tile 52 = localId 2 = row 0, col 2
        let rect = tileset.sourceRect(for: 52)
        #expect(rect.x == 64)
        #expect(rect.y == 0)
        #expect(rect.width == 32)
        #expect(rect.height == 32)
    }

    @Test func sourceRectBelowFirstGid() {
        let tileset = Tileset(
            texture: TextureHandle(id: 1),
            tileWidth: 16,
            tileHeight: 16,
            columns: 10,
            firstGid: 10
        )

        // Tile ID below firstGid should return empty rect
        let rect = tileset.sourceRect(for: 5)
        #expect(rect.width == 0)
        #expect(rect.height == 0)
    }
}

@Suite("TileLayer Tests")
struct TileLayerTests {
    @Test func tileAtPosition() {
        let tiles = [
            Tile(id: 1), Tile(id: 2), Tile(id: 3),
            Tile(id: 4), Tile(id: 5), Tile(id: 6)
        ]
        let layer = TileLayer(name: "ground", width: 3, height: 2, tiles: tiles)

        #expect(layer.tile(atColumn: 0, row: 0)?.id == 1)
        #expect(layer.tile(atColumn: 2, row: 0)?.id == 3)
        #expect(layer.tile(atColumn: 0, row: 1)?.id == 4)
        #expect(layer.tile(atColumn: 2, row: 1)?.id == 6)
    }

    @Test func tileOutOfBounds() {
        let layer = TileLayer(name: "test", width: 2, height: 2, tiles: [
            Tile(id: 1), Tile(id: 2),
            Tile(id: 3), Tile(id: 4)
        ])

        #expect(layer.tile(atColumn: -1, row: 0) == nil)
        #expect(layer.tile(atColumn: 2, row: 0) == nil)
        #expect(layer.tile(atColumn: 0, row: -1) == nil)
        #expect(layer.tile(atColumn: 0, row: 2) == nil)
    }

    @Test func layerDefaults() {
        let layer = TileLayer(name: "layer1", width: 1, height: 1, tiles: [Tile(id: 1)])
        #expect(layer.visible)
        #expect(layer.opacity == 1.0)
    }
}
