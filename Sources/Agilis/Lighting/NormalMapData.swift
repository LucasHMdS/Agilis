import AgilisCore

/// Per-entity normal and specular map data for the 2D lighting system.
///
/// Attach to entities that also have `Transform2D` and `Sprite` to enable
/// per-pixel normal-mapped lighting and specular highlights.
///
/// The normal map texture encodes tangent-space normals in RGB where
/// `(128, 128, 255)` represents a flat surface pointing straight up.
///
/// ## Usage
/// ```swift
/// let sprite = world.createEntity()
/// world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: sprite)
/// world.addComponent(Sprite(texture: diffuseTex), to: sprite)
/// world.addComponent(NormalMapData(
///     normalMap: normalTex,
///     specularMap: specularTex,
///     shininess: 64.0
/// ), to: sprite)
/// ```
public struct NormalMapData: Component, Sendable, Codable, SerializableComponent {
    public static let componentName = "NormalMapData"

    /// Normal map texture. RGB encodes tangent-space normals (128,128,255 = flat).
    public var normalMap: TextureHandle

    /// Optional specular map texture. R channel = specular intensity per pixel.
    /// `.invalid` means no specular map (uses uniform `specularIntensity` instead).
    public var specularMap: TextureHandle

    /// Specular intensity when no specular map is provided (0-1).
    public var specularIntensity: Float

    /// Specular shininess/exponent for Blinn-Phong (higher = tighter highlight).
    public var shininess: Float

    public init(
        normalMap: TextureHandle,
        specularMap: TextureHandle = .invalid,
        specularIntensity: Float = 0.5,
        shininess: Float = 32.0
    ) {
        self.normalMap = normalMap
        self.specularMap = specularMap
        self.specularIntensity = specularIntensity
        self.shininess = shininess
    }
}
