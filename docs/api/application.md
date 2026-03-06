# Application

## Application

`Sources/Agilis/Application/Application.swift`

The central engine object. Owns the game loop and all subsystems.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `config` | `WindowConfig` | Window configuration |
| `renderer` | `RenderBackend` | Rendering backend |
| `audio` | `AudioBackend` | Audio backend (low-level) |
| `audioManager` | `AudioManager` | High-level audio (groups, fading, crossfading) |
| `input` | `InputManager` | Input manager (keyboard, mouse, gamepad) |
| `world` | `World` | ECS world |
| `sceneManager` | `SceneManager` | Scene stack |
| `assets` | `AssetManager` | Asset cache |
| `timeScale` | `Double` | Game speed multiplier (default: 1.0) |
| `fps` | `Int` | Current FPS (updated once per second) |
| `frameTime` | `Double` | Duration of the last frame in seconds |
| `delegate` | `GameDelegate?` | Optional lifecycle delegate (weak) |

### Methods

```swift
// Create with default native backends (ANGLE renderer, MiniAudio audio, PlatformC input)
init(config: WindowConfig = WindowConfig())

// Install a plugin (call before run())
func install(_ plugin: Plugin)

// Start the game loop (blocks until window closes)
func run() throws

// Async game loop with parallel system scheduling support
func runAsync() async throws

// Request the application to stop
func quit()
```

`runAsync()` enables parallel system scheduling via Swift Concurrency. Systems that declare their `componentAccess` can run concurrently in the same stage. The sync `run()` always runs systems sequentially. See [ECS — Component Access & Parallel Scheduling](ecs.md#component-access--parallel-scheduling) for details.

### Creating an Application

```swift
let app = Application(config: WindowConfig(
    title: "My Game",
    width: 800,
    height: 600
))
```

An internal dependency-injection initializer `init(config:renderer:audio:inputBackend:)` is available for testing with mock backends.

---

## WindowConfig

`Sources/Agilis/Application/Configuration.swift`

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `title` | `String` | `"Agilis"` | Window title |
| `width` | `Int` | `800` | Window width in pixels |
| `height` | `Int` | `600` | Window height in pixels |
| `targetFPS` | `Int` | `60` | Target frame rate (0 = uncapped) |
| `resizable` | `Bool` | `true` | Whether window can be resized |
| `vsync` | `Bool` | `true` | Vertical sync |
| `fixedTimestep` | `Double` | `1.0/60.0` | Seconds per logic update |
| `maxFrameTime` | `Double` | `0.25` | Maximum frame time (prevents spiral-of-death) |

---

## GameDelegate

`Sources/Agilis/Application/GameDelegate.swift`

Optional lifecycle hooks. All methods have empty default implementations.

```swift
protocol GameDelegate: AnyObject {
    func gameDidStart(_ app: Application)
    func gameDidUpdate(_ app: Application, deltaTime: Double)
    func gameWillRender(_ app: Application, interpolation: Double)
    func gameWillStop(_ app: Application)
}
```

### Usage

```swift
class MyDelegate: GameDelegate {
    func gameDidStart(_ app: Application) {
        print("Engine initialized")
    }
}

app.delegate = MyDelegate()
```
