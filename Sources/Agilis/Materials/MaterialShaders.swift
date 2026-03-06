/// Embedded GLSL ES 300 fragment shaders for built-in material effects.
///
/// All shaders use the engine's default vertex shader (pass `nil` for vertex source).
/// The sprite texture is available as `texture0` (the engine's built-in sampler).
/// Fragment inputs `fragTexCoord` and `fragColor` come from the default vertex shader.
enum MaterialShaders {

    // MARK: - Flash

    /// Hit flash / damage blink effect.
    ///
    /// Mixes the original texture color with a solid color.
    /// - `flashColor`: vec4 — the flash color (RGBA, 0-1)
    /// - `flashAmount`: float — mix factor (0 = original, 1 = solid flash color)
    static let flashFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform vec4 flashColor;
    uniform float flashAmount;

    out vec4 finalColor;

    void main() {
        vec4 texel = texture(texture0, fragTexCoord) * fragColor;
        // Mix original color with flash color, preserving alpha
        vec3 mixed = mix(texel.rgb, flashColor.rgb, flashAmount);
        finalColor = vec4(mixed, texel.a * flashColor.a);
    }
    """

    // MARK: - Grayscale

    /// Desaturation effect.
    ///
    /// Converts to grayscale using standard luminance coefficients.
    /// - `amount`: float — desaturation amount (0 = full color, 1 = full grayscale)
    static let grayscaleFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float amount;

    out vec4 finalColor;

    void main() {
        vec4 texel = texture(texture0, fragTexCoord) * fragColor;
        float gray = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
        vec3 result = mix(texel.rgb, vec3(gray), amount);
        finalColor = vec4(result, texel.a);
    }
    """

    // MARK: - Dissolve

    /// Dissolve / disintegration effect using procedural noise.
    ///
    /// Pixels are discarded based on a noise pattern as threshold increases.
    /// An optional glowing edge appears at the dissolve boundary.
    /// - `threshold`: float — dissolve progress (0 = fully visible, 1 = fully dissolved)
    /// - `edgeWidth`: float — width of the glowing edge band (0-1, default 0.05)
    /// - `edgeColor`: vec4 — color of the dissolve edge (RGBA, 0-1)
    static let dissolveFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float threshold;
    uniform float edgeWidth;
    uniform vec4 edgeColor;

    out vec4 finalColor;

    // Simple hash-based noise (no texture dependency)
    float hash(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }

    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);

        float a = hash(i);
        float b = hash(i + vec2(1.0, 0.0));
        float c = hash(i + vec2(0.0, 1.0));
        float d = hash(i + vec2(1.0, 1.0));

        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }

    void main() {
        vec4 texel = texture(texture0, fragTexCoord) * fragColor;

        // Multi-octave noise for organic dissolve pattern
        float n = noise(fragTexCoord * 20.0) * 0.6
                + noise(fragTexCoord * 40.0) * 0.3
                + noise(fragTexCoord * 80.0) * 0.1;

        // Discard dissolved pixels
        if (n < threshold) {
            discard;
        }

        // Glowing edge at dissolve boundary
        float edgeFactor = 1.0 - smoothstep(0.0, edgeWidth, n - threshold);
        vec3 result = mix(texel.rgb, edgeColor.rgb, edgeFactor * edgeColor.a);
        finalColor = vec4(result, texel.a);
    }
    """

    // MARK: - Outline

    /// Sprite outline effect.
    ///
    /// Draws a colored outline around opaque regions of the sprite by sampling
    /// neighboring texels. Transparent pixels adjacent to opaque pixels become
    /// the outline color.
    /// - `outlineColor`: vec4 — outline color (RGBA, 0-1)
    /// - `outlineWidth`: float — outline thickness in pixels
    /// - `textureSize`: vec2 — texture dimensions in pixels (for texel offset calculation)
    static let outlineFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform vec4 outlineColor;
    uniform float outlineWidth;
    uniform vec2 textureSize;

    out vec4 finalColor;

    void main() {
        vec4 texel = texture(texture0, fragTexCoord) * fragColor;
        vec2 texelSize = outlineWidth / textureSize;

        // If the current pixel is opaque, keep it as-is
        if (texel.a > 0.1) {
            finalColor = texel;
            return;
        }

        // Sample 8 neighbors for outline detection
        float maxAlpha = 0.0;
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2( texelSize.x, 0.0)).a);
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2(-texelSize.x, 0.0)).a);
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2(0.0,  texelSize.y)).a);
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2(0.0, -texelSize.y)).a);
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2( texelSize.x,  texelSize.y)).a);
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2(-texelSize.x,  texelSize.y)).a);
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2( texelSize.x, -texelSize.y)).a);
        maxAlpha = max(maxAlpha, texture(texture0, fragTexCoord + vec2(-texelSize.x, -texelSize.y)).a);

        // If any neighbor is opaque, draw outline
        if (maxAlpha > 0.1) {
            finalColor = outlineColor;
        } else {
            finalColor = texel;
        }
    }
    """

    // MARK: - Color Replace

    /// Color replacement / palette swap effect.
    ///
    /// Replaces pixels matching a target color (within tolerance) with a replacement color.
    /// - `targetColor`: vec3 — the color to replace (RGB, 0-1)
    /// - `replacementColor`: vec3 — the new color (RGB, 0-1)
    /// - `tolerance`: float — how close a pixel must be to targetColor to be replaced (0-1)
    static let colorReplaceFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform vec3 targetColor;
    uniform vec3 replacementColor;
    uniform float tolerance;

    out vec4 finalColor;

    void main() {
        vec4 texel = texture(texture0, fragTexCoord) * fragColor;
        float dist = distance(texel.rgb, targetColor);
        if (dist <= tolerance) {
            // Smooth transition at the tolerance boundary
            float blend = smoothstep(tolerance, tolerance * 0.5, dist);
            vec3 result = mix(texel.rgb, replacementColor, blend);
            finalColor = vec4(result, texel.a);
        } else {
            finalColor = texel;
        }
    }
    """

    // MARK: - Wave

    /// Sine wave distortion effect (underwater / heat shimmer).
    ///
    /// Applies a sine-based displacement to UV coordinates for a wavy appearance.
    /// - `time`: float — elapsed time in seconds (for animation)
    /// - `amplitude`: float — wave height in UV space (default ~0.01)
    /// - `frequency`: float — number of wave cycles across the sprite (default 10)
    /// - `speed`: float — wave scroll speed (default 3)
    static let waveFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float time;
    uniform float amplitude;
    uniform float frequency;
    uniform float speed;

    out vec4 finalColor;

    void main() {
        vec2 uv = fragTexCoord;
        uv.x += sin(uv.y * frequency + time * speed) * amplitude;
        uv.y += cos(uv.x * frequency + time * speed * 0.7) * amplitude * 0.5;

        // Clamp UV to avoid sampling outside texture
        uv = clamp(uv, 0.0, 1.0);

        finalColor = texture(texture0, uv) * fragColor;
    }
    """
}
