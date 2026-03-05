# Animation State Machine

Declarative state machine for managing animation clip transitions. Sits on top of the existing [Animation System](../architecture.md) — manages *which clip* is on `SpriteAnimator`, while `AnimationSystem` continues frame advancement.

## AnimationStateMachine

`Sources/Agilis/Animation/AnimationStateMachine.swift`

Component storing states, transitions, parameters, and current state. Conforms to `Component`, `Sendable`, and `SerializableComponent`.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `states` | `[String: AnimationState]` | All defined states, keyed by name |
| `transitions` | `[AnimationTransition]` | Per-state transitions |
| `anyStateTransitions` | `[AnimationTransition]` | Transitions available from any state |
| `defaultStateName` | `String` | Entry/default state name |
| `currentStateName` | `String` | Currently active state name |
| `timeInState` | `Float` | Seconds elapsed in the current state |
| `previousStateName` | `String?` | State before the most recent transition |
| `parameters` | `[String: ParameterValue]` | Named parameters for transition conditions |
| `currentState` | `AnimationState?` | Current state definition (read-only computed) |

### Initialization

```swift
public init(defaultState: String)
```

### State Definition

Fluent methods (`@discardableResult`):

```swift
mutating func addState(_ name: String, clip: AnimationClip, speed: Float = 1.0) -> Self
mutating func addState(_ id: StateID, clip: AnimationClip, speed: Float = 1.0) -> Self
```

### Transition Definition

Fluent methods (`@discardableResult`):

```swift
mutating func addTransition(from: String, to: String,
                            conditions: [TransitionCondition],
                            exitTime: Float? = nil) -> Self

mutating func addAnyStateTransition(to: String,
                                    conditions: [TransitionCondition],
                                    exitTime: Float? = nil) -> Self
```

Type-safe overloads accepting `StateID` are also available.

### Parameter Setters

```swift
mutating func setBool(_ name: String, _ value: Bool)
mutating func setFloat(_ name: String, _ value: Float)
mutating func setInt(_ name: String, _ value: Int)
mutating func setTrigger(_ name: String)
```

### Parameter Getters

```swift
func getBool(_ name: String) -> Bool        // false if missing
func getFloat(_ name: String) -> Float      // 0 if missing
func getInt(_ name: String) -> Int          // 0 if missing
func isTriggerSet(_ name: String) -> Bool
```

### Type-Safe Identifiers

For compile-time safety, use `ParameterID<T>` and `StateID`:

```swift
public struct StateID: Hashable, Sendable, ExpressibleByStringLiteral {
    public let name: String
    public init(_ name: String)
}

public struct ParameterID<T>: Hashable, Sendable {
    public let name: String
    public init(_ name: String)
}
```

All parameter setters/getters and state/transition methods have `ParameterID<T>` / `StateID` overloads:

```swift
let speed = ParameterID<Float>("speed")
let isDead = ParameterID<Bool>("isDead")
let idle: StateID = "idle"

sm.setFloat(speed, 5.0)
sm.addTransition(from: idle, to: "walk",
    conditions: [.floatGreater(speed, 0.1)])
```

---

## AnimationState

```swift
public struct AnimationState: Sendable, Equatable, Codable {
    public var name: String
    public var clip: AnimationClip
    public var speed: Float           // Speed multiplier (default 1.0)
}
```

---

## AnimationTransition

```swift
public struct AnimationTransition: Sendable, Equatable, Codable {
    public var from: String           // Empty string = any-state transition
    public var to: String
    public var conditions: [TransitionCondition]
    public var exitTime: Float?       // Optional: 0-1 normalized gating
}
```

When `exitTime` is set, the transition only fires after the animator's progress exceeds that value (0.0 = start, 1.0 = end of clip).

---

## TransitionCondition

```swift
public enum TransitionCondition: Sendable, Equatable, Codable {
    case boolEquals(String, Bool)
    case floatGreater(String, Float)
    case floatLess(String, Float)
    case intEquals(String, Int)
    case trigger(String)
    case animationFinished         // oneShot clip completed
    case animationLooped           // clip looped this tick
    case afterTime(Float)          // seconds in current state
}
```

Type-safe factory methods available (e.g., `.floatGreater(ParameterID<Float>, Float)`).

---

## ParameterValue

```swift
public enum ParameterValue: Sendable, Equatable, Codable {
    case bool(Bool)
    case float(Float)
    case int(Int)
    case trigger(Bool)    // Consumed on successful transition
}
```

---

## AnimationStateChanged

Event emitted on the world when a state transition occurs:

```swift
public struct AnimationStateChanged: Event {
    public let entity: Entity
    public let from: String
    public let to: String
}
```

---

## AnimationStateMachineSystem

`Sources/Agilis/Animation/AnimationStateMachineSystem.swift`

Priority 45 — runs before `AnimationSystem` (50) so clip switches happen before frame advancement.

```swift
public final class AnimationStateMachineSystem: System {
    public init(priority: Int = 45)
    public var onStateChanged: ((Entity, String, String) -> Void)?
}
```

### Component Access

Reads `SpriteAnimator`. Writes `AnimationStateMachine` and `SpriteAnimator`. Emits `AnimationStateChanged` events.

### Transition Evaluation

Each tick:
1. Advance `timeInState` by `deltaTime`
2. Check any-state transitions first (skip if destination == current state)
3. Check per-state transitions (filtered by `from == currentStateName`)
4. First matching transition wins

### Trigger Safety

Two-pass condition evaluation:
1. First pass verifies ALL conditions without consuming triggers
2. Second pass consumes triggers only if all conditions passed

This prevents partial consumption on failed multi-condition transitions.

---

## Usage

### Setup

```swift
let smSystem = AnimationStateMachineSystem()
let animSystem = AnimationSystem()
world.addSystem(smSystem)    // priority 45
world.addSystem(animSystem)  // priority 50
```

### Defining States and Transitions

```swift
var sm = AnimationStateMachine(defaultState: "idle")
sm.addState("idle", clip: idleClip)
sm.addState("walk", clip: walkClip)
sm.addState("run", clip: runClip)
sm.addState("attack", clip: attackClip, speed: 1.5)
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

// Any-state transition (fires from any state except "death" itself)
sm.addAnyStateTransition(to: "death",
    conditions: [.boolEquals("isDead", true)])

world.addComponent(sm, to: entity)
```

### Driving Parameters

Game logic sets parameters; the system evaluates transitions automatically:

```swift
world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
    sm.setFloat("speed", velocity.length)
    sm.setBool("isGrounded", onGround)
    if attackPressed { sm.setTrigger("attack") }
}
```

### Reacting to State Changes

```swift
world.on(AnimationStateChanged.self) { event in
    if event.to == "death" {
        spawnDeathParticles(at: event.entity)
    }
}
```

### Exit Time Gating

```swift
// Only transition after 80% of attack animation plays
sm.addTransition(from: "attack", to: "idle",
    conditions: [.animationFinished],
    exitTime: 0.8)
```

---

## Key Behaviors

- **Priority 45** — runs before AnimationSystem (50) so `SpriteAnimator` gets the new clip before frame advancement
- **`forceSetClip`** — state machine always resets clips on transition (even same-name transitions won't occur due to any-state self-skip)
- **Speed override** — each state's `speed` is applied to the `SpriteAnimator` on transition
- **Serializable** — `AnimationStateMachine` conforms to `SerializableComponent` for save/load support
- **Time in state** — `timeInState` resets to 0 on each transition, used by `.afterTime` condition
