import Foundation

/// Root structure of a Tiled JSON export.
public struct TiledMapData: Codable, Sendable {
    public let width: Int
    public let height: Int
    public let tilewidth: Int
    public let tileheight: Int
    public let layers: [TiledLayerData]
    public let tilesets: [TiledTilesetRef]
    public let orientation: String?
    public let renderorder: String?
}

public struct TiledLayerData: Codable, Sendable {
    public let name: String
    public let type: String // "tilelayer", "objectgroup", "imagelayer", "group"
    public let width: Int?
    public let height: Int?
    // swiftlint:disable:next discouraged_optional_collection
    public let data: [Int]?
    public let visible: Bool
    public let opacity: Float
    public let x: Int
    public let y: Int
}

public struct TiledTilesetRef: Codable, Sendable {
    public let firstgid: Int
    public let source: String?
    // Embedded tileset fields (when not using external .tsj files)
    public let name: String?
    public let tilewidth: Int?
    public let tileheight: Int?
    public let tilecount: Int?
    public let columns: Int?
    public let image: String?
    public let imagewidth: Int?
    public let imageheight: Int?
}

/// Loads and parses Tiled JSON map files.
public struct TiledLoader: Sendable {
    public init() {}

    /// Parse a Tiled JSON map from data.
    public func load(from data: Data) throws -> TiledMapData {
        let decoder = JSONDecoder()
        return try decoder.decode(TiledMapData.self, from: data)
    }

    /// Parse from raw bytes.
    public func load(from bytes: [UInt8]) throws -> TiledMapData {
        try load(from: Data(bytes))
    }
}
