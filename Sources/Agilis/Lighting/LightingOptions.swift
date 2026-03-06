

/// Quality level for soft shadow blur passes.
public enum SoftShadowQuality: Int, Sendable, Codable {
    /// 1 blur pass — fast, slightly soft edges.
    case low = 1
    /// 2 blur passes — good balance of quality and performance.
    case medium = 2
    /// 3 blur passes — widest blur, smoothest shadows.
    case high = 3
}

/// Configuration for the 2D lighting system.
public struct LightingOptions: Sendable {
    /// Ambient light color. The light map is filled with this color before
    /// any lights are drawn. Dark ambient = darker unlit areas.
    public var ambientColor: Color

    /// Resolution scale for the light map relative to the screen size.
    /// 1.0 = full resolution, 0.5 = half resolution (better performance, softer look).
    public var lightMapScale: Float

    /// Maximum distance shadow volumes extend past occluders, in pixels.
    /// Larger values ensure shadows reach far enough but cost more fill rate.
    /// Set to 0 to auto-compute from the screen diagonal.
    public var shadowExtent: Float

    /// Whether to draw debug overlays (light radii, shadow volumes).
    public var debugDraw: Bool

    /// Debug color for light radius circles.
    public var debugLightColor: Color

    /// Debug color for shadow volume outlines.
    public var debugShadowColor: Color

    /// Whether to enable normal-mapped lighting. When true, the lighting system
    /// creates a normal buffer and uses per-pixel normal data from `NormalMapData`
    /// components for directional light shading.
    public var normalMappingEnabled: Bool

    /// Whether to enable the specular highlight pass. When true, lights with
    /// `specularEnabled = true` produce an additional additive specular pass
    /// using Blinn-Phong shading.
    public var specularEnabled: Bool

    /// Whether to flip the normal map Y axis. Set to `true` for DirectX-convention
    /// normal maps (green channel points down). Default `false` = OpenGL convention
    /// (green channel points up).
    public var flipNormalY: Bool

    /// Whether to draw the normal buffer as a debug overlay.
    public var debugNormalBuffer: Bool

    /// Whether to draw the specular buffer as a debug overlay.
    public var debugSpecularBuffer: Bool

    /// Whether to enable soft (blurred) shadows. When true, shadow volumes are
    /// rendered to a dedicated buffer and Gaussian-blurred before being applied
    /// to the light, producing smooth shadow edges instead of hard silhouettes.
    public var softShadows: Bool

    /// Global blur radius for soft shadows in pixels. Higher values produce
    /// softer, wider shadow edges. Each light can override this with its own
    /// `softShadowRadius`.
    public var softShadowRadius: Float

    /// Quality level for soft shadow blur. Controls the number of blur passes:
    /// `.low` = 1 pass, `.medium` = 2 passes, `.high` = 3 passes.
    public var softShadowQuality: SoftShadowQuality

    /// Whether to draw the shadow buffer as a debug overlay.
    public var debugShadowBuffer: Bool

    /// Expand shadow occluder shapes by this many pixels to prevent light leaks
    /// at corners where adjacent wall blocks meet. A small value (2-4) closes
    /// diagonal gaps without visibly affecting the shadows. Default 2.
    public var shadowBloat: Float

    public init(
        ambientColor: Color = Color(r: 30, g: 30, b: 40),
        lightMapScale: Float = 1.0,
        shadowExtent: Float = 0,
        debugDraw: Bool = false,
        debugLightColor: Color = .yellow,
        debugShadowColor: Color = Color(r: 128, g: 0, b: 128),
        normalMappingEnabled: Bool = false,
        specularEnabled: Bool = false,
        flipNormalY: Bool = false,
        debugNormalBuffer: Bool = false,
        debugSpecularBuffer: Bool = false,
        softShadows: Bool = false,
        softShadowRadius: Float = 4.0,
        softShadowQuality: SoftShadowQuality = .medium,
        debugShadowBuffer: Bool = false,
        shadowBloat: Float = 2
    ) {
        self.ambientColor = ambientColor
        self.lightMapScale = lightMapScale
        self.shadowExtent = shadowExtent
        self.debugDraw = debugDraw
        self.debugLightColor = debugLightColor
        self.debugShadowColor = debugShadowColor
        self.normalMappingEnabled = normalMappingEnabled
        self.specularEnabled = specularEnabled
        self.flipNormalY = flipNormalY
        self.debugNormalBuffer = debugNormalBuffer
        self.debugSpecularBuffer = debugSpecularBuffer
        self.softShadows = softShadows
        self.softShadowRadius = softShadowRadius
        self.softShadowQuality = softShadowQuality
        self.debugShadowBuffer = debugShadowBuffer
        self.shadowBloat = shadowBloat
    }
}
