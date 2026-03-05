/// Embedded GLSL shader source code for the 2D lighting system.
/// Shaders target OpenGL 3.3 (GLSL 330), which is raylib's default.
enum LightingShaders {

    /// Fragment shader for rendering a single point light into the light map.
    /// Produces a radial gradient with configurable color, intensity, radius, and falloff.
    ///
    /// Uniforms:
    ///   - lightPos: vec2 -- light position in screen space (pixels)
    ///   - lightColor: vec3 -- RGB color (0-1 range)
    ///   - lightRadius: float -- maximum reach in pixels
    ///   - lightIntensity: float -- brightness multiplier
    ///   - lightFalloff: float -- falloff exponent (1 = linear, 2 = quadratic)
    ///   - resolution: vec2 -- render target size in pixels
    static let pointLightFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform vec2 lightPos;
    uniform vec3 lightColor;
    uniform float lightRadius;
    uniform float lightIntensity;
    uniform float lightFalloff;
    uniform vec2 resolution;
    uniform sampler2D shadowBuffer;
    uniform int useShadowBuffer;

    out vec4 finalColor;

    void main() {
        // Convert from UV to pixel coordinates
        vec2 pixelPos = fragTexCoord * resolution;

        // Distance from this pixel to the light
        float dist = length(pixelPos - lightPos);

        // Normalized distance (0 at light center, 1 at radius)
        float normalizedDist = dist / lightRadius;

        // Attenuation with configurable falloff
        float attenuation = 1.0 - pow(clamp(normalizedDist, 0.0, 1.0), lightFalloff);
        attenuation *= lightIntensity;

        // Smooth edge falloff to prevent hard circular boundary
        attenuation *= smoothstep(1.0, 0.9, normalizedDist);

        // Apply soft shadow mask if available
        if (useShadowBuffer == 1) {
            float shadow = texture(shadowBuffer, fragTexCoord).r;
            attenuation *= shadow;
        }

        finalColor = vec4(lightColor * attenuation, attenuation);
    }
    """

    /// Fragment shader for a spotlight (cone-shaped light).
    ///
    /// Additional uniforms:
    ///   - lightDirection: vec2 -- normalized direction the spot faces
    ///   - lightConeAngle: float -- half-angle of the cone in radians
    static let spotLightFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform vec2 lightPos;
    uniform vec3 lightColor;
    uniform float lightRadius;
    uniform float lightIntensity;
    uniform float lightFalloff;
    uniform vec2 resolution;
    uniform vec2 lightDirection;
    uniform float lightConeAngle;
    uniform sampler2D shadowBuffer;
    uniform int useShadowBuffer;

    out vec4 finalColor;

    void main() {
        vec2 pixelPos = fragTexCoord * resolution;
        vec2 toPixel = pixelPos - lightPos;
        float dist = length(toPixel);

        float normalizedDist = dist / lightRadius;
        float attenuation = 1.0 - pow(clamp(normalizedDist, 0.0, 1.0), lightFalloff);
        attenuation *= lightIntensity;
        attenuation *= smoothstep(1.0, 0.9, normalizedDist);

        // Cone angle check
        vec2 dirToPixel = normalize(toPixel);
        float angle = acos(clamp(dot(dirToPixel, lightDirection), -1.0, 1.0));
        float coneFactor = smoothstep(lightConeAngle, lightConeAngle * 0.8, angle);
        attenuation *= coneFactor;

        // Apply soft shadow mask if available
        if (useShadowBuffer == 1) {
            float shadow = texture(shadowBuffer, fragTexCoord).r;
            attenuation *= shadow;
        }

        finalColor = vec4(lightColor * attenuation, attenuation);
    }
    """

    // MARK: - Normal-Mapped Light Shaders

    /// Point light with per-pixel diffuse from normal buffer.
    ///
    /// Additional uniforms over `pointLightFragment`:
    ///   - normalBuffer: sampler2D -- normal buffer render target
    ///   - lightZ: float -- virtual Z height for 3D light direction
    ///   - flipNormalY: int -- whether to flip normal Y (0 or 1)
    static let normalLitPointFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform vec2 lightPos;
    uniform vec3 lightColor;
    uniform float lightRadius;
    uniform float lightIntensity;
    uniform float lightFalloff;
    uniform vec2 resolution;
    uniform sampler2D normalBuffer;
    uniform float lightZ;
    uniform int flipNormalY;
    uniform sampler2D shadowBuffer;
    uniform int useShadowBuffer;

    out vec4 finalColor;

    vec3 decodeNormal(vec4 s, int flip) {
        vec3 n = s.rgb * 2.0 - 1.0;
        if (flip != 0) n.y = -n.y;
        return normalize(n);
    }

    void main() {
        vec2 pixelPos = fragTexCoord * resolution;
        float dist = length(pixelPos - lightPos);
        float normalizedDist = dist / lightRadius;

        float attenuation = 1.0 - pow(clamp(normalizedDist, 0.0, 1.0), lightFalloff);
        attenuation *= lightIntensity;
        attenuation *= smoothstep(1.0, 0.9, normalizedDist);

        // Sample normal buffer and compute diffuse
        vec4 normalSample = texture(normalBuffer, fragTexCoord);
        vec3 normal = decodeNormal(normalSample, flipNormalY);
        vec3 lightDir = normalize(vec3(lightPos - pixelPos, lightZ));
        float diffuse = max(dot(normal, lightDir), 0.0);

        attenuation *= diffuse;

        // Apply soft shadow mask if available
        if (useShadowBuffer == 1) {
            float shadow = texture(shadowBuffer, fragTexCoord).r;
            attenuation *= shadow;
        }

        finalColor = vec4(lightColor * attenuation, attenuation);
    }
    """

    /// Spot light with per-pixel diffuse from normal buffer.
    ///
    /// Additional uniforms over `spotLightFragment`:
    ///   - normalBuffer: sampler2D -- normal buffer render target
    ///   - lightZ: float -- virtual Z height for 3D light direction
    ///   - flipNormalY: int -- whether to flip normal Y (0 or 1)
    static let normalLitSpotFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform vec2 lightPos;
    uniform vec3 lightColor;
    uniform float lightRadius;
    uniform float lightIntensity;
    uniform float lightFalloff;
    uniform vec2 resolution;
    uniform vec2 lightDirection;
    uniform float lightConeAngle;
    uniform sampler2D normalBuffer;
    uniform float lightZ;
    uniform int flipNormalY;
    uniform sampler2D shadowBuffer;
    uniform int useShadowBuffer;

    out vec4 finalColor;

    vec3 decodeNormal(vec4 s, int flip) {
        vec3 n = s.rgb * 2.0 - 1.0;
        if (flip != 0) n.y = -n.y;
        return normalize(n);
    }

    void main() {
        vec2 pixelPos = fragTexCoord * resolution;
        vec2 toPixel = pixelPos - lightPos;
        float dist = length(toPixel);
        float normalizedDist = dist / lightRadius;

        float attenuation = 1.0 - pow(clamp(normalizedDist, 0.0, 1.0), lightFalloff);
        attenuation *= lightIntensity;
        attenuation *= smoothstep(1.0, 0.9, normalizedDist);

        // Cone angle check
        vec2 dirToPixel = normalize(toPixel);
        float angle = acos(clamp(dot(dirToPixel, lightDirection), -1.0, 1.0));
        float coneFactor = smoothstep(lightConeAngle, lightConeAngle * 0.8, angle);
        attenuation *= coneFactor;

        // Sample normal buffer and compute diffuse
        vec4 normalSample = texture(normalBuffer, fragTexCoord);
        vec3 normal = decodeNormal(normalSample, flipNormalY);
        vec3 lightDir = normalize(vec3(lightPos - pixelPos, lightZ));
        float diffuse = max(dot(normal, lightDir), 0.0);

        attenuation *= diffuse;

        // Apply soft shadow mask if available
        if (useShadowBuffer == 1) {
            float shadow = texture(shadowBuffer, fragTexCoord).r;
            attenuation *= shadow;
        }

        finalColor = vec4(lightColor * attenuation, attenuation);
    }
    """

    // MARK: - Specular Light Shaders

    /// Point light specular pass (additive). Produces Blinn-Phong highlights.
    ///
    /// Additional uniforms:
    ///   - normalBuffer: sampler2D -- normal buffer render target
    ///   - specularBuffer: sampler2D -- specular buffer (R = intensity)
    ///   - lightZ: float -- virtual Z height
    ///   - flipNormalY: int -- whether to flip normal Y
    ///   - specularStrength: float -- per-light specular multiplier
    ///   - shininess: float -- Blinn-Phong exponent
    static let specularPointFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform vec2 lightPos;
    uniform vec3 lightColor;
    uniform float lightRadius;
    uniform float lightIntensity;
    uniform float lightFalloff;
    uniform vec2 resolution;
    uniform sampler2D normalBuffer;
    uniform sampler2D specularBuffer;
    uniform float lightZ;
    uniform int flipNormalY;
    uniform float specularStrength;
    uniform float shininess;
    uniform sampler2D shadowBuffer;
    uniform int useShadowBuffer;

    out vec4 finalColor;

    vec3 decodeNormal(vec4 s, int flip) {
        vec3 n = s.rgb * 2.0 - 1.0;
        if (flip != 0) n.y = -n.y;
        return normalize(n);
    }

    void main() {
        vec2 pixelPos = fragTexCoord * resolution;
        float dist = length(pixelPos - lightPos);
        float normalizedDist = dist / lightRadius;

        float attenuation = 1.0 - pow(clamp(normalizedDist, 0.0, 1.0), lightFalloff);
        attenuation *= lightIntensity;
        attenuation *= smoothstep(1.0, 0.9, normalizedDist);

        // Apply soft shadow mask if available
        if (useShadowBuffer == 1) {
            float shadow = texture(shadowBuffer, fragTexCoord).r;
            attenuation *= shadow;
        }

        // Normal and light direction
        vec4 normalSample = texture(normalBuffer, fragTexCoord);
        vec3 normal = decodeNormal(normalSample, flipNormalY);
        vec3 lightDir = normalize(vec3(lightPos - pixelPos, lightZ));

        // Blinn-Phong specular
        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        vec3 halfDir = normalize(lightDir + viewDir);
        float spec = pow(max(dot(normal, halfDir), 0.0), shininess);

        // Specular intensity from buffer
        float specIntensity = texture(specularBuffer, fragTexCoord).r;

        float result = attenuation * spec * specIntensity * specularStrength;
        finalColor = vec4(lightColor * result, result);
    }
    """

    /// Spot light specular pass (additive).
    ///
    /// Same additional uniforms as `specularPointFragment` plus:
    ///   - lightDirection: vec2 -- normalized spot direction
    ///   - lightConeAngle: float -- half-angle of the cone
    static let specularSpotFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform vec2 lightPos;
    uniform vec3 lightColor;
    uniform float lightRadius;
    uniform float lightIntensity;
    uniform float lightFalloff;
    uniform vec2 resolution;
    uniform vec2 lightDirection;
    uniform float lightConeAngle;
    uniform sampler2D normalBuffer;
    uniform sampler2D specularBuffer;
    uniform float lightZ;
    uniform int flipNormalY;
    uniform float specularStrength;
    uniform float shininess;
    uniform sampler2D shadowBuffer;
    uniform int useShadowBuffer;

    out vec4 finalColor;

    vec3 decodeNormal(vec4 s, int flip) {
        vec3 n = s.rgb * 2.0 - 1.0;
        if (flip != 0) n.y = -n.y;
        return normalize(n);
    }

    void main() {
        vec2 pixelPos = fragTexCoord * resolution;
        vec2 toPixel = pixelPos - lightPos;
        float dist = length(toPixel);
        float normalizedDist = dist / lightRadius;

        float attenuation = 1.0 - pow(clamp(normalizedDist, 0.0, 1.0), lightFalloff);
        attenuation *= lightIntensity;
        attenuation *= smoothstep(1.0, 0.9, normalizedDist);

        // Cone angle check
        vec2 dirToPixel = normalize(toPixel);
        float angle = acos(clamp(dot(dirToPixel, lightDirection), -1.0, 1.0));
        float coneFactor = smoothstep(lightConeAngle, lightConeAngle * 0.8, angle);
        attenuation *= coneFactor;

        // Apply soft shadow mask if available
        if (useShadowBuffer == 1) {
            float shadow = texture(shadowBuffer, fragTexCoord).r;
            attenuation *= shadow;
        }

        // Normal and light direction
        vec4 normalSample = texture(normalBuffer, fragTexCoord);
        vec3 normal = decodeNormal(normalSample, flipNormalY);
        vec3 lightDir = normalize(vec3(lightPos - pixelPos, lightZ));

        // Blinn-Phong specular
        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        vec3 halfDir = normalize(lightDir + viewDir);
        float spec = pow(max(dot(normal, halfDir), 0.0), shininess);

        // Specular intensity from buffer
        float specIntensity = texture(specularBuffer, fragTexCoord).r;

        float result = attenuation * spec * specIntensity * specularStrength;
        finalColor = vec4(lightColor * result, result);
    }
    """

    // MARK: - Normal Buffer Pass Shader

    /// Renders a sprite's normal map to the normal buffer.
    /// Simply samples texture0 (the normal map) and outputs the RGB.
    static let normalPassFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;

    out vec4 finalColor;

    void main() {
        finalColor = texture(texture0, fragTexCoord);
    }
    """

    // MARK: - Shadow Blur Shaders

    /// Horizontal Gaussian blur for the shadow buffer.
    /// 9-tap separable kernel applied along the X axis.
    ///
    /// Uniforms:
    ///   - resolution: vec2 -- shadow buffer size in pixels
    ///   - blurRadius: float -- blur spread in pixels
    static let shadowBlurHorizontalFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform vec2 resolution;
    uniform float blurRadius;

    out vec4 finalColor;

    void main() {
        float weights[5] = float[](0.227027, 0.194596, 0.121622, 0.054054, 0.016216);
        float texelSize = blurRadius / resolution.x;

        vec3 result = texture(texture0, fragTexCoord).rgb * weights[0];
        for (int i = 1; i < 5; i++) {
            float offset = float(i) * texelSize;
            result += texture(texture0, fragTexCoord + vec2(offset, 0.0)).rgb * weights[i];
            result += texture(texture0, fragTexCoord - vec2(offset, 0.0)).rgb * weights[i];
        }

        finalColor = vec4(result, 1.0);
    }
    """

    /// Vertical Gaussian blur for the shadow buffer.
    /// 9-tap separable kernel applied along the Y axis.
    ///
    /// Uniforms:
    ///   - resolution: vec2 -- shadow buffer size in pixels
    ///   - blurRadius: float -- blur spread in pixels
    static let shadowBlurVerticalFragment = """
    #version 330

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;
    uniform vec2 resolution;
    uniform float blurRadius;

    out vec4 finalColor;

    void main() {
        float weights[5] = float[](0.227027, 0.194596, 0.121622, 0.054054, 0.016216);
        float texelSize = blurRadius / resolution.y;

        vec3 result = texture(texture0, fragTexCoord).rgb * weights[0];
        for (int i = 1; i < 5; i++) {
            float offset = float(i) * texelSize;
            result += texture(texture0, fragTexCoord + vec2(0.0, offset)).rgb * weights[i];
            result += texture(texture0, fragTexCoord - vec2(0.0, offset)).rgb * weights[i];
        }

        finalColor = vec4(result, 1.0);
    }
    """
}
