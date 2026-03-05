# Agilis

A cross-platform 2D game framework written in Swift, targeting Windows, Linux, and macOS.

Agilis provides a lightweight, backend-agnostic architecture with a built-in raylib backend for rendering, audio, and input. The core framework has zero platform-specific imports — all platform code lives behind swappable backend protocols.

## Features

- **Rendering** — Sprites, shapes, textures, text, camera, tilemaps, blend modes (alpha, additive, multiply), sprite batching, nine-patch sprites, render targets
- **Materials** — Per-sprite shader materials with typed uniforms, 6 built-in effects (flash, grayscale, dissolve, outline, color replace, wave), material templates, ShaderBuilder for custom GLSL, ShaderComposer for multi-effect composition, 6 GLSL include libraries (noise, easing, UV, color, math, normal mapping)
- **Post-Processing** — Screen-space effect pipeline with 6 built-in effects (bloom, chromatic aberration, color grading, vignette, scanlines, pixelate), custom effect support, automatic render target management
- **Animation** — Sprite animation system with forward, reverse, ping-pong, and one-shot playback; clips from sprite sheets, Aseprite, or TexturePacker; declarative animation state machine with parameter-driven transitions
- **Particles** — 2D particle system with configurable emission shapes, colors, scaling, gravity, and sprite rendering
- **UI System** — 12 retained-mode widgets (labels, buttons, sliders, toggles, text inputs, panels, progress bars, images, scroll containers, dropdowns, list views, modal dialogs), automatic layout, theming, configurable keyboard/gamepad navigation
- **Input** — Keyboard, mouse, and gamepad with press/release detection, action mapping, dead zones, and up to 4 gamepads
- **Audio** — Sound effects (in-memory) and music (streaming) with group volumes, fading, and crossfading via AudioManager
- **ECS** — Full Entity-Component-System with sparse-set storage, generational entity IDs, type-safe `forEach` queries, command buffers, system priorities, parent-child hierarchy, entity naming/tagging, component lifecycle events, event bus, prefabs, opt-in parallel system scheduling, and JSON serialization
- **Physics** — Built-in 2D physics with AABB, circle, and convex polygon collision shapes (SAT), impulse-based resolution, spatial hash broad phase, collision layers/masks, triggers, collision events, ray casting, spatial queries, continuous collision detection (CCD), and 6 physics joint types (revolute, distance, weld, prismatic, rope, motor) with breaking, motors, and spring-damper constraints
- **Scenes** — Stack-based scene management with animated transitions (fade, flash, custom easing)
- **Time** — Time scaling for slow motion, pause, and fast-forward
- **Assets** — Generic caching manager with pluggable loaders
- **File Formats** — Pure Swift parsers for LDtk, Tiled JSON, TexturePacker, and Aseprite with animation and tilemap bridges
- **Lighting** — Dynamic 2D lighting with point and spot lights, CPU-computed shadow volumes, per-pixel shader falloff, configurable ambient color and falloff, normal mapping with per-pixel diffuse, Blinn-Phong specular highlights, specular maps, soft shadows
- **Tweening** — Animate any property over time with 19 easing functions, sequences, yoyo, repeat, delay, and callbacks via TweenSystem; material uniform animation
- **Math** — Vector2, Rect, Size, Matrix3, Color, 19 easing functions
- **Debug** — Structured logging with level filtering and multiple outputs (console, file, ring buffer), debug overlay (FPS, frame graph, ECS stats, system timings), per-system debug renderers (animation, particles, tweens, tilemaps, UI, physics)
- **Plugins** — Extensibility via the Plugin protocol

## Quick Start

```swift
import Agilis

final class MyScene: Scene {
    private var ui: UIContext!

    func didEnter(app: Application) {
        let font = app.renderer.loadDefaultFont()
        ui = UIContext(font: font)

        let menu = UIContainer(id: "menu")
        menu.layout = .vertical(spacing: 12, alignment: .center)
        menu.add(UILabel("Hello, Agilis!", fontSize: 32))
        menu.add(UIButton("Quit", fontSize: 20) { [weak app] in app?.quit() })
        ui.add(menu)

        let screen = app.renderer.screenSize
        menu.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)
        if app.input.isKeyPressed(.escape) { app.quit() }
    }

    func render(app: Application, interpolation: Double) {
        ui.render(renderer: app.renderer)
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

## Using as a Dependency

Add Agilis to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourname/Agilis.git", from: "0.1.0"),
],
targets: [
    .executableTarget(
        name: "MyGame",
        dependencies: [
            .product(name: "Agilis", package: "Agilis"),
            // Optional: add AgilisFormats for file format parsers
        ]
    ),
]
```

## Building

Requires **Swift 6.0+**. No external dependencies — raylib is vendored and builds from source.

```
swift build
swift test
swift run UIDemo
swift run Pong
```

## Project Structure

```
Sources/
  AgilisCore/              Backend-agnostic protocols and value types
    Math/                   Vector2, Rect, Size, MathUtilities, EasingFunction
    Graphics/               RenderBackend protocol, Color, Sprite, Camera2D,
                              BlendMode, TextureHandle, FontHandle,
                              RenderTargetHandle, ShaderHandle, ImageData,
                              Material2D, PostProcessEffect, ShaderUniform
    Audio/                  AudioBackend protocol, SoundHandle, MusicHandle,
                              AudioGroup
    Input/                  InputBackend protocol, Key, MouseButton,
                              GamepadButton, GamepadAxis, GamepadStick
    Application/            WindowConfig
    Debug/                  LogLevel, LogEntry, LogOutput protocol

  Agilis/                  Main framework (re-exports AgilisCore + AgilisBackendRaylib)
    Application/            Application, GameDelegate, BackendFactory
    Core/                   ECS: Entity, Component, System, World, Query,
                              CommandBuffer, Prefab, Hierarchy, Metadata,
                              Event, ComponentAccess, SystemScheduler
    Animation/              AnimationSystem, SpriteAnimator, AnimationClip,
                              AnimationFrame, PlaybackMode, AnimationEvent,
                              AnimationStateMachine, AnimationStateMachineSystem
    Graphics/               TileMap, TextAlignment, SpriteBatch,
                              NinePatchSprite, RenderTargetDrawing
    Materials/              MaterialLibrary, MaterialTemplate, MaterialShaders,
                              MaterialRendering (MaterialContext),
                              ShaderBuilder, ShaderIncludes,
                              ShaderComposer, ComposableEffects
    PostProcess/            PostProcessPipeline, PostProcessShaders
      Effects/              BloomEffect, ChromaticAberrationEffect,
                              ColorGradingEffect, VignetteEffect,
                              ScanlinesEffect, PixelateEffect
    Particles/              ParticleEmitter, ParticleSystem, EmissionShape
    Lighting/               LightingSystem, Light2D, ShadowCaster2D,
                              ShadowGeometry, LightingShaders, NormalMapData
    Audio/                  AudioManager (group volumes, fading, crossfading)
    Input/                  InputManager, action mapping (keyboard, mouse, gamepad)
    Assets/                 AssetManager, pluggable loaders
    Math/                   Matrix3
    Physics/                PhysicsWorld2D, NarrowPhase (SAT), SpatialHashGrid,
                              ImpulseResolver, ContactTracker, CollisionFilter,
                              PhysicsDebugRenderer, SpatialQuery, SweptCollision,
                              Joint2D, JointStore, JointSolver
    Scene/                  Scene protocol, SceneManager, SceneTransition
    UI/                     UIContext, UINode, UIContainer, UILayout, UITheme,
                              UIInputConfig
      Widgets/              UILabel, UIButton, UIPanel, UISlider, UIToggle,
                              UITextInput, UIProgressBar, UIImage,
                              UIScrollContainer, UIDropdown, UIListView,
                              UIModalDialog
    Serialization/          WorldSerializer, SerializableComponent
    Tween/                  TweenSystem, TweenHandle, TweenTarget, TweenStep,
                              Interpolatable, TweenStore
    Debug/                  Log, DebugOverlay, per-system debug renderers
    Plugin/                 Plugin protocol
    Time/                   Clock

  AgilisBackendRaylib/     Raylib backend implementation
  AgilisFormats/           Pure Swift file format parsers (LDtk, Tiled,
                            TexturePacker, Aseprite) with animation and
                            tilemap bridges
  RaylibC/                Vendored raylib 5.5 C source

Examples/
  UIDemo/                 UI widget showcase with all 12 widgets
  Pong/                   Classic Pong with ECS, AI, scoring
  Platformer/             2D platformer with animation, particles, lighting
  TweenShowcase/          Interactive tween and easing demonstration
  PhysicsSandbox/         Interactive physics playground
  SaveLoadDemo/           World serialization demonstration
  DungeonCrawler/         Grid-based dungeon exploration
  TopDownShooter/         2D top-down shooter with particles and UI

Tests/
  AgilisTests/             Core framework, ECS, physics, materials, and UI tests (1450+ tests)
  AgilisFormatsTests/      Format parser tests
```

Users only need `import Agilis` — the Agilis module re-exports everything via `@_exported import`.

## Architecture

The framework is built around protocol-based backends:

- **`RenderBackend`** — All drawing goes through this protocol. The raylib backend implements it, but it can be swapped for Metal, WebGPU, or any other renderer.
- **`AudioBackend`** — Sound and music playback abstraction.
- **`InputBackend`** — Raw input polling abstraction (keyboard, mouse, gamepad).

Game code only touches framework types (`Sprite`, `Vector2`, `Color`, etc.) and never sees backend-specific types. This makes the core framework portable and testable without a window.

### Game Loop

Agilis uses a **fixed-timestep game loop**:
- Logic updates at a fixed rate (default 60Hz) via `Scene.update(deltaTime:)`
- Rendering runs at the display rate with an `interpolation` factor for smooth motion
- Input is polled once per frame with press/release edge detection
- Time scaling controls game speed (`app.timeScale`)

## UI System

Agilis includes a retained-mode UI system for menus, HUDs, settings screens, and dialogs.

**Widgets:** UILabel, UIButton, UISlider, UIToggle, UITextInput, UIProgressBar, UIImage, UIPanel, UIScrollContainer, UIDropdown, UIListView, UIModalDialog

**Layout:** Automatic vertical/horizontal stacking with alignment, or manual positioning. Containers can be nested for complex layouts.

**Theming:** `UITheme` struct with dark and light presets. All colors, fonts, and spacing are configurable.

**Navigation:** Configurable keyboard and gamepad navigation via `UIInputConfig`. Tab/Shift+Tab cycles through focusable widgets, Enter/Space activates, arrow keys adjust sliders. Mouse and keyboard coexist seamlessly.

```swift
let font = app.renderer.loadDefaultFont()
let ui = UIContext(font: font)
ui.inputConfig = .keyboardAndGamepad

let panel = UIContainer(id: "settings")
panel.layout = .vertical(spacing: 10, alignment: .center)
panel.add(UILabel("Settings", fontSize: 28))
panel.add(UISlider("Volume", value: 0.8, range: 0...1))
panel.add(UIToggle("Fullscreen", isOn: false))
panel.add(UIButton("Back") { /* return to menu */ })
ui.add(panel)
```

## Examples

### UIDemo
UI demo showcasing all 12 widgets: labels, buttons, slider, toggle, progress bar, dropdown, list view, and modal dialog. Supports keyboard and gamepad navigation.

### Pong
Classic Pong built on the ECS — paddles and ball as entities with custom components, AI prediction, named entity lookup, UI menus, keyboard input, and fixed-timestep interpolation.

### Platformer
2D platformer demonstrating animation clips, particle effects, dynamic lighting, multiple scenes (menu, gameplay, victory, game over), and level building.

### TweenShowcase
Interactive demonstration of all 19 easing functions and tween sequences with visual previews.

### PhysicsSandbox
Interactive physics playground for testing rigid bodies, collision shapes, joints, and spatial queries.

### SaveLoadDemo
World serialization demonstration — save and load full ECS state to/from JSON, including custom components and entity hierarchy.

### DungeonCrawler
Grid-based dungeon exploration with procedural generation, player and enemy components, and item pickups.

### TopDownShooter
2D top-down shooter with player, enemy, and bullet entities, particle effects, and UI scoring.

## License

MIT
