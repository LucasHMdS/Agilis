# Examples

Agilis ships with eight example projects in `Examples/`.

---

## UIDemo

`Examples/UIDemo/main.swift`

A UI demo that showcases the full widget system. It creates a single scene with all 12 interactive widgets on a cornflower-blue background, with keyboard and gamepad navigation enabled.

### What It Demonstrates

- **Application setup** — `WindowConfig`, `Application(config:)`, pushing an initial scene
- **UI system** — `UIContext`, `UIScrollContainer` with vertical layout, widget tree
- **Widgets** — `UILabel`, `UIButton`, `UISlider`, `UIToggle`, `UIProgressBar`, `UIDropdown`, `UIListView`, `UIModalDialog`, `UITextInput`, `UIImage`, `UIPanel`, `UIScrollContainer`
- **Configurable input** — `UIInputConfig.keyboardAndGamepad` for keyboard + gamepad navigation
- **Dynamic updates** — Updating label text and progress bar value from callbacks
- **Modal dialogs** — Presenting and dismissing modal overlays
- **Procedural textures** — `ImageData` + `loadTextureFromImage` for runtime-generated content
- **Background rendering** — Drawing shapes behind the UI layer
- **Input handling** — Escape key to quit (blocked when modal is active)

### Structure

```
Application(config)
  └─ UIDemoScene
       ├─ UIContext (inputConfig: .keyboardAndGamepad)
       │   └─ UIScrollContainer (vertical, centered)
       │       ├─ UILabel "Agilis UI Demo" (title)
       │       ├─ UILabel subtitle
       │       ├─ UIImage (procedural diamond icon)
       │       ├─ UILabel player name + UITextInput
       │       ├─ UILabel click counter (updated dynamically)
       │       ├─ UIButton "Click Me!" (increments counter)
       │       ├─ UIProgressBar (fills as you click)
       │       ├─ UIPanel "Settings"
       │       │   ├─ UISlider "Volume"
       │       │   ├─ UILabel toggle status + UIToggle "Dark Mode"
       │       │   ├─ UILabel difficulty + UIDropdown
       │       ├─ UILabel weapon status
       │       ├─ UIListView (Sword/Bow/Staff/Dagger/Axe/Spear)
       │       └─ UIButton "Show Dialog" → UIModalDialog
       └─ Background shapes (rect, circle)
```

### Key Patterns

**Creating a UI scene:**

```swift
final class UIDemoScene: Scene {
    private var ui: UIContext!

    func didEnter(app: Application) {
        let font = app.renderer.loadDefaultFont()
        ui = UIContext(font: font)
        ui.inputConfig = .keyboardAndGamepad

        let panel = UIContainer(id: "main")
        panel.layout = .vertical(spacing: 12, alignment: .center)
        // ... add widgets ...
        ui.add(panel)

        let screen = app.renderer.screenSize
        panel.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)
    }

    func render(app: Application, interpolation: Double) {
        ui.render(renderer: app.renderer)
    }
}
```

**Updating widgets from callbacks:**

```swift
let button = UIButton("Click Me!") { [weak self] in
    guard let self else { return }
    self.clickCount += 1
    self.counterLabel.text = "Clicks: \(self.clickCount)"
    self.progressBar.value = min(Float(self.clickCount) / 10.0, 1.0)
    self.ui.invalidateLayout()  // Text length changed, re-layout
}
```

**Presenting a modal dialog:**

```swift
let modal = UIModalDialog(title: "Hello!")
modal.addContent(UILabel("This is a modal dialog.", fontSize: 18))
modal.addOKCancel(
    onOK: { [weak self] in self?.ui.dismissModal() },
    onCancel: { [weak self] in self?.ui.dismissModal() }
)
ui.presentModal(modal)
```

### Running

```bash
swift run UIDemo
```

---

## PongGame

`Examples/Pong/`

A full Pong game with menu screens, AI opponent, serve mechanics, score tracking, and an FPS counter. Demonstrates the ECS in action alongside scene transitions, interpolated rendering, and UI menus.

### What It Demonstrates

- **ECS components** — `Position`, `PreviousPosition`, `Velocity`, `Paddle`, `Ball`, `AIControlled` as struct components
- **ECS systems** — `PongAISystem` (prediction), `PongMovementSystem` (apply velocity), `PongPhysicsSystem` (collisions)
- **Entity naming** — Named entities (`"leftPaddle"`, `"rightPaddle"`, `"ball"`) for direct lookups
- **Multiple scenes** — Menu, gameplay, and game-over screens with `sceneManager.replace()`
- **Fixed-timestep game loop** — Systems run at a fixed rate, rendering interpolates between frames
- **Input** — Keyboard controls (W/S or Up/Down for the player paddle)
- **AI opponent** — Predictive AI that tracks ball trajectory with wall-bounce simulation
- **Collision detection** — Rectangle intersection for paddle-ball collisions in `PongPhysicsSystem`
- **UI menus** — `UIContext` with themed buttons for menu and game-over screens
- **Custom rendering** — Seven-segment digit display, dashed court lines, "PONG" title drawn with rectangles
- **FPS counter** — `app.fps` displayed subtly in all scenes

### Scene Flow

```
MenuScene ──[Play]──> GameScene ──[Win]──> GameOverScene
    ^                    │                      │
    │                    │ [Escape]              │ [Menu]
    └────────────────────┘                      │
    └───────────────────────────────────────────┘
                                          [Rematch] ──> GameScene
```

### Scenes

**MenuScene** — Title screen with "PONG" drawn using primitive rectangles, court background, Play and Quit buttons via `UIContext`.

**GameScene** — Core gameplay using the ECS:

| Element | Details |
|---------|---------|
| Player paddle | Entity `"leftPaddle"` with Position, Velocity, Paddle components |
| AI paddle | Entity `"rightPaddle"` with Position, Velocity, Paddle, AIControlled components |
| Ball | Entity `"ball"` with Position, Velocity, Ball components |
| Systems | PongAISystem → PongMovementSystem → PongPhysicsSystem (priority-ordered) |
| Scoring | Scene reads ball Position, seven-segment digit display, first to 5 wins |
| Serve | Ball blinks at center, scene sets ball Velocity on launch |
| Interpolation | `PreviousPosition` component enables smooth interpolated rendering |

**GameOverScene** — Shows winner and final score, Rematch and Menu buttons.

### Key Patterns

**ECS entity setup:**

```swift
func didEnter(app: Application) {
    let world = app.world

    // Create left paddle (player)
    leftPaddle = world.createEntity()
    world.setName("leftPaddle", for: leftPaddle)
    world.addComponent(Position(x: Pong.paddleMargin, y: centerY), to: leftPaddle)
    world.addComponent(PreviousPosition(x: Pong.paddleMargin, y: centerY), to: leftPaddle)
    world.addComponent(Velocity(dx: 0, dy: 0), to: leftPaddle)
    world.addComponent(Paddle(halfWidth: ..., halfHeight: ..., speed: Pong.paddleSpeed), to: leftPaddle)

    // Register systems (priority controls execution order)
    world.addSystem(PongAISystem())       // priority -10
    world.addSystem(PongMovementSystem()) // priority 0
    world.addSystem(PongPhysicsSystem())  // priority 10
}
```

**ECS system with type-safe queries:**

```swift
final class PongMovementSystem: System {
    func update(context: SystemContext) {
        let dt = Float(context.deltaTime)
        context.world.forEach { (entity: Entity, pos: inout Position,
                                 prev: inout PreviousPosition, vel: inout Velocity) in
            prev.x = pos.x; prev.y = pos.y
            pos.x += vel.dx * dt; pos.y += vel.dy * dt
        }
    }
}
```

**Interpolated rendering from ECS:**

```swift
func render(app: Application, interpolation: Double) {
    let t = Float(interpolation)
    let leftPos = world.getComponent(Position.self, from: leftPaddle)!
    let leftPrev = world.getComponent(PreviousPosition.self, from: leftPaddle)!
    let drawLeftY = Agilis.lerp(leftPrev.y, leftPos.y, t: t)
    // Draw at interpolated positions for smooth motion
}
```

### Running

```bash
swift run PongGame
```

---

## Platformer

`Examples/Platformer/`

A side-scrolling platformer with jumping mechanics, enemies, collectibles, and a flagpole goal. Demonstrates the async game loop with parallel system scheduling, sprite animation, physics with collision layers, and event-driven gameplay.

### What It Demonstrates

- **Parallel system scheduling** — `app.runAsync()` with `world.parallelSchedulingEnabled = true`
- **Physics with collision layers** — `PhysicsWorld2D` with bitmask-based layer filtering (player, ground, enemy, coin, block, pipe, flagpole)
- **ECS systems with componentAccess** — `PlayerMovementSystem`, `EnemyAISystem`, `GameplaySystem`, `PostPhysicsSystem` with declared reads/writes
- **Event bus** — `CoinCollectedEvent`, `BlockHitEvent`, `EnemyStompedEvent`, `LevelCompleteEvent`, `PlayerHurtEvent`
- **Platformer mechanics** — Coyote time, jump buffering, variable jump height, invincibility frames
- **Procedural level building** — `LevelBuilder` creates ground, platforms, pipes, enemies, coins, and flagpole
- **Sprite sheet animation** — `SpriteSheet` helper for named regions within a texture atlas
- **Multiple scenes** — Menu → Game → Victory/GameOver with scene transitions
- **Sound effects** — Procedural audio for jumps, coin pickups, stomps, and hits
- **Resource cleanup** — Every scene destroys fonts, textures, sounds, systems, and entities in `willExit()`

### Files

| File | Purpose |
|------|---------|
| `main.swift` | Async entry point, enables parallel scheduling |
| `GameScene.swift` | Core gameplay, player input, HUD rendering |
| `MenuScene.swift` | Title screen with Play/Quit buttons |
| `GameOverScene.swift` | Death screen with Retry/Menu buttons |
| `VictoryScene.swift` | Level complete screen |
| `Components.swift` | Player, Enemy, Coin, QuestionBlock, Tile, Flagpole + events |
| `Systems.swift` | Four ECS systems with componentAccess declarations |
| `LevelBuilder.swift` | Procedural level generation |
| `SpriteSheet.swift` | Named sprite region lookup |
| `Constants.swift` | Physics and visual constants in `Mario` enum |

### Running

```bash
swift run Platformer
```

---

## DungeonCrawler

`Examples/DungeonCrawler/`

A top-down dungeon exploration game with procedurally generated rooms, dynamic 2D lighting with shadows, torch particles, and enemy patrol AI. Demonstrates the lighting system as a gameplay element.

### What It Demonstrates

- **2D lighting and shadows** — `LightingSystem` with dynamic point lights from wall sconces and shadow casting from wall colliders
- **Procedural dungeon generation** — `DungeonBuilder` creates room/hallway layouts with walls and floor tiles
- **Particle effects** — `ParticleEmitter` on torch entities with flickering light intensity
- **Top-down physics** — `PhysicsWorld2D` with zero gravity for grid-based movement
- **Enemy AI** — Patrol waypoints with `EnemyComp.patrolPath`, direction tracking
- **Camera follow** — `Camera2D` smoothly tracks the player through the dungeon
- **Scene management** — Menu → Game with scene transitions
- **Sound effects** — Procedural footstep and ambient audio

### Files

| File | Purpose |
|------|---------|
| `main.swift` | Entry point |
| `GameScene.swift` | Gameplay, lighting setup, camera, rendering pipeline |
| `MenuScene.swift` | Title screen |
| `Components.swift` | PlayerComp, EnemyComp, Torch, WallSconce |
| `DungeonBuilder.swift` | Procedural room/hallway generation |
| `Constants.swift` | Layout and visual constants in `Dungeon` enum |
| `SoundEffects.swift` | Audio generation |

### Running

```bash
swift run DungeonCrawler
```

---

## TopDownShooter

`Examples/TopDownShooter/`

A top-down arena shooter with wave-based enemy spawning, multiple weapon types, particle explosions, and score tracking. Demonstrates sprite batching, physics collision layers, event-driven feedback, and camera shake.

### What It Demonstrates

- **Physics with collision layers** — Player, enemy, and bullet layers with bitmask filtering
- **Sprite batching** — `SpriteBatch` for optimized draw calls
- **Event system** — `EnemyKilledEvent`, `WaveStartedEvent`, `PlayerDamagedEvent` for decoupled feedback
- **Particle effects** — Explosion particles on enemy death, muzzle flash
- **Camera shake** — Timer-based screen shake on kill events
- **Wave spawning** — `WaveManager` component tracks wave progression and spawn timing
- **Multiple weapon types** — Pistol, shotgun, laser with different damage/cooldown profiles
- **Score tracking** — `ScoreTracker` component for kills and score
- **Multiple scenes** — Menu → Game → GameOver with transitions
- **Sound effects** — Procedural weapon and explosion audio

### Files

| File | Purpose |
|------|---------|
| `main.swift` | Entry point |
| `GameScene.swift` | Gameplay, wave logic, collision handling, rendering |
| `MenuScene.swift` | Title screen |
| `GameOverScene.swift` | Score summary with Retry/Menu buttons |
| `Components.swift` | PlayerShooter, EnemyAI, BulletComp, WaveManager, ScoreTracker + events |
| `Constants.swift` | Balance and visual constants in `Shooter` enum |
| `SoundEffects.swift` | Audio generation |

### Running

```bash
swift run TopDownShooter
```

---

## TweenShowcase

`Examples/TweenShowcase/`

An interactive showcase of the tweening system. Three scenes demonstrate position/scale/color tweens, all 19 easing functions with animated curves, and multi-step tween sequences. Features scene transitions, nine-patch rendering, and render targets.

### What It Demonstrates

- **TweenSystem** — Position, scale, and custom color tweens with various easing functions
- **Easing functions** — All 19 easing types visualized with animated curves (linear, quad, cubic, quart, quint, sine, expo, circ, back, elastic, bounce — each with in/out/inOut)
- **Tween sequences** — Multi-step sequences with `moveTo`, `wait`, `fadeTo`, `callback` steps
- **Yoyo and repeat** — Looping animations with `setYoyo()` and `setRepeat(-1)`
- **Custom tweens** — User-defined `custom()` tweens for color interpolation
- **Scene transitions** — `.fade()` and `.flash()` transitions between showcase scenes
- **Nine-patch rendering** — `NinePatchSprite` for scalable panel backgrounds
- **UI integration** — Buttons for scene navigation

### Files

| File | Purpose |
|------|---------|
| `main.swift` | Entry point |
| `MenuScene.swift` | Animated title with tween-driven UI |
| `EasingScene.swift` | Grid of all 19 easing functions with live animation |
| `SequenceScene.swift` | Multi-step tween sequences |
| `Constants.swift` | Layout constants in `Showcase` enum |
| `RenderingHelpers.swift` | Easing curve visualization |

### Running

```bash
swift run TweenShowcase
```

---

## PhysicsSandbox

`Examples/PhysicsSandbox/`

An interactive physics sandbox with tabbed demos showcasing all six joint types, mouse-drag physics, continuous collision detection, joint breaking, and time scaling controls. Features physics debug rendering with configurable overlays.

### What It Demonstrates

- **All 6 joint types** — One demo per tab:
  - Revolute joints (ragdoll skeleton)
  - Distance joints (spring bridge)
  - Prismatic joints (elevator/crane)
  - Weld joints (composite objects)
  - Motor joints (smooth following)
  - Rope joints (tethered objects)
- **CCD** — Fast-moving projectiles with `useCCD: true` that don't tunnel through walls
- **Physics queries** — `pointQuery()` for mouse picking, `areaQuery()` for explosion radius
- **Joint breaking** — Joints that break when force exceeds threshold, with audio feedback
- **Time scaling** — P=pause, F1=slow motion, F2=normal, F3=fast forward via `app.timeScale`
- **Physics debug rendering** — Toggle colliders, contacts, velocities, normals, CCD paths
- **Mouse-drag physics** — Click and drag objects with velocity-based throwing
- **Sound effects** — Collision and joint break audio

### Files

| File | Purpose |
|------|---------|
| `main.swift` | Entry point |
| `GameScene.swift` | Tab management, input, debug toggle, time controls |
| `Components.swift` | Draggable, Projectile components |
| `DemoBuilders.swift` | Builder functions for each joint demo |
| `Constants.swift` | Physics constants in `Sandbox` enum |
| `SoundEffects.swift` | Audio generation |

### Running

```bash
swift run PhysicsSandbox
```

---

## SaveLoadDemo

`Examples/SaveLoadDemo/`

A top-down RPG room demonstrating entity serialization. Features a player who can pick up items, open chests, and talk to NPCs — all state is saved to and loaded from JSON using `WorldSerializer`. Custom components implement `SerializableComponent` for full persistence.

### What It Demonstrates

- **Entity serialization** — `WorldSerializer` with `encode(world:)` and `decode(from:into:)`
- **SerializableComponent protocol** — Six custom components with `Codable` conformance:
  - `PlayerTag` — player name
  - `Inventory` — item list with max slots
  - `Equipment` — weapon and armor slots
  - `ItemPickup` — ground items with type metadata
  - `Chest` — openable containers with contents
  - `NPCTag` — NPC dialogue and name
- **Save/load workflow** — Full round-trip: create world → play → save to JSON → clear world → load from JSON
- **Event bus** — `ItemPickedUp`, `ChestOpened`, `InventoryChanged` events
- **Top-down physics** — `PhysicsWorld2D` with zero gravity for grid movement
- **UI integration** — `UIListView` for inventory display, labels for equipment/status
- **Entity remapping** — `decode` returns `[UInt32: Entity]` remap table for re-establishing references
- **Scene management** — Menu → Game with transitions

### Files

| File | Purpose |
|------|---------|
| `main.swift` | Entry point |
| `GameScene.swift` | Gameplay, save/load logic, collision handling, UI |
| `MenuScene.swift` | Title screen with New Game / Load buttons |
| `Components.swift` | Six `SerializableComponent` types + three events |
| `Prefabs.swift` | Entity factory functions for items, chests, NPCs |
| `Constants.swift` | Layout constants in `RPG` enum |
| `SoundEffects.swift` | Audio generation |

### Key Patterns

**Registering custom components:**

```swift
let serializer = WorldSerializer()
serializer.registerDefaults()
serializer.register(PlayerTag.self)
serializer.register(Inventory.self)
serializer.register(Equipment.self)
serializer.register(ItemPickup.self)
serializer.register(Chest.self)
serializer.register(NPCTag.self)
```

**Save/load round-trip:**

```swift
// Save
let data = try serializer.encode(world: world)

// Load (into a fresh or cleared world)
let remap = try serializer.decode(from: data, into: world)
// remap[oldIndex] → newEntity for re-establishing references
```

### Running

```bash
swift run SaveLoadDemo
```
