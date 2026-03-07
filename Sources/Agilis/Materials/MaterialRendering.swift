/// Standard uniforms automatically injected into materials that declare them.
///
/// When a material's shader has a uniform matching one of the standard names,
/// the value is set automatically before the material's own uniforms are applied.
///
/// Standard uniform names (underscore prefix avoids collisions with user names):
/// - `_time`: Elapsed game time in seconds
/// - `_resolution`: Screen size as vec2
/// - `_deltaTime`: Frame delta time in seconds
///
/// ```swift
/// var context = MaterialContext()
/// context.time = elapsed
/// context.resolution = Vector2(x: Float(screenWidth), y: Float(screenHeight))
/// context.deltaTime = Float(dt)
/// renderer.applyMaterial(material, context: context)
/// ```
public struct MaterialContext: Sendable {
    /// Elapsed game time in seconds.
    public var time: Float

    /// Screen resolution in pixels.
    public var resolution: Vector2

    /// Frame delta time in seconds.
    public var deltaTime: Float

    public init(
        time: Float = 0,
        resolution: Vector2 = .zero,
        deltaTime: Float = 0
    ) {
        self.time = time
        self.resolution = resolution
        self.deltaTime = deltaTime
    }
}

extension RenderBackend {
    /// Apply a material with auto-injected standard uniforms.
    ///
    /// Standard uniforms (`_time`, `_resolution`, `_deltaTime`) are set
    /// before user uniforms. Shaders that do not declare these uniforms
    /// are unaffected (setting a uniform with an invalid location is a no-op).
    ///
    /// User uniforms may override standard uniforms if they use the same name.
    public func applyMaterial(_ material: Material2D, context: MaterialContext) {
        // Set standard uniforms
        setShaderFloat(material.shader, name: "_time", value: context.time)
        setShaderVec2(material.shader, name: "_resolution", value: context.resolution)
        setShaderFloat(material.shader, name: "_deltaTime", value: context.deltaTime)
        // Apply user uniforms (may override standard ones)
        applyMaterial(material)
    }
}
