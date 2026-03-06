/// A sprite is a textured quad defined by a texture and a source rectangle within it.
public struct Sprite: Sendable, Codable {
    /// The texture this sprite draws from.
    public var texture: TextureHandle

    /// The region within the texture to draw (in pixels).
    public var sourceRect: Rect

    /// The position to draw at (world coordinates).
    public var position: Vector2

    /// Scale factor.
    public var scale: Vector2

    /// Rotation in radians.
    public var rotation: Float

    /// The origin point for rotation and scaling (0,0 = top-left, relative to source rect size).
    public var origin: Vector2

    /// Tint color multiplied with the texture color.
    public var tint: Color

    /// Whether the sprite is flipped horizontally.
    public var flipX: Bool

    /// Whether the sprite is flipped vertically.
    public var flipY: Bool

    /// Blend mode for this sprite. Default is `.alpha` (standard transparency).
    public var blendMode: BlendMode

    /// Optional material for shader-based effects (flash, dissolve, outline, etc.).
    /// When set, the material's shader and uniforms are applied during rendering.
    /// If `nil`, the sprite renders with the default pipeline.
    public var material: Material2D?

    public init(
        texture: TextureHandle,
        sourceRect: Rect = Rect(),
        position: Vector2 = .zero,
        scale: Vector2 = .one,
        rotation: Float = 0,
        origin: Vector2 = .zero,
        tint: Color = .white,
        flipX: Bool = false,
        flipY: Bool = false,
        blendMode: BlendMode = .alpha,
        material: Material2D? = nil
    ) {
        self.texture = texture
        self.sourceRect = sourceRect
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.origin = origin
        self.tint = tint
        self.flipX = flipX
        self.flipY = flipY
        self.blendMode = blendMode
        self.material = material
    }
}
