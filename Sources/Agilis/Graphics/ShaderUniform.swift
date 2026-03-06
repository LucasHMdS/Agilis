/// A type-safe wrapper for shader uniform names.
///
/// Provides compile-time discoverability for commonly used uniform names
/// instead of raw string literals.
///
/// ```swift
/// renderer.setShaderFloat(shader, uniform: .time, value: elapsed)
/// ```
public struct ShaderUniform: Hashable, Sendable {
    public let name: String

    public init(_ name: String) { self.name = name }

    // MARK: - Common Uniforms

    public static let time = ShaderUniform("time")
    public static let resolution = ShaderUniform("resolution")
    public static let lightPosition = ShaderUniform("lightPosition")
    public static let lightColor = ShaderUniform("lightColor")
    public static let lightRadius = ShaderUniform("lightRadius")
    public static let lightIntensity = ShaderUniform("lightIntensity")
    public static let falloff = ShaderUniform("falloff")
    public static let ambientColor = ShaderUniform("ambientColor")
}

// MARK: - Renderer Typed Uniform Setters

extension Renderer {
    /// Set a float uniform using a typed `ShaderUniform` key.
    public func setShaderFloat(_ handle: ShaderHandle, uniform: ShaderUniform, value: Float) {
        setShaderFloat(handle, name: uniform.name, value: value)
    }

    /// Set a Vec2 uniform using a typed `ShaderUniform` key.
    public func setShaderVec2(_ handle: ShaderHandle, uniform: ShaderUniform, value: Vector2) {
        setShaderVec2(handle, name: uniform.name, value: value)
    }

    /// Set a Vec3 uniform using a typed `ShaderUniform` key.
    public func setShaderVec3(_ handle: ShaderHandle, uniform: ShaderUniform, x: Float, y: Float, z: Float) {
        setShaderVec3(handle, name: uniform.name, x: x, y: y, z: z)
    }

    /// Set a Vec4 uniform using a typed `ShaderUniform` key.
    public func setShaderVec4(_ handle: ShaderHandle, uniform: ShaderUniform, x: Float, y: Float, z: Float, w: Float) {
        setShaderVec4(handle, name: uniform.name, x: x, y: y, z: z, w: w)
    }

    /// Set an int uniform using a typed `ShaderUniform` key.
    public func setShaderInt(_ handle: ShaderHandle, uniform: ShaderUniform, value: Int32) {
        setShaderInt(handle, name: uniform.name, value: value)
    }

    /// Set a texture sampler uniform using a typed `ShaderUniform` key.
    public func setShaderTexture(_ handle: ShaderHandle, uniform: ShaderUniform, texture: TextureHandle) {
        setShaderTexture(handle, name: uniform.name, texture: texture)
    }
}
