# Debug

## Logging

### LogLevel

`Sources/AgilisCore/Debug/LogLevel.swift`

```swift
public enum LogLevel: Int, Comparable, Sendable, CustomStringConvertible {
    case trace = 0
    case debug = 1
    case info = 2
    case warn = 3
    case error = 4
}
```

Comparable by raw value. `description` returns the uppercase name (e.g. `"TRACE"`, `"ERROR"`).

---

### LogEntry

`Sources/AgilisCore/Debug/LogEntry.swift`

| Property | Type | Description |
|----------|------|-------------|
| `level` | `LogLevel` | Severity level |
| `category` | `String` | Source category (e.g. `"Physics"`, `"Audio"`) |
| `message` | `String` | Log message text |
| `timestamp` | `Double` | Seconds since engine start |

---

### LogOutput

`Sources/AgilisCore/Debug/LogOutput.swift`

Protocol for log destinations.

```swift
public protocol LogOutput: AnyObject, Sendable {
    var minimumLevel: LogLevel { get set }
    func write(_ entry: LogEntry)
}
```

Outputs only receive entries whose level meets or exceeds `minimumLevel`.

---

### Log

`Sources/Agilis/Debug/Log.swift`

Static logging facade. Not instantiated — all methods are static.

```swift
public enum Log {
    static var minimumLevel: LogLevel      // Global gate (default: .info)
    static var outputs: [LogOutput]        // Read-only list of registered outputs

    static func addOutput(_ output: LogOutput)
    static func removeAllOutputs()

    static func trace(_ category: String, _ message: String)
    static func debug(_ category: String, _ message: String)
    static func info(_ category: String, _ message: String)
    static func warn(_ category: String, _ message: String)
    static func error(_ category: String, _ message: String)
}
```

Messages are dispatched to all outputs whose `minimumLevel` is at or below the entry level. The global `minimumLevel` acts as a first gate before any output is consulted. Timestamps come from an internal `Clock` instance.

### Usage

```swift
Log.addOutput(ConsoleLogOutput())
Log.minimumLevel = .debug

Log.info("Physics", "Collision detected between \(entityA) and \(entityB)")
Log.warn("Assets", "Texture not found: player.png")
Log.error("Scene", "Failed to load level data")
```

---

### ConsoleLogOutput

`Sources/Agilis/Debug/ConsoleLogOutput.swift`

Prints formatted log entries to stdout.

```swift
let console = ConsoleLogOutput()          // minimumLevel defaults to .trace
console.minimumLevel = .warn              // Only show warnings and errors
Log.addOutput(console)
```

Format: `[LEVEL] [category] message`

---

### FileLogOutput

`Sources/Agilis/Debug/FileLogOutput.swift`

Writes log entries to a file. Uses `fopen`/`fputs` for cross-platform compatibility (Windows, Linux, macOS).

```swift
if let fileLog = FileLogOutput(path: "game.log") {
    fileLog.minimumLevel = .info
    Log.addOutput(fileLog)
}
```

Returns `nil` if the file cannot be opened. Each entry is written with a timestamp prefix and flushed immediately. The file handle is closed on `deinit`.

---

### RingBufferLogOutput

`Sources/Agilis/Debug/RingBufferLogOutput.swift`

Fixed-capacity circular buffer. Oldest entries are overwritten when full. Used by `DebugOverlay` for on-screen log display.

| Property | Type | Description |
|----------|------|-------------|
| `capacity` | `Int` | Maximum entries stored |
| `entryCount` | `Int` | Current number of entries |
| `entries` | `[LogEntry]` | Snapshot of stored entries (oldest first) |

```swift
let buffer = RingBufferLogOutput(capacity: 100, minimumLevel: .debug)
Log.addOutput(buffer)

// Read entries for display
for entry in buffer.entries {
    print("\(entry.level): \(entry.message)")
}

buffer.clear()   // Remove all entries
```

---

## Viewport Snapshots

Added to `RenderBackend` protocol:

```swift
func takeScreenshot(path: String)
func captureScreen() -> ImageData?
```

Default implementations are no-ops (returns `nil` for `captureScreen`). The raylib backend implements both using raylib's `TakeScreenshot` and `LoadImageFromScreen`.

### ImageData

`Sources/AgilisCore/Graphics/ImageData.swift`

| Property | Type | Description |
|----------|------|-------------|
| `width` | `Int` | Image width in pixels |
| `height` | `Int` | Image height in pixels |
| `pixels` | `[UInt8]` | Raw RGBA pixel data (4 bytes per pixel) |

### Usage

```swift
// Save to file
app.renderer.takeScreenshot(path: "screenshot.png")

// Capture to memory
if let image = app.renderer.captureScreen() {
    print("Captured \(image.width)x\(image.height) image")
}
```

---

## Debug Overlay

`Sources/Agilis/Debug/DebugOverlay.swift`

Unified HUD that renders FPS, frame graph, entity stats, system timings, and on-screen log.

### DebugOverlayOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `showFPS` | `Bool` | `true` | Show FPS counter and frame time |
| `showFrameGraph` | `Bool` | `true` | Show frame time bar graph |
| `showEntityStats` | `Bool` | `true` | Show entity/component/system counts |
| `showSystemTimings` | `Bool` | `true` | Show per-system timing table |
| `showLog` | `Bool` | `true` | Show on-screen log entries |
| `logLineCount` | `Int` | `8` | Max log lines displayed |
| `fontSize` | `Float` | `14` | Font size for all text |
| `graphSamples` | `Int` | `120` | Number of frame time samples in graph |
| `backgroundColor` | `Color` | Semi-transparent dark | Background color |
| `textColor` | `Color` | `.white` | Default text color |
| `warningColor` | `Color` | `.yellow` | Color for warnings |
| `errorColor` | `Color` | `.red` | Color for errors |

### DebugOverlay

| Property/Method | Description |
|-----------------|-------------|
| `font: FontHandle` | Font used for rendering |
| `options: DebugOverlayOptions` | Display configuration |
| `logBuffer: RingBufferLogOutput?` | Optional link to ring buffer for log display |
| `isVisible: Bool` | Toggle overlay on/off (default: `true`) |
| `recordFrame(frameTime:)` | Call each frame to update rolling history |
| `render(renderer:app:)` | Draw the full HUD in screen space |

### Sections (top-left, stacked vertically)

1. **FPS counter** — current FPS + frame time in ms
2. **Frame time graph** — bar graph of recent frame times (green/yellow/red thresholds)
3. **Entity stats** — entity count, component store count, system count
4. **System timings** — table of system names + execution time in ms (sorted by priority)
5. **On-screen log** — last N entries from ring buffer, color-coded by level

### Usage

```swift
let debugFont = app.renderer.loadDefaultFont()
let overlay = DebugOverlay(font: debugFont)

// Optional: connect ring buffer for log display
let logBuffer = RingBufferLogOutput(capacity: 50, minimumLevel: .debug)
Log.addOutput(logBuffer)
overlay.logBuffer = logBuffer

// In game loop
overlay.recordFrame(frameTime: deltaTime)

// In render (after scene, outside camera block)
overlay.render(renderer: app.renderer, app: app)

// Toggle with key press
if app.input.isKeyPressed(.f3) {
    overlay.isVisible.toggle()
}
```

---

## World Debug Stats

Added to `World`:

| Property | Type | Description |
|----------|------|-------------|
| `entityCount` | `Int` | Number of living entities |
| `componentStoreCount` | `Int` | Number of registered component types |
| `systemCount` | `Int` | Number of registered systems |
| `systemTimings` | `[(name: String, priority: Int, duration: Double)]` | Per-system execution times from last update |

System timings are populated during `update(deltaTime:)` and `updateParallel(deltaTime:)`. Each entry contains the system's class name, priority, and execution duration in seconds.

---

## Per-System Debug Renderers

All debug renderers follow the same pattern: `extension RenderBackend { public func drawXxxDebug(...) }` with a `Sendable` options struct. Call inside a camera block so overlays align with world-space positions (except UI debug, which is screen-space).

### Animation Debug

`Sources/Agilis/Debug/AnimationDebugRenderer.swift`

**AnimationDebugRendererOptions**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `drawSourceRects` | `Bool` | `true` | Draw outlines around sprite source rectangles |
| `drawAnimatorState` | `Bool` | `true` | Show clip name, frame index, play state |
| `sourceRectColor` | `Color` | `.green` | Color for source rect outlines |
| `stateTextColor` | `Color` | `.white` | Color for state text labels |
| `fontSize` | `Float` | `12` | Font size for labels |

```swift
app.renderer.drawAnimationDebug(world: app.world, font: debugFont)
```

Iterates entities with `(Transform2D, SpriteAnimator, Sprite)`. Draws source rect outlines and `> clipName [frame/total]` labels.

---

### Tween Debug

`Sources/Agilis/Debug/TweenDebugRenderer.swift`

**TweenDebugInfo** — public struct returned by `TweenSystem.debugTweenInfo(world:)`:

| Property | Type | Description |
|----------|------|-------------|
| `entity` | `Entity` | The entity being tweened |
| `targetType` | `String` | Property being animated (`"pos"`, `"rot"`, `"scale"`, etc.) |
| `progress` | `Float` | Progress from 0.0 to 1.0 |
| `targetPosition` | `Vector2?` | Target position (only for position tweens) |

**TweenDebugRendererOptions**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `drawPaths` | `Bool` | `true` | Draw lines to tween target (position tweens) |
| `drawProgress` | `Bool` | `true` | Show tween type and progress percentage |
| `pathColor` | `Color` | `.magenta` | Color for path lines |
| `fontSize` | `Float` | `12` | Font size for labels |

```swift
let infos = tweenSystem.debugTweenInfo(world: app.world)
app.renderer.drawTweenDebug(infos: infos, world: app.world, font: debugFont)
```

For position tweens, draws a line from the entity's current position to the target. Shows `targetType NN%` label near the entity.

---

### Particle Debug

`Sources/Agilis/Debug/ParticleDebugRenderer.swift`

**ParticleDebugRendererOptions**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `drawEmissionShape` | `Bool` | `true` | Draw emission shape outlines |
| `drawParticleCount` | `Bool` | `true` | Show particle count labels |
| `emissionShapeColor` | `Color` | `.yellow` | Color for outlines |
| `fontSize` | `Float` | `12` | Font size for labels |

```swift
app.renderer.drawParticleDebug(world: app.world, font: debugFont)
```

Iterates entities with `(Transform2D, ParticleEmitter)`. Draws:
- **Point** — crosshair
- **Circle** — circle outline
- **Ring** — circle outline + center dot
- **Rect** — rect outline
- Count label: `active/max [ON|OFF]`

---

### TileMap Debug

`Sources/Agilis/Debug/TileMapDebugRenderer.swift`

**TileMapDebugRendererOptions**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `drawGrid` | `Bool` | `true` | Draw tile grid lines (camera-culled) |
| `drawCullingRect` | `Bool` | `true` | Draw camera culling viewport rectangle |
| `gridColor` | `Color` | Semi-transparent white | Grid line color |
| `cullingRectColor` | `Color` | `.yellow` | Culling rect color |

```swift
app.renderer.drawTileMapDebug(tileMap: tileMap, camera: camera)
```

Grid lines are only drawn within the camera viewport for performance. Zero-size tile maps are skipped.

---

### UI Debug

`Sources/Agilis/Debug/UIDebugRenderer.swift`

**UIDebugRendererOptions**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `drawBounds` | `Bool` | `true` | Draw bounding rect outlines |
| `boundsColor` | `Color` | `.cyan` | Color for outlines |
| `fontSize` | `Float` | `10` | Font size for node ID labels |

```swift
// Call in screen space (outside camera block), after uiContext.render()
app.renderer.drawUIDebug(context: uiContext, font: debugFont)
```

Recursively walks the UI tree from `UIContext.root`. Draws bounding rectangles and node ID labels. Zero-size nodes are skipped.

---

## Existing Debug Renderers

These debug renderers existed before the debug infrastructure was added:

### Physics Debug

`Sources/Agilis/Physics/PhysicsDebugRenderer.swift`

See [Physics](physics.md) for details.

```swift
app.renderer.drawPhysicsDebug(world: app.world, events: physics.events)
app.renderer.drawJointsDebug(physics: physics, world: app.world)
```

### Lighting Debug

`Sources/Agilis/Lighting/LightingDebugRenderer.swift`

See [Lighting](lighting.md) for details.

```swift
app.renderer.drawLightingDebug(world: app.world, options: lighting.options)
```

---

## Full Debug Setup Example

```swift
// In Scene.didEnter
let debugFont = app.renderer.loadDefaultFont()

// Logging
let console = ConsoleLogOutput()
let ringBuffer = RingBufferLogOutput(capacity: 100, minimumLevel: .debug)
Log.addOutput(console)
Log.addOutput(ringBuffer)
Log.minimumLevel = .debug

// Debug overlay
let overlay = DebugOverlay(font: debugFont)
overlay.logBuffer = ringBuffer

// In Scene.update
overlay.recordFrame(frameTime: deltaTime)

// In Scene.render
app.renderer.beginCamera(camera)
// ... draw scene ...

// World-space debug overlays (inside camera block)
app.renderer.drawPhysicsDebug(world: app.world, events: physics.events)
app.renderer.drawAnimationDebug(world: app.world, font: debugFont)
app.renderer.drawParticleDebug(world: app.world, font: debugFont)
app.renderer.drawTileMapDebug(tileMap: tileMap, camera: camera)

let tweenInfos = tweenSystem.debugTweenInfo(world: app.world)
app.renderer.drawTweenDebug(infos: tweenInfos, world: app.world, font: debugFont)

app.renderer.endCamera()

// Screen-space overlays (outside camera block)
app.renderer.drawUIDebug(context: uiContext, font: debugFont)
overlay.render(renderer: app.renderer, app: app)

// Screenshot on key press
if app.input.isKeyPressed(.f12) {
    app.renderer.takeScreenshot(path: "screenshot.png")
}
```
