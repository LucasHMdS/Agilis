

/// A library of built-in material effects with shader lifecycle management.
///
/// `MaterialLibrary` loads and caches the GLSL shaders for built-in effects,
/// and provides factory methods that return configured `Material2D` values.
///
/// ```swift
/// // Setup (once, e.g. in Scene.didEnter)
/// let materials = MaterialLibrary()
/// materials.initialize(renderer: app.renderer)
///
/// // Create materials per-frame
/// var sprite = Sprite(texture: playerTex)
/// sprite.material = materials.flash(color: .white, amount: 1.0)
/// app.renderer.drawSprite(sprite)
///
/// // Cleanup (e.g. in Scene.willExit)
/// materials.shutdown()
/// ```
public final class MaterialLibrary: @unchecked Sendable {
    private var shaderCache: [String: ShaderHandle] = [:]
    private var renderer: (any RenderBackend)?

    public init() {}

    /// Load all built-in shaders. Call once during setup (e.g., `Scene.didEnter`).
    ///
    /// Pre-loads all 6 built-in shaders to avoid hitches during gameplay.
    /// If not called, shaders are lazily loaded on first use.
    public func initialize(renderer: any RenderBackend) {
        self.renderer = renderer

        // Pre-load all built-in shaders
        _ = loadShader(name: "flash", source: MaterialShaders.flashFragment)
        _ = loadShader(name: "grayscale", source: MaterialShaders.grayscaleFragment)
        _ = loadShader(name: "dissolve", source: MaterialShaders.dissolveFragment)
        _ = loadShader(name: "outline", source: MaterialShaders.outlineFragment)
        _ = loadShader(name: "colorReplace", source: MaterialShaders.colorReplaceFragment)
        _ = loadShader(name: "wave", source: MaterialShaders.waveFragment)
    }

    /// Free all cached shaders. Call during teardown (e.g., `Scene.willExit`).
    public func shutdown() {
        guard let renderer = renderer else { return }
        for (_, handle) in shaderCache {
            renderer.destroyShader(handle)
        }
        shaderCache.removeAll()
        self.renderer = nil
    }

    /// Whether the library has been initialized with a renderer.
    public var isInitialized: Bool { renderer != nil }

    // MARK: - Built-in Effects

    /// Create a flash / hit blink material.
    ///
    /// Mixes the sprite's texture color with a solid color.
    /// Useful for damage feedback, selection highlighting, or power-up effects.
    ///
    /// - Parameters:
    ///   - color: The flash color (default: white).
    ///   - amount: Mix factor — 0 = original, 1 = solid flash color (default: 1.0).
    /// - Returns: A configured `Material2D` with the flash shader.
    public func flash(color: Color = .white, amount: Float = 1.0) -> Material2D {
        let shader = getOrLoadShader(name: "flash", source: MaterialShaders.flashFragment)
        return Material2D(shader: shader, uniforms: [
            "flashColor": .color(color),
            "flashAmount": .float(amount),
        ])
    }

    /// Create a grayscale / desaturation material.
    ///
    /// Converts the sprite to grayscale using standard luminance coefficients.
    /// Useful for disabled states, death effects, or stylistic choices.
    ///
    /// - Parameter amount: Desaturation — 0 = full color, 1 = full grayscale (default: 1.0).
    /// - Returns: A configured `Material2D` with the grayscale shader.
    public func grayscale(amount: Float = 1.0) -> Material2D {
        let shader = getOrLoadShader(name: "grayscale", source: MaterialShaders.grayscaleFragment)
        return Material2D(shader: shader, uniforms: [
            "amount": .float(amount),
        ])
    }

    /// Create a dissolve / disintegration material.
    ///
    /// Progressively dissolves the sprite using a procedural noise pattern.
    /// Animate `threshold` from 0 to 1 for a death/disappear effect.
    ///
    /// - Parameters:
    ///   - threshold: Dissolve progress — 0 = fully visible, 1 = fully dissolved.
    ///   - edgeWidth: Width of the glowing edge band (default: 0.05).
    ///   - edgeColor: Color of the dissolve edge (default: white).
    /// - Returns: A configured `Material2D` with the dissolve shader.
    public func dissolve(
        threshold: Float,
        edgeWidth: Float = 0.05,
        edgeColor: Color = .white
    ) -> Material2D {
        let shader = getOrLoadShader(name: "dissolve", source: MaterialShaders.dissolveFragment)
        return Material2D(shader: shader, uniforms: [
            "threshold": .float(threshold),
            "edgeWidth": .float(edgeWidth),
            "edgeColor": .color(edgeColor),
        ])
    }

    /// Create a sprite outline material.
    ///
    /// Draws a colored outline around opaque regions of the sprite.
    /// Transparent pixels adjacent to opaque pixels become the outline color.
    ///
    /// - Parameters:
    ///   - color: Outline color (default: white).
    ///   - width: Outline thickness in pixels (default: 1.0).
    ///   - textureSize: The sprite texture dimensions in pixels (needed for texel calculation).
    /// - Returns: A configured `Material2D` with the outline shader.
    public func outline(
        color: Color = .white,
        width: Float = 1.0,
        textureSize: Vector2
    ) -> Material2D {
        let shader = getOrLoadShader(name: "outline", source: MaterialShaders.outlineFragment)
        return Material2D(shader: shader, uniforms: [
            "outlineColor": .color(color),
            "outlineWidth": .float(width),
            "textureSize": .vec2(textureSize),
        ])
    }

    /// Create a color replacement / palette swap material.
    ///
    /// Replaces pixels matching a target color (within tolerance) with a replacement color.
    /// Useful for team colors, palette swaps on retro sprites, or recoloring effects.
    ///
    /// - Parameters:
    ///   - target: The color to replace.
    ///   - replacement: The new color.
    ///   - tolerance: How close a pixel must be to the target to be replaced (default: 0.1).
    /// - Returns: A configured `Material2D` with the color replace shader.
    public func colorReplace(
        target: Color,
        replacement: Color,
        tolerance: Float = 0.1
    ) -> Material2D {
        let shader = getOrLoadShader(name: "colorReplace", source: MaterialShaders.colorReplaceFragment)
        return Material2D(shader: shader, uniforms: [
            "targetColor": .vec3(
                x: Float(target.r) / 255.0,
                y: Float(target.g) / 255.0,
                z: Float(target.b) / 255.0
            ),
            "replacementColor": .vec3(
                x: Float(replacement.r) / 255.0,
                y: Float(replacement.g) / 255.0,
                z: Float(replacement.b) / 255.0
            ),
            "tolerance": .float(tolerance),
        ])
    }

    /// Create a wave / distortion material.
    ///
    /// Applies sine wave displacement to UV coordinates for an underwater or heat shimmer effect.
    /// Pass the current elapsed time to animate the effect.
    ///
    /// - Parameters:
    ///   - time: Elapsed time in seconds (animate this value).
    ///   - amplitude: Wave height in UV space (default: 0.01). Higher = more distortion.
    ///   - frequency: Number of wave cycles across the sprite (default: 10.0).
    ///   - speed: Wave scroll speed (default: 3.0).
    /// - Returns: A configured `Material2D` with the wave shader.
    public func wave(
        time: Float,
        amplitude: Float = 0.01,
        frequency: Float = 10.0,
        speed: Float = 3.0
    ) -> Material2D {
        let shader = getOrLoadShader(name: "wave", source: MaterialShaders.waveFragment)
        return Material2D(shader: shader, uniforms: [
            "time": .float(time),
            "amplitude": .float(amplitude),
            "frequency": .float(frequency),
            "speed": .float(speed),
        ])
    }

    // MARK: - Templates

    /// Standard built-in effects available as templates.
    public enum BuiltinEffect: String, CaseIterable, Sendable {
        case flash, grayscale, dissolve, outline, colorReplace, wave
    }

    /// Get a reusable template for a built-in effect.
    ///
    /// Templates share the cached shader handle and define default uniform values.
    /// Create material instances via `template.instance()` or `template.instance(overrides:)`.
    ///
    /// ```swift
    /// let dissolveTemplate = materials.template(for: .dissolve)
    /// sprite.material = dissolveTemplate.instance(overrides: [
    ///     "threshold": .float(0.5)
    /// ])
    /// ```
    public func template(for effect: BuiltinEffect) -> MaterialTemplate {
        switch effect {
        case .flash:
            let shader = getOrLoadShader(name: "flash", source: MaterialShaders.flashFragment)
            return MaterialTemplate(name: "flash", shader: shader, defaults: [
                "flashColor": .color(.white),
                "flashAmount": .float(1.0),
            ])
        case .grayscale:
            let shader = getOrLoadShader(name: "grayscale", source: MaterialShaders.grayscaleFragment)
            return MaterialTemplate(name: "grayscale", shader: shader, defaults: [
                "amount": .float(1.0),
            ])
        case .dissolve:
            let shader = getOrLoadShader(name: "dissolve", source: MaterialShaders.dissolveFragment)
            return MaterialTemplate(name: "dissolve", shader: shader, defaults: [
                "threshold": .float(0.0),
                "edgeWidth": .float(0.05),
                "edgeColor": .color(.white),
            ])
        case .outline:
            let shader = getOrLoadShader(name: "outline", source: MaterialShaders.outlineFragment)
            return MaterialTemplate(name: "outline", shader: shader, defaults: [
                "outlineColor": .color(.white),
                "outlineWidth": .float(1.0),
                "textureSize": .vec2(Vector2(x: 64, y: 64)),
            ])
        case .colorReplace:
            let shader = getOrLoadShader(name: "colorReplace", source: MaterialShaders.colorReplaceFragment)
            return MaterialTemplate(name: "colorReplace", shader: shader, defaults: [
                "targetColor": .vec3(x: 1, y: 0, z: 0),
                "replacementColor": .vec3(x: 0, y: 0, z: 1),
                "tolerance": .float(0.1),
            ])
        case .wave:
            let shader = getOrLoadShader(name: "wave", source: MaterialShaders.waveFragment)
            return MaterialTemplate(name: "wave", shader: shader, defaults: [
                "time": .float(0),
                "amplitude": .float(0.01),
                "frequency": .float(10.0),
                "speed": .float(3.0),
            ])
        }
    }

    /// Material context for auto-injecting standard uniforms.
    ///
    /// Update this each frame to provide `_time`, `_resolution`, `_deltaTime`
    /// to shaders that declare those uniforms.
    public var context: MaterialContext = MaterialContext()

    // MARK: - Private

    private func getOrLoadShader(name: String, source: String) -> ShaderHandle {
        if let handle = shaderCache[name] {
            return handle
        }
        return loadShader(name: name, source: source)
    }

    @discardableResult
    private func loadShader(name: String, source: String) -> ShaderHandle {
        guard let renderer = renderer else { return .invalid }
        let handle = renderer.loadShader(vertexSource: nil, fragmentSource: source)
        shaderCache[name] = handle
        return handle
    }
}
