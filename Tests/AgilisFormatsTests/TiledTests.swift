@testable import AgilisFormats
import Foundation
import Testing

@Suite("Tiled JSON Parser Tests")
struct TiledTests {
    @Test func parseMinimalMap() throws {
        let json = """
        {
            "width": 10,
            "height": 8,
            "tilewidth": 16,
            "tileheight": 16,
            "layers": [],
            "tilesets": []
        }
        """
        let map = try TiledLoader().load(from: Data(json.utf8))

        #expect(map.width == 10)
        #expect(map.height == 8)
        #expect(map.tilewidth == 16)
        #expect(map.tileheight == 16)
        #expect(map.layers.isEmpty)
        #expect(map.tilesets.isEmpty)
    }

    @Test func parseTileLayer() throws {
        let json = """
        {
            "width": 3,
            "height": 2,
            "tilewidth": 16,
            "tileheight": 16,
            "layers": [
                {
                    "name": "Ground",
                    "type": "tilelayer",
                    "width": 3,
                    "height": 2,
                    "data": [1, 2, 3, 4, 5, 6],
                    "visible": true,
                    "opacity": 1.0,
                    "x": 0,
                    "y": 0
                }
            ],
            "tilesets": []
        }
        """
        let map = try TiledLoader().load(from: Data(json.utf8))

        #expect(map.layers.count == 1)
        let layer = map.layers[0]
        #expect(layer.name == "Ground")
        #expect(layer.type == "tilelayer")
        #expect(layer.width == 3)
        #expect(layer.height == 2)
        #expect(layer.data == [1, 2, 3, 4, 5, 6])
        #expect(layer.visible)
        #expect(layer.opacity == 1.0)
    }

    @Test func parseHiddenLayer() throws {
        let json = """
        {
            "width": 1,
            "height": 1,
            "tilewidth": 16,
            "tileheight": 16,
            "layers": [
                {
                    "name": "Collision",
                    "type": "tilelayer",
                    "width": 1,
                    "height": 1,
                    "data": [1],
                    "visible": false,
                    "opacity": 0.5,
                    "x": 0,
                    "y": 0
                }
            ],
            "tilesets": []
        }
        """
        let map = try TiledLoader().load(from: Data(json.utf8))
        let layer = map.layers[0]
        #expect(!layer.visible)
        #expect(layer.opacity == 0.5)
    }

    @Test func parseTilesetReference() throws {
        let json = """
        {
            "width": 1,
            "height": 1,
            "tilewidth": 16,
            "tileheight": 16,
            "layers": [],
            "tilesets": [
                {
                    "firstgid": 1,
                    "name": "terrain",
                    "tilewidth": 16,
                    "tileheight": 16,
                    "tilecount": 100,
                    "columns": 10,
                    "image": "terrain.png",
                    "imagewidth": 160,
                    "imageheight": 160
                }
            ]
        }
        """
        let map = try TiledLoader().load(from: Data(json.utf8))

        #expect(map.tilesets.count == 1)
        let ts = map.tilesets[0]
        #expect(ts.firstgid == 1)
        #expect(ts.name == "terrain")
        #expect(ts.tilewidth == 16)
        #expect(ts.columns == 10)
        #expect(ts.image == "terrain.png")
        #expect(ts.tilecount == 100)
    }

    @Test func parseExternalTilesetRef() throws {
        let json = """
        {
            "width": 1,
            "height": 1,
            "tilewidth": 16,
            "tileheight": 16,
            "layers": [],
            "tilesets": [
                {
                    "firstgid": 1,
                    "source": "terrain.tsj"
                }
            ]
        }
        """
        let map = try TiledLoader().load(from: Data(json.utf8))
        let ts = map.tilesets[0]
        #expect(ts.firstgid == 1)
        #expect(ts.source == "terrain.tsj")
        #expect(ts.name == nil)
    }

    @Test func parseOptionalFields() throws {
        let json = """
        {
            "width": 10,
            "height": 10,
            "tilewidth": 32,
            "tileheight": 32,
            "orientation": "orthogonal",
            "renderorder": "right-down",
            "layers": [],
            "tilesets": []
        }
        """
        let map = try TiledLoader().load(from: Data(json.utf8))
        #expect(map.orientation == "orthogonal")
        #expect(map.renderorder == "right-down")
    }

    @Test func loadFromBytes() throws {
        let json = """
        {"width":5,"height":5,"tilewidth":8,"tileheight":8,"layers":[],"tilesets":[]}
        """
        let map = try TiledLoader().load(from: Array(json.utf8))
        #expect(map.width == 5)
        #expect(map.tilewidth == 8)
    }
}
