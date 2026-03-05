import Agilis

// MARK: - LDtk → TileMap Bridge

extension TileMap {

    /// Create a TileMap from a single LDtk level.
    ///
    /// LDtk tiles use pixel coordinates (`px` for position, `src` for texture
    /// source) rather than grid indices. This bridge converts them to the
    /// grid-based `TileMap` format:
    /// - Position: `col = px[0] / gridSize`, `row = px[1] / gridSize`
    /// - Source rect: computed via `Tileset.sourceRect(for:)` using the tile's `t` field
    /// - Flip flags: `f` field (0=none, 1=flipX, 2=flipY, 3=both)
    ///
    /// Both `gridTiles` and `autoLayerTiles` are included. Layers are reversed
    /// from LDtk order (top-to-bottom) so index 0 = bottom layer, matching
    /// Tiled convention and draw order.
    ///
    /// ## Usage
    /// ```swift
    /// let project = try LDtkLoader().load(from: jsonData)
    /// let textures = ["tileset.png": renderer.loadTexture("tileset.png")]
    /// let level = project.levels[0]
    /// let tileMap = TileMap.fromLDtk(level: level, project: project, textures: textures)
    /// renderer.drawTileMap(tileMap, position: .zero, camera: camera)
    /// ```
    ///
    /// - Parameters:
    ///   - level: The LDtk level to convert.
    ///   - project: The parent LDtk project (for tileset definitions).
    ///   - textures: Map from tileset relative path to loaded TextureHandle.
    ///     If a tileset's relPath is not found, its texture is set to `.invalid`.
    /// - Returns: A TileMap with tile layers from gridTiles and autoLayerTiles.
    public static func fromLDtk(
        level: LDtkLevel,
        project: LDtkProject,
        textures: [String: TextureHandle]
    ) -> TileMap {
        guard let layerInstances = level.layerInstances else {
            return TileMap(layers: [], tilesets: [], tileWidth: project.defaultGridSize,
                           tileHeight: project.defaultGridSize, width: 0, height: 0)
        }

        // Build tileset lookup: uid → (LDtkTilesetDef, TextureHandle)
        var tilesetLookup: [Int: (def: LDtkTilesetDef, texture: TextureHandle)] = [:]
        for tsDef in project.defs.tilesets {
            let texture: TextureHandle
            if let relPath = tsDef.relPath {
                texture = textures[relPath] ?? .invalid
            } else {
                texture = .invalid
            }
            tilesetLookup[tsDef.uid] = (tsDef, texture)
        }

        // Determine the map grid size from the level pixel dimensions and the default grid
        let gridSize = project.defaultGridSize
        let mapWidth = level.pxWid / max(1, gridSize)
        let mapHeight = level.pxHei / max(1, gridSize)

        // Collect tilesets that are actually referenced
        var referencedTilesetUids = Set<Int>()

        // Convert layers (reversed: LDtk is top-to-bottom, we want bottom-to-top)
        var tileLayers: [TileLayer] = []

        for layerInstance in layerInstances.reversed() {
            // Merge gridTiles and autoLayerTiles
            let allTiles: [LDtkTileInstance]
            if !layerInstance.gridTiles.isEmpty {
                allTiles = layerInstance.gridTiles
            } else if !layerInstance.autoLayerTiles.isEmpty {
                allTiles = layerInstance.autoLayerTiles
            } else {
                continue // Skip layers with no tiles
            }

            guard let tilesetUid = layerInstance.tilesetDefUid else { continue }
            referencedTilesetUids.insert(tilesetUid)

            let layerGridSize = layerInstance.gridSize
            let layerWidth = layerInstance.cWid
            let layerHeight = layerInstance.cHei

            // Build tile grid (empty by default)
            var tiles = [Tile](repeating: .empty, count: layerWidth * layerHeight)

            for tileInst in allTiles {
                guard tileInst.px.count >= 2 else { continue }

                let col = tileInst.px[0] / max(1, layerGridSize)
                let row = tileInst.px[1] / max(1, layerGridSize)

                guard col >= 0, col < layerWidth, row >= 0, row < layerHeight else { continue }

                // Store tile.id = t + 1 so that 0 remains the empty sentinel
                let flipX = (tileInst.f & 1) != 0
                let flipY = (tileInst.f & 2) != 0
                tiles[row * layerWidth + col] = Tile(id: tileInst.t + 1, flipX: flipX, flipY: flipY)
            }

            tileLayers.append(TileLayer(
                name: layerInstance.identifier,
                width: layerWidth,
                height: layerHeight,
                tiles: tiles
            ))
        }

        // Build Tileset array from referenced tilesets
        let tilesets: [Tileset] = referencedTilesetUids.sorted().compactMap { uid -> Tileset? in
            guard let entry = tilesetLookup[uid] else { return nil }
            let tsDef = entry.def
            let columns = max(1, tsDef.pxWid / max(1, tsDef.tileGridSize))
            let tileCount = columns * max(1, tsDef.pxHei / max(1, tsDef.tileGridSize))
            return Tileset(
                texture: entry.texture,
                tileWidth: tsDef.tileGridSize,
                tileHeight: tsDef.tileGridSize,
                columns: columns,
                firstGid: 1, // LDtk local IDs start at 0; we offset by +1
                tileCount: tileCount
            )
        }

        return TileMap(
            layers: tileLayers,
            tilesets: tilesets,
            tileWidth: gridSize,
            tileHeight: gridSize,
            width: mapWidth,
            height: mapHeight
        )
    }
}
