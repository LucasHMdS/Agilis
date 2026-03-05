# Graphics

## RenderBackend

`Sources/AgilisCore/Graphics/RenderBackend.swift`

The abstraction over platform-specific rendering. All drawing goes through this protocol.

### Lifecycle

```swift
func initialize(config: WindowConfig) throws
func shutdown()
func shouldClose() -> Bool
func beginFrame()
func endFrame()
func setBackgroundColor(_ color: Color)
var screenSize: Size { get }
```

### Textures

```swift
func loadTexture(from path: String) -> TextureHandle
func loadTextureFromImage(_ image: ImageData) -> TextureHandle
func textureSize(_ handle: TextureHandle) -> Size
func destroyTexture(_ handle: TextureHandle)
```

`loadTextureFromImage` creates a GPU texture from raw RGBA pixel data. Useful for procedural textures, runtime-generated images, and screenshot processing.

### Drawing Primitives

```swift
func drawSprite(_ sprite: Sprite)
func drawSprites(_ sprites: [Sprite])   // Batch draw (default: calls drawSprite in a loop)
func drawRect(_ rect: Rect, color: Color)
func drawRectOutline(_ rect: Rect, color: Color, thickness: Float)
func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float)
func drawCircle(center: Vector2, radius: Float, color: Color)
func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float)
```

### Fonts and Text

```swift
func loadDefaultFont() -> FontHandle
func loadFont(from path: String, size: Int) -> FontHandle
func destroyFont(_ handle: FontHandle)
func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color)
func measureText(_ text: String, font: FontHandle, size: Float) -> Size
```

### Clipping

```swift
func beginClip(_ rect: Rect)   // Restrict drawing to rectangle
func endClip()                  // Restore full drawing area
```

### Camera

```swift
func beginCamera(_ camera: Camera2D)
func endCamera()
```

### Blend Modes

```swift
func beginBlendMode(_ mode: BlendMode)   // Set blend mode for subsequent draws
func endBlendMode()                       // Restore default alpha blending
```

Default implementations are no-ops (backward compatible).

### Render Targets

```swift
func createRenderTarget(width: Int, height: Int) -> RenderTargetHandle
func beginRenderTarget(_ handle: RenderTargetHandle)
func endRenderTarget()
func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle
func renderTargetSize(_ handle: RenderTargetHandle) -> Size
func destroyRenderTarget(_ handle: RenderTargetHandle)
```

Default implementations are no-ops (backward compatible). See [Render Targets](#render-targets-1) below.

### Shaders

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

Default implementations are no-ops (backward compatible). Pass `nil` for `vertexSource` to use the default vertex shader. GLSL 330 (OpenGL 3.3). See [Lighting](lighting.md) for lighting shaders, [Materials](materials.md) for the material system and ShaderBuilder, and [Post-Processing](post-processing.md) for the post-processing pipeline.

### Material Application (Extension)

```swift
func applyMaterial(_ material: Material2D)
func applyMaterial(_ material: Material2D, context: MaterialContext)
```

Applies a material's shader, uniforms, and blend mode. The context-aware version auto-injects `_time`, `_resolution`, `_deltaTime` uniforms before user uniforms. Called automatically by `drawSprite` when a sprite has a material. See [Materials](materials.md).

### Triangle Drawing

```swift
func drawTriangle(_ v1: Vector2, _ v2: Vector2, _ v3: Vector2, color: Color)
```

Draws a filled triangle. Default implementation is a no-op.

### Tilemap Rendering (Extension)

```swift
func drawTileMap(_ tileMap: TileMap, position: Vector2, camera: Camera2D?, tint: Color)
func drawTileLayer(_ layer: TileLayer, tilesets: [Tileset], tileWidth: Int, tileHeight: Int,
                   position: Vector2, camera: Camera2D?, tint: Color)
func batchTileMap(_ tileMap: TileMap, into batch: SpriteBatch, position: Vector2,
                  camera: Camera2D?, tint: Color, baseLayer: Int)
func batchTileLayer(_ layer: TileLayer, tilesets: [Tileset], tileWidth: Int, tileHeight: Int,
                    into batch: SpriteBatch, position: Vector2, camera: Camera2D?,
                    tint: Color, batchLayer: Int)
```

Camera-culled tilemap drawing. Only tiles overlapping the viewport are rendered.

### Particle Rendering (Extension)

```swift
func drawParticles(_ emitter: ParticleEmitter, at position: Vector2)
```

Draws all living particles with interpolated color and scale based on age.

### Physics Debug Rendering (Extension)

```swift
func drawPhysicsDebug(world: World, events: [CollisionEvent],
                      options: PhysicsDebugRendererOptions)
```

Visualizes colliders, contacts, velocities, and normals. See [Physics](physics.md).

### Lighting Debug Rendering (Extension)

```swift
func drawLightingDebug(world: World, options: LightingOptions)
```

Draws light radii, center dots, spotlight cones, and shadow caster outlines. See [Lighting](lighting.md).

### Animation Debug Rendering (Extension)

```swift
func drawAnimationDebug(world: World, font: FontHandle,
                        options: AnimationDebugRendererOptions)
```

Draws source rect outlines and animator state labels. See [Debug](debug.md).

### Tween Debug Rendering (Extension)

```swift
func drawTweenDebug(infos: [TweenDebugInfo], world: World, font: FontHandle,
                    options: TweenDebugRendererOptions)
```

Draws path lines for position tweens and progress labels. See [Debug](debug.md).

### Particle Debug Rendering (Extension)

```swift
func drawParticleDebug(world: World, font: FontHandle,
                       options: ParticleDebugRendererOptions)
```

Draws emission shape outlines and particle count labels. See [Debug](debug.md).

### TileMap Debug Rendering (Extension)

```swift
func drawTileMapDebug(tileMap: TileMap, position: Vector2, camera: Camera2D,
                      options: TileMapDebugRendererOptions)
```

Draws tile grid lines (camera-culled) and culling viewport rectangle. See [Debug](debug.md).

### UI Debug Rendering (Extension)

```swift
func drawUIDebug(context: UIContext, font: FontHandle,
                 options: UIDebugRendererOptions)
```

Draws bounding rectangles and node IDs for all UI nodes. See [Debug](debug.md).

### Screenshots

```swift
func takeScreenshot(path: String)
func captureScreen() -> ImageData?
```

Save the current frame to a file or capture it as raw pixel data. Default implementations are no-ops. See [Debug](debug.md).

---

## Sprite

`Sources/AgilisCore/Graphics/Sprite.swift`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `texture` | `TextureHandle` | — | GPU texture reference |
| `sourceRect` | `Rect` | — | Region within the texture (pixels) |
| `position` | `Vector2` | `.zero` | World position |
| `scale` | `Vector2` | `.one` | Scale factor |
| `rotation` | `Float` | `0` | Rotation in radians |
| `origin` | `Vector2` | `.zero` | Pivot point (relative to sourceRect) |
| `tint` | `Color` | `.white` | Color tint |
| `flipX` | `Bool` | `false` | Horizontal flip |
| `flipY` | `Bool` | `false` | Vertical flip |
| `blendMode` | `BlendMode` | `.alpha` | Blend mode for this sprite |
| `material` | `Material2D?` | `nil` | Optional shader material (see [Materials](materials.md)) |

`Sprite` also conforms to `Component` (via `SpriteComponentConformance.swift`) for use in the ECS. When a `material` is set, the renderer applies the material's shader and uniforms when drawing the sprite. `SpriteBatch` sorts by material shader ID to minimize GPU state changes.

---

## BlendMode

`Sources/AgilisCore/Graphics/BlendMode.swift`

Controls how source pixels are combined with destination pixels.

```swift
public enum BlendMode: Int, Sendable, Codable, Equatable {
    case alpha = 0          // Standard alpha blending (default)
    case additive = 1       // Adds source to destination (glow, fire, light)
    case multiplied = 2     // Multiplies source with destination (shadows, tinting)
    case premultiplied = 3  // For textures with premultiplied alpha
}
```

### Per-Sprite Blend Mode

```swift
var sprite = Sprite(texture: glowTexture, blendMode: .additive)
```

### Scoped Blend Mode (for shapes/text)

```swift
app.renderer.beginBlendMode(.additive)
app.renderer.drawCircle(center: pos, radius: 32, color: .yellow)
app.renderer.endBlendMode()
```

---

## Camera2D

`Sources/AgilisCore/Graphics/Camera2D.swift`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `target` | `Vector2` | `.zero` | World position the camera looks at |
| `offset` | `Vector2` | `.zero` | Screen offset (e.g., center of screen) |
| `zoom` | `Float` | `1.0` | Zoom level (2.0 = 2x zoom in) |
| `rotation` | `Float` | `0` | Rotation in radians |

### Usage

```swift
let camera = Camera2D(
    target: playerPosition,
    offset: Vector2(x: 400, y: 300),  // Center of 800x600 screen
    zoom: 1.0
)
app.renderer.beginCamera(camera)
// Draw world objects here
app.renderer.endCamera()
// Draw HUD/UI here (not affected by camera)
```

---

## TextureHandle / FontHandle / RenderTargetHandle / ShaderHandle

Opaque `UInt32` handles for GPU resources. Follow the same pattern:

```swift
let texture = app.renderer.loadTexture(from: "player.png")
let size = app.renderer.textureSize(texture)
// Use texture...
app.renderer.destroyTexture(texture)

let font = app.renderer.loadDefaultFont()
app.renderer.drawText("Hello", position: .zero, font: font, size: 24, color: .white)
let textSize = app.renderer.measureText("Hello", font: font, size: 24)
```

Static sentinel: `.invalid` (id = 0) for uninitialized handles.

---

## SpriteBatch

`Sources/Agilis/Graphics/SpriteBatch.swift`

Opt-in draw call optimization. Collects sprites, sorts by blend mode and texture, flushes efficiently.

```swift
let batch = SpriteBatch(sortMode: .byTexture)
```

### Sort Modes

| Mode | Behavior |
|------|----------|
| `.byTexture` | Groups by blend mode, then texture ID (default) |
| `.byLayer` | Groups by layer, then blend mode, then texture |
| `.none` | Insertion order (no sorting) |

### Methods

```swift
func add(_ sprite: Sprite)                    // Queue a sprite
func add(_ sprite: Sprite, layer: Int)        // Queue with layer (for .byLayer mode)
func add(_ sprites: [Sprite])                 // Queue multiple sprites
func flush(to renderer: RenderBackend)         // Sort, draw, and clear
func clear()                                   // Discard without drawing
```

### Statistics

| Property | Description |
|----------|-------------|
| `count` | Number of queued sprites |
| `isEmpty` | Whether the batch is empty |
| `lastSpriteCount` | Sprites drawn in last flush |
| `lastDrawCallCount` | State change groups in last flush |

### Usage

```swift
let batch = SpriteBatch()
for entity in entities {
    batch.add(sprite)
}
batch.flush(to: app.renderer)
// batch.lastDrawCallCount tells you how many state groups were drawn
```

---

## NinePatchSprite

`Sources/Agilis/Graphics/NinePatchSprite.swift`

A nine-patch (nine-slice) sprite for scalable UI backgrounds and borders. Corners stay unscaled, edges stretch on one axis, center stretches on both.

```swift
let ninePatch = NinePatchSprite(
    texture: panelTexture,
    sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
    border: 12,   // Uniform border inset
    tint: .white
)
app.renderer.drawNinePatch(ninePatch, destination: panelRect)
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `texture` | `TextureHandle` | Source texture |
| `sourceRect` | `Rect` | Region in the texture |
| `borderTop` | `Float` | Top border inset |
| `borderRight` | `Float` | Right border inset |
| `borderBottom` | `Float` | Bottom border inset |
| `borderLeft` | `Float` | Left border inset |
| `tint` | `Color` | Color tint |

### Drawing

`drawNinePatch(_:destination:)` is an extension on `RenderBackend`. It draws 9 sprites: corners (unscaled), edges (stretched on one axis), center (stretched on both axes).

---

## Render Targets

Off-screen rendering to textures. Enables screen transitions, post-processing, minimaps, and resolution-independent rendering.

```swift
let rt = app.renderer.createRenderTarget(width: 320, height: 240)

// Draw to off-screen target
app.renderer.beginRenderTarget(rt)
app.renderer.drawCircle(center: Vector2(x: 160, y: 120), radius: 50, color: .red)
app.renderer.endRenderTarget()

// Draw RT contents to screen (handles Y-flip automatically)
app.renderer.drawRenderTarget(rt, position: .zero)
```

### Convenience Drawing

```swift
// Draw at position with optional tint
func drawRenderTarget(_ handle: RenderTargetHandle, position: Vector2, tint: Color)

// Draw scaled to destination rect
func drawRenderTarget(_ handle: RenderTargetHandle, destination: Rect, tint: Color)
```

### Getting the Texture

```swift
let tex = app.renderer.renderTargetTexture(rt)
// Use tex with drawSprite, SpriteBatch, etc.
```

---

## TextAlignment

`Sources/Agilis/Graphics/TextAlignment.swift`

Cases: `.left`, `.center`, `.right`

Used by `UILabel` for text alignment within its frame.

---

## TileMap

`Sources/Agilis/Graphics/TileMap.swift`

### Tile

```swift
struct Tile {
    let id: Int         // 0 = empty
    var flipX: Bool
    var flipY: Bool
    static let empty = Tile(id: 0)
}
```

### Tileset

```swift
struct Tileset {
    let texture: TextureHandle
    let tileWidth: Int
    let tileHeight: Int
    let columns: Int
    let firstGid: Int
    let tileCount: Int

    func sourceRect(for tileId: Int) -> Rect  // Texture region for a tile ID
}
```

### TileLayer

```swift
struct TileLayer {
    let name: String
    let width: Int
    let height: Int
    var tiles: [Tile]
    var visible: Bool
    var opacity: Float

    func tile(atColumn col: Int, row: Int) -> Tile?
}
```

### TileMap

```swift
struct TileMap {
    var layers: [TileLayer]
    var tilesets: [Tileset]
    let tileWidth: Int
    let tileHeight: Int
    let width: Int      // Map width in tiles
    let height: Int     // Map height in tiles
}
```

### Tilemap Rendering

Camera-culled rendering via `RenderBackend` extensions:

```swift
// Direct drawing
app.renderer.drawTileMap(tileMap, position: .zero, camera: camera)

// Batched drawing (for SpriteBatch integration)
let batch = SpriteBatch(sortMode: .byLayer)
app.renderer.batchTileMap(tileMap, into: batch, camera: camera)
batch.flush(to: app.renderer)
```

Only tiles overlapping the viewport are iterated. Layer opacity is applied to tint alpha, invisible layers are skipped, and empty tiles (id=0) are skipped.
