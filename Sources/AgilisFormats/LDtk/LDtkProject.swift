import Foundation
import Agilis

/// Root structure of an LDtk project file.
public struct LDtkProject: Codable, Sendable {
    public let jsonVersion: String
    public let worldGridWidth: Int?
    public let worldGridHeight: Int?
    public let defaultPivotX: Float
    public let defaultPivotY: Float
    public let defaultGridSize: Int
    public let levels: [LDtkLevel]
    public let defs: LDtkDefinitions
}

public struct LDtkDefinitions: Codable, Sendable {
    public let layers: [LDtkLayerDef]
    public let tilesets: [LDtkTilesetDef]
}

public struct LDtkLayerDef: Codable, Sendable {
    public let identifier: String
    public let uid: Int
    public let type: String // "IntGrid", "Tiles", "Entities", "AutoLayer"
    public let gridSize: Int
    public let tilesetDefUid: Int?

    enum CodingKeys: String, CodingKey {
        case identifier, uid, type = "__type", gridSize, tilesetDefUid
    }
}

public struct LDtkTilesetDef: Codable, Sendable {
    public let identifier: String
    public let uid: Int
    public let relPath: String?
    public let pxWid: Int
    public let pxHei: Int
    public let tileGridSize: Int
}

public struct LDtkLevel: Codable, Sendable {
    public let identifier: String
    public let uid: Int
    public let pxWid: Int
    public let pxHei: Int
    public let worldX: Int
    public let worldY: Int
    public let layerInstances: [LDtkLayerInstance]?
}

public struct LDtkLayerInstance: Codable, Sendable {
    public let identifier: String
    public let type: String
    public let cWid: Int
    public let cHei: Int
    public let gridSize: Int
    public let tilesetDefUid: Int?
    public let tilesetRelPath: String?
    public let gridTiles: [LDtkTileInstance]
    public let autoLayerTiles: [LDtkTileInstance]
    public let intGridCsv: [Int]

    enum CodingKeys: String, CodingKey {
        case identifier
        case type = "__type"
        case cWid = "__cWid"
        case cHei = "__cHei"
        case gridSize = "__gridSize"
        case tilesetDefUid = "__tilesetDefUid"
        case tilesetRelPath = "__tilesetRelPath"
        case gridTiles, autoLayerTiles, intGridCsv
    }
}

public struct LDtkTileInstance: Codable, Sendable {
    /// Pixel coordinates in the layer [x, y].
    public let px: [Int]
    /// Pixel coordinates in the tileset [x, y].
    public let src: [Int]
    /// Flip flags: 0=none, 1=X, 2=Y, 3=both.
    public let f: Int
    /// Tile ID.
    public let t: Int
}
