# Post-Processing

## PostProcessEffect Protocol

`Sources/Agilis/Graphics/PostProcessEffect.swift`

The protocol for screen-space post-processing effects. Each effect processes a fullscreen render target with a fragment shader. Effects are managed by `PostProcessPipeline`.

```swift
public protocol PostProcessEffect: AnyObject, Sendable {
    var name: String { get }
    var isEnabled: Bool { get set }
    var order: Int { get }
    func initialize(renderer: any RenderBackend)
    func shutdown(renderer: any RenderBackend)
    func resize(width: Int, height: Int, renderer: any RenderBackend)
    func apply(input: RenderTargetHandle, output: RenderTargetHandle,
               renderer: any RenderBackend, deltaTime: Float)
}
```

Default no-op implementations are provided for `shutdown` and `resize`.

### Standard Effect Orders

| Order | Effect |
|-------|--------|
| 100 | Bloom |
| 200 | Chromatic Aberration |
| 300 | Color Grading |
| 400 | Vignette |
| 500 | Scanlines |
| 600 | Pixelate |

Leave gaps between your custom effect orders so built-in effects can be inserted.

---

## PostProcessPipeline

`Sources/Agilis/PostProcess/PostProcessPipeline.swift`

Manages a chain of post-processing effects with automatic render target ping-pong buffering.

### Setup

```swift
let postProcess = PostProcessPipeline()
postProcess.add(BloomEffect(intensity: 1.2))
postProcess.add(VignetteEffect())
postProcess.initialize(renderer: app.renderer)
```

### Render Integration

Wrap your scene rendering between `beginCapture` and `endCaptureAndApply`:

```swift
func render(app: Application, interpolation: Double) {
    let dt = Float(1.0 / 60.0)

    postProcess.beginCapture(renderer: app.renderer)

    app.renderer.beginCamera(camera)
    // Draw entire scene: sprites, tilemaps, particles...
    app.renderer.endCamera()

    // Lighting composites onto the captured scene
    lighting.renderLightMap(renderer: app.renderer, camera: camera)
    lighting.compositeLightMap(renderer: app.renderer)

    postProcess.endCaptureAndApply(renderer: app.renderer, deltaTime: dt)

    // Draw HUD/UI after post-processing (not affected)
    ui.render(renderer: app.renderer)
}
```

### Effect Management

```swift
postProcess.add(_ effect: any PostProcessEffect)
postProcess.remove(named: String) -> Bool
postProcess.effect(ofType: T.Type) -> T?
postProcess.effect(named: String) -> (any PostProcessEffect)?
postProcess.allEffects: [any PostProcessEffect]
postProcess.effectCount: Int
```

Effects added after `initialize` are auto-initialized. Removed effects are auto-shut-down.

### Runtime Parameter Tweaking

```swift
if let vignette = postProcess.effect(ofType: VignetteEffect.self) {
    vignette.intensity = 0.8
}

if let bloom = postProcess.effect(ofType: BloomEffect.self) {
    bloom.threshold = 0.6
}
```

### Lifecycle

| Method | When | Purpose |
|--------|------|---------|
| `initialize(renderer:)` | `Scene.didEnter` | Creates render targets, initializes all effects |
| `shutdown(renderer:)` | `Scene.willExit` | Frees render targets, shuts down all effects |

Screen resize is detected automatically in `beginCapture` and triggers render target recreation plus `resize` calls on all effects.

### Disabling Effects

```swift
// Disable at zero cost (no render target ping-pong for disabled effects)
postProcess.effect(ofType: BloomEffect.self)?.isEnabled = false
```

When all effects are disabled, the pipeline passes the scene through to the screen with no overhead beyond the initial render target capture.

---

## Built-in Effects

All effects are in `Sources/Agilis/PostProcess/Effects/`.

### BloomEffect

Glow effect that extracts bright pixels and blurs them additively. Two-pass: horizontal Gaussian blur on bright pixels, then vertical blur composited with the original scene.

```swift
let bloom = BloomEffect(
    threshold: 0.8,   // Brightness threshold for extraction (0-1)
    intensity: 1.0    // Bloom strength multiplier
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `threshold` | `Float` | `0.8` | Minimum brightness for extraction |
| `intensity` | `Float` | `1.0` | Bloom strength multiplier |

### ChromaticAberrationEffect

Radial RGB channel offset for a lens distortion look.

```swift
let chromatic = ChromaticAberrationEffect(amount: 0.003)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `amount` | `Float` | `0.003` | UV offset for RGB channel separation |

### ColorGradingEffect

Color adjustment: brightness, contrast, saturation, gamma, and tint.

```swift
let grading = ColorGradingEffect(
    brightness: 0.0,
    contrast: 1.0,
    saturation: 1.2,
    gamma: 1.0,
    tint: .white
)
```

| Property | Type | Default | Range | Description |
|----------|------|---------|-------|-------------|
| `brightness` | `Float` | `0.0` | -1 to 1 | Additive brightness |
| `contrast` | `Float` | `1.0` | 0 to 2 | Contrast multiplier |
| `saturation` | `Float` | `1.0` | 0 to 2 | Saturation multiplier |
| `gamma` | `Float` | `1.0` | 0.1 to 3 | Gamma correction |
| `tint` | `Color` | `.white` | — | Multiplicative color tint |

### VignetteEffect

Darkens the edges of the screen for a cinematic look.

```swift
let vignette = VignetteEffect(
    intensity: 0.5,
    radius: 0.75,
    softness: 0.45
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `intensity` | `Float` | `0.5` | How dark edges get (0 = none, 1 = black) |
| `radius` | `Float` | `0.75` | Where vignette starts (0 = center, 1 = edges) |
| `softness` | `Float` | `0.45` | Falloff transition width |

### ScanlinesEffect

CRT scanline simulation with optional barrel distortion.

```swift
let scanlines = ScanlinesEffect(
    lineSpacing: 2.0,
    lineIntensity: 0.15,
    curvature: 0.0
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `lineSpacing` | `Float` | `2.0` | Pixels between scanlines |
| `lineIntensity` | `Float` | `0.15` | Darkness of scanlines (0-1) |
| `curvature` | `Float` | `0.0` | Barrel distortion amount (0-1) |

### PixelateEffect

Reduces effective resolution for a retro pixelation look.

```swift
let pixelate = PixelateEffect(pixelSize: 4.0)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `pixelSize` | `Float` | `4.0` | Virtual pixel size in screen pixels |

---

## Custom Effects

Implement `PostProcessEffect` to create your own:

```swift
final class InvertEffect: PostProcessEffect, @unchecked Sendable {
    let name = "invert"
    var isEnabled = true
    var order: Int { 350 }

    private var shader: ShaderHandle = .invalid

    private static let glsl = """
    #version 330
    in vec2 fragTexCoord;
    in vec4 fragColor;
    uniform sampler2D texture0;
    out vec4 finalColor;
    void main() {
        vec4 color = texture(texture0, fragTexCoord);
        finalColor = vec4(1.0 - color.rgb, color.a);
    }
    """

    func initialize(renderer: any RenderBackend) {
        shader = renderer.loadShader(vertexSource: nil, fragmentSource: Self.glsl)
    }

    func shutdown(renderer: any RenderBackend) {
        if shader != .invalid { renderer.destroyShader(shader) }
        shader = .invalid
    }

    func apply(input: RenderTargetHandle, output: RenderTargetHandle,
               renderer: any RenderBackend, deltaTime: Float) {
        guard shader != .invalid else { return }

        let texture = renderer.renderTargetTexture(input)
        let size = renderer.renderTargetSize(input)

        renderer.beginRenderTarget(output)
        renderer.beginShader(shader)
        renderer.drawSprite(Sprite(
            texture: texture,
            sourceRect: Rect(x: 0, y: 0, width: size.width, height: size.height),
            tint: .white,
            flipY: true
        ))
        renderer.endShader()
        renderer.endRenderTarget()
    }
}
```

You can also use `ShaderBuilder.createPostProcess` for the GLSL source:

```swift
private static let glsl = ShaderBuilder.createPostProcess(
    body: """
    vec4 color = sampleTexture(fragTexCoord);
    finalColor = vec4(1.0 - color.rgb, color.a);
    """
)
```

---

## PostProcessShaders

`Sources/Agilis/PostProcess/PostProcessShaders.swift`

Embedded GLSL 330 fragment shaders used by the built-in effects. All use the default vertex shader (pass `nil` for vertex source). Available as static string constants if you want to reference them directly:

| Constant | Effect |
|----------|--------|
| `vignetteFragment` | Edge darkening |
| `chromaticAberrationFragment` | RGB channel offset |
| `colorGradingFragment` | Color adjustment |
| `scanlinesFragment` | CRT scanlines |
| `pixelateFragment` | Pixelation |
| `bloomExtractFragment` | Bright pixel extraction + horizontal blur |
| `bloomCompositeFragment` | Vertical blur + additive composite |

---

## Full Example

```swift
final class PostProcessScene: Scene {
    private var postProcess: PostProcessPipeline!
    private var lighting: LightingSystem!

    func didEnter(app: Application) {
        // Setup post-processing
        postProcess = PostProcessPipeline()
        postProcess.add(BloomEffect(threshold: 0.7, intensity: 1.5))
        postProcess.add(ChromaticAberrationEffect(amount: 0.002))
        postProcess.add(VignetteEffect(intensity: 0.4))
        postProcess.initialize(renderer: app.renderer)

        // Setup lighting
        lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 20, g: 20, b: 30)
        ))
        lighting.initialize(renderer: app.renderer)
        app.world.addSystem(lighting)

        // Create scene entities...
    }

    func render(app: Application, interpolation: Double) {
        let camera = Camera2D(
            target: Vector2(x: 400, y: 300),
            offset: Vector2(x: 400, y: 300)
        )

        // Everything between beginCapture and endCaptureAndApply is post-processed
        postProcess.beginCapture(renderer: app.renderer)

        app.renderer.beginCamera(camera)
        // Draw scene sprites, tilemaps, particles...
        app.renderer.endCamera()

        lighting.renderLightMap(renderer: app.renderer, camera: camera)
        lighting.compositeLightMap(renderer: app.renderer)

        postProcess.endCaptureAndApply(
            renderer: app.renderer,
            deltaTime: Float(1.0 / 60.0)
        )

        // HUD/UI drawn after post-processing (unaffected)
    }

    func willExit(app: Application) {
        postProcess.shutdown(renderer: app.renderer)
        lighting.shutdown(renderer: app.renderer)
    }
}
```
