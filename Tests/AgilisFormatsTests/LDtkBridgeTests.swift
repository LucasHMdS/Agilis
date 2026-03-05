import Testing
import Foundation
@testable import AgilisFormats
@testable import Agilis

// MARK: - LDtk Bridge Tests

@Suite("LDtk Bridge Tests")
struct LDtkBridgeTests {

    // MARK: - Helpers

    /// Create a minimal LDtk project JSON and parse it.
    private func makeLDtkProject(
        gridSize: Int = 16,
        tilesets: [(uid: Int, relPath: String, pxWid: Int, pxHei: Int, tileGridSize: Int)] = [
            (uid: 1, relPath: "tiles.png", pxWid: 64, pxHei: 64, tileGridSize: 16)
        ],
        levels: [String]
    ) -> Data {
        let tilesetDefs = tilesets.map { ts in
            """
            {
                "identifier": "Tileset_\(ts.uid)",
                "uid": \(ts.uid),
                "relPath": "\(ts.relPath)",
                "pxWid": \(ts.pxWid),
                "pxHei": \(ts.pxHei),
                "tileGridSize": \(ts.tileGridSize)
            }
            """
        }.joined(separator: ",\n")

        let json = """
        {
            "jsonVersion": "1.0.0",
            "worldGridWidth": null,
            "worldGridHeight": null,
            "defaultPivotX": 0,
            "defaultPivotY": 0,
            "defaultGridSize": \(gridSize),
            "levels": [\(levels.joined(separator: ",\n"))],
            "defs": {
                "layers": [],
                "tilesets": [\(tilesetDefs)]
            }
        }
        """
        return Data(json.utf8)
    }

    private func levelJSON(
        identifier: String = "Level_0",
        uid: Int = 0,
        pxWid: Int = 48,
        pxHei: Int = 32,
        layers: [String]
    ) -> String {
        return """
        {
            "identifier": "\(identifier)",
            "uid": \(uid),
            "pxWid": \(pxWid),
            "pxHei": \(pxHei),
            "worldX": 0,
            "worldY": 0,
            "layerInstances": [\(layers.joined(separator: ",\n"))]
        }
        """
    }

    private func tileLayerJSON(
        identifier: String = "Tiles",
        cWid: Int = 3,
        cHei: Int = 2,
        gridSize: Int = 16,
        tilesetDefUid: Int = 1,
        tilesetRelPath: String = "tiles.png",
        gridTiles: [(px0: Int, px1: Int, src0: Int, src1: Int, f: Int, t: Int)] = [],
        autoLayerTiles: [(px0: Int, px1: Int, src0: Int, src1: Int, f: Int, t: Int)] = []
    ) -> String {
        let gridTilesJSON = gridTiles.map { tile in
            """
            {"px": [\(tile.px0), \(tile.px1)], "src": [\(tile.src0), \(tile.src1)], "f": \(tile.f), "t": \(tile.t)}
            """
        }.joined(separator: ",\n")

        let autoTilesJSON = autoLayerTiles.map { tile in
            """
            {"px": [\(tile.px0), \(tile.px1)], "src": [\(tile.src0), \(tile.src1)], "f": \(tile.f), "t": \(tile.t)}
            """
        }.joined(separator: ",\n")

        return """
        {
            "identifier": "\(identifier)",
            "__type": "Tiles",
            "__cWid": \(cWid),
            "__cHei": \(cHei),
            "__gridSize": \(gridSize),
            "__tilesetDefUid": \(tilesetDefUid),
            "__tilesetRelPath": "\(tilesetRelPath)",
            "gridTiles": [\(gridTilesJSON)],
            "autoLayerTiles": [\(autoTilesJSON)],
            "intGridCsv": []
        }
        """
    }

    // MARK: - Tests

    @Test("Basic level conversion with gridTiles")
    func basicLevelConversion() throws {
        let data = makeLDtkProject(
            levels: [
                levelJSON(layers: [
                    tileLayerJSON(gridTiles: [
                        (px0: 0, px1: 0, src0: 0, src1: 0, f: 0, t: 0),
                        (px0: 16, px1: 0, src0: 16, src1: 0, f: 0, t: 1),
                        (px0: 32, px1: 0, src0: 32, src1: 0, f: 0, t: 2),
                        (px0: 0, px1: 16, src0: 0, src1: 16, f: 0, t: 4),
                    ])
                ])
            ]
        )
        let project = try LDtkLoader().load(from: data)
        let textures: [String: TextureHandle] = ["tiles.png": TextureHandle(id: 1)]
        let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: textures)

        #expect(tileMap.tileWidth == 16)
        #expect(tileMap.tileHeight == 16)
        #expect(tileMap.width == 3)
        #expect(tileMap.height == 2)
        #expect(tileMap.layers.count == 1)

        let layer = tileMap.layers[0]
        #expect(layer.name == "Tiles")
        #expect(layer.width == 3)
        #expect(layer.height == 2)

        // Tile at (0,0): t=0, stored as id=1 (offset by +1)
        #expect(layer.tile(atColumn: 0, row: 0)?.id == 1)
        // Tile at (1,0): t=1, stored as id=2
        #expect(layer.tile(atColumn: 1, row: 0)?.id == 2)
        // Tile at (2,0): t=2, stored as id=3
        #expect(layer.tile(atColumn: 2, row: 0)?.id == 3)
        // Tile at (0,1): t=4, stored as id=5
        #expect(layer.tile(atColumn: 0, row: 1)?.id == 5)
        // Tile at (1,1): empty (not set)
        #expect(layer.tile(atColumn: 1, row: 1)?.id == 0)
    }

    @Test("Pixel-to-grid coordinate conversion")
    func pixelToGridConversion() throws {
        // Use 32px grid to test that px coordinates are divided by gridSize
        let data = makeLDtkProject(
            gridSize: 32,
            tilesets: [
                (uid: 1, relPath: "tiles.png", pxWid: 128, pxHei: 128, tileGridSize: 32)
            ],
            levels: [
                levelJSON(pxWid: 128, pxHei: 64, layers: [
                    tileLayerJSON(cWid: 4, cHei: 2, gridSize: 32, gridTiles: [
                        (px0: 0, px1: 0, src0: 0, src1: 0, f: 0, t: 0),
                        (px0: 96, px1: 32, src0: 96, src1: 32, f: 0, t: 7),
                    ])
                ])
            ]
        )
        let project = try LDtkLoader().load(from: data)
        let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: ["tiles.png": TextureHandle(id: 1)])

        let layer = tileMap.layers[0]
        // px=(0,0) / 32 = col=0, row=0
        #expect(layer.tile(atColumn: 0, row: 0)?.id == 1)
        // px=(96,32) / 32 = col=3, row=1
        #expect(layer.tile(atColumn: 3, row: 1)?.id == 8)
    }

    @Test("Flip flag decoding: f=0,1,2,3")
    func flipFlagDecoding() throws {
        let data = makeLDtkProject(
            levels: [
                levelJSON(layers: [
                    tileLayerJSON(cWid: 4, cHei: 1, gridTiles: [
                        (px0: 0, px1: 0, src0: 0, src1: 0, f: 0, t: 0),  // no flip
                        (px0: 16, px1: 0, src0: 0, src1: 0, f: 1, t: 0), // flipX
                        (px0: 32, px1: 0, src0: 0, src1: 0, f: 2, t: 0), // flipY
                        (px0: 48, px1: 0, src0: 0, src1: 0, f: 3, t: 0), // both
                    ])
                ])
            ]
        )
        let project = try LDtkLoader().load(from: data)
        let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: ["tiles.png": TextureHandle(id: 1)])

        let tiles = tileMap.layers[0].tiles
        // f=0: no flip
        #expect(tiles[0].flipX == false)
        #expect(tiles[0].flipY == false)
        // f=1: flipX
        #expect(tiles[1].flipX == true)
        #expect(tiles[1].flipY == false)
        // f=2: flipY
        #expect(tiles[2].flipX == false)
        #expect(tiles[2].flipY == true)
        // f=3: both
        #expect(tiles[3].flipX == true)
        #expect(tiles[3].flipY == true)
    }

    @Test("AutoLayerTiles included when gridTiles is empty")
    func autoLayerTilesIncluded() throws {
        let data = makeLDtkProject(
            levels: [
                levelJSON(layers: [
                    tileLayerJSON(autoLayerTiles: [
                        (px0: 0, px1: 0, src0: 0, src1: 0, f: 0, t: 0),
                        (px0: 16, px1: 0, src0: 16, src1: 0, f: 0, t: 1),
                    ])
                ])
            ]
        )
        let project = try LDtkLoader().load(from: data)
        let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: ["tiles.png": TextureHandle(id: 1)])

        #expect(tileMap.layers.count == 1)
        #expect(tileMap.layers[0].tile(atColumn: 0, row: 0)?.id == 1)
        #expect(tileMap.layers[0].tile(atColumn: 1, row: 0)?.id == 2)
    }

    @Test("Layer ordering reversed from LDtk order")
    func layerOrderingReversed() throws {
        let data = makeLDtkProject(
            levels: [
                levelJSON(layers: [
                    tileLayerJSON(identifier: "TopLayer", gridTiles: [
                        (px0: 0, px1: 0, src0: 0, src1: 0, f: 0, t: 0),
                    ]),
                    tileLayerJSON(identifier: "BottomLayer", gridTiles: [
                        (px0: 0, px1: 0, src0: 16, src1: 0, f: 0, t: 1),
                    ])
                ])
            ]
        )
        let project = try LDtkLoader().load(from: data)
        let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: ["tiles.png": TextureHandle(id: 1)])

        // LDtk: TopLayer is first (index 0), BottomLayer is second (index 1)
        // After reversal: BottomLayer should be index 0, TopLayer should be index 1
        #expect(tileMap.layers.count == 2)
        #expect(tileMap.layers[0].name == "BottomLayer")
        #expect(tileMap.layers[1].name == "TopLayer")
    }

    @Test("Missing tileset texture handled gracefully")
    func missingTilesetTexture() throws {
        let data = makeLDtkProject(
            levels: [
                levelJSON(layers: [
                    tileLayerJSON(gridTiles: [
                        (px0: 0, px1: 0, src0: 0, src1: 0, f: 0, t: 0),
                    ])
                ])
            ]
        )
        let project = try LDtkLoader().load(from: data)
        // Provide empty textures map — no "tiles.png"
        let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: [:])

        #expect(tileMap.tilesets.count == 1)
        #expect(tileMap.tilesets[0].texture == .invalid)
        // Layer data should still be present
        #expect(tileMap.layers.count == 1)
    }

    @Test("Empty level produces empty TileMap")
    func emptyLevel() throws {
        let levelStr = """
        {
            "identifier": "Empty",
            "uid": 0,
            "pxWid": 48,
            "pxHei": 32,
            "worldX": 0,
            "worldY": 0,
            "layerInstances": []
        }
        """
        let data = makeLDtkProject(levels: [levelStr])
        let project = try LDtkLoader().load(from: data)
        let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: [:])

        #expect(tileMap.layers.isEmpty)
        #expect(tileMap.tilesets.isEmpty)
    }
}
