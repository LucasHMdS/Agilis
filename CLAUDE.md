# CLAUDE.md

## Project Overview

Agilis is a cross-platform 2D game framework written in Swift 6.0+, targeting Windows, Linux, and macOS. It uses a backend-agnostic architecture with native backends (ANGLE for rendering, MiniAudio for audio, PlatformC for windowing/input). Zero external Swift package dependencies.

## Build & Test

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run all tests (1450+ tests)
swiftlint lint --strict  # Run SwiftLint (enforced in CI on PRs)
swift run UIDemo         # UI widget showcase
swift run Pong           # Classic Pong game
swift run Platformer     # 2D platformer with animation, particles, lighting
swift run TweenShowcase  # Interactive tween/easing demo
swift run PhysicsSandbox # Interactive physics playground
swift run SaveLoadDemo   # World serialization demo
swift run DungeonCrawler # Grid-based dungeon exploration
swift run TopDownShooter # 2D top-down shooter
```

Tests use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.
- Test targets: `AgilisTests` (main framework), `AgilisFormatsTests` (format parsers)
- Examples live in `Examples/` directory (each has `main.swift`)

## CI & Linting

- **CI platforms**: Linux (Ubuntu), macOS (macos-26), Windows — all run `swift build` + `swift test`
- **SwiftLint**: v0.64.0-rc.1, runs on PRs to `main`/`develop`, `--strict` mode
- **SwiftLint config**: `.swiftlint.yml` — disabled rules: `file_length`, `function_body_length`, `large_tuple`, `type_body_length`
- **ANGLE pre-built libs**: Required before first build. Use `scripts/build_angle_macos.sh` (macOS), `scripts/build_angle_linux.sh` (Linux), `scripts/build_angle.bat` (Windows). CI caches these.
- **PR branches**: Target `main` or `develop`

## Project Structure

```
Sources/PlatformC/            Native windowing and input (Win32/Cocoa/X11)
Sources/AngleC/               ANGLE — EGL + OpenGL ES 3.0 (pre-built binaries)
Sources/MiniaudioC/           MiniAudio — cross-platform audio (single-header)
Sources/StbC/                 stb libraries — image loading, font rasterization
Sources/Agilis/               Main framework (depends on all C targets above)
  Application/               Application, GameDelegate
  Core/                      ECS: Entity, Component, System, World, Query,
                               SparseSet, ComponentStorage, CommandBuffer,
                               SystemContext, Prefab, EntityHierarchy, EntityMetadata,
                               Event, ComponentAccess, ComponentRegistry,
                               SystemScheduler
  Animation/                 AnimationSystem, SpriteAnimator, AnimationClip,
                               AnimationFrame, PlaybackMode, AnimationEvent,
                               AnimationStateMachine, AnimationStateMachineSystem,
                               Sprite→Component conformance
  Graphics/                  RenderBackend protocol, Renderer (ANGLE/GLES3),
                               TileMap, TileMapRendering, TextAlignment,
                               SpriteBatch, RenderTargetDrawing, NinePatchSprite,
                               Color, Sprite, Camera2D, BlendMode, TextureHandle,
                               FontHandle, RenderTargetHandle, ShaderHandle,
                               ImageData, Material2D, PostProcessEffect, ShaderUniform
  Materials/                 MaterialLibrary, MaterialTemplate, MaterialShaders,
                               MaterialRendering (MaterialContext),
                               ShaderBuilder, ShaderIncludes,
                               ShaderComposer, ComposableEffects
  PostProcess/               PostProcessPipeline, PostProcessShaders
    Effects/                 BloomEffect, ChromaticAberrationEffect,
                               ColorGradingEffect, VignetteEffect,
                               ScanlinesEffect, PixelateEffect
  Particles/                 ParticleEmitter, ParticleSystem,
                               EmissionShape, ParticleRenderShape
  Lighting/                  LightingSystem, Light2D, ShadowCaster2D,
                               ShadowGeometry, LightingShaders, LightingOptions,
                               LightingDebugRenderer, NormalMapData
  Audio/                     AudioBackend protocol, AudioEngine (MiniAudio),
                               AudioManager (group volumes, fading, crossfading)
  Input/                     InputBackend protocol, NativeInput (PlatformC),
                               InputManager, action mapping (keyboard,
                               mouse, gamepad)
  Assets/                    AssetManager, pluggable loaders
  Math/                      Vector2, Rect, Size, Matrix3, MathUtilities,
                               EasingFunction
  Physics/                   PhysicsWorld2D, NarrowPhase (SAT), SpatialHashGrid,
                               ImpulseResolver, ContactTracker, CollisionFilter,
                               PhysicsDebugRenderer, SpatialQuery, SweptCollision,
                               Joint2D, JointStore, JointSolver,
                               GeometryHelpers, PhysicsConstants
                             Queries: raycast, raycastAll, pointQuery, areaQuery
                             Components: Transform2D, Velocity2D, RigidBody2D, Collider2D
                             Shapes: CollisionShape (AABB, Circle, ConvexPolygon)
                             Joints: Revolute, Distance, Weld, Prismatic, Rope, Motor
                               (JointHandle, JointDefinition)
  Scene/                     Scene protocol, SceneManager (stack-based),
                               SceneTransition (fade, flash, custom)
  UI/                        UIContext, UINode, UIContainer, UILayout, UITheme,
                               UIInputConfig, UILayoutEngine
    Widgets/                 UILabel, UIButton, UIPanel, UISlider, UIToggle,
                               UITextInput, UIProgressBar, UIImage, UIScrollContainer,
                               UIDropdown, UIListView, UIModalDialog
  Serialization/             SerializableComponent protocol, WorldSerializer,
                               BuiltinSerializableComponents
  Tween/                     TweenSystem, TweenHandle, TweenTarget, TweenStep,
                               Interpolatable, TweenStore, TweenTypes,
                               TweenMaterialExtension
  Debug/                     Log, ConsoleLogOutput, FileLogOutput,
                               RingBufferLogOutput, DebugOverlay,
                               AnimationDebugRenderer, TweenDebugRenderer,
                               ParticleDebugRenderer, TileMapDebugRenderer,
                               UIDebugRenderer
  Plugin/                    Plugin protocol
  Time/                      Clock
Sources/AgilisFormats/        Pure Swift parsers (LDtk, Tiled, TexturePacker, Aseprite)
                             Animation bridges: Aseprite→AnimationClip, TextureAtlas→AnimationClip
                             Tilemap bridges: Tiled→TileMap, LDtk→TileMap
```

Users only need `import Agilis` — the module contains all framework types.

## ECS Architecture

The ECS uses **sparse-set storage** with **generational entity IDs**.

### Key design decisions
- **Components** are `protocol Component {}` — structs recommended, classes allowed (no `AnyObject` constraint)
- **Entities** use generational indexing (`index: UInt32` + `generation: UInt32`) for stale reference detection
- **Queries** use `forEach` overloads for 1–8 component types with `inout` access — NOT parameter packs. Also `forEachReadOnly` (1–8) for non-mutable iteration.
- **Systems** receive `SystemContext` (world + deltaTime + commands), with backward-compat bridge to old `update(world:deltaTime:)`
- **Command buffers** defer entity/component mutations during system iteration, flushed after each system
- **System priority** is integer-based (lower runs first, default 0)
- **Component access** — systems declare `componentAccess` (reads/writes/mutatesEntities/emitsEvents) for parallel scheduling. Default is maximally conservative (forces sequential).
- Component storage is in `SparseSet<T>` wrapped by `ComponentStore<T>`, type-erased via `AnyComponentStorage`
- Internal slot helpers (`allEntitySlotCount`, `isSlotAlive`, `entityFromSlot`) live in `World.swift` because they access private `slots`

### Typical system pattern
```swift
final class MovementSystem: System {
    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [], writes: [Position.self, Velocity.self])
    }

    func update(context: SystemContext) {
        context.world.forEach { (e: Entity, pos: inout Position, vel: inout Velocity) in
            pos.x += vel.dx * Float(context.deltaTime)
        }
    }
}
```

## Parallel System Scheduling

Opt-in parallel execution of ECS systems using Swift Concurrency (`async/await` + `TaskGroup`).

### Overview
- **Off by default** — `world.parallelSchedulingEnabled = false`. Zero overhead when disabled.
- **Async game loop** — `Application.runAsync()` enables parallel scheduling. The sync `run()` remains unchanged and always runs sequentially.
- **System.update stays synchronous** — called inside `TaskGroup.addTask`. Systems don't need to become async.
- **Deterministic** — CommandBuffers flushed in priority order after each parallel stage.

### ComponentAccess
Systems declare which component types they read and write via `componentAccess`:

```swift
var componentAccess: ComponentAccess {
    ComponentAccess(
        reads: [Transform2D.self],
        writes: [ParticleEmitter.self],
        mutatesEntities: false,
        emitsEvents: false
    )
}
```

Default (unannotated) systems are maximally conservative (`mutatesEntities: true, emitsEvents: true`), forcing sequential execution. Only systems that explicitly declare their access benefit from parallelism.

### SystemScheduler
Builds an execution plan: array of stages, where each stage contains systems safe to run concurrently. Stages execute sequentially; systems within a stage run in parallel via `TaskGroup`.

Two systems can run in parallel if:
1. Neither declares `mutatesEntities: true`
2. Neither declares `emitsEvents: true`
3. Their write sets don't overlap each other's read or write sets

Uses `ComponentBitset` (256-bit, 4×UInt64) for O(1) conflict detection via `ComponentRegistry`.

### Built-in System Access Declarations

| System (Priority) | Reads | Writes | Entities | Events |
|---|---|---|---|---|
| TweenSystem (25) | — | Transform2D, Sprite | no | yes |
| AnimStateMachine (45) | SpriteAnimator | AnimStateMachine, SpriteAnimator | no | yes |
| AnimationSystem (50) | — | SpriteAnimator, Sprite | no | no |
| PhysicsWorld2D (100) | RigidBody2D, Collider2D | Transform2D, PreviousTransform2D, Velocity2D | no | no |
| ParticleSystem (200) | Transform2D | ParticleEmitter | no | no |
| LightingSystem (300) | Transform2D, Light2D, Collider2D, ShadowCaster2D, Sprite | — | no | no |

ParticleSystem + LightingSystem can run in the same parallel stage (disjoint access).

### Usage
```swift
// Async entry point for parallel scheduling
public func runAsync() async throws  // on Application

// Enable parallel scheduling
world.parallelSchedulingEnabled = true

// Run the async game loop
try await app.runAsync()
```

### Thread Safety
- Scheduler guarantees systems in the same stage access disjoint `ComponentStore<T>` instances
- Each system gets its own `CommandBuffer` — no contention
- `@unchecked Sendable` wrappers (`UnsafeSystemRef`, `UnsafeBufferRef`) bridge non-Sendable types across TaskGroup boundaries
- GPU calls (OpenGL ES via ANGLE) remain on the main thread (rendering is never parallelized)

## Physics & Collision

Built-in 2D physics with impulse-based collision response.

### Components
- **`Transform2D`** — position (Vector2) + rotation (Float) + scale (Vector2). Standard position component.
- **`PreviousTransform2D`** — snapshot of previous frame for interpolated rendering. Auto-updated by PhysicsWorld2D.
- **`Velocity2D`** — linear (Vector2) + angular (Float). Integrated by PhysicsWorld2D each tick.
- **`RigidBody2D`** — mass, inertia (moment of inertia), restitution, friction, gravityScale, linearDamping, bodyType (dynamic/static/kinematic). `computeInertia(mass:shape:)` static helper for circle/AABB/polygon.
- **`Collider2D`** — shape (CollisionShape), offset, isTrigger, layer/mask bitmasks

### Collision shapes
- `.aabb(halfExtents:)` — axis-aligned bounding box (half-width, half-height)
- `.circle(radius:)` — circle
- `.polygon(ConvexPolygon)` — convex polygon with precomputed normals (SAT). Vertices must be CCW in math coords.

### Pipeline (PhysicsWorld2D.update)
1. Store PreviousTransform2D
2. Apply gravity + damping to dynamic bodies
3. Integrate velocity → position
4. CCD sweep — clamp fast-moving `useCCD` bodies to earliest time of impact (angular sweep + bilateral)
5. Broad phase: spatial hash grid
6. Narrow phase: SAT for all 6 shape pairs
7. Impulse resolution + penetration correction
8. Joint constraint solving (pre-solve, warm start, velocity iterations, position iterations, break detection)
9. Collision events (began/ongoing/ended)
10. Joint events (broken joints, callbacks)

### Collision layers
Layer/mask bitmasks: `(a.layer & b.mask) != 0 && (b.layer & a.mask) != 0`

### Usage
```swift
let physics = PhysicsWorld2D(gravity: Vector2(x: 0, y: 980))
world.addSystem(physics)

physics.onCollisionBegan = { event in ... }
```

## Physics Joints & Constraints

Constrain pairs of entities with physics joints. Uses a sequential impulse solver (Projected Gauss-Seidel) with warm starting and Baumgarte position stabilization.

### Joint Types
- **Revolute (pin/hinge)** — `RevoluteJointDef`: shared anchor, optional angle limits (`enableLimit`, `lowerAngle`, `upperAngle`), optional motor (`enableMotor`, `motorSpeed`, `maxMotorTorque`). 2-DOF positional constraint + 1-DOF angular.
- **Distance (spring)** — `DistanceJointDef`: two anchors, rest `length` (0 = auto-compute), optional spring (`frequencyHz`, `dampingRatio`). 1-DOF scalar constraint along axis.
- **Weld (fixed)** — `WeldJointDef`: locks relative position and angle, optional soft weld (`frequencyHz`, `dampingRatio`). 3-DOF constraint (2 positional + 1 angular).
- **Prismatic (slider)** — `PrismaticJointDef`: shared anchor + world-space `axis`. Constrains bodies to slide along axis, locks rotation. Optional translation limits (`enableLimit`, `lowerTranslation`, `upperTranslation`), optional motor (`enableMotor`, `motorSpeed`, `maxMotorForce`). 1-DOF perpendicular + 1-DOF angular + optional 1-DOF limit + optional 1-DOF motor.
- **Rope (max distance)** — `RopeJointDef`: two anchors, `maxLength` (0 = auto-compute from initial distance). Only pulls when stretched — goes slack when closer (tension-only, never pushes). 1-DOF scalar constraint (conditional).
- **Motor (driven offset)** — `MotorJointDef`: drives body B toward `linearOffset` (in A's local frame) and `angularOffset` relative to A. `correctionFactor` (0–1) controls stiffness. `maxForce`/`maxTorque` limit motor output (NOT breaking thresholds). 3-DOF soft constraint (2 linear + 1 angular).

### Breaking Joints
All joint types except motor support `maxForce` and/or `maxTorque` (0 = unbreakable). When exceeded, the joint is destroyed and a `JointEvent` fires. Motor joints do not break — their `maxForce`/`maxTorque` limit motor output power.

### Key Types
- **`JointHandle`** — opaque UInt32 handle (same pattern as TextureHandle). `.invalid` = id 0.
- **`JointDefinition`** — enum: `.revolute(RevoluteJointDef)`, `.distance(DistanceJointDef)`, `.weld(WeldJointDef)`, `.prismatic(PrismaticJointDef)`, `.rope(RopeJointDef)`, `.motor(MotorJointDef)`
- **`JointEvent`** — handle, entityA, entityB, type (`.broken`)
- **`JointSolver`** — stateless enum with static methods (same pattern as ImpulseResolver)
- **`JointStore`** — internal lifecycle management with deterministic iteration via sorted keys

### PhysicsWorld2D Joint API
```swift
func createJoint(_ definition: JointDefinition, in world: World) -> JointHandle
func destroyJoint(_ handle: JointHandle)
var jointCount: Int
func removeAllJoints()
func debugJointInfo(world: World) -> [JointDebugInfo]
var velocityIterations: Int  // default 6
var positionIterations: Int  // default 2
var onJointBroken: ((JointEvent) -> Void)?
```

### Usage
```swift
// Revolute joint (door hinge)
let hinge = physics.createJoint(.revolute(RevoluteJointDef(
    entityA: wall, entityB: door,
    anchor: Vector2(x: 100, y: 200)
)), in: world)

// Distance joint (spring/bungee)
let spring = physics.createJoint(.distance(DistanceJointDef(
    entityA: anchor, entityB: player,
    anchorA: Vector2(x: 200, y: 0),
    anchorB: Vector2(x: 200, y: 100),
    frequencyHz: 2.0, dampingRatio: 0.5
)), in: world)

// Weld joint (composite object)
let weld = physics.createJoint(.weld(WeldJointDef(
    entityA: body, entityB: turret,
    anchor: Vector2(x: 150, y: 150)
)), in: world)

// Prismatic joint (elevator/sliding door)
let slider = physics.createJoint(.prismatic(PrismaticJointDef(
    entityA: rail, entityB: platform,
    anchor: Vector2(x: 200, y: 100),
    axis: Vector2(x: 0, y: 1),  // vertical axis
    enableLimit: true,
    lowerTranslation: 0, upperTranslation: 200,
    enableMotor: true, motorSpeed: 50, maxMotorForce: 500
)), in: world)

// Rope joint (tether/chain)
let rope = physics.createJoint(.rope(RopeJointDef(
    entityA: anchor, entityB: ball,
    anchorA: Vector2(x: 200, y: 100),
    anchorB: Vector2(x: 200, y: 300),
    maxLength: 250
)), in: world)

// Motor joint (smooth pursuit/moving platform)
let motor = physics.createJoint(.motor(MotorJointDef(
    entityA: reference, entityB: follower,
    linearOffset: Vector2(x: 50, y: 0),
    correctionFactor: 0.3,
    maxForce: 500, maxTorque: 200
)), in: world)

// Breaking joint callback
physics.onJointBroken = { event in
    print("Joint \(event.handle.id) broke!")
}

// Debug rendering
app.renderer.drawJointsDebug(physics: physics, world: world)
```

## Continuous Collision Detection (CCD)

Opt-in swept shape testing that prevents fast-moving bodies from tunneling through thin colliders.

### Enabling CCD
Set `useCCD: true` on `RigidBody2D`. Only applies to dynamic bodies.

### SweptCollision
`Sources/Agilis/Physics/SweptCollision.swift` — stateless `enum SweptCollision` (same pattern as `NarrowPhase`, `SpatialQuery`).

- **`timeOfImpact(movingShape:startPos:endPos:movingRot:staticShape:staticPos:staticRot:)`** → `Float?` — TOI in [0,1] or nil (single-rotation, exact for circle/AABB pairs)
- **`timeOfImpact(movingShape:startPos:endPos:startRot:endRot:staticShape:staticPos:staticRot:)`** → `Float?` — angular sweep overload; uses bounding circle for non-circle shapes with angular displacement, delegates to exact path when angular displacement is zero or shape is circle
- **`angularSweepExtent(of:angularDisplacement:)`** → `Float` — max arc distance from rotation (0 for circles, `boundingRadius * |angle|` for AABB/polygon)
- **`minimumExtent(of:)`** → `Float` — smallest dimension of a shape (early-out threshold)
- **`boundingRadius(of:)`** → `Float` — center-to-farthest-point (polygon fallback radius)

### Shape Pair Support
- Circle/AABB pairs: exact Minkowski-based algorithms
- Polygon-involving pairs: conservative bounding circle fallback (may clamp slightly early, guarantees no tunneling)
- Angular sweep (non-circle with rotation): conservative bounding circle regardless of static shape type

### Pipeline Integration
Step 4 in `PhysicsWorld2D.update` — runs after velocity integration, before broad phase. Collects CCD bodies whose translational displacement OR angular sweep extent exceeds the shape's minimum extent. Sweeps each CCD body against all collidable entities (brute force + AABB pre-filter). For bilateral CCD, builds a `ccdBodyLookup` dictionary for O(1) candidate detection; when candidate B is also a CCD body, sweeps A in B's reference frame using relative velocity (A sweeps toward `endPos - B_displacement` against B at its previous position). Clamps position and rotation to earliest TOI.

### Key Behaviors
- Triggers skipped — CCD does not block passage through trigger zones
- Layer/mask respected — same bidirectional `shouldCollide` check as discrete collision
- Early-out — both translational displacement < `minimumExtent(of: shape)` AND angular extent < same threshold required to skip sweep
- Angular sweep — rotating non-circle shapes use conservative bounding circle; rotation clamped alongside position
- Bilateral CCD — two CCD-enabled dynamic bodies use relative velocity to prevent mutual tunneling
- Collision events fire — narrow phase detects contact at clamped position

### Debug Rendering
`PhysicsDebugRendererOptions.drawCCDPaths` (default `false`) — draws sweep paths for CCD bodies. Paths are drawn when translational displacement > 0.01 OR angular displacement > 0.01.

### Usage
```swift
// Fast-moving bullet with CCD
world.addComponent(RigidBody2D(
    mass: 0.1, gravityScale: 0, bodyType: .dynamic, useCCD: true
), to: bullet)
world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

// Spinning rod with CCD (angular sweep prevents rotational tunneling)
world.addComponent(RigidBody2D(mass: 1, gravityScale: 0, bodyType: .dynamic, useCCD: true), to: rod)
world.addComponent(Velocity2D(linear: Vector2(x: 500, y: 0), angular: 30), to: rod)
world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 2))), to: rod)
```

## Animation System

Sprite animation driven by the ECS. Animates `Sprite.sourceRect` to select frames from a sprite sheet.

### Data Types
- **`PlaybackMode`** — `.forward`, `.reverse`, `.pingPong` (no double endpoints), `.oneShot` (plays once, stops on last frame)
- **`AnimationFrame`** — sourceRect (Rect) + duration (Float, seconds)
- **`AnimationClip`** — name + frames array + playback mode. Reusable, value type (copy-on-write arrays).
  - `AnimationClip.fromSpriteSheet(...)` — factory for uniform grid sprite sheets
  - `AnimationClip.fromAseprite(...)` — creates clips from Aseprite frame tags (ms→s, direction mapping)
  - `AnimationClip.fromTextureAtlas(...)` — creates clips by prefix matching TexturePacker frames

### Components
- **`SpriteAnimator`** — per-entity playback state: clip, currentFrameIndex, frameTime, isPlaying, speed, lastEvent
  - `setClip(_:)` — switch clips, no-op if same name (safe in per-frame game logic)
  - `forceSetClip(_:)` — always resets, even with same name
- **`Sprite`** — retroactive `Component` conformance added in `SpriteComponentConformance.swift`

### System
- **`AnimationSystem`** (priority 50) — iterates `(SpriteAnimator, Sprite)` pairs, advances time, writes `sprite.sourceRect`
  - `onAnimationEvent` callback for looped/completed events
  - `lastEvent` on SpriteAnimator is set on event tick, cleared next tick

### Usage
```swift
let animSystem = AnimationSystem()
world.addSystem(animSystem)

let entity = world.createEntity()
world.addComponent(Sprite(texture: spriteSheet), to: entity)
world.addComponent(SpriteAnimator(clip: walkClip), to: entity)
```

## Animation State Machine

Declarative state machine for managing animation clip transitions. Sits on top of the existing `AnimationSystem` — manages *which clip* is on `SpriteAnimator`, while `AnimationSystem` continues frame advancement.

### Core Types
- **`AnimationStateMachine`** — Component storing states, transitions, parameters, and current state
- **`AnimationState`** — Named state mapping to an `AnimationClip` with optional speed override
- **`AnimationTransition`** — Transition from one state to another with conditions and optional exit time
- **`TransitionCondition`** — Condition enum: `.boolEquals`, `.floatGreater`, `.floatLess`, `.intEquals`, `.trigger`, `.animationFinished`, `.animationLooped`, `.afterTime`
- **`ParameterValue`** — Parameter storage: `.bool`, `.float`, `.int`, `.trigger`
- **`AnimationStateChanged`** — Event emitted on state transitions

### AnimationStateMachineSystem (Priority 45)
Runs before `AnimationSystem` (50). Each tick: advance `timeInState`, check any-state transitions first (skip self), then per-state transitions (allow self). Two-pass condition evaluation for trigger safety (triggers only consumed when ALL conditions pass). Uses `forceSetClip` for transitions.

### Usage
```swift
let smSystem = AnimationStateMachineSystem()
let animSystem = AnimationSystem()
world.addSystem(smSystem)    // priority 45
world.addSystem(animSystem)  // priority 50

var sm = AnimationStateMachine(defaultState: "idle")
sm.addState("idle", clip: idleClip)
sm.addState("walk", clip: walkClip)
sm.addState("run", clip: runClip)
sm.addState("attack", clip: attackClip)
sm.addState("death", clip: deathClip)

sm.addTransition(from: "idle", to: "walk",
    conditions: [.floatGreater("speed", 0.1)])
sm.addTransition(from: "walk", to: "idle",
    conditions: [.floatLess("speed", 0.1)])
sm.addTransition(from: "walk", to: "run",
    conditions: [.floatGreater("speed", 5.0)])
sm.addTransition(from: "idle", to: "attack",
    conditions: [.trigger("attack")])
sm.addTransition(from: "attack", to: "idle",
    conditions: [.animationFinished])
sm.addAnyStateTransition(to: "death",
    conditions: [.boolEquals("isDead", true)])

world.addComponent(sm, to: entity)

// Game logic — just set parameters
world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
    sm.setFloat("speed", velocity.length)
    sm.setBool("isGrounded", onGround)
    if attackPressed { sm.setTrigger("attack") }
}

// React to state changes
world.on(AnimationStateChanged.self) { event in
    if event.to == "death" { spawnDeathParticles(at: event.entity) }
}
```

## Tweening / Interpolation

Animate arbitrary component properties over time using easing functions. Centralized storage (like JointStore) — tweens are NOT ECS components.

### Core Types
- **`TweenHandle`** — opaque UInt32 handle (same pattern as JointHandle). `.invalid` = id 0.
- **`TweenTarget`** — enum: `.position`, `.rotation`, `.scale`, `.spriteColor`, `.spriteAlpha`, `.custom(apply:)`
- **`TweenStep`** — enum for sequence steps: `.moveTo`, `.rotateTo`, `.scaleTo`, `.tintTo`, `.fadeTo`, `.fadeOut`, `.fadeIn`, `.wait`, `.callback`, `.custom`
- **`Interpolatable`** — protocol for types supporting `interpolated(to:t:)`. Built-in: `Float`, `Vector2`, `Color`.
- **`TweenCompleted`** — event emitted on world when a tween finishes

### TweenSystem (Priority 25)
Runs between gameplay systems (0) and animation (50). Update loop: advance elapsed time, apply easing, write interpolated values via `world.updateComponent`, handle delay/repeat/yoyo, auto-cancel on entity death.

### TweenSystem API
```swift
// Creation (all @discardableResult, return TweenHandle)
func moveTo(_:target:duration:easing:delay:in:) -> TweenHandle
func moveFromTo(_:from:to:duration:easing:delay:) -> TweenHandle
func rotateTo(_:target:duration:easing:delay:in:) -> TweenHandle
func scaleTo(_:target:duration:easing:delay:in:) -> TweenHandle
func scaleUniformTo(_:target:duration:easing:delay:in:) -> TweenHandle
func tintTo(_:target:duration:easing:delay:in:) -> TweenHandle
func fadeTo(_:alpha:duration:easing:delay:in:) -> TweenHandle
func fadeOut(_:duration:easing:delay:in:) -> TweenHandle
func fadeIn(_:duration:easing:delay:in:) -> TweenHandle
func custom(_:duration:easing:delay:apply:) -> TweenHandle

// Modifiers (fluent, @discardableResult)
func setRepeat(_:count:) -> TweenHandle   // -1 = infinite
func setYoyo(_:enabled:) -> TweenHandle
func onStart(_:_:) -> TweenHandle
func onUpdate(_:_:) -> TweenHandle
func onComplete(_:_:) -> TweenHandle

// Sequences
func sequence(_:steps:repeatCount:in:) -> TweenHandle
func onSequenceComplete(_:_:) -> TweenHandle

// Lifecycle
func cancel(_:)
func cancelAll(on:)
func pause(_:) / resume(_:)
func pauseAll(on:) / resumeAll(on:)
var tweenCount: Int
func isActive(_:) -> Bool
func removeAll()

// Callback
var onTweenCompleted: ((TweenHandle, Entity) -> Void)?
```

### Usage
```swift
let tweens = TweenSystem()
world.addSystem(tweens)

// Move with ease-out
tweens.moveTo(player, target: Vector2(x: 300, y: 200),
              duration: 0.5, easing: .cubicOut, in: world)

// Pulsing scale (yoyo + infinite repeat)
let pulse = tweens.scaleTo(icon, target: Vector2(x: 1.2, y: 1.2),
                           duration: 0.3, easing: .sineInOut, in: world)
tweens.setYoyo(pulse)
tweens.setRepeat(pulse, count: -1)

// Sequence
tweens.sequence(player, steps: [
    .moveTo(target: Vector2(x: 300, y: 200), duration: 0.3, easing: .cubicOut),
    .wait(duration: 0.1),
    .fadeOut(duration: 0.2, easing: .quadIn),
    .callback { print("Player vanished!") }
], in: world)

// Completion callback
let h = tweens.moveTo(bullet, target: impactPoint,
                      duration: 0.2, easing: .linear, in: world)
tweens.onComplete(h) { spawnExplosion(at: impactPoint) }

// Custom tween (user-defined component)
tweens.custom(entity, duration: 1.0, easing: .linear) { world, entity, t in
    world.updateComponent(Health.self, on: entity) { h in
        h.current = lerp(startHP, 100, t: t)
    }
}
```

## Gamepad Input

Supports up to 4 gamepads. Follows the same 3-layer architecture as keyboard/mouse input.

### Architecture
1. **Agilis enums** — `GamepadButton` (18 buttons), `GamepadAxis` (6 axes), `GamepadStick` (.left/.right)
2. **InputBackend protocol** — 4 gamepad methods with default no-op implementations (backward compatible)
3. **InputManager** — polls button state per-frame, tracks press/release transitions, applies dead zones to axes

### Button State (per gamepad, same pattern as keyboard)
- `isGamepadButtonDown(_:_:)` — held this frame
- `isGamepadButtonPressed(_:_:)` — first pressed this frame
- `isGamepadButtonReleased(_:_:)` — released this frame

### Axes & Sticks
- `gamepadAxis(_:_:)` — single axis with dead zone applied (default 0.1, configurable via `gamepadDeadZone`)
- `gamepadStick(_:_:)` — returns Vector2 for left/right stick with per-axis dead zone

### Action Mapping Integration
```swift
app.input.registerAction("jump", keys: [.space], gamepadButtons: [.faceDown])
if app.input.isActionJustActivated("jump") { ... } // checks keyboard + gamepad 0
```

Actions check gamepad 0 (player 1) for all action queries. Gamepad buttons use OR logic with keys and mouse buttons.

## Audio

Two-layer architecture: `AudioBackend` protocol for platform abstraction, `AudioManager` for high-level features.

### AudioBackend Protocol
- Sound effects (in-memory): `loadSound`, `playSound`, `stopSound`, `unloadSound`
- Music (streaming): `loadMusic`, `playMusic`, `pauseMusic`, `resumeMusic`, `stopMusic`, `updateMusicStream`, `unloadMusic`
- Queries: `isSoundPlaying(_:)`, `isMusicPlaying(_:)` — with default `false` implementations
- Volume: `setSoundVolume(_:volume:)`, `setMusicVolume(_:volume:)`, `setMasterVolume(_:)` — setters with default no-ops

### AudioManager
Wraps `AudioBackend` with group volumes, fading, and crossfading. Automatically updated each frame by `Application`.

- **Audio groups** — `.music`, `.sfx`, `.ui` with independent volume multipliers
  - `setGroupVolume(_:volume:)` / `groupVolume(for:)` — effective volume = base × group
  - Changing group volume retroactively updates all playing sounds in that group
- **Sound effects** — `playSound(_:volume:pitch:group:)`, `playUISound(_:volume:)`
- **Music** — single-track with optional fade
  - `playMusic(_:volume:looping:fadeDuration:)` — instant or fade-in
  - `fadeOutMusic(duration:)` — fade out and stop
  - `crossfadeToMusic(_:volume:looping:duration:)` — simultaneous fade out old + fade in new
- **`update(deltaTime:)`** — advances fades, updates music streams, cleans up finished sounds

### Usage
```swift
app.audioManager.setGroupVolume(.sfx, volume: 0.5)
app.audioManager.playSound(explosionHandle, group: .sfx)
app.audioManager.playMusic(bgmHandle, fadeDuration: 2.0)
app.audioManager.crossfadeToMusic(bossMusic, duration: 1.5)
```

## Scene Transitions

Animated transitions between scenes. The `SceneManager` supports both instant scene changes and fade transitions.

### SceneTransition
- **`SceneTransition`** — struct describing a transition effect: duration, color, easing, midpoint callback
- **Factories**: `.fade(duration:color:easing:onMidpoint:)`, `.flash(duration:easing:)`, `.instant`
- Duration is split: first half = fade out (old scene), second half = fade in (new scene)
- Scene swap (`willExit`/`didEnter`) happens at the midpoint when screen is fully covered
- `onMidpoint` callback fires at midpoint — use for asset loading while screen is covered

### SceneManager Transition API
- `replace(with:transition:app:)` — replace with fade
- `push(_:transition:app:)` — push with fade
- `pop(transition:app:)` — pop with fade
- `replaceAll(with:transition:app:)` — replace all with fade
- `isTransitioning` — whether a transition is active
- Original instant methods (`push`, `pop`, `replace`, `replaceAll`) remain unchanged

### Usage
```swift
// Fade to black and back (default)
app.sceneManager.replace(with: GameScene(), transition: .fade(), app: app)

// Custom fade with loading callback
app.sceneManager.replace(
    with: Level2Scene(),
    transition: .fade(duration: 1.0, color: .black, easing: .cubicInOut) {
        // Loading work here — screen is fully black
    },
    app: app
)

// White flash
app.sceneManager.replace(with: BossScene(), transition: .flash(), app: app)
```

## Physics Debug Rendering

Visualize colliders, contacts, velocities, surface normals, and joints for physics debugging.

### RenderBackend Extension
- **`drawPhysicsDebug(world:events:options:)`** — draws all debug overlays in one call
- **`drawJointsDebug(physics:world:options:)`** — draws joint connections and anchor points
- Call at the end of `render()` so overlays appear on top

### PhysicsDebugRendererOptions
- **Toggles**: `drawColliders` (default true), `drawContacts` (default true), `drawVelocities` (false), `drawNormals` (false), `drawJoints` (default true), `drawCCDPaths` (false)
- **Body type colors**: dynamic = cyan, kinematic = yellow, static = gray, trigger = green
- **Contact/velocity colors**: contacts = red, velocities = magenta, normals = orange
- **Joint colors**: `jointColor` = light blue, `jointAnchorColor` = gold, `jointAnchorRadius` = 4.0
- **Thicknesses**: `colliderThickness`, `normalLength`, `velocityScale`, `contactPointRadius`

### Shape Drawing
- **AABB (no rotation)**: `drawRectOutline`
- **AABB (rotated)**: 4 transformed corner lines
- **Circle**: `drawCircleOutline`
- **Polygon**: transform vertices to world space, draw line loop
- Vertex transformation matches NarrowPhase formula: `x' = x*cos(r) - y*sin(r) + pos.x`

### Usage
```swift
// Basic debug draw — colliders + contacts
app.renderer.drawPhysicsDebug(world: app.world, events: physics.lastEvents)

// Custom options
var options = PhysicsDebugRendererOptions()
options.drawVelocities = true
options.drawNormals = true
app.renderer.drawPhysicsDebug(world: app.world, events: physics.lastEvents, options: options)
```

## Ray Casting & Spatial Queries

Query the physics world for intersections without running the full collision pipeline.

### PhysicsWorld2D Query API
- **`raycast(world:origin:direction:maxDistance:layerMask:)`** → `RaycastHit?` — closest hit along a ray
- **`raycastAll(world:origin:direction:maxDistance:layerMask:)`** → `[RaycastHit]` — all hits, sorted by distance
- **`pointQuery(world:point:layerMask:)`** → `[PointQueryResult]` — all entities containing a point
- **`areaQuery(world:rect:layerMask:)`** → `[AreaQueryResult]` — all entities overlapping a rectangle

### Result Types
- **`RaycastHit`** — entity, point (world-space), normal (outward), distance
- **`PointQueryResult`** — entity
- **`AreaQueryResult`** — entity

### SpatialQuery (Geometry Layer)
Pure geometry functions (analogous to NarrowPhase). All winding-direction agnostic:
- **Ray intersection**: `rayVsAABB` (slab method), `rayVsCircle` (quadratic), `rayVsPolygon` (edge-segment intersection)
- **Point tests**: `pointInAABB`, `pointInCircle`, `pointInPolygon` (cross-product winding test)
- **Area overlap**: `rectOverlapsAABB`, `rectOverlapsCircle`, `rectOverlapsPolygon` (SAT)
- **Unified dispatchers**: `raycast(shape:)`, `pointTest(shape:)`, `areaTest(shape:)` — handle rotation (AABB→polygon promotion)

### Layer Mask Filtering
Single mask check: `collider.layer & layerMask != 0`. No bidirectional check (queries aren't entities).

### Usage
```swift
// Line-of-sight check
if let hit = physics.raycast(world: world, origin: gunTip,
                              direction: aimDir, maxDistance: 500) {
    print("Hit \(hit.entity) at \(hit.point)")
}

// Mouse picking
let picks = physics.pointQuery(world: world, point: mouseWorldPos)

// Explosion radius
let affected = physics.areaQuery(world: world,
    rect: Rect(x: cx-50, y: cy-50, width: 100, height: 100))
```

## Time Scaling

Control game speed with a single property. Affects all fixed-timestep systems.

### Application.timeScale
- **`timeScale: Double`** — multiplier for game time (default `1.0`)
  - `0` — paused (rendering continues, audio stays real-time)
  - `0.5` — slow motion (half speed)
  - `1.0` — normal speed
  - `2.0+` — fast forward
- Negative values clamped to 0
- Affects: physics, animation, particles, lighting, scene transitions, plugins
- Does **not** affect: audio fading/music, input polling, rendering

### How It Works
Applied to the fixed-timestep accumulator: `accumulator += frameTime * max(timeScale, 0)`. When timeScale is 0, no fixed-timestep ticks run, but the render loop continues. All downstream systems automatically scale because they only execute during ticks.

### Usage
```swift
// Slow-motion bullet time
app.timeScale = 0.25

// Pause game (render still runs for pause menu overlay)
app.timeScale = 0

// Fast-forward for debugging
app.timeScale = 4.0

// Resume normal speed
app.timeScale = 1.0
```

## Entity Serialization

Save and load ECS world state to JSON. Registry-based type system for component serialization.

### SerializableComponent Protocol
- **`SerializableComponent`** — extends `Component` + `Codable` with a `static var componentName: String`
- Built-in conformances: Transform2D, PreviousTransform2D, Velocity2D, RigidBody2D, Collider2D, Sprite, SpriteAnimator, ParticleEmitter, Light2D, ShadowCaster2D
- Users can conform their own components to `SerializableComponent`

### WorldSerializer
- **`register(_:)`** — register a component type for serialization
- **`registerDefaults()`** — registers all 10 built-in component types
- **`encode(world:)`** → `Data` — serializes all entities, components, hierarchy, names, tags to JSON
- **`decode(from:into:)`** → `[UInt32: Entity]` — deserializes JSON into a world, returns old-index → new-entity remap table

### Serialization Details
- Entity indices are remapped on decode (old slots → fresh entities)
- Hierarchy (parent/child) restored via remap table
- Metadata (names, tags) preserved
- **ConvexPolygon** serializes vertices only; normals and bounds recompute on decode
- **RigidBody2D** skips `inverseMass` (recomputed from mass + bodyType on decode)
- **ParticleEmitter** serializes config only; internal particle pool state is not preserved
- **SpriteAnimator** skips `lastEvent` (transient, cleared each tick)
- **TextureHandle / SoundHandle** serialize as raw UInt32 IDs (GPU handles invalid after reload)
- Systems are **not** serialized — re-add them after loading

### Usage
```swift
let serializer = WorldSerializer()
serializer.registerDefaults()
serializer.register(Health.self)  // custom component

// Save
let data = try serializer.encode(world: world)

// Load
let newWorld = World()
let remap = try serializer.decode(from: data, into: newWorld)
// remap[oldIndex] → newEntity
```

## Event Bus

Lightweight pub/sub event system on `World` for decoupled game logic. Separate from component lifecycle events (`onComponentAdded`/`onComponentRemoved`).

### Event Protocol
- **`Event`** — marker protocol (like `Component`). Structs recommended.

### World API
- **`on(_:handler:)`** — subscribe to an event type, returns handler index (discardable)
- **`emit(_:)`** — synchronous dispatch to all registered handlers
- **`removeHandlers(for:)`** — remove all handlers for a specific event type
- **`removeAllEventHandlers()`** — clear all event handlers

### Design
- **Synchronous** — consistent with all existing event patterns (physics, animation, lifecycle)
- **Type-keyed** — `[ObjectIdentifier: [(Any) -> Void]]`, same erasure pattern as component storage
- **Re-entrant safe** — `emit()` iterates a value-type snapshot; emitting from a handler works. Handlers added during emission don't fire for the current emit.
- No `Sendable` constraint on `Event` — framework is single-threaded

### Usage
```swift
struct PlayerDied: Event {
    let entity: Entity
    let killedBy: Entity?
}

world.on(PlayerDied.self) { event in
    print("Player \(event.entity.index) died!")
}

world.emit(PlayerDied(entity: player, killedBy: enemy))
```

## Tilemap Rendering

Camera-culled tilemap drawing with SpriteBatch integration and format bridges.

### RenderBackend Extension
- **`drawTileMap(_:position:camera:tint:)`** — draw all visible layers, camera-culled
- **`drawTileLayer(_:tilesets:tileWidth:tileHeight:position:camera:tint:)`** — draw a single layer
- **`batchTileMap(_:into:position:camera:tint:baseLayer:)`** — add tiles to SpriteBatch
- **`batchTileLayer(_:tilesets:tileWidth:tileHeight:into:position:camera:tint:batchLayer:)`** — batch a single layer

### Culling
- Viewport computed from `Camera2D` (target, offset, zoom) or full screen
- Only tiles overlapping the viewport are iterated
- Layer opacity applied to tint alpha, invisible layers skipped, empty tiles (id=0) skipped

### Format Bridges (AgilisFormats)
- **`TileMap.fromTiled(_:textures:)`** — convert parsed Tiled JSON to TileMap. Decodes GID flip bits (bit 31=flipX, bit 30=flipY). Only tilelayer type converted.
- **`TileMap.fromLDtk(level:project:textures:)`** — convert LDtk level to TileMap. Pixel-to-grid conversion, flip flag decoding (f=0/1/2/3), layer order reversed (bottom-first). Tile IDs offset by +1 (LDtk `t` + 1) so 0 = empty.

### Usage
```swift
// Direct drawing
app.renderer.drawTileMap(tileMap, position: .zero, camera: camera)

// Batched drawing
let batch = SpriteBatch(sortMode: .byLayer)
app.renderer.batchTileMap(tileMap, into: batch, camera: camera)
batch.flush(to: app.renderer)

// From Tiled
let tiled = try TiledLoader().load(from: jsonData)
let tileMap = TileMap.fromTiled(tiled, textures: ["tileset.png": texHandle])

// From LDtk
let project = try LDtkLoader().load(from: jsonData)
let tileMap = TileMap.fromLDtk(level: project.levels[0], project: project, textures: textures)
```

## Sprite Batching

Opt-in draw call optimization. Collects sprites, sorts by blend mode then texture, flushes efficiently.

### SpriteBatch
- **`SpriteBatch(sortMode:)`** — collects sprites via `add()`, draws them on `flush(to:)`
- **Sort modes**: `.byTexture` (default, groups by blend mode then texture), `.byLayer` (layer → blend mode → texture), `.none` (insertion order)
- **Stats**: `lastDrawCallCount` (state change groups), `lastSpriteCount` (total sprites)
- Layer is per-call (`add(sprite, layer: 0)`) — not stored on Sprite

### RenderBackend
- **`drawSprites(_ sprites: [Sprite])`** — batch draw method with default fallback to `drawSprite` loop
- Renderer overrides with cached texture lookups and blend mode state tracking for sorted sprite arrays

### Usage
```swift
let batch = SpriteBatch()
for entity in entities {
    batch.add(sprite)
}
batch.flush(to: app.renderer)
// batch.lastDrawCallCount tells you how many state change groups were drawn
```

## Blend Modes

Per-sprite and scoped blend mode control for rendering effects.

### BlendMode Enum
- **`.alpha`** — standard alpha blending (default)
- **`.additive`** — adds source to destination (glow, fire, light effects)
- **`.multiplied`** — multiplies source with destination (shadows, tinting)
- **`.premultiplied`** — premultiplied alpha blending

### Per-Sprite Blend Mode
Each `Sprite` has a `blendMode` property (default `.alpha`). The renderer automatically sets/restores the GPU blend state around each sprite draw. `SpriteBatch` sorts by blend mode to minimize state changes.

```swift
var glowSprite = Sprite(texture: glowTex, blendMode: .additive)
renderer.drawSprite(glowSprite)
```

### Scoped Blend Mode
For shapes and text, use `beginBlendMode`/`endBlendMode` on `RenderBackend`:

```swift
renderer.beginBlendMode(.additive)
renderer.drawCircle(center: pos, radius: 20, color: .yellow)
renderer.endBlendMode()
```

Both methods have default no-op implementations for backward compatibility.

## Material System

Per-sprite shader materials with typed uniforms, built-in effects, shader composition, and GLSL include libraries.

### Core Types

- **`UniformValue`** — enum: `.float`, `.vec2`, `.vec3`, `.vec4`, `.int`, `.color` (auto-converts 0-255→0.0-1.0), `.texture`
- **`Material2D`** — struct: `shader` (ShaderHandle) + `uniforms` ([String: UniformValue]) + optional `blendMode` override. `sortKey` returns `shader.id` for batching.
- **`MaterialContext`** — standard uniforms auto-injected: `_time` (Float), `_resolution` (Vector2), `_deltaTime` (Float)

### MaterialLibrary

Factory class for built-in material effects with shader lifecycle management.

- **`initialize(renderer:)`** — pre-load all 6 built-in shaders
- **`shutdown()`** — destroy all cached shaders
- **`context: MaterialContext`** — update each frame for standard uniform injection

### Built-in Effects (6)
```swift
library.flash(color: .white, amount: 1.0)          // Hit blink / selection highlight
library.grayscale(amount: 1.0)                      // Desaturation (disabled state, death)
library.dissolve(threshold: 0.5, edgeWidth: 0.05, edgeColor: .white)  // Disintegration
library.outline(color: .white, width: 1.0, textureSize: size)         // Sprite border
library.colorReplace(target: .red, replacement: .blue, tolerance: 0.1) // Palette swap
library.wave(time: t, amplitude: 0.01, frequency: 10, speed: 3)       // Underwater/heat
```

### MaterialTemplate

Reusable material definition with defaults. Shared shader handle (no duplication).
```swift
let template = library.template(for: .dissolve)
var mat = template.instance(overrides: ["threshold": .float(0.3)])
```

### ShaderBuilder

Boilerplate-free GLSL 330 fragment shader generation:
```swift
let source = ShaderBuilder.createFragment(
    uniforms: ["amount": "float"],
    includes: [.noise],
    body: """
    vec4 color = sampleTexture(fragTexCoord);
    color.rgb += noise2D(fragTexCoord * 20.0) * amount;
    finalColor = color;
    """
)
```
Also `createPostProcess(uniforms:includes:body:)` for post-process shaders (no tint multiplication).

### ShaderIncludes (6 GLSL Libraries)
- **`.noise`** — `hash21`, `noise2D`, `fbm` (Perlin-style)
- **`.easing`** — `easeQuadIn/Out`, `easeCubicIn/Out`, `easeSineIn/Out`, `easeSmoothstep`
- **`.uv`** — `rotateUV`, `scrollUV`, `tileUV`
- **`.color`** — `rgb2hsv`, `hsv2rgb`, `luminance`
- **`.math`** — `remap`, `smootherStep`, `inverseLerp`
- **`.normalMapping`** — `decodeNormal`, `lightDirection3D`, `lambertDiffuse`, `blinnPhongSpecular`

### ShaderComposer

Chain multiple effects into a single shader (no intermediate render passes):
```swift
let composer = ShaderComposer()
composer.addEffect("grayscale",
    uniforms: ["amount": "float"],
    includes: [.color],
    body: """
    float luma = luminance(color.rgb);
    color.rgb = mix(color.rgb, vec3(luma), amount);
    """)
composer.addEffect("tint",
    uniforms: ["tintColor": "vec3"],
    body: "color.rgb *= tintColor;")
let shader = renderer.loadShader(vertexSource: nil, fragmentSource: composer.build())
```

### ComposableEffects (Pre-built Snippets)
- `grayscale()`, `flash()`, `hueShift()`, `tint()`, `invertColors()`, `brightnessContrast()`

### Material Rendering
- `Sprite` has optional `material: Material2D?` — when set, shader is used instead of default
- `renderer.applyMaterial(_:context:)` — sets standard + user uniforms
- Material blend mode overrides sprite blend mode if specified

### Material Tween Extensions
```swift
// Animate material uniform float
tweens.tweenMaterialUniform(entity, uniform: "threshold", to: 1.0,
                            duration: 0.5, easing: .linear, in: world)

// Animate material color
tweens.tweenMaterialColor(entity, uniform: "flashColor", to: .red,
                          duration: 0.3, in: world)
```

## Render Targets

Off-screen rendering to textures. Enables screen transitions, post-processing, minimaps, resolution-independent rendering.

### RenderBackend Protocol
- **`createRenderTarget(width:height:)`** → `RenderTargetHandle` (`.invalid` on failure)
- **`beginRenderTarget(_:)`** / **`endRenderTarget()`** — redirect drawing to/from the target
- **`renderTargetTexture(_:)`** → `TextureHandle` for the color buffer
- **`renderTargetSize(_:)`** → `Size`
- **`destroyRenderTarget(_:)`** — frees GPU resources + invalidates associated texture
- All methods have default no-op implementations (backward compatible)

### Convenience Drawing
- **`drawRenderTarget(_:position:tint:)`** — draws RT contents with automatic Y-flip
- **`drawRenderTarget(_:destination:tint:)`** — scaled version with Y-flip

### Renderer Implementation
- Color buffer bridged into `textures` dictionary so `drawSprite`/`SpriteBatch` work unmodified
- `destroyTexture` guards against double-free on RT-owned textures
- `shutdown()` cleans up render targets before textures

### Usage
```swift
let rt = app.renderer.createRenderTarget(width: 320, height: 240)
app.renderer.beginRenderTarget(rt)
// draw to off-screen target...
app.renderer.endRenderTarget()
// draw RT contents to screen (handles Y-flip automatically)
app.renderer.drawRenderTarget(rt, position: .zero)
```

## Post-Processing Pipeline

Screen-space effect pipeline with ping-pong buffering. Captures the scene to a render target, applies a chain of effects, and composites to the screen.

### PostProcessEffect Protocol
- **`name: String`** — identifier
- **`isEnabled: Bool`** — disabled = zero cost (completely skipped)
- **`order: Int`** — priority (lower runs first)
- **`initialize(renderer:)`** — load GPU resources
- **`shutdown(renderer:)`** — free GPU resources
- **`resize(width:height:renderer:)`** — handle screen size changes
- **`apply(input:output:renderer:deltaTime:)`** — process from input RT to output RT

### PostProcessPipeline
- **`add(_ effect:)`** — add effect (auto-sorted by order)
- **`remove(named:)`** — remove by name
- **`effect(ofType:)`** — get for runtime tweaking
- **`beginCapture(renderer:)`** — start capturing scene (handles resize)
- **`endCaptureAndApply(renderer:deltaTime:)`** — process chain and composite

### Built-in Effects (6)

| Effect | Order | Key Properties |
|---|---|---|
| **BloomEffect** | 100 | `threshold` (0-1), `intensity` (brightness multiplier) |
| **ChromaticAberrationEffect** | 200 | `amount` (UV offset, typically 0.002-0.005) |
| **ColorGradingEffect** | 300 | `brightness` (-1..1), `contrast` (0-2), `saturation` (0-2), `gamma`, `tint` |
| **VignetteEffect** | 400 | `intensity` (0-1), `radius`, `softness` |
| **ScanlinesEffect** | 500 | `lineSpacing`, `lineIntensity`, `curvature` (CRT simulation) |
| **PixelateEffect** | 600 | `pixelSize` (higher = more pixelated) |

### Usage
```swift
// Setup (Scene.didEnter)
let postProcess = PostProcessPipeline()
postProcess.add(BloomEffect(threshold: 0.8, intensity: 1.2))
postProcess.add(VignetteEffect(intensity: 0.4))
postProcess.initialize(renderer: app.renderer)

// Render (Scene.render)
postProcess.beginCapture(renderer: app.renderer)
app.renderer.beginCamera(camera)
// ... draw scene ...
app.renderer.endCamera()
lighting.renderLightMap(renderer: app.renderer, camera: camera)
lighting.compositeLightMap(renderer: app.renderer)
postProcess.endCaptureAndApply(renderer: app.renderer, deltaTime: deltaTime)

// Cleanup (Scene.willExit)
postProcess.shutdown(renderer: app.renderer)
```

Custom effects implement `PostProcessEffect` protocol with a GLSL fragment shader (use `ShaderBuilder.createPostProcess`).

## Particle System

Lightweight 2D particle effects. Particles are pooled inside the emitter component (not ECS entities).

### Components
- **`ParticleEmitter`** — emission config + internal particle pool. Requires `Transform2D` on the entity.
  - `emissionRate` (particles/sec), `maxParticles`, `isEmitting`
  - `lifetime`, `speed`, `angle` (ClosedRange<Float> for randomization)
  - `gravity`, `damping` — per-particle physics
  - `startColor`/`endColor`, `startScale`/`endScale` — interpolated over lifetime
  - `emissionShape` — `.point`, `.circle(radius:)`, `.ring(radius:)`, `.rect(width:height:)`
  - `renderShape` — `.circle(radius:)`, `.rect(width:height:)`, `.sprite(texture:sourceRect:)`
  - `worldSpace` — true: particles detach from emitter, false: follow emitter
  - `burst(count:)` — immediate emission, works even when `isEmitting` is false

### System
- **`ParticleSystem`** (priority 200) — iterates `(ParticleEmitter, Transform2D)`, handles emission + physics + dead particle removal
- Pool uses swap-remove for O(1) dead particle cleanup

### Rendering
- **`renderer.drawParticles(emitter, at: position)`** — convenience on `RenderBackend`
- Interpolates color and scale per-particle based on normalized age (0→1)
- Draws circles, rects, or sprites depending on `renderShape`

### Usage
```swift
let particleSystem = ParticleSystem()
world.addSystem(particleSystem)

let entity = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: entity)
world.addComponent(ParticleEmitter(
    emissionRate: 50, maxParticles: 200,
    lifetime: 0.5...1.5, speed: 50...100,
    startColor: .yellow,
    endColor: Color(r: 255, g: 0, b: 0, a: 0),
    renderShape: .circle(radius: 3)
), to: entity)
```

## 2D Lighting & Shadows

Dynamic 2D lighting with shadow volumes. Renders a light map to an off-screen render target using GLSL shaders, composited onto the scene with `BlendMode.multiplied`.

### Shader Infrastructure

Minimal shader API added to `RenderBackend` protocol:
- **`loadShader(vertexSource:fragmentSource:)`** → `ShaderHandle`
- **`beginShader(_:)`** / **`endShader()`** — scoped shader usage
- **`setShaderFloat/Vec2/Vec3/Vec4`** — typed uniform setters
- **`setShaderTexture`** — bind texture to shader uniform
- **`destroyShader(_:)`** — free GPU resources
- **`drawTriangle(_:_:_:color:)`** — filled triangle for shadow volume rendering
- All methods have default no-op extensions (backward compatible)
- `ShaderHandle` follows the same opaque handle pattern as `TextureHandle`

### Components
- **`Light2D`** — point or spot light. Properties: `lightType` (.point / .spot(direction, coneAngle)), `color`, `intensity`, `radius`, `castsShadows`, `falloff`, `isEnabled`, `shadowLayerMask`, `specularEnabled`, `specularStrength`, `zHeight`, `softShadowRadius`
- **`ShadowCaster2D`** — opt-in marker component. Properties: `layer` (UInt32 bitmask), `isEnabled`. Requires `Transform2D` + `Collider2D` on the same entity.

### LightingSystem
- **System** (priority 300) — after physics (100), particles (200)
- **`initialize(renderer:)`** — loads GLSL shaders, creates light map render target (+ normal/specular buffers if enabled, + soft shadow buffers if enabled). Call once in `Scene.didEnter`.
- **`shutdown(renderer:)`** — frees GPU resources. Call in `Scene.willExit`.
- **`update(context:)`** — snapshots Light2D+Transform2D and ShadowCaster2D+Collider2D+Transform2D pairs
- **`renderLightMap(renderer:camera:)`** — clears with ambient color, draws each light additively with per-pixel shader falloff. Hard shadows: draws shadow volumes as black triangles. Soft shadows: renders volumes to a shadow buffer, applies Gaussian blur, binds blurred buffer to light shader.
- **`compositeLightMap(renderer:)`** — draws light map to screen using `BlendMode.multiplied`
- **`isInitialized`**, **`isNormalMappingInitialized`**, **`isSoftShadowsInitialized`** — GPU resource state flags

### Shadow Geometry
Pure geometry module (`enum ShadowGeometry`). CPU-computed shadow volumes from collider shapes:
- **Polygon/AABB shadows** — silhouette edge detection (facing vs. away from light), projects boundary vertices by `shadowExtent`
- **Circle shadows** — tangent point computation + arc approximation (configurable segments)
- **Early-outs**: distance culling, light-inside-shape detection
- `computeShadows(lightPosition:lightRadius:occluders:shadowExtent:)` → `[ShadowVolume]`

### GLSL Shaders
Embedded as Swift string constants (`LightingShaders`). GLSL 330 (OpenGL 3.3):
- **Point light fragment**: radial falloff with configurable intensity, color, radius, falloff exponent, smoothstep edges
- **Spot light fragment**: same as point + cone angle check with soft edges
- **Normal-lit variants**: `normalLitPointFragment`, `normalLitSpotFragment` — add `normalBuffer`, `lightZ`, `flipNormalY` uniforms for per-pixel diffuse
- **Specular variants**: `specularPointFragment`, `specularSpotFragment` — add `specularBuffer`, `specularStrength`, `shininess` for Blinn-Phong highlights
- **Shadow blur shaders**: `shadowBlurHorizontalFragment`, `shadowBlurVerticalFragment` — separable 9-tap Gaussian blur with `resolution` and `blurRadius` uniforms
- All 6 light shaders include `shadowBuffer` (sampler2D) and `useShadowBuffer` (int) uniforms for soft shadow integration

### LightingOptions
- `ambientColor` — light map clear color (default: dark blue-gray)
- `lightMapScale` — resolution scale (1.0 = full, 0.5 = half for performance)
- `shadowExtent` — max shadow reach (0 = auto from screen diagonal)
- `debugDraw`, `debugLightColor`, `debugShadowColor` — debug overlay toggles
- `normalMappingEnabled`, `specularEnabled`, `flipNormalY` — normal map toggles
- `debugNormalBuffer`, `debugSpecularBuffer` — buffer debug overlays
- `softShadows` — master toggle for soft (blurred) shadows (default: false)
- `softShadowRadius` — global Gaussian blur radius in pixels (default: 4.0)
- `softShadowQuality` — `.low` (1 pass), `.medium` (2), `.high` (3) (default: .medium)
- `debugShadowBuffer` — draw shadow buffer overlay on screen

### Debug Rendering
- **`renderer.drawLightingDebug(world:options:)`** — `RenderBackend` extension
- Draws: light radius circles, center dots, spotlight direction/cone, shadow caster outlines
- **`renderer.drawNormalBufferDebug(lighting:options:)`** — draws normal buffer (green), specular buffer (cyan), shadow buffer (magenta) overlays at 25% scale

### Usage
```swift
// Setup (in Scene.didEnter)
let lighting = LightingSystem(options: LightingOptions(
    ambientColor: Color(r: 20, g: 20, b: 30)
))
lighting.initialize(renderer: app.renderer)
world.addSystem(lighting)

// Create lights
let torch = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: torch)
world.addComponent(Light2D(
    color: Color(r: 255, g: 200, b: 100),
    intensity: 1.5,
    radius: 250,
    castsShadows: true,
    falloff: 1.5
), to: torch)

// Create shadow casters (opt-in via ShadowCaster2D)
let wall = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 200, y: 150)), to: wall)
world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 10))), to: wall)
world.addComponent(ShadowCaster2D(), to: wall)

// Render (in Scene.render)
app.renderer.beginCamera(camera)
// ... draw scene sprites, tilemaps, etc ...
app.renderer.endCamera()

lighting.renderLightMap(renderer: app.renderer, camera: camera)
lighting.compositeLightMap(renderer: app.renderer)

// Soft shadows setup
let lighting = LightingSystem(options: LightingOptions(
    ambientColor: Color(r: 10, g: 10, b: 20),
    softShadows: true,
    softShadowRadius: 6.0,
    softShadowQuality: .high
))
lighting.initialize(renderer: app.renderer)

// Per-light blur radius override (0 = use global)
world.addComponent(Light2D(
    castsShadows: true,
    softShadowRadius: 10.0  // Override global 6.0 for this light
), to: lamp)
```

## UI Widgets

12 widgets plus configurable input, nine-patch rendering, modal dialog support, and overlay rendering.

### UIInputConfig (Configurable Input)

Replaces hardcoded keyboard navigation with configurable keyboard and/or gamepad bindings. Set on `UIContext.inputConfig`.

- **`KeyboardConfig`** — confirm, cancel, up/down/left/right, nextFocus keys (Shift+Tab for prevFocus)
- **`GamepadConfig`** — same actions mapped to gamepad buttons, configurable gamepad index
- **Presets**: `.default` (keyboard only), `.keyboardAndGamepad` (both enabled)
- Mouse input always active (not configurable through UIInputConfig)

### UIDropdown (Select Widget)

Dropdown button that shows a popup list of options when activated. Popup auto-positions to stay within screen bounds (opens downward by default, upward if no room, scrollable if too many options).

- Mouse: click opens, hover highlights, click selects, click-outside closes
- Keyboard/gamepad: confirm opens/selects, cancel closes, up/down navigate options
- `maxVisibleOptions` (default 6) — limits popup height, enables scrolling
- `renderOverlay()` draws popup on top of siblings (correct z-order)

### UIListView (Scrollable List)

Data-driven scrollable list with single-item selection. Renders items directly (no child UINodes per row).

- Mouse: click selects, scroll wheel scrolls
- Keyboard/gamepad: up/down move selection when focused (consumes input before focus navigation)
- `scrollOffset`, `rowHeight`, `showScrollBar` configurable
- Auto-scrolls to keep selection visible

### UIModalDialog (Modal Overlay)

Centered dialog box with dimmed overlay that blocks all background UI input.

- `UIContext.presentModal()` / `dismissModal()` — manages modal state
- When active: only modal receives input, focus trapped within modal buttons
- Builder API: `addContent()`, `addButton()`, `addOKCancel()`
- `dismissOnCancel` (default true) — cancel input binding dismisses the dialog

### NinePatchSprite (Rendering Primitive)

Value-type struct for scalable UI backgrounds. Divides a texture region into 9 zones (corners unscaled, edges stretch one axis, center stretches both).

```swift
let patch = NinePatchSprite(texture: panelTex, sourceRect: sourceRect, border: 12)
renderer.drawNinePatch(patch, destination: Rect(x: 10, y: 10, width: 300, height: 200))
```

### Overlay Rendering

`UINode.renderOverlay()` — second render pass after main `render()`. Default is no-op; `UIContainer` recurses children. Used by UIDropdown for popup z-order. Called automatically by `UIContext.render()`.

## Logging

Structured logging with level filtering and multiple output destinations.

### Log Levels
`LogLevel` enum: `.trace`, `.debug`, `.info`, `.warn`, `.error`. `Comparable` by severity.

### LogEntry
`LogEntry` struct: `level`, `category` (String), `message` (String), `timestamp` (Double, seconds since init).

### LogOutput Protocol
`LogOutput`: `minimumLevel: LogLevel` + `write(_: LogEntry)`. Implement for custom destinations.

### Built-in Outputs
- **`ConsoleLogOutput`** — prints `[time] [LEVEL] [category] message` to stdout
- **`FileLogOutput`** — writes to file via `fopen`/`fputs` (cross-platform). Init returns nil if file can't be opened.
- **`RingBufferLogOutput`** — fixed-capacity circular buffer. `entries` property returns snapshot (oldest first). Used by `DebugOverlay`.

### Log Facade
`Log` — static enum (not instantiated). `nonisolated(unsafe)` static state (single-threaded framework).

```swift
Log.minimumLevel = .debug  // global gate
Log.addOutput(ConsoleLogOutput(minimumLevel: .info))
Log.addOutput(RingBufferLogOutput(capacity: 256, minimumLevel: .debug))

Log.info("Physics", "Simulation started")
Log.error("Rendering", "Shader compilation failed: \(error)")
Log.trace("ECS", "Entity \(entity.index) created")
```

## Viewport Snapshots

Capture the framebuffer to file or memory.

### RenderBackend Protocol
- **`takeScreenshot(path:)`** — saves framebuffer to PNG file
- **`captureScreen() -> ImageData?`** — reads framebuffer pixels into `ImageData` (RGBA)

Both have default no-op implementations. The Renderer reads the OpenGL ES framebuffer via `glReadPixels`.

### Usage
```swift
// Save to file
app.renderer.takeScreenshot(path: "screenshot.png")

// Capture to memory
if let image = app.renderer.captureScreen() {
    // image.width, image.height, image.pixels (RGBA bytes)
}
```

## Debug Overlay

Unified in-game HUD for performance monitoring and diagnostics.

### DebugOverlay
Class that renders FPS, frame graph, ECS stats, system timings, and on-screen log.

### DebugOverlayOptions
- `showFPS`, `showFrameGraph`, `showEntityStats`, `showSystemTimings`, `showLog` (all default `true`)
- `logLineCount` (default 8), `fontSize` (default 14), `graphSamples` (default 120)
- `backgroundColor`, `textColor`, `warningColor`, `errorColor`

### World Debug Stats
- **`world.entityCount`** — alive entities
- **`world.componentStoreCount`** — registered component types
- **`world.systemCount`** — registered systems
- **`world.systemTimings`** — `[(name: String, priority: Int, duration: Double)]`, populated each `update()` / `updateParallel()` tick

### Usage
```swift
let logBuffer = RingBufferLogOutput(capacity: 256, minimumLevel: .debug)
Log.addOutput(logBuffer)

let overlay = DebugOverlay(font: app.renderer.loadDefaultFont())
overlay.logBuffer = logBuffer

// In render():
overlay.recordFrame(frameTime: app.frameTime)
overlay.render(renderer: app.renderer, app: app)
```

## Per-System Debug Renderers

All follow the existing pattern: `extension RenderBackend` with `Sendable` options struct.

### AnimationDebugRenderer
`drawAnimationDebug(world:font:options:)` — iterates `(Transform2D, SpriteAnimator, Sprite)`. Draws source rect outlines and clip name/frame index labels.

Options: `drawSourceRects`, `drawAnimatorState`, `sourceRectColor` (green), `stateTextColor` (white), `fontSize` (12).

### TweenDebugRenderer
`drawTweenDebug(infos:world:font:options:)` — takes `[TweenDebugInfo]` from `TweenSystem.debugTweenInfo(world:)`. Draws path lines to targets (position tweens) and progress labels.

`TweenDebugInfo`: `entity`, `targetType` (String), `progress` (Float 0-1), `targetPosition` (Vector2?, position tweens only).

Options: `drawPaths`, `drawProgress`, `pathColor` (magenta), `fontSize` (12).

### ParticleDebugRenderer
`drawParticleDebug(world:font:options:)` — iterates `(Transform2D, ParticleEmitter)`. Draws emission shape outlines (crosshair/circle/ring/rect) and particle count labels (`42/200 [ON]`).

Options: `drawEmissionShape`, `drawParticleCount`, `emissionShapeColor` (yellow), `fontSize` (12).

### TileMapDebugRenderer
`drawTileMapDebug(tileMap:position:camera:options:)` — draws tile grid lines (camera-culled) and culling viewport rectangle.

Options: `drawGrid`, `drawCullingRect`, `gridColor` (semi-transparent white), `cullingRectColor` (yellow).

### UIDebugRenderer
`drawUIDebug(context:font:options:)` — recursively walks UI tree. Draws bounding rect outlines and node ID labels.

Options: `drawBounds`, `boundsColor` (cyan), `fontSize` (10).

### Usage
```swift
// In render(), inside camera block:
app.renderer.drawAnimationDebug(world: app.world, font: font)
app.renderer.drawParticleDebug(world: app.world, font: font)
app.renderer.drawTweenDebug(infos: tweens.debugTweenInfo(world: app.world),
                            world: app.world, font: font)
app.renderer.drawTileMapDebug(tileMap: tileMap, camera: camera)

// Outside camera block (screen space):
app.renderer.drawUIDebug(context: uiContext, font: font)
```

## Callback Capture Best Practices

Physics callbacks (`onCollisionBegan`, `onCollisionEnded`, `onJointBroken`) and event handlers store closures that can create retain cycles if `self` is captured strongly. Always use `[weak self]` when referencing your scene or game object:

```swift
// CORRECT — weak capture prevents retain cycle
physics.onCollisionBegan = { [weak self] event in
    self?.handleCollision(event)
}

// INCORRECT — strong capture creates a retain cycle
physics.onCollisionBegan = { event in
    self.handleCollision(event) // self retains physics, physics retains self
}
```

The same applies to `world.on(EventType.self)` handlers and tween callbacks.

## Scene Resource Lifecycle

Clean up scene-specific resources during scene transitions to prevent GPU memory leaks:

```swift
class GameScene: Scene {
    var textures: [TextureHandle] = []
    var sounds: [SoundHandle] = []

    func didEnter(app: Application) {
        textures.append(app.renderer.loadTexture(from: "assets/player.png"))
        sounds.append(app.audioManager.loadSound(from: "assets/jump.wav"))
    }

    func willExit(app: Application) {
        // Clean up GPU/audio resources before scene is deallocated
        for tex in textures { app.renderer.destroyTexture(tex) }
        for snd in sounds { app.audioManager.unloadSound(snd) }
        textures.removeAll()
        sounds.removeAll()

        // Remove event handlers to avoid dangling callbacks
        app.world.removeAllEventHandlers()
    }
}
```

## Code Conventions

- Swift 6.0+ with strict concurrency checking
- Single-threaded by default — all game code runs on the main thread. Opt-in parallel system scheduling available via `world.parallelSchedulingEnabled` and `Application.runAsync()`.
- `@unchecked Sendable` on engine classes (World, Application, CommandBuffer) — safe because access is either single-threaded or scheduler-guaranteed disjoint. These types assume single-threaded access from the game loop; the parallel scheduler provides disjoint-access guarantees for concurrent system execution.
- `@unchecked Sendable` wrapper structs (`UnsafeSystemRef`, `UnsafeBufferRef`) bridge non-Sendable types across `TaskGroup` boundaries
- `internal` access for cross-file helpers within the Agilis module
- `private` for state within a single file
- No external Swift dependencies — everything is self-contained
- ANGLE, MiniAudio, PlatformC, and stb are vendored C sources, built via SPM C targets
- Windows linker flags: `/SUBSYSTEM:WINDOWS`, `/ENTRY:mainCRTStartup` on executables
- C language standard: C99

## Platform Notes

- Windows: Swift 6.2 toolchain, MSVC build tools
- Runtime DLLs required for distribution (swiftCore.dll, Foundation.dll, _FoundationICU.dll, etc.) — see `DLLs/` folder
- Examples use `/SUBSYSTEM:WINDOWS` so they launch without a console window
