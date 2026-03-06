/// A value that can be set on a shader uniform.
///
/// Each case maps directly to a GLSL uniform type. The `.color` case is a convenience
/// that automatically converts from 0-255 byte range to 0.0-1.0 float range when applied.
public enum UniformValue: Sendable, Equatable, Codable {
    /// A single float (GLSL `float`).
    case float(Float)
    /// A 2D vector (GLSL `vec2`).
    case vec2(Vector2)
    /// A 3D vector (GLSL `vec3`).
    case vec3(x: Float, y: Float, z: Float)
    /// A 4D vector (GLSL `vec4`).
    case vec4(x: Float, y: Float, z: Float, w: Float)
    /// An integer (GLSL `int`).
    case int(Int32)
    /// A color, automatically converted to vec4 (r/255, g/255, b/255, a/255) when applied.
    case color(Color)
    /// A texture sampler.
    case texture(TextureHandle)
}

/// A material defines the visual appearance of a sprite beyond its texture and tint.
///
/// A material bundles a shader with its uniform values and an optional blend mode override.
/// Materials are value types — lightweight to copy and modify per-sprite.
///
/// ```swift
/// // Using a built-in effect from MaterialLibrary
/// var sprite = Sprite(texture: playerTex)
/// sprite.material = materials.flash(color: .white, amount: 1.0)
///
/// // Using a custom shader
/// let shader = app.renderer.loadShader(vertexSource: nil, fragmentSource: myGLSL)
/// sprite.material = Material2D(shader: shader, uniforms: [
///     "time": .float(elapsed),
///     "tintColor": .color(.red)
/// ])
/// ```
public struct Material2D: Sendable, Equatable, Codable {
    /// The shader program to use for rendering.
    public var shader: ShaderHandle

    /// Uniform values to set on the shader before drawing.
    /// Keys are GLSL uniform names.
    public var uniforms: [String: UniformValue]

    /// Optional blend mode override. If `nil`, the sprite's own `blendMode` is used.
    /// Set this to force a specific blend mode regardless of the sprite's setting
    /// (e.g., `.additive` for a glow material).
    public var blendMode: BlendMode?

    public init(
        shader: ShaderHandle,
        uniforms: [String: UniformValue] = [:],
        blendMode: BlendMode? = nil
    ) {
        self.shader = shader
        self.uniforms = uniforms
        self.blendMode = blendMode
    }

    /// Sort key for batching. Sprites with the same sort key use the same shader,
    /// so they can be drawn together with only uniform updates between them
    /// (no expensive shader switches).
    public var sortKey: UInt32 { shader.id }
}
