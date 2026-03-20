/// A reusable material definition that creates `Material2D` instances.
///
/// Templates define a shader and default uniform values. Create instances with
/// optional per-sprite overrides. Templates are reference types that share the
/// underlying shader handle (no duplication).
///
/// ```swift
/// // Create a template for dissolve effects
/// let dissolveTemplate = MaterialTemplate(
///     name: "dissolve",
///     shader: dissolveShader,
///     defaults: [
///         "edgeWidth": .float(0.05),
///         "edgeColor": .color(.white),
///     ]
/// )
///
/// // Create instances with per-sprite overrides
/// sprite.material = dissolveTemplate.instance(overrides: [
///     "threshold": .float(0.5)
/// ])
/// ```
public final class MaterialTemplate: @unchecked Sendable {
    deinit {}

    /// Human-readable name for debugging and identification.
    public let name: String

    /// The shader program shared by all instances.
    public let shader: ShaderHandle

    /// Default uniform values. Instances inherit these unless overridden.
    public let defaults: [String: UniformValue]

    /// Optional blend mode inherited by all instances.
    public let blendMode: BlendMode?

    public init(
        name: String,
        shader: ShaderHandle,
        defaults: [String: UniformValue] = [:],
        blendMode: BlendMode? = nil
    ) {
        self.name = name
        self.shader = shader
        self.defaults = defaults
        self.blendMode = blendMode
    }

    /// Create a `Material2D` instance with default uniform values.
    public func instance() -> Material2D {
        Material2D(shader: shader, uniforms: defaults, blendMode: blendMode)
    }

    /// Create a `Material2D` instance with overridden uniform values.
    ///
    /// Non-overridden values use the template defaults.
    /// Overrides can add new uniforms not in the defaults.
    public func instance(overrides: [String: UniformValue]) -> Material2D {
        var uniforms = defaults
        for (key, value) in overrides {
            uniforms[key] = value
        }
        return Material2D(shader: shader, uniforms: uniforms, blendMode: blendMode)
    }
}
