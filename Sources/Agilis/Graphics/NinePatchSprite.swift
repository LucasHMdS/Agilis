/// A nine-patch (nine-slice) sprite definition for scalable UI backgrounds.
///
/// Divides a texture region into 9 zones: 4 corners (unscaled), 4 edges (stretched
/// along one axis), and 1 center (stretched both axes). This allows UI panels and
/// buttons to scale to any size while preserving border details.
///
/// ## Usage
/// ```swift
/// let patch = NinePatchSprite(
///     texture: panelTexture,
///     sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
///     border: 12
/// )
/// renderer.drawNinePatch(patch, destination: Rect(x: 10, y: 10, width: 300, height: 200))
/// ```
public struct NinePatchSprite: Sendable {
    /// The texture containing the nine-patch source.
    public var texture: TextureHandle

    /// The region within the texture to use as the nine-patch source.
    public var sourceRect: Rect

    /// Border insets defining the 9 zones.
    public var borderTop: Float
    public var borderRight: Float
    public var borderBottom: Float
    public var borderLeft: Float

    /// Tint color applied to all 9 patches.
    public var tint: Color

    /// Create a nine-patch with per-side border sizes.
    public init(
        texture: TextureHandle,
        sourceRect: Rect,
        borderTop: Float,
        borderRight: Float,
        borderBottom: Float,
        borderLeft: Float,
        tint: Color = .white
    ) {
        self.texture = texture
        self.sourceRect = sourceRect
        self.borderTop = borderTop
        self.borderRight = borderRight
        self.borderBottom = borderBottom
        self.borderLeft = borderLeft
        self.tint = tint
    }

    /// Create a nine-patch with uniform border size on all sides.
    public init(
        texture: TextureHandle,
        sourceRect: Rect,
        border: Float,
        tint: Color = .white
    ) {
        self.init(
            texture: texture,
            sourceRect: sourceRect,
            borderTop: border,
            borderRight: border,
            borderBottom: border,
            borderLeft: border,
            tint: tint
        )
    }
}

// MARK: - Renderer Extension

extension RenderBackend {
    /// Draw a nine-patch sprite scaled to fill the destination rectangle.
    ///
    /// The 4 corners are drawn at their original size, edges are stretched along
    /// one axis, and the center is stretched along both axes.
    public func drawNinePatch(_ ninePatch: NinePatchSprite, destination: Rect) {
        let src = ninePatch.sourceRect
        let dst = destination
        let tex = ninePatch.texture
        let tint = ninePatch.tint

        let bT = ninePatch.borderTop
        let bR = ninePatch.borderRight
        let bB = ninePatch.borderBottom
        let bL = ninePatch.borderLeft

        // Source regions
        let srcCenterW = src.width - bL - bR
        let srcCenterH = src.height - bT - bB

        // Destination regions
        let dstCenterW = dst.width - bL - bR
        let dstCenterH = dst.height - bT - bB

        // If destination is too small for borders, just draw the whole thing scaled
        if dstCenterW <= 0 || dstCenterH <= 0 {
            drawSprite(Sprite(
                texture: tex,
                sourceRect: src,
                position: Vector2(x: dst.x, y: dst.y),
                scale: Vector2(x: dst.width / src.width, y: dst.height / src.height),
                tint: tint
            ))
            return
        }

        // Helper to draw one patch
        func patch(
            srcX: Float,
            srcY: Float,
            srcW: Float,
            srcH: Float,
            dstX: Float,
            dstY: Float,
            dstW: Float,
            dstH: Float
        ) {
            guard srcW > 0 && srcH > 0 && dstW > 0 && dstH > 0 else { return }
            drawSprite(Sprite(
                texture: tex,
                sourceRect: Rect(x: srcX, y: srcY, width: srcW, height: srcH),
                position: Vector2(x: dstX, y: dstY),
                scale: Vector2(x: dstW / srcW, y: dstH / srcH),
                tint: tint
            ))
        }

        // Top-left corner
        patch(
            srcX: src.x,
            srcY: src.y,
            srcW: bL,
            srcH: bT,
            dstX: dst.x,
            dstY: dst.y,
            dstW: bL,
            dstH: bT
        )

        // Top edge
        patch(
            srcX: src.x + bL,
            srcY: src.y,
            srcW: srcCenterW,
            srcH: bT,
            dstX: dst.x + bL,
            dstY: dst.y,
            dstW: dstCenterW,
            dstH: bT
        )

        // Top-right corner
        patch(
            srcX: src.x + bL + srcCenterW,
            srcY: src.y,
            srcW: bR,
            srcH: bT,
            dstX: dst.x + bL + dstCenterW,
            dstY: dst.y,
            dstW: bR,
            dstH: bT
        )

        // Left edge
        patch(
            srcX: src.x,
            srcY: src.y + bT,
            srcW: bL,
            srcH: srcCenterH,
            dstX: dst.x,
            dstY: dst.y + bT,
            dstW: bL,
            dstH: dstCenterH
        )

        // Center
        patch(
            srcX: src.x + bL,
            srcY: src.y + bT,
            srcW: srcCenterW,
            srcH: srcCenterH,
            dstX: dst.x + bL,
            dstY: dst.y + bT,
            dstW: dstCenterW,
            dstH: dstCenterH
        )

        // Right edge
        patch(
            srcX: src.x + bL + srcCenterW,
            srcY: src.y + bT,
            srcW: bR,
            srcH: srcCenterH,
            dstX: dst.x + bL + dstCenterW,
            dstY: dst.y + bT,
            dstW: bR,
            dstH: dstCenterH
        )

        // Bottom-left corner
        patch(
            srcX: src.x,
            srcY: src.y + bT + srcCenterH,
            srcW: bL,
            srcH: bB,
            dstX: dst.x,
            dstY: dst.y + bT + dstCenterH,
            dstW: bL,
            dstH: bB
        )

        // Bottom edge
        patch(
            srcX: src.x + bL,
            srcY: src.y + bT + srcCenterH,
            srcW: srcCenterW,
            srcH: bB,
            dstX: dst.x + bL,
            dstY: dst.y + bT + dstCenterH,
            dstW: dstCenterW,
            dstH: bB
        )

        // Bottom-right corner
        patch(
            srcX: src.x + bL + srcCenterW,
            srcY: src.y + bT + srcCenterH,
            srcW: bR,
            srcH: bB,
            dstX: dst.x + bL + dstCenterW,
            dstY: dst.y + bT + dstCenterH,
            dstW: bR,
            dstH: bB
        )
    }
}
