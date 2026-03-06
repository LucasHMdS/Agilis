

/// A widget that displays a texture.
public class UIImage: UINode, @unchecked Sendable {
    public var texture: TextureHandle
    public var tint: Color

    /// If set, the image will be rendered at this fixed size.
    /// Otherwise, it uses the texture's natural size.
    public var fixedSize: Size?

    public init(texture: TextureHandle, tint: Color = .white, fixedSize: Size? = nil) {
        self.texture = texture
        self.tint = tint
        self.fixedSize = fixedSize
        super.init()
    }

    public override func sizeThatFits(_ available: Size) -> Size {
        if let fixed = fixedSize {
            return fixed
        }
        // Return a default; actual texture size requires the renderer
        return Size(width: min(available.width, 64), height: min(available.height, 64))
    }

    public override func render(renderer: any RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        let texSize = renderer.textureSize(texture)
        guard texSize.width > 0 && texSize.height > 0 else { return }

        let sprite = Sprite(
            texture: texture,
            sourceRect: Rect(x: 0, y: 0, width: texSize.width, height: texSize.height),
            position: Vector2(x: frame.x, y: frame.y),
            scale: Vector2(x: frame.width / texSize.width,
                           y: frame.height / texSize.height),
            rotation: 0,
            origin: .zero,
            tint: tint,
            flipX: false,
            flipY: false
        )
        renderer.drawSprite(sprite)
    }
}
