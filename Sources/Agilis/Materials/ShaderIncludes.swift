/// Built-in GLSL include libraries that can be injected into custom shaders.
///
/// Use with `ShaderBuilder` to add common utility functions to your shaders
/// without writing boilerplate GLSL.
///
/// ```swift
/// let source = ShaderBuilder.createFragment(
///     uniforms: ["hueShift": "float"],
///     includes: [.color, .noise],
///     body: """
///     vec4 color = sampleTexture(fragTexCoord);
///     vec3 hsv = rgb2hsv(color.rgb);
///     hsv.x = fract(hsv.x + hueShift);
///     color.rgb = hsv2rgb(hsv);
///     float n = noise2D(fragTexCoord * 20.0);
///     color.rgb += n * 0.05;
///     finalColor = color;
///     """
/// )
/// ```
public enum ShaderInclude: String, Sendable, CaseIterable {
    /// Noise functions: `hash21`, `noise2D`, `fbm`.
    case noise

    /// Easing functions: `easeQuadIn/Out`, `easeCubicIn/Out`, `easeSineIn/Out`, `easeSmoothstep`.
    case easing

    /// UV manipulation: `rotateUV`, `scrollUV`, `tileUV`.
    case uv

    /// Color utilities: `rgb2hsv`, `hsv2rgb`, `luminance`.
    case color

    /// Math utilities: `remap`, `smootherStep`, `inverseLerp`.
    case math

    /// Normal mapping utilities: `decodeNormal`, `lightDirection3D`,
    /// `lambertDiffuse`, `blinnPhongSpecular`.
    case normalMapping

    /// The GLSL source for this include library.
    var glslSource: String {
        switch self {
        case .noise: return ShaderIncludeLibrary.noise
        case .easing: return ShaderIncludeLibrary.easing
        case .uv: return ShaderIncludeLibrary.uv
        case .color: return ShaderIncludeLibrary.color
        case .math: return ShaderIncludeLibrary.math
        case .normalMapping: return ShaderIncludeLibrary.normalMapping
        }
    }
}

/// GLSL source code for include libraries. Each function is self-contained
/// with no dependencies on other includes.
enum ShaderIncludeLibrary {
    static let noise = """
    // --- Noise functions ---
    float hash21(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }

    float noise2D(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash21(i);
        float b = hash21(i + vec2(1.0, 0.0));
        float c = hash21(i + vec2(0.0, 1.0));
        float d = hash21(i + vec2(1.0, 1.0));
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }

    float fbm(vec2 p, int octaves) {
        float value = 0.0;
        float amplitude = 0.5;
        for (int i = 0; i < octaves; i++) {
            value += amplitude * noise2D(p);
            p *= 2.0;
            amplitude *= 0.5;
        }
        return value;
    }
    """

    static let easing = """
    // --- Easing functions ---
    float easeQuadIn(float t) { return t * t; }
    float easeQuadOut(float t) { return t * (2.0 - t); }
    float easeCubicIn(float t) { return t * t * t; }
    float easeCubicOut(float t) { float f = t - 1.0; return f * f * f + 1.0; }
    float easeSineIn(float t) { return 1.0 - cos(t * 3.14159265 * 0.5); }
    float easeSineOut(float t) { return sin(t * 3.14159265 * 0.5); }
    float easeSmoothstep(float t) { return t * t * (3.0 - 2.0 * t); }
    """

    static let uv = """
    // --- UV manipulation ---
    vec2 rotateUV(vec2 uv, float angle, vec2 center) {
        float c = cos(angle);
        float s = sin(angle);
        uv -= center;
        return vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c) + center;
    }

    vec2 scrollUV(vec2 uv, vec2 speed, float time) {
        return fract(uv + speed * time);
    }

    vec2 tileUV(vec2 uv, vec2 tiles) {
        return fract(uv * tiles);
    }
    """

    static let color = """
    // --- Color utilities ---
    vec3 rgb2hsv(vec3 c) {
        vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
        vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
        vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
        float d = q.x - min(q.w, q.y);
        float e = 1.0e-10;
        return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    }

    vec3 hsv2rgb(vec3 c) {
        vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
        return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
    }

    float luminance(vec3 c) {
        return dot(c, vec3(0.2126, 0.7152, 0.0722));
    }
    """

    static let math = """
    // --- Math utilities ---
    float remap(float value, float inMin, float inMax, float outMin, float outMax) {
        return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
    }

    float smootherStep(float edge0, float edge1, float x) {
        x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
        return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
    }

    float inverseLerp(float a, float b, float v) {
        return (v - a) / (b - a);
    }
    """

    static let normalMapping = """
    // --- Normal mapping utilities ---

    // Decode tangent-space normal from a normal map sample (0-1 range to -1..1).
    vec3 decodeNormal(vec4 normalSample, int flipY) {
        vec3 n = normalSample.rgb * 2.0 - 1.0;
        if (flipY != 0) n.y = -n.y;
        return normalize(n);
    }

    // Compute 3D light direction from screen-space positions with virtual Z height.
    vec3 lightDirection3D(vec2 pixelPos, vec2 lightPos, float lightZ) {
        return normalize(vec3(lightPos - pixelPos, lightZ));
    }

    // Lambert diffuse factor.
    float lambertDiffuse(vec3 normal, vec3 lightDir) {
        return max(dot(normal, lightDir), 0.0);
    }

    // Blinn-Phong specular (view direction is always (0,0,1) for top-down 2D).
    float blinnPhongSpecular(vec3 normal, vec3 lightDir, float shininess) {
        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        vec3 halfDir = normalize(lightDir + viewDir);
        return pow(max(dot(normal, halfDir), 0.0), shininess);
    }
    """
}
