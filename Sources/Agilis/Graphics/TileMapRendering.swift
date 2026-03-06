

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - TileMap Rendering

extension Renderer {

    /// Draw all visible layers of a tilemap.
    ///
    /// Camera-based culling ensures only tiles overlapping the viewport are drawn.
    /// Layers are drawn bottom-to-top (index 0 first). Hidden layers and empty
    /// tiles (id == 0) are skipped automatically.
    ///
    /// ## Usage
    /// ```swift
    /// app.renderer.beginCamera(camera)
    /// app.renderer.drawTileMap(tileMap, position: .zero, camera: camera)
    /// app.renderer.endCamera()
    /// ```
    ///
    /// - Parameters:
    ///   - tileMap: The tilemap to draw.
    ///   - position: World position of the tilemap's top-left corner.
    ///   - camera: Camera for viewport culling. Pass nil to use the full screen.
    ///   - tint: Color tint applied to all tiles (white = no tint).
    public func drawTileMap(
        _ tileMap: TileMap,
        position: Vector2 = .zero,
        camera: Camera2D? = nil,
        tint: Color = .white
    ) {
        for layer in tileMap.layers {
            guard layer.visible else { continue }

            drawTileLayer(
                layer,
                tilesets: tileMap.tilesets,
                tileWidth: tileMap.tileWidth,
                tileHeight: tileMap.tileHeight,
                position: position,
                camera: camera,
                tint: tint
            )
        }
    }

    /// Draw a single tile layer.
    ///
    /// - Parameters:
    ///   - layer: The tile layer to draw.
    ///   - tilesets: Available tilesets (tiles are matched by GID range).
    ///   - tileWidth: Tile width in pixels.
    ///   - tileHeight: Tile height in pixels.
    ///   - position: World position of the layer's top-left corner.
    ///   - camera: Camera for viewport culling. Pass nil to use the full screen.
    ///   - tint: Color tint applied to all tiles.
    public func drawTileLayer(
        _ layer: TileLayer,
        tilesets: [Tileset],
        tileWidth: Int,
        tileHeight: Int,
        position: Vector2 = .zero,
        camera: Camera2D? = nil,
        tint: Color = .white
    ) {
        guard tileWidth > 0 && tileHeight > 0 else { return }

        let effectiveAlpha = UInt8(Float(tint.a) * layer.opacity)
        let layerTint = Color(r: tint.r, g: tint.g, b: tint.b, a: effectiveAlpha)

        let tileRange = _visibleTileRange(
            layerWidth: layer.width,
            layerHeight: layer.height,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            position: position,
            camera: camera,
            screenSize: screenSize
        )

        guard tileRange.startCol <= tileRange.endCol &&
              tileRange.startRow <= tileRange.endRow else { return }

        let tw = Float(tileWidth)
        let th = Float(tileHeight)

        for row in tileRange.startRow...tileRange.endRow {
            for col in tileRange.startCol...tileRange.endCol {
                guard let tile = layer.tile(atColumn: col, row: row),
                      tile.id != 0 else { continue }

                guard let tileset = _findTileset(for: tile.id, in: tilesets) else { continue }

                let sprite = Sprite(
                    texture: tileset.texture,
                    sourceRect: tileset.sourceRect(for: tile.id),
                    position: Vector2(
                        x: Float(col) * tw + position.x,
                        y: Float(row) * th + position.y
                    ),
                    tint: layerTint,
                    flipX: tile.flipX,
                    flipY: tile.flipY
                )
                drawSprite(sprite)
            }
        }
    }

    // MARK: - SpriteBatch Integration

    /// Add all visible tiles from a tilemap to a SpriteBatch.
    ///
    /// Each tilemap layer is mapped to a sequential batch layer starting
    /// from `baseLayer`, so draw order is preserved when the batch uses
    /// `.byLayer` sort mode.
    ///
    /// - Parameters:
    ///   - tileMap: The tilemap to batch.
    ///   - batch: The SpriteBatch to add tiles to.
    ///   - position: World position of the tilemap's top-left corner.
    ///   - camera: Camera for viewport culling. Pass nil to use the full screen.
    ///   - tint: Color tint applied to all tiles.
    ///   - baseLayer: Starting batch layer for the first tilemap layer.
    public func batchTileMap(
        _ tileMap: TileMap,
        into batch: SpriteBatch,
        position: Vector2 = .zero,
        camera: Camera2D? = nil,
        tint: Color = .white,
        baseLayer: Int = 0
    ) {
        for (i, layer) in tileMap.layers.enumerated() {
            guard layer.visible else { continue }

            batchTileLayer(
                layer,
                tilesets: tileMap.tilesets,
                tileWidth: tileMap.tileWidth,
                tileHeight: tileMap.tileHeight,
                into: batch,
                position: position,
                camera: camera,
                tint: tint,
                batchLayer: baseLayer + i
            )
        }
    }

    /// Add a single layer's tiles to a SpriteBatch.
    ///
    /// - Parameters:
    ///   - layer: The tile layer to batch.
    ///   - tilesets: Available tilesets.
    ///   - tileWidth: Tile width in pixels.
    ///   - tileHeight: Tile height in pixels.
    ///   - batch: The SpriteBatch to add tiles to.
    ///   - position: World position of the layer's top-left corner.
    ///   - camera: Camera for viewport culling. Pass nil to use the full screen.
    ///   - tint: Color tint applied to all tiles.
    ///   - batchLayer: Batch layer for sort ordering.
    public func batchTileLayer(
        _ layer: TileLayer,
        tilesets: [Tileset],
        tileWidth: Int,
        tileHeight: Int,
        into batch: SpriteBatch,
        position: Vector2 = .zero,
        camera: Camera2D? = nil,
        tint: Color = .white,
        batchLayer: Int = 0
    ) {
        guard tileWidth > 0 && tileHeight > 0 else { return }

        let effectiveAlpha = UInt8(Float(tint.a) * layer.opacity)
        let layerTint = Color(r: tint.r, g: tint.g, b: tint.b, a: effectiveAlpha)

        let tileRange = _visibleTileRange(
            layerWidth: layer.width,
            layerHeight: layer.height,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            position: position,
            camera: camera,
            screenSize: screenSize
        )

        guard tileRange.startCol <= tileRange.endCol &&
              tileRange.startRow <= tileRange.endRow else { return }

        let tw = Float(tileWidth)
        let th = Float(tileHeight)

        for row in tileRange.startRow...tileRange.endRow {
            for col in tileRange.startCol...tileRange.endCol {
                guard let tile = layer.tile(atColumn: col, row: row),
                      tile.id != 0 else { continue }

                guard let tileset = _findTileset(for: tile.id, in: tilesets) else { continue }

                let sprite = Sprite(
                    texture: tileset.texture,
                    sourceRect: tileset.sourceRect(for: tile.id),
                    position: Vector2(
                        x: Float(col) * tw + position.x,
                        y: Float(row) * th + position.y
                    ),
                    tint: layerTint,
                    flipX: tile.flipX,
                    flipY: tile.flipY
                )
                batch.add(sprite, layer: batchLayer)
            }
        }
    }

}

// MARK: - Private Helpers

/// Visible tile range within a layer.
private struct _TileRange {
    let startCol: Int
    let endCol: Int
    let startRow: Int
    let endRow: Int
}

/// Compute the range of tiles visible in the viewport.
private func _visibleTileRange(
    layerWidth: Int,
    layerHeight: Int,
    tileWidth: Int,
    tileHeight: Int,
    position: Vector2,
    camera: Camera2D?,
    screenSize: Size
) -> _TileRange {
    let viewport: Rect

    if let camera = camera {
        let viewW = screenSize.width / camera.zoom
        let viewH = screenSize.height / camera.zoom
        let viewX = camera.target.x - camera.offset.x / camera.zoom
        let viewY = camera.target.y - camera.offset.y / camera.zoom
        viewport = Rect(x: viewX, y: viewY, width: viewW, height: viewH)
    } else {
        viewport = Rect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
    }

    let tw = Float(tileWidth)
    let th = Float(tileHeight)

    // Convert viewport to tile coordinates relative to map position
    let localMinX = viewport.x - position.x
    let localMinY = viewport.y - position.y
    let localMaxX = localMinX + viewport.width
    let localMaxY = localMinY + viewport.height

    let startCol = max(0, Int(floorf(localMinX / tw)))
    let startRow = max(0, Int(floorf(localMinY / th)))
    let endCol = min(layerWidth - 1, Int(floorf(localMaxX / tw)))
    let endRow = min(layerHeight - 1, Int(floorf(localMaxY / th)))

    // Handle case where viewport doesn't overlap the layer at all
    if startCol > endCol || startRow > endRow {
        return _TileRange(startCol: 0, endCol: -1, startRow: 0, endRow: -1)
    }

    return _TileRange(
        startCol: startCol,
        endCol: endCol,
        startRow: startRow,
        endRow: endRow
    )
}

/// Find the tileset that contains a given tile ID.
/// Tilesets are matched by GID range: the tileset with the highest
/// `firstGid` that is <= the tile ID wins.
private func _findTileset(for tileId: Int, in tilesets: [Tileset]) -> Tileset? {
    var best: Tileset?
    for tileset in tilesets {
        if tileId >= tileset.firstGid {
            if best == nil || tileset.firstGid > best!.firstGid {
                best = tileset
            }
        }
    }
    return best
}
