@testable import AgilisFormats
import Foundation
import Testing

@Suite("LDtk Parser Tests")
struct LDtkTests {
    @Test func parseMinimalProject() throws {
        let json = """
        {
            "jsonVersion": "1.5.3",
            "defaultPivotX": 0,
            "defaultPivotY": 0,
            "defaultGridSize": 16,
            "levels": [],
            "defs": {
                "layers": [],
                "tilesets": []
            }
        }
        """
        let project = try LDtkLoader().load(from: Data(json.utf8))

        #expect(project.jsonVersion == "1.5.3")
        #expect(project.defaultGridSize == 16)
        #expect(project.defaultPivotX == 0)
        #expect(project.defaultPivotY == 0)
        #expect(project.levels.isEmpty)
        #expect(project.defs.layers.isEmpty)
        #expect(project.defs.tilesets.isEmpty)
    }

    @Test func parseProjectWithLevel() throws {
        let json = """
        {
            "jsonVersion": "1.5.3",
            "defaultPivotX": 0.5,
            "defaultPivotY": 0.5,
            "defaultGridSize": 16,
            "levels": [
                {
                    "identifier": "Level_0",
                    "uid": 0,
                    "pxWid": 256,
                    "pxHei": 256,
                    "worldX": 0,
                    "worldY": 0,
                    "layerInstances": []
                }
            ],
            "defs": {
                "layers": [],
                "tilesets": []
            }
        }
        """
        let project = try LDtkLoader().load(from: Data(json.utf8))

        #expect(project.levels.count == 1)
        #expect(project.levels[0].identifier == "Level_0")
        #expect(project.levels[0].pxWid == 256)
        #expect(project.levels[0].pxHei == 256)
        #expect(project.levels[0].worldX == 0)
    }

    @Test func parseTilesetDefinition() throws {
        let json = """
        {
            "jsonVersion": "1.5.3",
            "defaultPivotX": 0,
            "defaultPivotY": 0,
            "defaultGridSize": 16,
            "levels": [],
            "defs": {
                "layers": [],
                "tilesets": [
                    {
                        "identifier": "Terrain",
                        "uid": 1,
                        "relPath": "terrain.png",
                        "pxWid": 256,
                        "pxHei": 256,
                        "tileGridSize": 16
                    }
                ]
            }
        }
        """
        let project = try LDtkLoader().load(from: Data(json.utf8))

        #expect(project.defs.tilesets.count == 1)
        let tileset = project.defs.tilesets[0]
        #expect(tileset.identifier == "Terrain")
        #expect(tileset.uid == 1)
        #expect(tileset.relPath == "terrain.png")
        #expect(tileset.pxWid == 256)
        #expect(tileset.tileGridSize == 16)
    }

    @Test func parseLayerWithTiles() throws {
        let json = """
        {
            "jsonVersion": "1.5.3",
            "defaultPivotX": 0,
            "defaultPivotY": 0,
            "defaultGridSize": 16,
            "levels": [
                {
                    "identifier": "Level_0",
                    "uid": 0,
                    "pxWid": 32,
                    "pxHei": 32,
                    "worldX": 0,
                    "worldY": 0,
                    "layerInstances": [
                        {
                            "identifier": "Ground",
                            "__type": "Tiles",
                            "__cWid": 2,
                            "__cHei": 2,
                            "__gridSize": 16,
                            "__tilesetDefUid": 1,
                            "__tilesetRelPath": "tiles.png",
                            "gridTiles": [
                                {"px": [0, 0], "src": [0, 0], "f": 0, "t": 0},
                                {"px": [16, 0], "src": [16, 0], "f": 1, "t": 1}
                            ],
                            "autoLayerTiles": [],
                            "intGridCsv": []
                        }
                    ]
                }
            ],
            "defs": {
                "layers": [],
                "tilesets": []
            }
        }
        """
        let project = try LDtkLoader().load(from: Data(json.utf8))
        // swiftlint:disable:next force_unwrapping
        let layer = project.levels[0].layerInstances![0]

        #expect(layer.identifier == "Ground")
        #expect(layer.type == "Tiles")
        #expect(layer.cWid == 2)
        #expect(layer.cHei == 2)
        #expect(layer.gridSize == 16)
        #expect(layer.tilesetDefUid == 1)
        #expect(layer.tilesetRelPath == "tiles.png")
        #expect(layer.gridTiles.count == 2)

        let tile0 = layer.gridTiles[0]
        #expect(tile0.px == [0, 0])
        #expect(tile0.src == [0, 0])
        #expect(tile0.f == 0)

        let tile1 = layer.gridTiles[1]
        #expect(tile1.f == 1) // flipped X
        #expect(tile1.t == 1)
    }

    @Test func loadFromBytes() throws {
        let json = """
        {
            "jsonVersion": "1.0.0",
            "defaultPivotX": 0,
            "defaultPivotY": 0,
            "defaultGridSize": 8,
            "levels": [],
            "defs": {"layers": [], "tilesets": []}
        }
        """
        let bytes = Array(json.utf8)
        let project = try LDtkLoader().load(from: bytes)
        #expect(project.defaultGridSize == 8)
    }
}
