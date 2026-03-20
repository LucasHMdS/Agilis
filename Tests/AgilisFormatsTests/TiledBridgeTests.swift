@testable import Agilis
@testable import AgilisFormats
import Foundation
import Testing

// MARK: - Tiled Bridge Tests

@Suite("Tiled Bridge Tests")
struct TiledBridgeTests {

    // MARK: - Helpers

    private func makeTiledJSON(
        width: Int = 3,
        height: Int = 2,
        tilewidth: Int = 16,
        tileheight: Int = 16,
        layers: [String],
        tilesets: [String]
    ) -> Data {
        let json = """
        {
            "width": \(width),
            "height": \(height),
            "tilewidth": \(tilewidth),
            "tileheight": \(tileheight),
            "orientation": "orthogonal",
            "renderorder": "right-down",
            "layers": [\(layers.joined(separator: ",\n"))],
            "tilesets": [\(tilesets.joined(separator: ",\n"))]
        }
        """
        return Data(json.utf8)
    }

    private func tileLayerJSON(
        name: String = "ground",
        width: Int = 3,
        height: Int = 2,
        data: [Int],
        visible: Bool = true,
        opacity: Float = 1.0
    ) -> String {
        let dataStr = data.map { String($0) }.joined(separator: ",")
        return """
        {
            "name": "\(name)",
            "type": "tilelayer",
            "width": \(width),
            "height": \(height),
            "data": [\(dataStr)],
            "visible": \(visible),
            "opacity": \(opacity),
            "x": 0,
            "y": 0
        }
        """
    }

    private func objectLayerJSON(name: String = "objects") -> String {
        """
        {
            "name": "\(name)",
            "type": "objectgroup",
            "width": 0,
            "height": 0,
            "visible": true,
            "opacity": 1.0,
            "x": 0,
            "y": 0
        }
        """
    }

    private func tilesetJSON(
        firstgid: Int = 1,
        name: String = "tiles",
        tilewidth: Int = 16,
        tileheight: Int = 16,
        columns: Int = 4,
        tilecount: Int = 16,
        image: String = "tiles.png",
        imagewidth: Int = 64,
        imageheight: Int = 64
    ) -> String {
        """
        {
            "firstgid": \(firstgid),
            "name": "\(name)",
            "tilewidth": \(tilewidth),
            "tileheight": \(tileheight),
            "columns": \(columns),
            "tilecount": \(tilecount),
            "image": "\(image)",
            "imagewidth": \(imagewidth),
            "imageheight": \(imageheight)
        }
        """
    }

    // MARK: - Basic Conversion Tests

    @Test("Basic layer conversion preserves tile IDs and dimensions")
    func basicLayerConversion() throws {
        let data = makeTiledJSON(
            layers: [
                tileLayerJSON(data: [1, 2, 3, 4, 5, 6])
            ],
            tilesets: [
                tilesetJSON()
            ]
        )
        let tiled = try TiledLoader().load(from: data)
        let textures: [String: TextureHandle] = ["tiles.png": TextureHandle(id: 1)]

        let tileMap = TileMap.fromTiled(tiled, textures: textures)

        #expect(tileMap.width == 3)
        #expect(tileMap.height == 2)
        #expect(tileMap.tileWidth == 16)
        #expect(tileMap.tileHeight == 16)
        #expect(tileMap.layers.count == 1)
        #expect(tileMap.tilesets.count == 1)

        let layer = tileMap.layers[0]
        #expect(layer.name == "ground")
        #expect(layer.width == 3)
        #expect(layer.height == 2)
        #expect(layer.tiles.count == 6)
        #expect(layer.tiles[0].id == 1)
        #expect(layer.tiles[1].id == 2)
        #expect(layer.tiles[5].id == 6)
    }

    @Test("GID flip bit decoding extracts flipX and flipY")
    func gidFlipBitDecoding() throws {
        // Bit 31 = flipX, Bit 30 = flipY
        // flipX only: 0x80000000 | 5 = 2147483653
        let flipXGid = Int(bitPattern: UInt(0x80000000 | 5))
        // flipY only: 0x40000000 | 5 = 1073741829
        let flipYGid = Int(bitPattern: UInt(0x40000000 | 5))
        // Both flips: 0xC0000000 | 5 = 3221225477
        let flipBothGid = Int(bitPattern: UInt(0xC0000000 | 5))

        let data = makeTiledJSON(
            width: 4,
            height: 1,
            layers: [
                tileLayerJSON(width: 4, height: 1, data: [5, flipXGid, flipYGid, flipBothGid])
            ],
            tilesets: [tilesetJSON()]
        )
        let tiled = try TiledLoader().load(from: data)
        let tileMap = TileMap.fromTiled(tiled, textures: ["tiles.png": TextureHandle(id: 1)])

        let tiles = tileMap.layers[0].tiles
        // Normal tile
        #expect(tiles[0].id == 5)
        #expect(tiles[0].flipX == false)
        #expect(tiles[0].flipY == false)
        // FlipX only
        #expect(tiles[1].id == 5)
        #expect(tiles[1].flipX == true)
        #expect(tiles[1].flipY == false)
        // FlipY only
        #expect(tiles[2].id == 5)
        #expect(tiles[2].flipX == false)
        #expect(tiles[2].flipY == true)
        // Both flips
        #expect(tiles[3].id == 5)
        #expect(tiles[3].flipX == true)
        #expect(tiles[3].flipY == true)
    }

    @Test("Empty tiles (GID 0) preserved as Tile.empty")
    func emptyTilesPreserved() throws {
        let data = makeTiledJSON(
            width: 3,
            height: 1,
            layers: [
                tileLayerJSON(width: 3, height: 1, data: [1, 0, 3])
            ],
            tilesets: [tilesetJSON()]
        )
        let tiled = try TiledLoader().load(from: data)
        let tileMap = TileMap.fromTiled(tiled, textures: ["tiles.png": TextureHandle(id: 1)])

        let tiles = tileMap.layers[0].tiles
        #expect(tiles[0].id == 1)
        #expect(tiles[1].id == 0) // empty
        #expect(tiles[2].id == 3)
    }

    @Test("Multiple tilesets with different firstGid")
    func multipleTilesets() throws {
        let data = makeTiledJSON(
            layers: [
                tileLayerJSON(data: [1, 2, 17, 18, 0, 3])
            ],
            tilesets: [
                tilesetJSON(firstgid: 1, name: "ground", image: "ground.png"),
                tilesetJSON(firstgid: 17, name: "objects", columns: 8, tilecount: 32, image: "objects.png")
            ]
        )
        let tiled = try TiledLoader().load(from: data)
        let textures: [String: TextureHandle] = [
            "ground.png": TextureHandle(id: 1),
            "objects.png": TextureHandle(id: 2)
        ]

        let tileMap = TileMap.fromTiled(tiled, textures: textures)

        #expect(tileMap.tilesets.count == 2)
        #expect(tileMap.tilesets[0].firstGid == 1)
        #expect(tileMap.tilesets[0].texture == TextureHandle(id: 1))
        #expect(tileMap.tilesets[1].firstGid == 17)
        #expect(tileMap.tilesets[1].texture == TextureHandle(id: 2))
        #expect(tileMap.tilesets[1].columns == 8)
    }

    @Test("Only tilelayer type is converted, objectgroup skipped")
    func onlyTileLayersConverted() throws {
        let data = makeTiledJSON(
            layers: [
                tileLayerJSON(name: "ground", data: [1, 2, 3, 4, 5, 6]),
                objectLayerJSON(name: "enemies"),
                tileLayerJSON(name: "foreground", data: [0, 0, 7, 8, 0, 0])
            ],
            tilesets: [tilesetJSON()]
        )
        let tiled = try TiledLoader().load(from: data)
        let tileMap = TileMap.fromTiled(tiled, textures: ["tiles.png": TextureHandle(id: 1)])

        #expect(tileMap.layers.count == 2)
        #expect(tileMap.layers[0].name == "ground")
        #expect(tileMap.layers[1].name == "foreground")
    }

    @Test("Missing texture returns .invalid handle in tileset")
    func missingTextureReturnsInvalid() throws {
        let data = makeTiledJSON(
            layers: [
                tileLayerJSON(data: [1, 2, 3, 4, 5, 6])
            ],
            tilesets: [
                tilesetJSON(image: "missing.png")
            ]
        )
        let tiled = try TiledLoader().load(from: data)
        // Provide empty textures map
        let tileMap = TileMap.fromTiled(tiled, textures: [:])

        #expect(tileMap.tilesets.count == 1)
        #expect(tileMap.tilesets[0].texture == .invalid)
    }

    @Test("Layer visibility and opacity preserved")
    func layerVisibilityAndOpacity() throws {
        let data = makeTiledJSON(
            layers: [
                tileLayerJSON(name: "visible", data: [1, 2, 3, 4, 5, 6], visible: true, opacity: 0.75),
                tileLayerJSON(name: "hidden", data: [1, 2, 3, 4, 5, 6], visible: false, opacity: 0.5)
            ],
            tilesets: [tilesetJSON()]
        )
        let tiled = try TiledLoader().load(from: data)
        let tileMap = TileMap.fromTiled(tiled, textures: ["tiles.png": TextureHandle(id: 1)])

        #expect(tileMap.layers[0].visible == true)
        #expect(abs(tileMap.layers[0].opacity - 0.75) < 0.001)
        #expect(tileMap.layers[1].visible == false)
        #expect(abs(tileMap.layers[1].opacity - 0.5) < 0.001)
    }

    @Test("Tileset properties preserved correctly")
    func tilesetPropertiesPreserved() throws {
        let data = makeTiledJSON(
            tilewidth: 32,
            tileheight: 32,
            layers: [
                tileLayerJSON(data: [1, 2, 3, 4, 5, 6])
            ],
            tilesets: [
                tilesetJSON(firstgid: 1, tilewidth: 32, tileheight: 32, columns: 8, tilecount: 64, image: "big.png")
            ]
        )
        let tiled = try TiledLoader().load(from: data)
        let tileMap = TileMap.fromTiled(tiled, textures: ["big.png": TextureHandle(id: 5)])

        let ts = tileMap.tilesets[0]
        #expect(ts.tileWidth == 32)
        #expect(ts.tileHeight == 32)
        #expect(ts.columns == 8)
        #expect(ts.firstGid == 1)
        #expect(ts.tileCount == 64)
        #expect(ts.texture == TextureHandle(id: 5))
    }
}
