/// Combines multiple fragment effects into a single GLSL shader program.
///
/// Each added effect transforms a `vec4 color` variable in sequence. The first
/// effect reads from `sampleTexture(fragTexCoord)`, and each subsequent effect
/// receives the previous effect's output.
///
/// ```swift
/// let composer = ShaderComposer()
/// composer.addEffect("grayscale",
///     body: "color.rgb = vec3(luminance(color.rgb));")
/// composer.addEffect("tint",
///     uniforms: ["tintColor": "vec3"],
///     body: "color.rgb *= tintColor;")
/// let source = composer.build()
/// let shader = renderer.loadShader(vertexSource: nil, fragmentSource: source)
/// ```
///
/// Use `ComposableEffects` for pre-built effect snippets.
public final class ShaderComposer: @unchecked Sendable {

    deinit {}

    /// A single composable effect step.
    private struct Effect {
        let name: String
        let uniforms: [String: String]
        let includes: Set<ShaderInclude>
        let body: String
    }

    private var effects: [Effect] = []
    private var isPostProcess: Bool = false

    public init() {}

    /// Configure this composer for post-processing (sampleTexture without tint).
    ///
    /// Call before `build()`. Default is sprite mode (sampleTexture multiplies fragColor).
    @discardableResult
    public func setPostProcess(_ enabled: Bool = true) -> ShaderComposer {
        isPostProcess = enabled
        return self
    }

    /// Add a named effect to the composition chain.
    ///
    /// The `body` should operate on a `vec4 color` variable. It is available as a
    /// local variable already containing the result of previous effects (or the
    /// initial texture sample for the first effect).
    ///
    /// - Parameters:
    ///   - name: Descriptive name (used as a comment in the output).
    ///   - uniforms: GLSL uniform declarations this effect needs (name → type).
    ///   - includes: Built-in GLSL include libraries this effect requires.
    ///   - body: GLSL code that reads/writes `color`.
    public func addEffect(
        _ name: String,
        uniforms: [String: String] = [:],
        includes: Set<ShaderInclude> = [],
        body: String
    ) {
        effects.append(Effect(
            name: name,
            uniforms: uniforms,
            includes: includes,
            body: body
        ))
    }

    /// Build the final GLSL ES 300 fragment shader source.
    ///
    /// All uniforms are merged (duplicates by name use the last-added type).
    /// All includes are deduplicated. Effects run in the order they were added.
    ///
    /// - Returns: Complete GLSL ES 300 fragment shader source string.
    public func build() -> String {
        // Merge uniforms across all effects (last-added type wins for duplicates)
        var mergedUniforms: [String: String] = [:]
        var mergedIncludes: Set<ShaderInclude> = []

        for effect in effects {
            for (name, type) in effect.uniforms {
                mergedUniforms[name] = type
            }
            mergedIncludes.formUnion(effect.includes)
        }

        // Build the composed body
        var body = "    vec4 color = sampleTexture(fragTexCoord);\n"
        for effect in effects {
            body += "\n    // --- \(effect.name) ---\n"
            // Indent each line of the effect body
            for line in effect.body.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
                if trimmed.isEmpty {
                    body += "\n"
                } else {
                    body += "    \(trimmed)\n"
                }
            }
        }
        body += "\n    finalColor = color;"

        if isPostProcess {
            return ShaderBuilder.createPostProcess(
                uniforms: mergedUniforms,
                includes: mergedIncludes,
                body: body
            )
        } else {
            return ShaderBuilder.createFragment(
                uniforms: mergedUniforms,
                includes: mergedIncludes,
                body: body
            )
        }
    }

    /// The number of effects currently in the chain.
    public var effectCount: Int { effects.count }
}
