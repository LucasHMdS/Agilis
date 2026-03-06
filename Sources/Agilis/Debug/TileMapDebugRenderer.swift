

/// Configuration for tilemap debug rendering.
public struct TileMapDebugRendererOptions: Sendable {
    /// Draw tile grid lines within the camera viewport.
    public var drawGrid: Bool
    /// Draw the camera culling viewport rectangle.
    public var drawCullingRect: Bool
    /// Color for grid lines.
    public var gridColor: Color
    /// Color for the culling rectangle.
    public var cullingRectColor: Color

    public init(
        drawGrid: Bool = true,
        drawCullingRect: Bool = true,
        gridColor: Color = Color(r: 255, g: 255, b: 255, a: 40),
        cullingRectColor: Color = .yellow
    ) {
        self.drawGrid = drawGrid
        self.drawCullingRect = drawCullingRect
        self.gridColor = gridColor
        self.cullingRectColor = cullingRectColor
    }
}

extension RenderBackend {

    /// Draw debug overlays for a tilemap.
    ///
    /// Shows tile grid lines (camera-culled) and the culling viewport rectangle.
    /// Call inside a camera block.
    ///
    /// - Parameters:
    ///   - tileMap: The tilemap to debug.
    ///   - position: World-space position of the tilemap origin.
    ///   - camera: The active camera (used for culling).
    ///   - options: Rendering options.
    public func drawTileMapDebug(
        tileMap: TileMap,
        position: Vector2 = .zero,
        camera: Camera2D,
        options: TileMapDebugRendererOptions = TileMapDebugRendererOptions()
    ) {
        let tw = Float(tileMap.tileWidth)
        let th = Float(tileMap.tileHeight)
        guard tw > 0 && th > 0 else { return }

        // Compute viewport in world space
        let screen = screenSize
        let vpWidth = screen.width / camera.zoom
        let vpHeight = screen.height / camera.zoom
        let vpX = camera.target.x - camera.offset.x / camera.zoom
        let vpY = camera.target.y - camera.offset.y / camera.zoom

        let viewportRect = Rect(x: vpX, y: vpY, width: vpWidth, height: vpHeight)

        if options.drawCullingRect {
            drawRectOutline(viewportRect, color: options.cullingRectColor, thickness: 1)
        }

        if options.drawGrid {
            // Determine visible tile range
            let mapWidth = Float(tileMap.width) * tw
            let mapHeight = Float(tileMap.height) * th

            let startX = max(vpX - position.x, 0)
            let startY = max(vpY - position.y, 0)
            let endX = min(vpX + vpWidth - position.x, mapWidth)
            let endY = min(vpY + vpHeight - position.y, mapHeight)

            let firstCol = Int(startX / tw)
            let lastCol = min(Int(endX / tw) + 1, tileMap.width)
            let firstRow = Int(startY / th)
            let lastRow = min(Int(endY / th) + 1, tileMap.height)

            // Vertical grid lines
            for col in firstCol...lastCol {
                let x = position.x + Float(col) * tw
                drawLine(
                    from: Vector2(x: x, y: position.y + Float(firstRow) * th),
                    to: Vector2(x: x, y: position.y + Float(lastRow) * th),
                    color: options.gridColor, thickness: 1
                )
            }

            // Horizontal grid lines
            for row in firstRow...lastRow {
                let y = position.y + Float(row) * th
                drawLine(
                    from: Vector2(x: position.x + Float(firstCol) * tw, y: y),
                    to: Vector2(x: position.x + Float(lastCol) * tw, y: y),
                    color: options.gridColor, thickness: 1
                )
            }
        }
    }
}
