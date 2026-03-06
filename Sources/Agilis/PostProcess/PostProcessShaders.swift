/// Embedded GLSL ES 300 fragment shaders for built-in post-processing effects.
///
/// All shaders use the engine's default vertex shader (pass `nil` for vertex source).
/// The input render target texture is available as `texture0`.
/// Fragment inputs `fragTexCoord` and `fragColor` come from the default vertex shader.
enum PostProcessShaders {

    // MARK: - Vignette

    /// Darkens screen edges with configurable falloff.
    ///
    /// - `intensity`: float (0-1) -- how dark the edges get
    /// - `radius`: float (0-1) -- where vignette starts (distance from center)
    /// - `softness`: float (0-1) -- falloff width
    static let vignetteFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float intensity;
    uniform float radius;
    uniform float softness;

    out vec4 finalColor;

    void main() {
        vec4 color = texture(texture0, fragTexCoord);
        vec2 uv = fragTexCoord - 0.5;
        float dist = length(uv) * 2.0;
        float vignette = 1.0 - smoothstep(radius, radius + softness, dist) * intensity;
        finalColor = vec4(color.rgb * vignette, color.a);
    }
    """

    // MARK: - Chromatic Aberration

    /// Radial RGB channel offset for a lens distortion look.
    ///
    /// - `amount`: float -- offset in UV space (e.g. 0.003)
    static let chromaticAberrationFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float amount;

    out vec4 finalColor;

    void main() {
        vec2 center = vec2(0.5);
        vec2 dir = fragTexCoord - center;
        vec2 offset = normalize(dir) * amount;

        float r = texture(texture0, fragTexCoord + offset).r;
        float g = texture(texture0, fragTexCoord).g;
        float b = texture(texture0, fragTexCoord - offset).b;
        float a = texture(texture0, fragTexCoord).a;
        finalColor = vec4(r, g, b, a);
    }
    """

    // MARK: - Color Grading

    /// Color adjustment: brightness, contrast, saturation, gamma, tint.
    ///
    /// - `brightness`: float (-1 to 1, default 0) -- additive brightness
    /// - `contrast`: float (0-2, default 1) -- contrast multiplier
    /// - `saturation`: float (0-2, default 1) -- saturation multiplier
    /// - `gamma`: float (0.1-3, default 1) -- gamma correction
    /// - `tint`: vec3 (default 1,1,1) -- color multiply
    static let colorGradingFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float brightness;
    uniform float contrast;
    uniform float saturation;
    uniform float gamma;
    uniform vec3 tint;

    out vec4 finalColor;

    void main() {
        vec4 color = texture(texture0, fragTexCoord);

        // Brightness
        color.rgb += brightness;

        // Contrast
        color.rgb = (color.rgb - 0.5) * contrast + 0.5;

        // Saturation
        float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        color.rgb = mix(vec3(luma), color.rgb, saturation);

        // Gamma
        color.rgb = pow(max(color.rgb, vec3(0.0)), vec3(1.0 / gamma));

        // Tint
        color.rgb *= tint;

        finalColor = vec4(clamp(color.rgb, 0.0, 1.0), color.a);
    }
    """

    // MARK: - Scanlines

    /// CRT scanline simulation with optional barrel distortion.
    ///
    /// - `lineSpacing`: float -- pixels between lines (default 2.0)
    /// - `lineIntensity`: float (0-1) -- darkness of lines (default 0.15)
    /// - `curvature`: float (0-1) -- barrel distortion (default 0.0)
    /// - `resolution`: vec2 -- screen resolution in pixels
    static let scanlinesFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float lineSpacing;
    uniform float lineIntensity;
    uniform float curvature;
    uniform vec2 resolution;

    out vec4 finalColor;

    void main() {
        vec2 uv = fragTexCoord;

        // Optional barrel distortion for CRT curvature
        if (curvature > 0.0) {
            vec2 centered = uv - 0.5;
            float r2 = dot(centered, centered);
            uv = 0.5 + centered * (1.0 + curvature * r2);
        }

        vec4 color = texture(texture0, uv);

        // Scanline darkening
        float scanline = sin(uv.y * resolution.y * 3.14159 / lineSpacing) * 0.5 + 0.5;
        color.rgb *= 1.0 - (scanline * lineIntensity);

        // Black outside screen bounds when curvature is applied
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            color = vec4(0.0);
        }

        finalColor = color;
    }
    """

    // MARK: - Pixelate

    /// Reduces effective resolution for a retro pixelation look.
    ///
    /// - `pixelSize`: float -- virtual pixel size in screen pixels (e.g. 4.0)
    /// - `resolution`: vec2 -- screen resolution in pixels
    static let pixelateFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float pixelSize;
    uniform vec2 resolution;

    out vec4 finalColor;

    void main() {
        vec2 grid = floor(fragTexCoord * resolution / pixelSize) * pixelSize / resolution;
        finalColor = texture(texture0, grid);
    }
    """

    // MARK: - Bloom

    /// Pass 1: Extract bright pixels and apply horizontal Gaussian blur.
    ///
    /// - `threshold`: float -- brightness threshold for extraction (default 0.8)
    /// - `resolution`: vec2 -- render target resolution
    static let bloomExtractFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform float threshold;
    uniform vec2 resolution;

    out vec4 finalColor;

    void main() {
        vec2 texelSize = 1.0 / resolution;

        // 9-tap Gaussian weights
        float weights[5] = float[](0.227027, 0.194596, 0.121622, 0.054054, 0.016216);

        // Extract bright pixels from center sample
        vec4 center = texture(texture0, fragTexCoord);
        float brightness = dot(center.rgb, vec3(0.2126, 0.7152, 0.0722));
        vec3 result = (brightness > threshold) ? center.rgb * weights[0] : vec3(0.0);

        // Horizontal Gaussian blur on bright pixels
        for (int i = 1; i < 5; i++) {
            vec2 offsetR = vec2(texelSize.x * float(i), 0.0);
            vec2 offsetL = vec2(-texelSize.x * float(i), 0.0);

            vec4 sampleR = texture(texture0, fragTexCoord + offsetR);
            float brightR = dot(sampleR.rgb, vec3(0.2126, 0.7152, 0.0722));
            result += ((brightR > threshold) ? sampleR.rgb : vec3(0.0)) * weights[i];

            vec4 sampleL = texture(texture0, fragTexCoord + offsetL);
            float brightL = dot(sampleL.rgb, vec3(0.2126, 0.7152, 0.0722));
            result += ((brightL > threshold) ? sampleL.rgb : vec3(0.0)) * weights[i];
        }

        finalColor = vec4(result, 1.0);
    }
    """

    /// Pass 2: Vertical Gaussian blur, then additive composite with original scene.
    ///
    /// - `sceneTexture`: sampler2D -- the original unprocessed scene
    /// - `intensity`: float -- bloom strength multiplier (default 1.0)
    /// - `resolution`: vec2 -- render target resolution
    static let bloomCompositeFragment = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform sampler2D sceneTexture;
    uniform float intensity;
    uniform vec2 resolution;

    out vec4 finalColor;

    void main() {
        vec2 texelSize = 1.0 / resolution;

        // 9-tap Gaussian weights
        float weights[5] = float[](0.227027, 0.194596, 0.121622, 0.054054, 0.016216);

        // Vertical Gaussian blur on the bright/blurred input
        vec3 bloom = texture(texture0, fragTexCoord).rgb * weights[0];
        for (int i = 1; i < 5; i++) {
            vec2 offsetU = vec2(0.0, texelSize.y * float(i));
            vec2 offsetD = vec2(0.0, -texelSize.y * float(i));
            bloom += texture(texture0, fragTexCoord + offsetU).rgb * weights[i];
            bloom += texture(texture0, fragTexCoord + offsetD).rgb * weights[i];
        }

        // Additive composite with original scene
        vec4 scene = texture(sceneTexture, fragTexCoord);
        finalColor = vec4(scene.rgb + bloom * intensity, scene.a);
    }
    """
}
