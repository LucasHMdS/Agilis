# Tweening

Animate arbitrary component properties over time using easing functions. Centralized storage (like JointStore) — tweens are NOT ECS components.

## TweenHandle

`Sources/Agilis/Tween/TweenHandle.swift`

Opaque `UInt32` handle (same pattern as `JointHandle`, `TextureHandle`). `.invalid` = id 0.

```swift
public struct TweenHandle: Sendable, Hashable {
    public let id: UInt32
    public static let invalid = TweenHandle(id: 0)
}
```

---

## TweenTarget

`Sources/Agilis/Tween/TweenTarget.swift`

Enum describing what property a tween animates:

```swift
public enum TweenTarget {
    case position(from: Vector2, to: Vector2)
    case rotation(from: Float, to: Float)
    case scale(from: Vector2, to: Vector2)
    case spriteColor(from: Color, to: Color)
    case spriteAlpha(from: Float, to: Float)
    case custom(apply: (World, Entity, Float) -> Void)
}
```

---

## TweenStep

`Sources/Agilis/Tween/TweenTarget.swift`

Steps for building tween sequences:

```swift
public enum TweenStep {
    case moveTo(target: Vector2, duration: Float, easing: EasingFunction = .linear)
    case rotateTo(target: Float, duration: Float, easing: EasingFunction = .linear)
    case scaleTo(target: Vector2, duration: Float, easing: EasingFunction = .linear)
    case tintTo(target: Color, duration: Float, easing: EasingFunction = .linear)
    case fadeTo(alpha: Float, duration: Float, easing: EasingFunction = .linear)
    case fadeOut(duration: Float, easing: EasingFunction = .linear)
    case fadeIn(duration: Float, easing: EasingFunction = .linear)
    case wait(duration: Float)
    case callback(() -> Void)
    case custom(duration: Float, easing: EasingFunction = .linear,
                apply: (World, Entity, Float) -> Void)
}
```

Sequences read current component values at each step's start time, enabling relative animations.

---

## Interpolatable

`Sources/Agilis/Tween/Interpolatable.swift`

Protocol for types that support linear interpolation:

```swift
public protocol Interpolatable: Sendable {
    func interpolated(to target: Self, t: Float) -> Self
}
```

Built-in conformances: `Float`, `Vector2`, `Color`.

---

## TweenCompleted

`Sources/Agilis/Tween/TweenTypes.swift`

Event emitted on the world when a tween finishes:

```swift
public struct TweenCompleted: Event {
    public let handle: TweenHandle
    public let entity: Entity
}
```

---

## TweenSystem

`Sources/Agilis/Tween/TweenSystem.swift`

The central system for creating, updating, and managing tweens. Priority 25 (runs between gameplay systems at 0 and animation systems at 50).

```swift
public final class TweenSystem: System {
    public init(priority: Int = 25)
    public var onTweenCompleted: ((TweenHandle, Entity) -> Void)?
}
```

### Component Access

Writes `Transform2D` and `Sprite`. Emits `TweenCompleted` events.

### Creation Methods

All return `TweenHandle` and are `@discardableResult`.

```swift
func moveTo(_ entity: Entity, target: Vector2, duration: Float,
            easing: EasingFunction = .linear, delay: Float = 0,
            in world: World) -> TweenHandle

func moveFromTo(_ entity: Entity, from: Vector2, to: Vector2,
                duration: Float, easing: EasingFunction = .linear,
                delay: Float = 0) -> TweenHandle

func rotateTo(_ entity: Entity, target: Float, duration: Float,
              easing: EasingFunction = .linear, delay: Float = 0,
              in world: World) -> TweenHandle

func scaleTo(_ entity: Entity, target: Vector2, duration: Float,
             easing: EasingFunction = .linear, delay: Float = 0,
             in world: World) -> TweenHandle

func scaleUniformTo(_ entity: Entity, target: Float, duration: Float,
                    easing: EasingFunction = .linear, delay: Float = 0,
                    in world: World) -> TweenHandle

func tintTo(_ entity: Entity, target: Color, duration: Float,
            easing: EasingFunction = .linear, delay: Float = 0,
            in world: World) -> TweenHandle

func fadeTo(_ entity: Entity, alpha: Float, duration: Float,
            easing: EasingFunction = .linear, delay: Float = 0,
            in world: World) -> TweenHandle

func fadeOut(_ entity: Entity, duration: Float,
             easing: EasingFunction = .linear, delay: Float = 0,
             in world: World) -> TweenHandle

func fadeIn(_ entity: Entity, duration: Float,
            easing: EasingFunction = .linear, delay: Float = 0,
            in world: World) -> TweenHandle

func custom(_ entity: Entity, duration: Float,
            easing: EasingFunction = .linear, delay: Float = 0,
            apply: (World, Entity, Float) -> Void) -> TweenHandle
```

### Modifiers

Fluent methods (`@discardableResult`, return the same `TweenHandle`):

```swift
func setRepeat(_ handle: TweenHandle, count: Int) -> TweenHandle   // -1 = infinite
func setYoyo(_ handle: TweenHandle, enabled: Bool = true) -> TweenHandle
func onStart(_ handle: TweenHandle, _ callback: () -> Void) -> TweenHandle
func onUpdate(_ handle: TweenHandle, _ callback: (Float) -> Void) -> TweenHandle
func onComplete(_ handle: TweenHandle, _ callback: () -> Void) -> TweenHandle
```

### Sequences

```swift
func sequence(_ entity: Entity, steps: [TweenStep],
              repeatCount: Int = 0, in world: World) -> TweenHandle

func onSequenceComplete(_ handle: TweenHandle,
                        _ callback: () -> Void) -> TweenHandle
```

### Lifecycle Control

```swift
func cancel(_ handle: TweenHandle)
func cancelAll(on entity: Entity)
func pause(_ handle: TweenHandle)
func resume(_ handle: TweenHandle)
func pauseAll(on entity: Entity)
func resumeAll(on entity: Entity)
var tweenCount: Int { get }
func isActive(_ handle: TweenHandle) -> Bool
func removeAll()
```

### Material Uniform Tweening

```swift
func tweenMaterialUniform(_ entity: Entity, uniform name: String,
                          to targetValue: Float, duration: Float,
                          easing: EasingFunction = .linear, delay: Float = 0,
                          in world: World) -> TweenHandle

func tweenMaterialColor(_ entity: Entity, uniform name: String,
                        to targetColor: Color, duration: Float,
                        easing: EasingFunction = .linear, delay: Float = 0,
                        in world: World) -> TweenHandle
```

### Debug

```swift
func debugTweenInfo(world: World) -> [TweenDebugInfo]
```

Returns snapshots of all active tweens for use with the tween debug renderer.

---

## TweenDebugInfo

`Sources/Agilis/Debug/TweenDebugRenderer.swift`

```swift
public struct TweenDebugInfo: Sendable {
    public let entity: Entity
    public let targetType: String
    public let progress: Float
    public let targetPosition: Vector2?
}
```

Used with `renderer.drawTweenDebug(infos:world:font:options:)` for visualization. See [Debug](debug.md).

---

## Usage

### Basic Tweens

```swift
let tweens = TweenSystem()
world.addSystem(tweens)

// Move with ease-out
tweens.moveTo(player, target: Vector2(x: 300, y: 200),
              duration: 0.5, easing: .cubicOut, in: world)

// Rotate 90 degrees
tweens.rotateTo(player, target: Float.pi / 2,
                duration: 0.3, easing: .sineInOut, in: world)

// Fade out
tweens.fadeOut(enemy, duration: 0.5, easing: .quadIn, in: world)
```

### Repeat and Yoyo

```swift
// Pulsing scale (yoyo + infinite repeat)
let pulse = tweens.scaleTo(icon, target: Vector2(x: 1.2, y: 1.2),
                           duration: 0.3, easing: .sineInOut, in: world)
tweens.setYoyo(pulse)
tweens.setRepeat(pulse, count: -1)
```

### Sequences

```swift
tweens.sequence(player, steps: [
    .moveTo(target: Vector2(x: 300, y: 200), duration: 0.3, easing: .cubicOut),
    .wait(duration: 0.1),
    .fadeOut(duration: 0.2, easing: .quadIn),
    .callback { print("Player vanished!") }
], in: world)
```

### Completion Callbacks

```swift
let h = tweens.moveTo(bullet, target: impactPoint,
                      duration: 0.2, easing: .linear, in: world)
tweens.onComplete(h) { spawnExplosion(at: impactPoint) }
```

### Custom Tweens

```swift
tweens.custom(entity, duration: 1.0, easing: .linear) { world, entity, t in
    world.updateComponent(Health.self, on: entity) { h in
        h.current = lerp(startHP, 100, t: t)
    }
}
```

### Event Handling

```swift
world.on(TweenCompleted.self) { event in
    print("Tween \(event.handle.id) finished on entity \(event.entity.index)")
}
```

---

## Key Behaviors

- **Priority 25** — runs between gameplay (0) and animation (50)
- **Auto-cancel on entity death** — tweens targeting destroyed entities are removed automatically
- **Delay support** — all creation methods accept an optional `delay` parameter
- **Yoyo** — reverses direction at the end, then forward again (one cycle = forward + reverse)
- **Repeat** — count of additional plays (-1 = infinite). Combined with yoyo for ping-pong effects.
- **Sequence steps** read current component values at step start time, enabling relative animations
- **TweenCompleted event** emitted on the world when a tween finishes (also fires `onTweenCompleted` callback)
