/// Helpers for creating custom GLSL 330 fragment shaders with less boilerplate.
///
/// Provides the standard preamble (version, inputs, sampler), optional include
/// libraries (noise, easing, UV, color, math), and auto-injected standard uniform
/// declarations.
///
/// ## Creating a Sprite Shader
/// ```swift
/// let source = ShaderBuilder.createFragment(
///     uniforms: ["tintColor": "vec4", "tintAmount": "float"],
///     body: """
///     vec4 color = sampleTexture(fragTexCoord);
///     color.rgb = mix(color.rgb, tintColor.rgb, tintAmount);
///     finalColor = color;
///     """
/// )
/// let shader = renderer.loadShader(vertexSource: nil, fragmentSource: source)
/// ```
///
/// ## Creating a Post-Process Shader
/// ```swift
/// let source = ShaderBuilder.createPostProcess(
///     uniforms: ["strength": "float"],
///     includes: [.noise],
///     body: """
///     vec4 color = sampleTexture(fragTexCoord);
///     color.rgb += noise2D(fragTexCoord * 50.0) * strength;
///     finalColor = color;
///     """
/// )
/// ```
public enum ShaderBuilder {

    /// Create a fragment shader source string for sprite rendering.
    ///
    /// The generated shader includes:
    /// - `#version 330` header
    /// - Standard inputs (`fragTexCoord`, `fragColor`)
    /// - `texture0` sampler (raylib's built-in sprite texture)
    /// - Standard auto-inject uniform declarations (`_time`, `_resolution`, `_deltaTime`)
    /// - All declared user uniforms
    /// - Requested include libraries
    /// - `sampleTexture(uv)` convenience function (multiplies by `fragColor` tint)
    /// - `finalColor` output variable
    ///
    /// - Parameters:
    ///   - uniforms: Map of GLSL uniform name to type string (e.g. `["amount": "float"]`).
    ///   - includes: Set of built-in GLSL includes to inject.
    ///   - body: GLSL fragment body. Write to `finalColor`.
    /// - Returns: Complete GLSL 330 fragment shader source.
    public static func createFragment(
        uniforms: [String: String] = [:],
        includes: Set<ShaderInclude> = [],
        body: String
    ) -> String {
        return buildShader(
            uniforms: uniforms,
            includes: includes,
            body: body,
            sampleMultipliesTint: true
        )
    }

    /// Create a fragment shader source string for post-processing.
    ///
    /// Same as `createFragment` but `sampleTexture(uv)` does NOT multiply by
    /// `fragColor` (post-process reads from a render target, not a tinted sprite).
    ///
    /// - Parameters:
    ///   - uniforms: Map of GLSL uniform name to type string.
    ///   - includes: Set of built-in GLSL includes to inject.
    ///   - body: GLSL fragment body. Write to `finalColor`.
    /// - Returns: Complete GLSL 330 fragment shader source.
    public static func createPostProcess(
        uniforms: [String: String] = [:],
        includes: Set<ShaderInclude> = [],
        body: String
    ) -> String {
        return buildShader(
            uniforms: uniforms,
            includes: includes,
            body: body,
            sampleMultipliesTint: false
        )
    }

    // MARK: - Private

    private static func buildShader(
        uniforms: [String: String],
        includes: Set<ShaderInclude>,
        body: String,
        sampleMultipliesTint: Bool
    ) -> String {
        var source = "#version 330\n\n"

        // Standard inputs
        source += "in vec2 fragTexCoord;\n"
        source += "in vec4 fragColor;\n\n"

        // Texture sampler
        source += "uniform sampler2D texture0;\n\n"

        // Auto-inject standard uniforms
        source += "// Standard auto-injected uniforms\n"
        source += "uniform float _time;\n"
        source += "uniform vec2 _resolution;\n"
        source += "uniform float _deltaTime;\n\n"

        // User uniforms (sorted for deterministic output)
        if !uniforms.isEmpty {
            source += "// User uniforms\n"
            for (name, type) in uniforms.sorted(by: { $0.key < $1.key }) {
                source += "uniform \(type) \(name);\n"
            }
            source += "\n"
        }

        // Includes (sorted for deterministic output)
        let sortedIncludes = includes.sorted(by: { $0.rawValue < $1.rawValue })
        for include in sortedIncludes {
            source += include.glslSource + "\n\n"
        }

        // Convenience texture sampler
        if sampleMultipliesTint {
            source += "vec4 sampleTexture(vec2 uv) {\n"
            source += "    return texture(texture0, uv) * fragColor;\n"
            source += "}\n\n"
        } else {
            source += "vec4 sampleTexture(vec2 uv) {\n"
            source += "    return texture(texture0, uv);\n"
            source += "}\n\n"
        }

        // Output and main
        source += "out vec4 finalColor;\n\n"
        source += "void main() {\n"
        source += body + "\n"
        source += "}\n"

        return source
    }
}
