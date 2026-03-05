import AgilisCore

/// A tile within a tilemap layer.
public struct Tile: Sendable, Hashable {
    /// The tile ID (index into the tileset). 0 typically means empty.
    public var id: Int

    /// Whether the tile is flipped horizontally.
    public var flipX: Bool

    /// Whether the tile is flipped vertically.
    public var flipY: Bool

    public init(id: Int = 0, flipX: Bool = false, flipY: Bool = false) {
        self.id = id
        self.flipX = flipX
        self.flipY = flipY
    }

    public static let empty = Tile(id: 0)
}

/// A tileset associates tile IDs with a texture atlas.
public struct Tileset: Sendable {
    public var texture: TextureHandle
    public var tileWidth: Int
    public var tileHeight: Int
    public var columns: Int
    public var firstGid: Int
    public var tileCount: Int

    public init(
        texture: TextureHandle,
        tileWidth: Int,
        tileHeight: Int,
        columns: Int,
        firstGid: Int = 1,
        tileCount: Int = 0
    ) {
        self.texture = texture
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.columns = columns
        self.firstGid = firstGid
        self.tileCount = tileCount
    }

    /// Returns the source rectangle in the texture for a given tile ID.
    public func sourceRect(for tileId: Int) -> Rect {
        let localId = tileId - firstGid
        guard localId >= 0 else { return Rect() }
        let col = localId % columns
        let row = localId / columns
        return Rect(
            x: Float(col * tileWidth),
            y: Float(row * tileHeight),
            width: Float(tileWidth),
            height: Float(tileHeight)
        )
    }
}

/// A single layer of tiles in a tilemap.
public struct TileLayer: Sendable {
    public var name: String
    public var width: Int
    public var height: Int
    public var tiles: [Tile]
    public var visible: Bool
    public var opacity: Float

    public init(
        name: String,
        width: Int,
        height: Int,
        tiles: [Tile],
        visible: Bool = true,
        opacity: Float = 1.0
    ) {
        self.name = name
        self.width = width
        self.height = height
        self.tiles = tiles
        self.visible = visible
        self.opacity = opacity
    }

    /// Get the tile at a grid position, or nil if out of bounds.
    public func tile(atColumn col: Int, row: Int) -> Tile? {
        guard col >= 0, col < width, row >= 0, row < height else { return nil }
        return tiles[row * width + col]
    }
}

/// A complete tilemap with layers and tilesets.
public struct TileMap: Sendable {
    public var layers: [TileLayer]
    public var tilesets: [Tileset]
    public var tileWidth: Int
    public var tileHeight: Int
    public var width: Int
    public var height: Int

    public init(
        layers: [TileLayer],
        tilesets: [Tileset],
        tileWidth: Int,
        tileHeight: Int,
        width: Int,
        height: Int
    ) {
        self.layers = layers
        self.tilesets = tilesets
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.width = width
        self.height = height
    }
}
