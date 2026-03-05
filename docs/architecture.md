# Architecture

## Layered Design

Agilis is organized into four library targets:

```
AgilisCore              Backend protocols and value types (no platform deps)
Agilis                  Main framework (re-exports AgilisCore + AgilisBackendRaylib)
AgilisBackendRaylib     Raylib backend (rendering, audio, input)
AgilisFormats           Pure Swift file format parsers
```

Game code only needs `import Agilis` — the module re-exports everything. Users never touch backend-specific types directly. This makes the core portable and testable without a window.

## Backend Protocols

All platform-specific behavior is abstracted behind three protocols:

- **`RenderBackend`** — Drawing, textures, fonts, text, clipping, camera, blend modes, render targets, shaders
- **`AudioBackend`** — Sound effects (in-memory) and music (streaming)
- **`InputBackend`** — Raw keyboard, mouse, and gamepad polling

The raylib backend provides concrete implementations, but these can be swapped for Metal, WebGPU, SDL, or any other renderer.

## Application

`Application` is the central engine object. It owns:

- The render, audio, and input backends
- The `AudioManager` (group volumes, fading, crossfading)
- The ECS `World` (sparse-set storage, generational entities, queries, hierarchy, metadata)
- The `SceneManager` (scene stack with animated transitions)
- The `AssetManager` (caching)
- The `timeScale` property (game speed multiplier)
- FPS tracking

A convenience factory creates a fully configured application:

```swift
let app = createApplication(config: WindowConfig(
    title: "My Game",
    width: 800,
    height: 600
))
```

## Game Loop

Agilis uses a **fixed-timestep game loop** with variable-rate rendering. Two entry points are available:

- **`Application.run()`** — synchronous, all systems run sequentially (default)
- **`Application.runAsync()`** — async, enables parallel system scheduling when `world.parallelSchedulingEnabled` is true

```
while running:
    elapsed = clock.elapsed()
    accumulator += elapsed * timeScale

    input.update()          // Poll once per frame

    while accumulator >= fixedTimestep:
        scene.update(deltaTime: fixedDT)    // Logic at fixed rate (default 60Hz)
        world.update(deltaTime: fixedDT)    // ECS systems (sequential or parallel)
        accumulator -= fixedDT

    interpolation = accumulator / fixedDT
    scene.render(interpolation: interpolation)  // Render at display rate
```

When parallel scheduling is enabled, `world.updateParallel()` groups compatible systems into stages using `SystemScheduler`. Systems within a stage run concurrently via `TaskGroup`; stages execute sequentially. Each system gets its own `CommandBuffer`, flushed in priority order after each stage for determinism.

- **Logic** updates at a fixed rate (`config.fixedTimestep`, default 1/60s) for deterministic behavior
- **Rendering** runs at the display rate with an `interpolation` factor (0.0-1.0) for smooth motion between logic frames
- **Input** is polled once per frame with press/release edge detection
- **Max frame time** (`config.maxFrameTime`, default 0.25s) prevents the "spiral of death" during lag spikes
- **Time scaling** multiplies the accumulator, allowing slow motion, pause, and fast-forward

## Concurrency

Agilis targets Swift 6 with strict concurrency checking:

- All UI and engine classes use `@unchecked Sendable` since they run on a single game thread by default
- Static mutable state uses `nonisolated(unsafe)` where needed
- The framework is single-threaded by default — all game code runs on the main thread within the game loop
- **Opt-in parallel scheduling** — `world.parallelSchedulingEnabled = true` with `Application.runAsync()` enables concurrent system execution via Swift Concurrency (`async/await` + `TaskGroup`)
- Systems declare `componentAccess` (reads/writes/mutatesEntities/emitsEvents) so the `SystemScheduler` can group non-conflicting systems into parallel stages
- Thread safety is guaranteed by the scheduler (disjoint component access per stage), not by locks — no contention on `ComponentStore`
- Raylib GPU calls remain on the main thread; only system logic is parallelized
- `@unchecked Sendable` wrappers bridge non-Sendable types (System references, CommandBuffers) across `TaskGroup` boundaries

## Scene Management

Scenes are managed as a stack:

- `push` — Add a scene on top (previous scene pauses but stays in memory)
- `pop` — Remove the current scene (previous resumes)
- `replace` — Swap the top scene (previous is removed)
- `replaceAll` — Clear the entire stack and set a single scene

All methods have transition-aware variants that accept a `SceneTransition` for animated fades between scenes. Only the top scene receives `update` and `render` calls.

## Animation System

Sprite animation driven by the ECS. `SpriteAnimator` holds playback state, `AnimationSystem` (priority 50) iterates `(SpriteAnimator, Sprite)` pairs and advances frames. Supports forward, reverse, ping-pong, and one-shot playback modes. Animation clips can be created from sprite sheets, Aseprite data, or TexturePacker atlases.

## Particle System

Lightweight 2D particles pooled inside `ParticleEmitter` components (not ECS entities). `ParticleSystem` (priority 200) handles emission, physics, and cleanup. Supports point, circle, ring, and rect emission shapes with sprite or shape rendering.

## Material System

Four-layer shader and material system:

- **Material2D** — value type pairing a `ShaderHandle` with typed `[String: UniformValue]` uniforms and optional `BlendMode`. Assigned to sprites via `Sprite.material`. SpriteBatch sorts by shader ID.
- **MaterialLibrary** — manages 6 built-in effects (flash, grayscale, dissolve, outline, colorReplace, wave) with shader caching. Provides factory methods and `MaterialTemplate` for reusable definitions.
- **ShaderBuilder** — generates complete GLSL 330 fragment shaders from uniform declarations, `ShaderInclude` libraries (noise, easing, UV, color, math), and user body code. Separate methods for sprite rendering (`createFragment`) and post-processing (`createPostProcess`).
- **ShaderComposer** — chains multiple named fragment effects into a single shader program, merging uniforms and deduplicating includes. `ComposableEffects` provides 6 pre-built snippets.

`MaterialContext` auto-injects standard uniforms (`_time`, `_resolution`, `_deltaTime`) into any shader that declares them. `TweenSystem` extensions animate float and color uniforms over time.

## Post-Processing Pipeline

Screen-space effect chain managed by `PostProcessPipeline`. Captures the scene into a render target, runs enabled effects via ping-pong buffers, and composites the result to screen. Auto-detects screen resize.

`PostProcessEffect` protocol defines the effect interface (initialize, shutdown, resize, apply). Six built-in effects: bloom (2-pass Gaussian), chromatic aberration, color grading, vignette, scanlines, pixelate. Custom effects implement the same protocol.

The pipeline integrates between scene rendering and HUD/UI drawing. Effects are sorted by `order` property; disabled effects are skipped at zero cost.

## Lighting System

Dynamic 2D lighting with shadow volumes and normal mapping. `LightingSystem` (priority 300) snapshots `Light2D`, `ShadowCaster2D`, and `NormalMapData` components during `update()`, then provides `renderNormalBuffer()`, `renderLightMap()`, and `compositeLightMap()` methods for the render pipeline. Lights are drawn to an off-screen render target using GLSL shaders for per-pixel falloff (additive blend). Shadow volumes are CPU-computed from `Collider2D` geometry using silhouette edge detection and rendered as black triangles. The light map is composited onto the scene using `BlendMode.multiplied`.

When `normalMappingEnabled` is true, a G-buffer style approach renders per-entity normal maps to an auxiliary buffer. Light shaders sample this buffer for per-pixel Lambert diffuse calculation. When `specularEnabled` is also true, a specular buffer stores per-pixel specular intensity and a second additive pass per light computes Blinn-Phong specular highlights. All normal mapping features are opt-in with zero overhead when disabled.

When `softShadows` is enabled, each shadow-casting light's shadow volumes are rendered to a dedicated shadow buffer (white = lit, black = shadow), then Gaussian-blurred with configurable quality (1-3 separable passes using a 9-tap kernel), and sampled in the light shader via a `shadowBuffer` uniform. This replaces the hard black triangle approach with smooth shadow edges. Each light can override the global blur radius for per-light control. The feature is fully opt-in with zero overhead when disabled.

## Physics System

Agilis includes a built-in 2D physics system driven by the ECS, with collision detection, impulse resolution, and constraint joints.

### Components

| Component | Purpose |
|-----------|---------|
| `Transform2D` | Position, rotation, scale — the standard position component |
| `PreviousTransform2D` | Previous-frame snapshot for interpolated rendering |
| `Velocity2D` | Linear (Vector2) and angular (Float) velocity |
| `RigidBody2D` | Mass, inertia, restitution, friction, gravity scale, body type |
| `Collider2D` | Collision shape, offset, trigger flag, layer/mask bitmasks |

### Collision Shapes

- `.aabb(halfExtents:)` — Axis-aligned bounding box
- `.circle(radius:)` — Circle
- `.polygon(ConvexPolygon)` — Convex polygon using SAT (Separating Axis Theorem)

All 6 shape pair combinations are handled (AABB-AABB, Circle-Circle, AABB-Circle, Polygon-Polygon, Polygon-Circle, Polygon-AABB). Rotated AABBs are promoted to polygons automatically.

### Pipeline

`PhysicsWorld2D` is a `System` that runs each fixed-timestep tick:

1. **Store previous transforms** — copies `Transform2D` into `PreviousTransform2D`
2. **Apply gravity** — adds `gravity * gravityScale * dt` to dynamic bodies
3. **Integrate velocities** — updates position and rotation from velocity
4. **CCD sweep** — clamp fast-moving `useCCD` bodies to earliest time of impact (prevents tunneling). Angular sweep uses conservative bounding circle for rotating non-circle shapes. Bilateral CCD uses relative velocity between two CCD bodies.
5. **Broad phase** — spatial hash grid finds potential collision pairs
6. **Narrow phase** — SAT collision tests on each pair, filtered by layer/mask
7. **Response** — impulse-based velocity resolution + penetration correction
8. **Joint solving** — sequential impulse constraint solver (pre-solve, warm start, velocity iterations, position iterations, break detection)
9. **Collision events** — generates began/ongoing/ended collision events
10. **Joint events** — broken joint callbacks and cleanup

### Joints

Six joint types constrain pairs of entities:

- **Revolute** (pin/hinge) — shared anchor point, optional angle limits and motor
- **Distance** (spring) — maintains distance between anchors, optional spring-damper
- **Weld** (fixed) — locks relative position and angle, optional soft weld
- **Prismatic** (slider) — constrains bodies to slide along a fixed axis, locks rotation, optional translation limits and motor
- **Rope** (max distance) — enforces maximum distance between anchors, goes slack when closer
- **Motor** (driven offset) — drives body B toward a target offset relative to body A, does not break

Joints use a sequential impulse solver with warm starting, Baumgarte stabilization, and configurable velocity/position iterations. Joints can optionally break when force or torque exceeds a threshold, firing a `JointEvent`. Motor joints do not support breaking.

### Spatial Queries

Raycast, point query, and area query methods on `PhysicsWorld2D` for line-of-sight, mouse picking, and explosion radius checks.

### Body Types

- **Dynamic** — Fully simulated (gravity, collisions, forces, joints)
- **Static** — Never moves (walls, floors, joint anchors)
- **Kinematic** — Moves programmatically, pushes dynamic bodies but isn't pushed

### Usage

```swift
let physics = PhysicsWorld2D(gravity: Vector2(x: 0, y: 980))
world.addSystem(physics)

// Create a dynamic ball
let ball = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 400, y: 100)), to: ball)
world.addComponent(Velocity2D(), to: ball)
world.addComponent(RigidBody2D(mass: 1, restitution: 0.8), to: ball)
world.addComponent(Collider2D(shape: .circle(radius: 16)), to: ball)

// Listen for collisions
physics.onCollisionBegan = { event in
    print("Hit: \(event.entityA) vs \(event.entityB)")
}

// Create a revolute joint (e.g., pendulum)
let joint = physics.createJoint(.revolute(RevoluteJointDef(
    entityA: anchor, entityB: ball,
    anchor: Vector2(x: 400, y: 100)
)), in: world)
```

## Tweening System

`TweenSystem` (priority 25) animates component properties over time using easing functions. Tweens are stored centrally (like joints) — not as ECS components. The system writes interpolated values to `Transform2D` and `Sprite` components each tick.

Supports single-property tweens (move, rotate, scale, tint, fade), custom tweens with user closures, and multi-step sequences. Tweens auto-cancel when their target entity is destroyed. Yoyo and repeat modifiers enable looping effects. Material uniform tweening allows animating shader parameters. `TweenCompleted` events fire on the world when tweens finish.

See [Tweening API](api/tweening.md) for the full reference.

## Event Bus

The ECS `World` includes a type-keyed pub/sub event bus for decoupled game logic. Event handlers are registered with `world.on(EventType.self)` and dispatched synchronously via `world.emit()`. This is separate from component lifecycle events (`onComponentAdded`/`onComponentRemoved`).

Events are struct types conforming to the `Event` marker protocol. The system is re-entrant safe (emitting from a handler works) and type-keyed for O(1) dispatch. Built-in systems that emit events include `TweenSystem` (`TweenCompleted`), `AnimationStateMachineSystem` (`AnimationStateChanged`), and `PhysicsWorld2D` (collision/joint events use callback closures instead).

Remove event handlers during scene exits with `world.removeAllEventHandlers()` to prevent dangling callbacks.

See [ECS — Event Bus](api/ecs.md#event-bus) for the full reference.

## UI System

12 widgets for building menus, HUDs, and in-game overlays. `UIContext` manages the widget tree, input routing (mouse, keyboard, gamepad), focus navigation, and modal dialog state. Widgets are arranged via `UILayout` (vertical, horizontal, or manual positioning) within `UIContainer` and `UIPanel` nodes.

Available widgets: `UILabel`, `UIButton`, `UISlider`, `UIToggle`, `UITextInput`, `UIProgressBar`, `UIImage`, `UIScrollContainer`, `UIDropdown`, `UIListView`, `UIPanel`, `UIModalDialog`. Input configuration (`UIInputConfig`) supports keyboard-only, gamepad-only, or both. `UITheme` controls visual styling.

See [UI API](api/ui.md) for the full reference.

## Serialization

`WorldSerializer` saves and loads ECS world state to JSON. Components conforming to `SerializableComponent` are registered and serialized with entity hierarchy, names, and tags preserved.

## Debug Infrastructure

Three pillars for runtime debugging:

### Structured Logging

`Log` is a static facade that dispatches `LogEntry` messages to registered `LogOutput` destinations. Built-in outputs: `ConsoleLogOutput` (stdout), `FileLogOutput` (file), `RingBufferLogOutput` (circular buffer for on-screen display). The protocol and value types (`LogLevel`, `LogEntry`, `LogOutput`) live in AgilisCore for backend-agnostic use; concrete outputs live in Agilis.

### Debug Overlay

`DebugOverlay` is a unified HUD rendering FPS, frame time graph, entity/component/system stats, per-system timing table, and on-screen log. Connects to `RingBufferLogOutput` for log display. `World` exposes `entityCount`, `componentStoreCount`, `systemCount`, and `systemTimings` (populated with `Clock`-based instrumentation during `update()`).

### Visual Debug Renderers

All follow the pattern `extension RenderBackend { func drawXxxDebug(...) }` with a `Sendable` options struct:

- **Physics** — colliders, contacts, velocities, normals, joints, CCD paths
- **Lighting** — light radii, spotlight cones, shadow caster outlines, buffer overlays
- **Animation** — sprite source rect outlines, clip name/frame/play state labels
- **Tween** — path lines to position targets, progress percentage labels
- **Particle** — emission shape outlines (point/circle/ring/rect), particle count labels
- **TileMap** — tile grid lines (camera-culled), culling viewport rectangle
- **UI** — bounding rectangles and node ID labels for all UI nodes

Viewport snapshots are available via `takeScreenshot(path:)` (file) and `captureScreen()` (in-memory `ImageData`) on `RenderBackend`.

See [Debug API](api/debug.md) for full reference.

## Plugin System

Plugins extend the engine without modifying core code:

```swift
app.install(myPlugin)    // Before app.run()
```

Plugins receive `install(in:)` at registration, `update(deltaTime:)` each tick, and `uninstall()` at shutdown (reverse order).
