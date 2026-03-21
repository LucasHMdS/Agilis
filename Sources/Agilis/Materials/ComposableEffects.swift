/// Pre-built effect snippets for use with `ShaderComposer`.
///
/// Each method returns a tuple of (uniforms, includes, body) that can be passed
/// directly to `ShaderComposer.addEffect`.
///
/// ```swift
/// let composer = ShaderComposer()
/// let (u1, i1, b1) = ComposableEffects.grayscale()
/// composer.addEffect("grayscale", uniforms: u1, includes: i1, body: b1)
/// let (u2, i2, b2) = ComposableEffects.tint()
/// composer.addEffect("tint", uniforms: u2, includes: i2, body: b2)
/// let source = composer.build()
/// ```
public enum ComposableEffects {

    /// Result type for composable effect snippets.
    public typealias Snippet = (
        uniforms: [String: String],
        includes: Set<ShaderInclude>,
        body: String
    )

    /// Convert to grayscale using perceptual luminance weights.
    ///
    /// - Uniform `grayscaleAmount` (float, 0–1): blend between original and grayscale.
    public static func grayscale() -> Snippet {
        (
            uniforms: ["grayscaleAmount": "float"],
            includes: [.color],
            body: """
            float luma = luminance(color.rgb);
            color.rgb = mix(color.rgb, vec3(luma), grayscaleAmount);
            """
        )
    }

    /// Flash/hit effect — blends toward a solid color.
    ///
    /// - Uniform `flashColor` (vec3): target flash color.
    /// - Uniform `flashAmount` (float, 0–1): blend strength.
    public static func flash() -> Snippet {
        (
            uniforms: ["flashColor": "vec3", "flashAmount": "float"],
            includes: [],
            body: """
            color.rgb = mix(color.rgb, flashColor, flashAmount);
            """
        )
    }

    /// Shift the hue of all pixels.
    ///
    /// - Uniform `hueShift` (float): amount to rotate hue (0–1 = full rotation).
    public static func hueShift() -> Snippet {
        (
            uniforms: ["hueShift": "float"],
            includes: [.color],
            body: """
            vec3 hsv = rgb2hsv(color.rgb);
            hsv.x = fract(hsv.x + hueShift);
            color.rgb = hsv2rgb(hsv);
            """
        )
    }

    /// Multiply color by a tint color.
    ///
    /// - Uniform `tintColor` (vec3): multiplicative tint.
    public static func tint() -> Snippet {
        (
            uniforms: ["tintColor": "vec3"],
            includes: [],
            body: """
            color.rgb *= tintColor;
            """
        )
    }

    /// Invert all color channels.
    ///
    /// - Uniform `invertAmount` (float, 0–1): blend between original and inverted.
    public static func invertColors() -> Snippet {
        (
            uniforms: ["invertAmount": "float"],
            includes: [],
            body: """
            vec3 inverted = vec3(1.0) - color.rgb;
            color.rgb = mix(color.rgb, inverted, invertAmount);
            """
        )
    }

    /// Adjust brightness and contrast.
    ///
    /// - Uniform `brightnessOffset` (float, -1 to 1): additive brightness.
    /// - Uniform `contrastScale` (float, 0–2): contrast multiplier.
    public static func brightnessContrast() -> Snippet {
        (
            uniforms: ["brightnessOffset": "float", "contrastScale": "float"],
            includes: [],
            body: """
            color.rgb += brightnessOffset;
            color.rgb = (color.rgb - 0.5) * contrastScale + 0.5;
            color.rgb = clamp(color.rgb, 0.0, 1.0);
            """
        )
    }
}
