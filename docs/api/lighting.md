# Lighting

## LightingSystem

`Sources/Agilis/Lighting/LightingSystem.swift`

The main lighting system. Conforms to `System` (priority 300) and manages the full 2D lighting pipeline: light map creation, shadow computation, and compositing.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `priority` | `Int` | Execution priority (default: 300) |
| `options` | `LightingOptions` | Lighting configuration (mutable) |
| `isInitialized` | `Bool` | Whether GPU resources have been loaded |
| `isNormalMappingInitialized` | `Bool` | Whether normal mapping GPU resources have been loaded |
| `isSoftShadowsInitialized` | `Bool` | Whether soft shadow GPU resources have been loaded |

### Setup

```swift
let lighting = LightingSystem(
    options: LightingOptions(ambientColor: Color(r: 20, g: 20, b: 30)),
    priority: 300
)
lighting.initialize(renderer: app.renderer)  // Load shaders, create light map RT
world.addSystem(lighting)
```

### Lifecycle

| Method | When to Call | Purpose |
|--------|-------------|---------|
| `initialize(renderer:)` | `Scene.didEnter` | Loads GLSL shaders, creates light map render target (+ normal/specular buffers if enabled, + soft shadow buffers if enabled) |
| `shutdown(renderer:)` | `Scene.willExit` | Frees all GPU resources (shaders, render targets) |
| `update(context:)` | Automatic (ECS) | Snapshots light, shadow caster, and normal map entity state |
| `renderNormalBuffer(renderer:camera:)` | `Scene.render()` | Renders normal/specular maps to auxiliary buffers (only when normal mapping enabled) |
| `renderLightMap(renderer:camera:)` | `Scene.render()` | Renders all lights and shadows to the light map (uses normal-lit shaders if enabled) |
| `compositeLightMap(renderer:)` | `Scene.render()` | Draws the light map over the scene |

### Render Pipeline

`renderNormalBuffer` (when normal mapping is enabled) performs:

1. Clears the normal buffer with flat normal color `(128, 128, 255)` — pointing straight up
2. For each entity with `NormalMapData`, draws the normal map texture at the sprite's screen position
3. If specular is enabled, clears the specular buffer and renders specular maps (or uniform intensity for entities without a specular map)

`renderLightMap` performs the following for each enabled light:

1. Clears the light map with `options.ambientColor`
2. Converts light world position to screen position using the camera
3. Culls lights outside the viewport
4. Computes shadow volumes from nearby occluders (if `castsShadows` is true)
5. **Soft shadow path** (when `softShadows` is enabled): renders shadow volumes to a dedicated shadow buffer (white = lit, black = shadow), applies multi-pass Gaussian blur (1-3 passes based on `softShadowQuality`), then binds the blurred buffer as a `shadowBuffer` uniform so the light shader samples it for smooth shadow edges
6. **Hard shadow path** (default): draws shadow volumes as black triangles directly on the light map to subtract light
7. Draws the light using a GLSL shader (additive blend) for per-pixel falloff — uses normal-lit shaders when normal mapping is enabled, sampling the normal buffer for per-pixel diffuse
8. If specular is enabled, runs a second additive pass per light for Blinn-Phong specular highlights (also masked by the shadow buffer when soft shadows are active)

`compositeLightMap` draws the light map RT to the screen using `BlendMode.multiplied`, which darkens unlit areas and preserves lit areas.

### Usage

```swift
// In Scene.render()
app.renderer.beginCamera(camera)
// ... draw scene sprites, tilemaps, etc ...
app.renderer.endCamera()

// Normal mapping pass (only needed when normalMappingEnabled is true)
lighting.renderNormalBuffer(renderer: app.renderer, camera: camera)

lighting.renderLightMap(renderer: app.renderer, camera: camera)
lighting.compositeLightMap(renderer: app.renderer)
```

---

## Components

### Light2D

`Sources/Agilis/Lighting/Light2D.swift`

ECS component for 2D lights. Requires `Transform2D` on the same entity for position.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `lightType` | `LightType` | `.point` | Light shape (point or spot) |
| `color` | `Color` | `.white` | Light color (RGB) |
| `intensity` | `Float` | `1.0` | Brightness multiplier (>1 = overbright) |
| `radius` | `Float` | `200` | Maximum reach in pixels |
| `castsShadows` | `Bool` | `true` | Whether this light casts shadows |
| `falloff` | `Float` | `1.0` | Falloff curve (1.0 = linear, 2.0 = quadratic) |
| `isEnabled` | `Bool` | `true` | Toggle light on/off |
| `shadowLayerMask` | `UInt32` | `0xFFFFFFFF` | Bitmask filter for shadow casters |
| `specularEnabled` | `Bool` | `false` | Whether this light produces specular highlights |
| `specularStrength` | `Float` | `1.0` | Per-light specular strength multiplier |
| `zHeight` | `Float` | `100.0` | Virtual Z height for 3D-like lighting angle on 2D normal maps |
| `softShadowRadius` | `Float` | `0.0` | Per-light blur radius override for soft shadows (0 = use global) |

### LightType

```swift
public enum LightType: Sendable, Codable, Equatable {
    case point
    case spot(direction: Float, coneAngle: Float)
}
```

- **`.point`** — Emits light in all directions with radial falloff
- **`.spot(direction:coneAngle:)`** — Emits light in a cone. `direction` is the angle in radians, `coneAngle` is the half-angle of the cone

### ShadowCaster2D

`Sources/Agilis/Lighting/ShadowCaster2D.swift`

Opt-in marker component for shadow casting. Requires `Transform2D` and `Collider2D` on the same entity. The collider's shape (AABB, circle, polygon) defines the shadow geometry.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `layer` | `UInt32` | `1` | Bitmask matched against `Light2D.shadowLayerMask` |
| `isEnabled` | `Bool` | `true` | Toggle shadow casting on/off |

Not all colliders should cast shadows (triggers, sensors, etc.), so this is opt-in.

### NormalMapData

`Sources/Agilis/Lighting/NormalMapData.swift`

ECS component for per-entity normal and specular map data. Requires `Transform2D` and `Sprite` on the same entity (the normal map aligns with the sprite's texture).

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `normalMap` | `TextureHandle` | (required) | Normal map texture (RGB = tangent-space normals, 128,128,255 = flat) |
| `specularMap` | `TextureHandle` | `.invalid` | Optional specular map (R channel = intensity). `.invalid` uses uniform value |
| `specularIntensity` | `Float` | `0.5` | Specular intensity when no specular map is provided (0-1) |
| `shininess` | `Float` | `32.0` | Blinn-Phong shininess exponent (higher = tighter highlight) |

Conforms to `SerializableComponent` (registered in `WorldSerializer.registerDefaults()`).

### Entity Setup Examples

```swift
// Point light
let torch = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: torch)
world.addComponent(Light2D(
    color: Color(r: 255, g: 200, b: 100),
    intensity: 1.5,
    radius: 250,
    castsShadows: true,
    falloff: 1.5
), to: torch)

// Spotlight
let flashlight = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 200, y: 200)), to: flashlight)
world.addComponent(Light2D(
    lightType: .spot(direction: 0, coneAngle: Float.pi / 6),
    color: .white,
    radius: 300
), to: flashlight)

// Shadow-casting wall
let wall = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 300, y: 200)), to: wall)
world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 10))), to: wall)
world.addComponent(ShadowCaster2D(), to: wall)

// Shadow-casting pillar (circle)
let pillar = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 500, y: 300)), to: pillar)
world.addComponent(Collider2D(shape: .circle(radius: 15)), to: pillar)
world.addComponent(ShadowCaster2D(), to: pillar)

// Normal-mapped sprite (requires normalMappingEnabled in LightingOptions)
let brick = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 300, y: 300)), to: brick)
world.addComponent(Sprite(texture: brickDiffuseTex), to: brick)
world.addComponent(NormalMapData(
    normalMap: brickNormalTex,
    specularMap: brickSpecularTex,
    shininess: 64.0
), to: brick)

// Normal-mapped sprite without specular map (uses uniform intensity)
let stone = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 500, y: 300)), to: stone)
world.addComponent(Sprite(texture: stoneDiffuseTex), to: stone)
world.addComponent(NormalMapData(
    normalMap: stoneNormalTex,
    specularIntensity: 0.3,
    shininess: 16.0
), to: stone)
```

---

## LightingOptions

`Sources/Agilis/Lighting/LightingOptions.swift`

Configuration for the lighting system. Can be modified at runtime via `lightingSystem.options`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ambientColor` | `Color` | `(30, 30, 40)` | Light map clear color (darker = darker unlit areas) |
| `lightMapScale` | `Float` | `1.0` | Resolution scale (0.5 = half res, softer look, better perf) |
| `shadowExtent` | `Float` | `0` | Max shadow reach in pixels (0 = auto from screen diagonal) |
| `debugDraw` | `Bool` | `false` | Show debug overlays |
| `debugLightColor` | `Color` | `.yellow` | Color for debug light radius circles |
| `debugShadowColor` | `Color` | `(128, 0, 128)` | Color for debug shadow caster outlines |
| `normalMappingEnabled` | `Bool` | `false` | Master toggle for normal-mapped lighting |
| `specularEnabled` | `Bool` | `false` | Master toggle for specular highlights |
| `flipNormalY` | `Bool` | `false` | Flip normal map Y axis (OpenGL vs DirectX convention) |
| `debugNormalBuffer` | `Bool` | `false` | Draw normal buffer overlay on screen |
| `debugSpecularBuffer` | `Bool` | `false` | Draw specular buffer overlay on screen |
| `softShadows` | `Bool` | `false` | Master toggle for soft (blurred) shadows |
| `softShadowRadius` | `Float` | `4.0` | Global Gaussian blur radius in pixels |
| `softShadowQuality` | `SoftShadowQuality` | `.medium` | Blur passes: `.low` (1), `.medium` (2), `.high` (3) |
| `debugShadowBuffer` | `Bool` | `false` | Draw shadow buffer overlay on screen |

```swift
// Pitch-dark ambient (only lights illuminate)
let options = LightingOptions(ambientColor: .black)

// Half-resolution light map for better performance
let options = LightingOptions(lightMapScale: 0.5)

// Bright ambient with debugging enabled
var options = LightingOptions(ambientColor: Color(r: 80, g: 80, b: 100))
options.debugDraw = true

// Normal mapping with specular highlights
let options = LightingOptions(
    ambientColor: Color(r: 20, g: 20, b: 30),
    normalMappingEnabled: true,
    specularEnabled: true
)

// Debug normal/specular buffers (draws 25% scale overlays in top-left)
var options = LightingOptions(normalMappingEnabled: true, specularEnabled: true)
options.debugNormalBuffer = true
options.debugSpecularBuffer = true

// Soft shadows with high quality blur
let options = LightingOptions(
    ambientColor: Color(r: 15, g: 15, b: 25),
    softShadows: true,
    softShadowRadius: 8.0,
    softShadowQuality: .high
)

// Debug shadow buffer overlay
var options = LightingOptions(softShadows: true)
options.debugShadowBuffer = true
```

---

## ShadowGeometry

`Sources/Agilis/Lighting/ShadowGeometry.swift`

Pure geometry module for CPU-side shadow volume computation. Namespace: `enum ShadowGeometry` (no instances).

### Types

```swift
public struct ShadowVolume: Sendable {
    public let vertices: [Vector2]   // World-space polygon (triangle-fan)
}

public struct ShadowOccluder: Sendable {
    public let shape: CollisionShape
    public let position: Vector2
    public let rotation: Float
    public let offset: Vector2
}
```

### Batch Computation

```swift
static func computeShadows(
    lightPosition: Vector2,
    lightRadius: Float,
    occluders: [ShadowOccluder],
    shadowExtent: Float = 1000
) -> [ShadowVolume]
```

Computes shadow volumes for all occluders within range of the light. Handles AABB, circle, and convex polygon shapes. Applies early-out optimizations:

- **Distance culling** — skips occluders beyond `lightRadius + occluderRadius`
- **Inside detection** — returns `nil` for occluders the light is inside of

### Individual Shape Shadows

```swift
// Polygon/AABB shadow (silhouette edge detection + projection)
static func shadowForPolygon(
    lightPos: Vector2,
    vertices: [Vector2],     // World-space convex polygon
    shadowExtent: Float
) -> ShadowVolume?

// Circle shadow (tangent points + arc approximation)
static func shadowForCircle(
    lightPos: Vector2,
    center: Vector2,
    radius: Float,
    shadowExtent: Float,
    arcSegments: Int = 8
) -> ShadowVolume?
```

### Helper Functions

```swift
// Generate AABB vertices in CCW order (bottom-left, bottom-right, top-right, top-left)
static func aabbVertices(halfExtents: Vector2) -> [Vector2]

// Transform local-space vertices to world space
static func transformVertices(_ vertices: [Vector2], position: Vector2, rotation: Float) -> [Vector2]
```

---

## Shader Infrastructure

`Sources/Agilis/Graphics/ShaderHandle.swift`, `Sources/Agilis/Graphics/RenderBackend.swift`

Minimal shader API on the `RenderBackend` protocol. Used internally by `LightingSystem`, `MaterialLibrary`, and `PostProcessPipeline`. For the full material and shader system, see [Materials](materials.md). For post-processing, see [Post-Processing](post-processing.md).

### ShaderHandle

Opaque GPU shader handle, same pattern as `TextureHandle`:

```swift
public struct ShaderHandle: Sendable, Hashable {
    public let id: UInt32
    public static let invalid = ShaderHandle(id: 0)
}
```

### RenderBackend Shader Methods

```swift
func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle
func beginShader(_ handle: ShaderHandle)
func endShader()
func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float)
func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2)
func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float)
func setShaderVec4(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float, w: Float)
func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle)
func destroyShader(_ handle: ShaderHandle)
```

All methods have default no-op implementations (backward compatible). Pass `nil` for `vertexSource` to use the default vertex shader.

### Triangle Drawing

```swift
func drawTriangle(_ v1: Vector2, _ v2: Vector2, _ v3: Vector2, color: Color)
```

Draws a filled triangle. Used internally by `LightingSystem` for shadow volume rendering (triangle-fan decomposition). Default implementation is a no-op.

---

## GLSL Shaders

`Sources/Agilis/Lighting/LightingShaders.swift`

Embedded GLSL 330 (OpenGL 3.3) shaders as Swift string constants. Used internally by `LightingSystem`.

### Point Light Fragment Shader

Uniforms:

| Uniform | Type | Description |
|---------|------|-------------|
| `lightPos` | `vec2` | Light position in screen space |
| `lightColor` | `vec3` | RGB color (0-1 range) |
| `lightRadius` | `float` | Max reach in pixels |
| `lightIntensity` | `float` | Brightness multiplier |
| `lightFalloff` | `float` | Falloff exponent (1.0 = linear) |
| `resolution` | `vec2` | Light map dimensions |

Attenuation formula: `(1 - pow(clamp(dist/radius, 0, 1), falloff)) * intensity` with `smoothstep` edge softening.

### Spot Light Fragment Shader

Same uniforms as point light, plus:

| Uniform | Type | Description |
|---------|------|-------------|
| `lightDirection` | `vec2` | Normalized cone direction |
| `lightConeAngle` | `float` | Half-angle of the cone |

Adds cone factor: `smoothstep(coneAngle, coneAngle * 0.8, angle)` for soft cone edges.

### Normal-Lit Fragment Shaders

When `normalMappingEnabled` is true, `renderLightMap` uses normal-aware variants of the point and spot light shaders (`normalLitPointFragment`, `normalLitSpotFragment`). These have all the same uniforms as the base shaders, plus:

| Uniform | Type | Description |
|---------|------|-------------|
| `normalBuffer` | `sampler2D` | Normal buffer render target |
| `lightZ` | `float` | Virtual Z height for 3D light direction |
| `flipNormalY` | `int` | Whether to flip normal map Y axis (0 or 1) |

Diffuse calculation: `attenuation * lambertDiffuse(normal, lightDir3D)`. Where the normal buffer reads `(128, 128, 255)` (flat normal), the result equals the original flat attenuation for backward compatibility.

### Specular Fragment Shaders

When `specularEnabled` is true, a second additive pass runs per light using specular shaders (`specularPointFragment`, `specularSpotFragment`). These add:

| Uniform | Type | Description |
|---------|------|-------------|
| `normalBuffer` | `sampler2D` | Normal buffer render target |
| `specularBuffer` | `sampler2D` | Specular intensity buffer (R channel) |
| `lightZ` | `float` | Virtual Z height |
| `flipNormalY` | `int` | Y-flip toggle |
| `specularStrength` | `float` | Per-light specular multiplier |
| `shininess` | `float` | Blinn-Phong exponent |

Uses Blinn-Phong with a fixed view direction of `(0, 0, 1)` (top-down 2D).

### Shadow Buffer Uniforms

When `softShadows` is enabled, all 6 light shaders (point, spot, normal-lit point, normal-lit spot, specular point, specular spot) include two additional uniforms:

| Uniform | Type | Description |
|---------|------|-------------|
| `shadowBuffer` | `sampler2D` | Blurred shadow buffer (white = lit, black = shadow) |
| `useShadowBuffer` | `int` | 0 = ignore shadow buffer, 1 = sample it. Coherent branch for zero-cost when disabled. |

When `useShadowBuffer` is 1, the light shader multiplies its attenuation by the shadow buffer sample at the fragment's screen position, producing smooth shadow edges.

### Shadow Blur Shaders

Two separable Gaussian blur shaders (`shadowBlurHorizontalFragment`, `shadowBlurVerticalFragment`) blur the per-light shadow buffer. Each uses a 9-tap kernel with hardcoded weights.

| Uniform | Type | Description |
|---------|------|-------------|
| `resolution` | `vec2` | Shadow buffer dimensions (for texel size calculation) |
| `blurRadius` | `float` | Blur spread in pixels (effective radius = per-light override or global `softShadowRadius`) |

The horizontal pass offsets samples along `vec2(offset, 0.0)`, the vertical pass along `vec2(0.0, offset)`. Quality setting controls how many blur passes run: low = 1, medium = 2, high = 3.

### Normal Pass Fragment Shader

`normalPassFragment` renders a sprite's normal map texture to the normal buffer. Simply samples the texture and outputs the RGB values. Used internally by `renderNormalBuffer()`.

---

## Debug Rendering

`Sources/Agilis/Lighting/LightingDebugRenderer.swift`

Visualize lights and shadow casters for debugging. Extension on `RenderBackend`.

```swift
func drawLightingDebug(world: World, options: LightingOptions = LightingOptions())
func drawNormalBufferDebug(lighting: LightingSystem, options: LightingOptions = LightingOptions())
```

`drawLightingDebug` draws:

- Light radius circles (wireframe, `options.debugLightColor`)
- Light center dots
- Spotlight direction arrows and cone edge lines
- Shadow caster outlines (handles AABB, rotated AABB, circle, polygon)

`drawNormalBufferDebug` draws (when enabled via debug flags):

- Normal buffer at 25% scale in the top-left corner (green outline) — when `debugNormalBuffer` is true
- Specular buffer next to it (cyan outline) — when `debugSpecularBuffer` is true
- Shadow buffer next to it (magenta outline) — when `debugShadowBuffer` is true

### Usage

```swift
// Basic debug draw
app.renderer.drawLightingDebug(world: app.world)

// Normal/specular buffer debug overlays
app.renderer.drawNormalBufferDebug(lighting: lighting, options: lighting.options)

// With custom options
var options = LightingOptions()
options.debugLightColor = .green
options.debugShadowColor = .red
app.renderer.drawLightingDebug(world: app.world, options: options)
```

---

## Full Example

### Basic Lighting

```swift
final class LitScene: Scene {
    private var lighting: LightingSystem!

    func didEnter(app: Application) {
        let world = app.world

        // Setup lighting
        lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 15, g: 15, b: 25)
        ))
        lighting.initialize(renderer: app.renderer)
        world.addSystem(lighting)

        // Create a warm torch light
        let torch = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: torch)
        world.addComponent(Light2D(
            color: Color(r: 255, g: 180, b: 80),
            intensity: 1.5,
            radius: 300,
            castsShadows: true,
            falloff: 1.5
        ), to: torch)

        // Create shadow-casting walls
        for i in 0..<3 {
            let wall = world.createEntity()
            world.addComponent(Transform2D(
                position: Vector2(x: 250 + Float(i) * 150, y: 250)
            ), to: wall)
            world.addComponent(Collider2D(
                shape: .aabb(halfExtents: Vector2(x: 30, y: 8))
            ), to: wall)
            world.addComponent(ShadowCaster2D(), to: wall)
        }
    }

    func render(app: Application, interpolation: Double) {
        let camera = Camera2D(
            target: Vector2(x: 400, y: 300),
            offset: Vector2(x: 400, y: 300)
        )

        app.renderer.beginCamera(camera)
        // Draw your scene here (sprites, tilemaps, etc.)
        app.renderer.endCamera()

        lighting.renderLightMap(renderer: app.renderer, camera: camera)
        lighting.compositeLightMap(renderer: app.renderer)
    }

    func willExit(app: Application) {
        lighting.shutdown(renderer: app.renderer)
    }
}
```

### Normal Mapping with Specular

```swift
final class NormalMappedScene: Scene {
    private var lighting: LightingSystem!

    func didEnter(app: Application) {
        let world = app.world

        // Enable normal mapping and specular highlights
        lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 15, g: 15, b: 25),
            normalMappingEnabled: true,
            specularEnabled: true
        ))
        lighting.initialize(renderer: app.renderer)
        world.addSystem(lighting)

        // Light with specular enabled and virtual Z height
        let torch = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: torch)
        world.addComponent(Light2D(
            color: Color(r: 255, g: 200, b: 100),
            intensity: 1.5,
            radius: 300,
            castsShadows: true,
            specularEnabled: true,
            specularStrength: 2.0,
            zHeight: 150.0
        ), to: torch)

        // Normal-mapped sprite
        let brick = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: brick)
        world.addComponent(Sprite(texture: brickDiffuseTex), to: brick)
        world.addComponent(NormalMapData(
            normalMap: brickNormalTex,
            specularMap: brickSpecularTex,
            shininess: 64.0
        ), to: brick)
    }

    func render(app: Application, interpolation: Double) {
        let camera = Camera2D(
            target: Vector2(x: 400, y: 300),
            offset: Vector2(x: 400, y: 300)
        )

        app.renderer.beginCamera(camera)
        // Draw scene sprites
        app.renderer.endCamera()

        // Normal buffer pass (populates the G-buffer)
        lighting.renderNormalBuffer(renderer: app.renderer, camera: camera)
        // Light map pass (uses normal-lit shaders + specular pass)
        lighting.renderLightMap(renderer: app.renderer, camera: camera)
        lighting.compositeLightMap(renderer: app.renderer)

        // Optional: debug buffer overlays
        // app.renderer.drawNormalBufferDebug(lighting: lighting, options: lighting.options)
    }

    func willExit(app: Application) {
        lighting.shutdown(renderer: app.renderer)
    }
}
```

### Soft Shadows

```swift
final class SoftShadowScene: Scene {
    private var lighting: LightingSystem!

    func didEnter(app: Application) {
        let world = app.world

        // Enable soft shadows with high quality blur
        lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 10, g: 10, b: 20),
            softShadows: true,
            softShadowRadius: 6.0,
            softShadowQuality: .high
        ))
        lighting.initialize(renderer: app.renderer)
        world.addSystem(lighting)

        // Point light with per-light blur radius override
        let lamp = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: lamp)
        world.addComponent(Light2D(
            color: Color(r: 255, g: 220, b: 150),
            intensity: 1.5,
            radius: 350,
            castsShadows: true,
            softShadowRadius: 10.0  // Override global 6.0 for this light
        ), to: lamp)

        // Shadow casters
        let pillar = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 300, y: 250)), to: pillar)
        world.addComponent(Collider2D(shape: .circle(radius: 20)), to: pillar)
        world.addComponent(ShadowCaster2D(), to: pillar)

        let wall = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 500, y: 200)), to: wall)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: 60, y: 8))
        ), to: wall)
        world.addComponent(ShadowCaster2D(), to: wall)
    }

    func render(app: Application, interpolation: Double) {
        let camera = Camera2D(
            target: Vector2(x: 400, y: 300),
            offset: Vector2(x: 400, y: 300)
        )

        app.renderer.beginCamera(camera)
        // Draw scene sprites
        app.renderer.endCamera()

        lighting.renderLightMap(renderer: app.renderer, camera: camera)
        lighting.compositeLightMap(renderer: app.renderer)

        // Optional: debug shadow buffer overlay
        // app.renderer.drawNormalBufferDebug(lighting: lighting, options: lighting.options)
    }

    func willExit(app: Application) {
        lighting.shutdown(renderer: app.renderer)
    }
}
```
