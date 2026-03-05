import Agilis

// MARK: - Tiled → TileMap Bridge

extension TileMap {

    /// Create a TileMap from parsed Tiled JSON data.
    ///
    /// Tiled encodes flip flags in the high bits of tile GIDs:
    /// - Bit 31: horizontal flip
    /// - Bit 30: vertical flip
    /// - Bit 29: diagonal flip (ignored — rotation not supported)
    ///
    /// Lower 28 bits contain the actual tile GID. Empty tiles (GID 0) are
    /// preserved as `Tile.empty`.
    ///
    /// Only layers with `type == "tilelayer"` and non-nil `data` are converted.
    /// Object layers, image layers, and group layers are skipped.
    ///
    /// ## Usage
    /// ```swift
    /// let tiled = try TiledLoader().load(from: jsonData)
    /// let textures = ["tileset.png": renderer.loadTexture("tileset.png")]
    /// let tileMap = TileMap.fromTiled(tiled, textures: textures)
    /// renderer.drawTileMap(tileMap, position: .zero, camera: camera)
    /// ```
    ///
    /// - Parameters:
    ///   - tiled: Parsed Tiled map data.
    ///   - textures: Map from tileset image filename to loaded TextureHandle.
    ///     If a tileset's image is not found, its texture is set to `.invalid`.
    /// - Returns: A TileMap with all tile layers converted.
    public static func fromTiled(
        _ tiled: TiledMapData,
        textures: [String: TextureHandle]
    ) -> TileMap {
        // Convert tilesets
        let tilesets = tiled.tilesets.compactMap { ref -> Tileset? in
            // Only convert embedded tilesets (with columns info)
            guard let columns = ref.columns, columns > 0,
                  let tileWidth = ref.tilewidth,
                  let tileHeight = ref.tileheight else {
                return nil
            }

            let texture: TextureHandle
            if let image = ref.image {
                texture = textures[image] ?? .invalid
            } else {
                texture = .invalid
            }

            return Tileset(
                texture: texture,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                columns: columns,
                firstGid: ref.firstgid,
                tileCount: ref.tilecount ?? 0
            )
        }

        // Convert tile layers
        let layers = tiled.layers.compactMap { layerData -> TileLayer? in
            guard layerData.type == "tilelayer",
                  let data = layerData.data,
                  let width = layerData.width,
                  let height = layerData.height else {
                return nil
            }

            let tiles = data.map { rawGid -> Tile in
                let (gid, flipX, flipY) = _decodeTiledGid(rawGid)
                if gid == 0 {
                    return .empty
                }
                return Tile(id: gid, flipX: flipX, flipY: flipY)
            }

            return TileLayer(
                name: layerData.name,
                width: width,
                height: height,
                tiles: tiles,
                visible: layerData.visible,
                opacity: layerData.opacity
            )
        }

        return TileMap(
            layers: layers,
            tilesets: tilesets,
            tileWidth: tiled.tilewidth,
            tileHeight: tiled.tileheight,
            width: tiled.width,
            height: tiled.height
        )
    }
}

// MARK: - Private Helpers

/// Tiled GID bit masks for flip flags.
private let _flipHorizontal: UInt32 = 0x80000000
private let _flipVertical:   UInt32 = 0x40000000
private let _flipDiagonal:   UInt32 = 0x20000000
private let _gidMask:        UInt32 = 0x1FFFFFFF

/// Decode a Tiled raw GID into the actual tile ID and flip flags.
private func _decodeTiledGid(_ rawGid: Int) -> (gid: Int, flipX: Bool, flipY: Bool) {
    let raw = UInt32(truncatingIfNeeded: rawGid)
    let gid = Int(raw & _gidMask)
    let flipX = (raw & _flipHorizontal) != 0
    let flipY = (raw & _flipVertical) != 0
    return (gid, flipX, flipY)
}
