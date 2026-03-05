# Plugin

## Plugin Protocol

`Sources/Agilis/Plugin/Plugin.swift`

Plugins extend the engine without modifying core code. `update` and `uninstall` have empty default implementations.

```swift
protocol Plugin: AnyObject {
    var name: String { get }
    func install(in app: Application)       // Called when installed
    func update(deltaTime: Double)          // Called each fixed-timestep tick
    func uninstall()                        // Called on shutdown
}
```

### Lifecycle

1. `install(in:)` — Called immediately when `app.install(plugin)` is called. Register ECS systems, load assets, or configure state here.
2. `update(deltaTime:)` — Called every fixed-timestep tick, after scene and ECS updates.
3. `uninstall()` — Called during `app.run()` shutdown, in reverse installation order.

### Example

```swift
class DebugPlugin: Plugin {
    var name: String { "Debug" }

    func install(in app: Application) {
        print("Debug plugin installed")
    }

    func update(deltaTime: Double) {
        // Could track frame timing, draw debug overlays, etc.
    }
}

// Usage
let app = createApplication(config: config)
app.install(DebugPlugin())
try app.run()
```

### Installation Order

Plugins update in installation order and uninstall in reverse order:

```swift
app.install(pluginA)    // install A, update order: A
app.install(pluginB)    // install B, update order: A, B
// Shutdown: uninstall B, then uninstall A
```
