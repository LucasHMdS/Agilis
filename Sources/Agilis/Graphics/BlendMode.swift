/// Blend mode for rendering operations.
///
/// Controls how source pixels are combined with destination pixels.
/// Set per-sprite via `Sprite.blendMode`, or use `beginBlendMode`/`endBlendMode`
/// on `Renderer` for scoped blending of shapes and text.
public enum BlendMode: Int, Sendable, Codable, Equatable {
    /// Standard alpha blending (default). Source alpha controls transparency.
    case alpha = 0

    /// Additive blending. Adds source to destination — good for glow, fire, light effects.
    case additive = 1

    /// Multiply blending. Multiplies source with destination — good for shadows, tinting.
    case multiplied = 2

    /// Premultiplied alpha blending. Use when textures have premultiplied alpha.
    case premultiplied = 3
}
