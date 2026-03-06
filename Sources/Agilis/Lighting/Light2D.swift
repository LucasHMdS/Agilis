

/// The type of a 2D light source.
public enum LightType: Sendable, Codable, Equatable {
    /// Radial light emitting equally in all directions.
    case point
    /// Cone-shaped light with a direction and angle spread.
    /// - Parameters:
    ///   - direction: The direction the spot faces, in radians.
    ///   - coneAngle: The half-angle of the cone, in radians.
    case spot(direction: Float, coneAngle: Float)
}

/// A 2D light source component. Requires a `Transform2D` on the same entity
/// to define the light's position.
///
/// ## Usage
/// ```swift
/// let light = world.createEntity()
/// world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: light)
/// world.addComponent(Light2D(
///     color: .yellow,
///     intensity: 1.5,
///     radius: 200,
///     castsShadows: true
/// ), to: light)
/// ```
public struct Light2D: Component, Sendable, Codable, SerializableComponent {
    public static let componentName = "Light2D"

    /// The type of light (point or spot).
    public var lightType: LightType

    /// Light color (RGB, alpha ignored).
    public var color: Color

    /// Brightness multiplier. Values > 1 produce overbright lights.
    public var intensity: Float

    /// Maximum reach of the light in pixels. Beyond this distance, the light
    /// contributes zero illumination.
    public var radius: Float

    /// Whether this light generates shadow volumes from nearby shadow casters.
    public var castsShadows: Bool

    /// Falloff exponent. 1.0 = linear, 2.0 = quadratic (more realistic),
    /// 0.5 = slower falloff.
    public var falloff: Float

    /// Whether this light is currently active.
    public var isEnabled: Bool

    /// Collision layer mask for shadow casting. Only shadow casters whose
    /// layer matches this mask will block this light. Default: all layers.
    public var shadowLayerMask: UInt32

    /// Whether this light produces specular highlights on normal-mapped surfaces.
    /// Only effective when `LightingOptions.specularEnabled` is also true.
    public var specularEnabled: Bool

    /// Per-light specular strength multiplier (0-10). Higher values produce
    /// brighter highlights.
    public var specularStrength: Float

    /// Virtual Z height for 3D-like lighting angle on 2D normal maps, in pixels.
    /// Higher values make the light appear more "overhead", producing subtler
    /// normal map shading. Lower values make the light more "grazing", producing
    /// stronger directional effects.
    public var zHeight: Float

    /// Per-light blur radius override for soft shadows, in pixels.
    /// Set to 0 (default) to use the global `LightingOptions.softShadowRadius`.
    /// Only effective when `LightingOptions.softShadows` is true.
    public var softShadowRadius: Float

    public init(
        lightType: LightType = .point,
        color: Color = .white,
        intensity: Float = 1.0,
        radius: Float = 200,
        castsShadows: Bool = false,
        falloff: Float = 1.0,
        isEnabled: Bool = true,
        shadowLayerMask: UInt32 = 0xFFFF_FFFF,
        specularEnabled: Bool = false,
        specularStrength: Float = 1.0,
        zHeight: Float = 100.0,
        softShadowRadius: Float = 0.0
    ) {
        self.lightType = lightType
        self.color = color
        self.intensity = intensity
        self.radius = radius
        self.castsShadows = castsShadows
        self.falloff = falloff
        self.isEnabled = isEnabled
        self.shadowLayerMask = shadowLayerMask
        self.specularEnabled = specularEnabled
        self.specularStrength = specularStrength
        self.zHeight = zHeight
        self.softShadowRadius = softShadowRadius
    }

    // MARK: - Backward-Compatible Codable

    private enum CodingKeys: String, CodingKey {
        case lightType, color, intensity, radius, castsShadows, falloff
        case isEnabled, shadowLayerMask
        case specularEnabled, specularStrength, zHeight
        case softShadowRadius
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lightType = try container.decode(LightType.self, forKey: .lightType)
        color = try container.decode(Color.self, forKey: .color)
        intensity = try container.decode(Float.self, forKey: .intensity)
        radius = try container.decode(Float.self, forKey: .radius)
        castsShadows = try container.decode(Bool.self, forKey: .castsShadows)
        falloff = try container.decode(Float.self, forKey: .falloff)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        shadowLayerMask = try container.decode(UInt32.self, forKey: .shadowLayerMask)
        specularEnabled = try container.decodeIfPresent(Bool.self, forKey: .specularEnabled) ?? false
        specularStrength = try container.decodeIfPresent(Float.self, forKey: .specularStrength) ?? 1.0
        zHeight = try container.decodeIfPresent(Float.self, forKey: .zHeight) ?? 100.0
        softShadowRadius = try container.decodeIfPresent(Float.self, forKey: .softShadowRadius) ?? 0.0
    }
}
