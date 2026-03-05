# Getting Started

## Prerequisites

- **Swift 6.0+** (Windows, macOS, or Linux)
- No external dependencies — raylib is vendored and builds from source

## Creating a New Project

Create a `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyGame",
    dependencies: [
        .package(url: "https://github.com/yourname/Agilis.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "MyGame",
            dependencies: [
                .product(name: "Agilis", package: "Agilis"),
            ]
        ),
    ]
)
```

Optionally add `AgilisFormats` for file format parsers (LDtk, Tiled, TexturePacker, Aseprite).

## Minimal Example

Create `Sources/MyGame/main.swift`:

```swift
import Agilis

final class MyScene: Scene {
    func update(app: Application, deltaTime: Double) {
        if app.input.isKeyPressed(.escape) {
            app.quit()
        }
    }

    func render(app: Application, interpolation: Double) {
        app.renderer.drawCircle(
            center: Vector2(x: 400, y: 300),
            radius: 50,
            color: .yellow
        )
    }
}

let app = createApplication(config: WindowConfig(
    title: "My Game",
    width: 800,
    height: 600
))
app.sceneManager.push(MyScene(), app: app)
try app.run()
```

## Building and Running

```
swift build
swift run MyGame
```

## Running the Bundled Examples

From the Agilis repository:

```
swift run UIDemo           # UI demo with all 12 widgets
swift run PongGame         # Full Pong game with menus and AI
swift run Platformer       # Side-scrolling platformer with parallel ECS
swift run DungeonCrawler   # Top-down dungeon with lighting and shadows
swift run TopDownShooter   # Arena shooter with waves and particles
swift run TweenShowcase    # Tween system demo with easing functions
swift run PhysicsSandbox   # Interactive physics with all 6 joint types
swift run SaveLoadDemo     # Entity serialization with save/load
```

## Next Steps

- [Architecture](architecture.md) — Understand the framework design
- [Graphics](api/graphics.md) — Rendering, sprites, blend modes, sprite batching, render targets, tilemaps
- [Materials](api/materials.md) — Material2D, MaterialLibrary (6 effects), MaterialTemplate, ShaderBuilder, ShaderComposer, GLSL include libraries
- [Post-Processing](api/post-processing.md) — PostProcessPipeline with 6 built-in effects (bloom, vignette, chromatic aberration, color grading, scanlines, pixelate)
- [UI System](api/ui.md) — Build menus and HUDs with 12 widgets
- [Input](api/input.md) — Handle keyboard, mouse, and gamepad input
- [Audio](api/audio.md) — Sound effects, music, group volumes, fading
- [ECS](api/ecs.md) — Entity-Component-System with sparse-set storage, type-safe queries, prefabs, hierarchy, serialization
- [Physics](api/physics.md) — 2D collision detection, physics simulation, continuous collision detection (CCD), joints (revolute, distance, weld), ray casting, spatial queries
- [Lighting](api/lighting.md) — 2D lighting, shadow volumes, shaders, debug overlays
- [Scenes](api/scenes.md) — Scene management with animated transitions
- [Tweening](api/tweening.md) — Animate properties over time with easing, sequences, yoyo, repeat, and callbacks
- [Animation State Machine](api/animation-state-machine.md) — Declarative state machine for managing animation clip transitions with parameter-driven conditions
- [Math](api/math.md) — Vector2, Rect, Matrix3, Color, easing functions
- [Time](api/time.md) — Clock, time scaling
- [File Formats](api/formats.md) — Parsers for LDtk, Tiled, TexturePacker, Aseprite with animation and tilemap bridges
- [Examples](examples.md) — Walkthrough of the bundled examples
