extension RenderBackend {
    /// Draw a render target's contents to the screen at the given position.
    /// Handles the Y-flip automatically (OpenGL framebuffer textures are Y-inverted).
    public func drawRenderTarget(
        _ handle: RenderTargetHandle,
        position: Vector2 = .zero,
        tint: Color = .white
    ) {
        let texture = renderTargetTexture(handle)
        guard texture != .invalid else { return }
        let size = renderTargetSize(handle)
        drawSprite(Sprite(
            texture: texture,
            sourceRect: Rect(x: 0, y: 0, width: size.width, height: size.height),
            position: position,
            tint: tint,
            flipY: true
        ))
    }

    /// Draw a render target's contents scaled to fill a destination rectangle.
    /// Handles the Y-flip automatically.
    public func drawRenderTarget(
        _ handle: RenderTargetHandle,
        destination: Rect,
        tint: Color = .white
    ) {
        let texture = renderTargetTexture(handle)
        guard texture != .invalid else { return }
        let size = renderTargetSize(handle)
        guard size.width > 0 && size.height > 0 else { return }
        drawSprite(Sprite(
            texture: texture,
            sourceRect: Rect(x: 0, y: 0, width: size.width, height: size.height),
            position: Vector2(x: destination.x, y: destination.y),
            scale: Vector2(x: destination.width / size.width, y: destination.height / size.height),
            tint: tint,
            flipY: true
        ))
    }
}
