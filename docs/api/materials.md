# Materials

## Material2D

`Sources/Agilis/Graphics/Material2D.swift`

A value type that pairs a shader program with typed uniform values. Assigned to sprites via `Sprite.material` for per-sprite visual effects.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `shader` | `ShaderHandle` | GPU shader program |
| `uniforms` | `[String: UniformValue]` | Named uniform values |
| `blendMode` | `BlendMode?` | Optional blend mode override |
| `sortKey` | `UInt32` | Shader ID for SpriteBatch sorting |

### UniformValue

```swift
public enum UniformValue: Sendable, Equatable, Codable {
    case float(Float)
    case vec2(Vector2)
    case vec3(x: Float, y: Float, z: Float)
    case vec4(x: Float, y: Float, z: Float, w: Float)
    case int(Int32)
    case color(Color)
    case texture(TextureHandle)
}
```

### Usage

```swift
var sprite = Sprite(texture: playerTex)
sprite.material = Material2D(
    shader: myShader,
    uniforms: ["amount": .float(0.5), "tint": .color(.red)]
)
app.renderer.drawSprite(sprite)
```

### Applying Materials Manually

`RenderBackend` has an `applyMaterial(_:)` extension that sets the shader, uniforms, and blend mode in the correct order. This is called automatically by `drawSprite` when a material is present.

---

## MaterialLibrary

`Sources/Agilis/Materials/MaterialLibrary.swift`

Loads, caches, and provides 6 built-in material effects. Manages shader lifecycle.

### Setup

```swift
let materials = MaterialLibrary()
materials.initialize(renderer: app.renderer)  // Pre-loads all 6 shaders

// In Scene.willExit:
materials.shutdown()
```

### Built-in Effects

| Method | Effect | Key Parameters |
|--------|--------|---------------|
| `flash(color:amount:)` | Hit blink / highlight | color (Color), amount (0-1) |
| `grayscale(amount:)` | Desaturation | amount (0-1) |
| `dissolve(threshold:edgeWidth:edgeColor:)` | Noise dissolve | threshold (0-1), edgeWidth, edgeColor |
| `outline(color:width:textureSize:)` | Sprite outline | color, width (px), textureSize (Vector2) |
| `colorReplace(target:replacement:tolerance:)` | Palette swap | target/replacement (Color), tolerance |
| `wave(time:amplitude:frequency:speed:)` | UV distortion | time (animate), amplitude, frequency, speed |

### Usage

```swift
// Flash on hit
sprite.material = materials.flash(color: .white, amount: 1.0)

// Dissolve death effect (animate threshold 0 -> 1)
sprite.material = materials.dissolve(threshold: progress)
```

### BuiltinEffect Enum

```swift
public enum BuiltinEffect: String, CaseIterable, Sendable {
    case flash, grayscale, dissolve, outline, colorReplace, wave
}
```

---

## MaterialTemplate

`Sources/Agilis/Materials/MaterialTemplate.swift`

A reusable material definition. Templates share a shader handle and define default uniform values. Create `Material2D` instances with optional per-sprite overrides.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Human-readable identifier |
| `shader` | `ShaderHandle` | Shared shader program |
| `defaults` | `[String: UniformValue]` | Default uniform values |
| `blendMode` | `BlendMode?` | Optional blend mode |

### Creating Templates

```swift
// From MaterialLibrary
let dissolveTemplate = materials.template(for: .dissolve)

// Custom template
let myTemplate = MaterialTemplate(
    name: "glow",
    shader: glowShader,
    defaults: ["intensity": .float(1.0), "color": .color(.yellow)],
    blendMode: .additive
)
```

### Creating Instances

```swift
// Instance with all defaults
let mat = dissolveTemplate.instance()

// Instance with overrides (non-overridden values use defaults)
let mat = dissolveTemplate.instance(overrides: ["threshold": .float(0.5)])
```

Instances are independent value types. Modifying one does not affect others or the template.

---

## MaterialContext

`Sources/Agilis/Materials/MaterialRendering.swift`

Standard uniforms automatically injected into shaders. Uses underscore-prefixed names to avoid collisions with user uniforms.

### Standard Uniforms

| Uniform | Type | Description |
|---------|------|-------------|
| `_time` | `float` | Elapsed game time in seconds |
| `_resolution` | `vec2` | Screen resolution in pixels |
| `_deltaTime` | `float` | Frame delta time in seconds |

### Usage

```swift
// Update context each frame
materials.context.time = elapsed
materials.context.resolution = Vector2(x: Float(screenW), y: Float(screenH))
materials.context.deltaTime = Float(dt)

// Apply material with auto-injected uniforms
renderer.applyMaterial(material, context: materials.context)
```

Shaders that don't declare these uniforms are unaffected (setting a uniform with an invalid location is a no-op).

---

## ShaderBuilder

`Sources/Agilis/Materials/ShaderBuilder.swift`

Generates complete GLSL 330 fragment shaders with less boilerplate. Handles the standard preamble, include libraries, and auto-injected uniforms.

### createFragment

For sprite rendering. The `sampleTexture(uv)` helper multiplies by `fragColor` (sprite tint).

```swift
let source = ShaderBuilder.createFragment(
    uniforms: ["tintColor": "vec4", "tintAmount": "float"],
    includes: [.color],
    body: """
    vec4 color = sampleTexture(fragTexCoord);
    color.rgb = mix(color.rgb, tintColor.rgb, tintAmount);
    finalColor = color;
    """
)
let shader = renderer.loadShader(vertexSource: nil, fragmentSource: source)
```

### createPostProcess

For post-processing. The `sampleTexture(uv)` helper does NOT multiply by `fragColor` (reads from render target, not tinted sprite).

```swift
let source = ShaderBuilder.createPostProcess(
    uniforms: ["strength": "float"],
    includes: [.noise],
    body: """
    vec4 color = sampleTexture(fragTexCoord);
    color.rgb += noise2D(fragTexCoord * 50.0) * strength;
    finalColor = color;
    """
)
```

### Generated Shader Structure

Both methods produce a shader with:
1. `#version 330` header
2. Standard inputs (`fragTexCoord`, `fragColor`)
3. `texture0` sampler (the sprite texture bound by the renderer)
4. Standard uniform declarations (`_time`, `_resolution`, `_deltaTime`)
5. User uniform declarations (sorted alphabetically for deterministic output)
6. Requested include libraries (sorted alphabetically)
7. `sampleTexture(uv)` convenience function
8. `out vec4 finalColor` declaration
9. `void main()` with user body code

---

## ShaderInclude

`Sources/Agilis/Materials/ShaderIncludes.swift`

Built-in GLSL utility libraries that can be injected into custom shaders via `ShaderBuilder` or `ShaderComposer`.

| Include | Functions |
|---------|-----------|
| `.noise` | `hash21(vec2)`, `noise2D(vec2)`, `fbm(vec2, int)` |
| `.easing` | `easeQuadIn/Out`, `easeCubicIn/Out`, `easeSineIn/Out`, `easeSmoothstep` |
| `.uv` | `rotateUV(vec2, float, vec2)`, `scrollUV(vec2, vec2, float)`, `tileUV(vec2, vec2)` |
| `.color` | `rgb2hsv(vec3)`, `hsv2rgb(vec3)`, `luminance(vec3)` |
| `.math` | `remap(float, ...)`, `smootherStep(float, ...)`, `inverseLerp(float, ...)` |
| `.normalMapping` | `decodeNormal(vec4, int)`, `lightDirection3D(vec2, vec2, float)`, `lambertDiffuse(vec3, vec3)`, `blinnPhongSpecular(vec3, vec3, float)` |

### Usage

```swift
let source = ShaderBuilder.createFragment(
    uniforms: ["hueShift": "float"],
    includes: [.color, .noise],
    body: """
    vec4 color = sampleTexture(fragTexCoord);
    vec3 hsv = rgb2hsv(color.rgb);
    hsv.x = fract(hsv.x + hueShift);
    color.rgb = hsv2rgb(hsv);
    float n = noise2D(fragTexCoord * 20.0);
    color.rgb += n * 0.05;
    finalColor = color;
    """
)
```

---

## ShaderComposer

`Sources/Agilis/Materials/ShaderComposer.swift`

Chains multiple fragment effects into a single GLSL shader program. Each effect transforms a `vec4 color` variable in sequence.

### Methods

```swift
func addEffect(_ name: String, uniforms: [String: String],
               includes: Set<ShaderInclude>, body: String)
func setPostProcess(_ enabled: Bool) -> ShaderComposer  // Fluent
func build() -> String                                   // Complete GLSL source
var effectCount: Int
```

### Behavior

- Uniforms are merged across all effects (last-added type wins for duplicates)
- Includes are deduplicated
- Effects run in the order they were added
- The first effect reads from `sampleTexture(fragTexCoord)`
- Each subsequent effect operates on the previous effect's `color` output

### Usage

```swift
let composer = ShaderComposer()
composer.addEffect("grayscale",
    uniforms: ["amount": "float"],
    includes: [.color],
    body: "color.rgb = mix(color.rgb, vec3(luminance(color.rgb)), amount);")
composer.addEffect("tint",
    uniforms: ["tintColor": "vec3"],
    body: "color.rgb *= tintColor;")
let source = composer.build()
let shader = renderer.loadShader(vertexSource: nil, fragmentSource: source)
```

For post-processing shaders, call `setPostProcess()` before `build()`.

---

## ComposableEffects

`Sources/Agilis/Materials/ComposableEffects.swift`

Pre-built effect snippets for use with `ShaderComposer`. Each returns a `Snippet` tuple of `(uniforms, includes, body)`.

| Method | Uniforms | Includes |
|--------|----------|----------|
| `grayscale()` | `grayscaleAmount` (float) | `.color` |
| `flash()` | `flashColor` (vec3), `flashAmount` (float) | — |
| `hueShift()` | `hueShift` (float) | `.color` |
| `tint()` | `tintColor` (vec3) | — |
| `invertColors()` | `invertAmount` (float) | — |
| `brightnessContrast()` | `brightnessOffset` (float), `contrastScale` (float) | — |

### Usage

```swift
let composer = ShaderComposer()

let (u1, i1, b1) = ComposableEffects.grayscale()
composer.addEffect("grayscale", uniforms: u1, includes: i1, body: b1)

let (u2, i2, b2) = ComposableEffects.flash()
composer.addEffect("flash", uniforms: u2, includes: i2, body: b2)

let source = composer.build()
```

---

## Tween Integration

`Sources/Agilis/Tween/TweenMaterialExtension.swift`

Convenience methods on `TweenSystem` for animating material uniforms over time.

### tweenMaterialUniform

Animates a float uniform from its current value to a target.

```swift
// Animate dissolve threshold from current to 1.0 over 2 seconds
tweens.tweenMaterialUniform(
    entity, uniform: "threshold",
    to: 1.0, duration: 2.0, easing: .cubicIn, in: world
)
```

Returns `.invalid` if the entity has no `Sprite`, no material, or the named uniform is not a `.float`.

### tweenMaterialColor

Animates a color uniform from its current value to a target.

```swift
tweens.tweenMaterialColor(
    entity, uniform: "flashColor",
    to: .red, duration: 0.5, easing: .sineOut, in: world
)
```

Returns `.invalid` if the entity has no `Sprite`, no material, or the named uniform is not a `.color`.

---

## Full Example

```swift
final class EffectsScene: Scene {
    private var materials: MaterialLibrary!
    private var tweens: TweenSystem!
    private var elapsed: Float = 0

    func didEnter(app: Application) {
        materials = MaterialLibrary()
        materials.initialize(renderer: app.renderer)

        tweens = TweenSystem()
        app.world.addSystem(tweens)

        // Create a dissolving enemy
        let enemy = app.world.createEntity()
        app.world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: enemy)
        var sprite = Sprite(texture: enemyTex)
        sprite.material = materials.dissolve(threshold: 0)
        app.world.addComponent(sprite, to: enemy)

        // Animate the dissolve over 2 seconds
        tweens.tweenMaterialUniform(
            enemy, uniform: "threshold",
            to: 1.0, duration: 2.0, easing: .cubicIn, in: app.world
        )
    }

    func update(app: Application, deltaTime: Double) {
        elapsed += Float(deltaTime)
        materials.context.time = elapsed
        materials.context.resolution = Vector2(
            x: app.renderer.screenSize.width,
            y: app.renderer.screenSize.height
        )
        materials.context.deltaTime = Float(deltaTime)
    }

    func willExit(app: Application) {
        materials.shutdown()
    }
}
```
