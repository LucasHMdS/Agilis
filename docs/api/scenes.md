# Scenes

## Scene Protocol

`Sources/Agilis/Scene/Scene.swift`

Scenes represent distinct game states (menu, gameplay, pause, game over). All methods have empty default implementations.

```swift
protocol Scene: AnyObject {
    func didEnter(app: Application)                     // Scene becomes active
    func update(app: Application, deltaTime: Double)    // Fixed-timestep logic
    func render(app: Application, interpolation: Double) // Called each frame
    func willExit(app: Application)                     // Scene is about to be removed
}
```

### Lifecycle

1. `didEnter` — Called once when the scene becomes the active (top) scene. Initialize resources, set up UI, load assets here.
2. `update` — Called at a fixed rate (default 60Hz). Game logic, input handling, physics go here.
3. `render` — Called every frame. The `interpolation` parameter (0.0-1.0) represents progress between logic frames for smooth rendering.
4. `willExit` — Called when the scene is about to be replaced or removed. Clean up resources here.

---

## SceneManager

`Sources/Agilis/Scene/SceneManager.swift`

Manages a stack of scenes. Only the top scene is active.

### Properties

```swift
var currentScene: Scene?    // The active (top) scene
var isTransitioning: Bool   // Whether an animated transition is active
```

### Instant Methods

```swift
// Push a new scene on top. Previous scene stays in memory but stops receiving updates.
func push(_ scene: Scene, app: Application)

// Remove the current scene. Previous scene resumes.
func pop(app: Application) -> Scene?

// Replace only the top scene. Previous is removed.
func replace(with scene: Scene, app: Application)

// Clear the entire stack and set a single scene.
func replaceAll(with scene: Scene, app: Application)
```

### Transition Methods

All instant methods have transition-aware variants:

```swift
func push(_ scene: Scene, transition: SceneTransition, app: Application)
func pop(transition: SceneTransition, app: Application)
func replace(with scene: Scene, transition: SceneTransition, app: Application)
func replaceAll(with scene: Scene, transition: SceneTransition, app: Application)
```

---

## SceneTransition

`Sources/Agilis/Scene/SceneTransition.swift`

Animated transitions between scenes. Duration is split: first half fades out the old scene, second half fades in the new scene. Scene swap (`willExit`/`didEnter`) happens at the midpoint when the screen is fully covered.

### Factories

```swift
// Fade to a color and back (default: black, 0.5s, linear easing)
static func fade(duration: Double = 0.5, color: Color = .black,
                 easing: EasingFunction = .linear,
                 onMidpoint: (() -> Void)? = nil) -> SceneTransition

// White flash (fast fade to white and back)
static func flash(duration: Double = 0.3,
                  easing: EasingFunction = .linear) -> SceneTransition

// No animation
static let instant: SceneTransition
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `duration` | `Double` | Total transition time in seconds |
| `color` | `Color` | Overlay color |
| `easing` | `EasingFunction` | Easing curve for the fade |
| `onMidpoint` | `(() -> Void)?` | Callback at midpoint (screen fully covered) |

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

// Instant (same as non-transition version)
app.sceneManager.replace(with: MenuScene(), transition: .instant, app: app)
```

### Scene Transition Patterns

**Menu to Gameplay:**
```swift
// Replace with fade — menu is no longer needed
app.sceneManager.replace(with: GameScene(), transition: .fade(), app: app)
```

**Gameplay to Pause:**
```swift
// Push — game state preserved underneath (no transition needed)
app.sceneManager.push(PauseScene(), app: app)
```

**Unpause:**
```swift
// Pop — returns to the game scene
app.sceneManager.pop(app: app)
```

**Game Over to Menu (fresh start):**
```swift
// ReplaceAll with fade — clear everything
app.sceneManager.replaceAll(with: MenuScene(), transition: .fade(), app: app)
```
