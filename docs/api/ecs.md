# Entity-Component-System

## Overview

Agilis provides a full-featured ECS where:

- **Entities** are lightweight generational IDs (detect stale references)
- **Components** are data containers (structs or classes)
- **Systems** contain behavior, receiving a `SystemContext` with world access and deferred commands
- **World** manages all entities, components, systems, hierarchy, metadata, and lifecycle events

Components are stored in **sparse sets** for cache-friendly iteration. Type-safe **`forEach` queries** replace verbose manual component lookups.

## Entity

`Sources/Agilis/Core/Entity.swift`

A lightweight handle using generational indexing. When an entity is destroyed and its slot recycled, the generation increments — any stale handle with the old generation fails `isAlive` checks.

```swift
struct Entity: Sendable, Hashable {
    let index: UInt32       // Slot index in the entity allocator
    let generation: UInt32  // Generation counter for stale reference detection
}
```

`Entity.null` is a sentinel value representing no entity.

## Component

`Sources/Agilis/Core/Component.swift`

A marker protocol for data containers. Both structs and classes can be components. Structs are recommended for cache-friendly iteration.

```swift
protocol Component {}
```

### Example Components

```swift
struct Position: Component {
    var x: Float
    var y: Float
}

struct Velocity: Component {
    var dx: Float
    var dy: Float
}

struct Health: Component {
    var hp: Int
}

// Zero-size tag components work too
struct Frozen: Component {}
```

## System

`Sources/Agilis/Core/System.swift`

Systems contain game logic that operates on entities with specific components. They receive a `SystemContext` providing world access and a command buffer for deferred mutations.

```swift
protocol System: AnyObject {
    var priority: Int { get }                   // Lower runs first (default: 0)
    func setup(world: World)                    // Called once when added (default: no-op)
    func update(context: SystemContext)          // Called every fixed-timestep tick
}
```

### SystemContext

```swift
struct SystemContext {
    let world: World           // Read/write access to the ECS world
    let deltaTime: Double      // Fixed-timestep delta time
    let commands: CommandBuffer // Deferred mutations (flushed after each system)
}
```

### Example System

```swift
final class MovementSystem: System {
    func update(context: SystemContext) {
        context.world.forEach { (entity: Entity, pos: inout Position, vel: inout Velocity) in
            pos.x += vel.dx * Float(context.deltaTime)
            pos.y += vel.dy * Float(context.deltaTime)
        }
    }
}
```

### System Priority

Systems with lower `priority` values run first. Systems with the same priority run in insertion order.

```swift
final class PhysicsSystem: System {
    var priority: Int { -10 }  // Runs early
    func update(context: SystemContext) { /* ... */ }
}

final class RenderPrepSystem: System {
    var priority: Int { 10 }  // Runs late
    func update(context: SystemContext) { /* ... */ }
}
```

## World

`Sources/Agilis/Core/World.swift`

The central ECS manager. Called automatically by the game loop each tick.

### Entity Management

```swift
func createEntity() -> Entity          // Create a new entity (reuses recycled slots)
func destroyEntity(_ entity: Entity)   // Destroy entity, its children, and all components
func isAlive(_ entity: Entity) -> Bool // Check if handle is still valid (generation matches)
var entityCount: Int                   // Number of living entities
var allEntities: [Entity]              // All living entities
```

### Component Management

```swift
func addComponent<T: Component>(_ component: T, to entity: Entity)
func getComponent<T: Component>(_ type: T.Type, from entity: Entity) -> T?
func updateComponent<T: Component>(_ type: T.Type, on entity: Entity, _ body: (inout T) -> Void) -> Bool
func removeComponent<T: Component>(_ type: T.Type, from entity: Entity)
func hasComponent<T: Component>(_ type: T.Type, on entity: Entity) -> Bool
```

### Type-Safe Queries

The `forEach` method iterates all entities with the required component types, providing direct `inout` access. Overloads support 1–8 component types.

```swift
// Single component
world.forEach { (entity: Entity, pos: inout Position) in
    pos.x += 1
}

// Two components — only entities with BOTH are iterated
world.forEach { (entity: Entity, pos: inout Position, vel: inout Velocity) in
    pos.x += vel.dx
    pos.y += vel.dy
}

// Three components
world.forEach { (entity: Entity, pos: inout Position, vel: inout Velocity, hp: inout Health) in
    pos.x += vel.dx
    hp.hp -= 1
}
```

### System Management

```swift
func addSystem(_ system: System, priority: Int? = nil)  // Calls setup() immediately
func removeSystem(_ system: System)
func update(deltaTime: Double)   // Runs all systems in priority order (called by game loop)
```

### Command Buffer

During system iteration, direct world mutations can invalidate iteration state. The command buffer defers these operations until after the current system finishes.

```swift
final class SpawnSystem: System {
    func update(context: SystemContext) {
        context.world.forEach { (e: Entity, spawner: inout Spawner) in
            spawner.timer -= Float(context.deltaTime)
            if spawner.timer <= 0 {
                spawner.timer = spawner.interval
                // Deferred — applied after this system returns
                let bullet = context.commands.createEntity(in: context.world)
                context.commands.addComponent(Position(x: 0, y: 0), to: bullet)
                context.commands.addComponent(Velocity(dx: 200, dy: 0), to: bullet)
            }
        }
    }
}
```

CommandBuffer API:

```swift
func createEntity(in world: World) -> Entity
func destroyEntity(_ entity: Entity)
func addComponent<T: Component>(_ component: T, to entity: Entity)
func removeComponent<T: Component>(_ type: T.Type, from entity: Entity)
```

### Entity Hierarchy

Entities can have parent-child relationships. Destroying a parent recursively destroys all children.

```swift
func setParent(_ parent: Entity?, for child: Entity)
func children(of entity: Entity) -> [Entity]
func parent(of entity: Entity) -> Entity?
```

```swift
let ship = world.createEntity()
let turret = world.createEntity()
world.setParent(ship, for: turret)

world.children(of: ship)    // [turret]
world.parent(of: turret)    // ship
world.destroyEntity(ship)   // Also destroys turret
```

### Entity Names and Tags

Names are unique (one entity per name). Tags are many-to-many. Both are reverse-indexed for efficient lookup.

```swift
// Names
func setName(_ name: String, for entity: Entity)
func entity(named: String) -> Entity?
func name(of entity: Entity) -> String?

// Tags
func addTag(_ tag: String, to entity: Entity)
func removeTag(_ tag: String, from entity: Entity)
func hasTag(_ tag: String, on entity: Entity) -> Bool
func entitiesWithTag(_ tag: String) -> [Entity]
```

```swift
let player = world.createEntity()
world.setName("Player1", for: player)
world.addTag("team_red", to: player)
world.addTag("controllable", to: player)

if let p = world.entity(named: "Player1") { /* ... */ }
let redTeam = world.entitiesWithTag("team_red")
```

### Component Lifecycle Events

Register handlers that fire when components are added to or removed from entities.

```swift
func onComponentAdded<T: Component>(_ type: T.Type, handler: (Entity, World) -> Void)
func onComponentRemoved<T: Component>(_ type: T.Type, handler: (Entity, World) -> Void)
```

```swift
world.onComponentAdded(Health.self) { entity, world in
    print("Entity \(entity.index) gained health")
}

world.onComponentRemoved(Health.self) { entity, world in
    print("Entity \(entity.index) lost health")
}
```

Remove handlers also fire when an entity is destroyed (for each component it had).

## Prefabs

`Sources/Agilis/Core/Prefab.swift`

Reusable entity templates with predefined components, names, tags, and child prefabs.

```swift
var enemyPrefab = Prefab()
enemyPrefab.add(Position(x: 0, y: 0))
enemyPrefab.add(Velocity(dx: 0, dy: 0))
enemyPrefab.add(Health(hp: 50))
enemyPrefab.withTag("enemy")

// Spawn 10 enemies
for i in 0..<10 {
    let enemy = enemyPrefab.instantiate(in: world)
    world.addComponent(Position(x: Float(i) * 100, y: 300), to: enemy)
}
```

Prefabs can include child prefabs that are automatically parented:

```swift
var turretPrefab = Prefab()
turretPrefab.add(Position(x: 10, y: 0))

var shipPrefab = Prefab()
shipPrefab.add(Position(x: 100, y: 200))
shipPrefab.addChild(turretPrefab)

let ship = shipPrefab.instantiate(in: world)  // turret is auto-parented
```

## Serialization

`Sources/Agilis/Serialization/`

Save and load ECS world state to JSON. Uses a registry-based type system for component serialization.

### SerializableComponent

```swift
protocol SerializableComponent: Component, Codable {
    static var componentName: String { get }
}
```

Built-in conformances: `Transform2D`, `PreviousTransform2D`, `Velocity2D`, `RigidBody2D`, `Collider2D`, `Sprite`, `SpriteAnimator`, `ParticleEmitter`, `Light2D`, `ShadowCaster2D`, `AnimationStateMachine`, `NormalMapData`.

User components can conform by implementing `SerializableComponent`:

```swift
struct Health: SerializableComponent {
    static var componentName: String { "Health" }
    var hp: Int
}
```

### WorldSerializer

```swift
let serializer = WorldSerializer()
serializer.registerDefaults()        // Registers all 12 built-in types
serializer.register(Health.self)     // Register custom component

// Save
let data = try serializer.encode(world: world)

// Load
let newWorld = World()
let remap = try serializer.decode(from: data, into: newWorld)
// remap[oldIndex] → newEntity
```

### What Gets Serialized

- All entities and their components (registered types only)
- Entity hierarchy (parent/child)
- Entity metadata (names, tags)
- Entity indices are remapped on decode (old slots -> fresh entities)

### What Does NOT Get Serialized

- Systems (re-add them after loading)
- GPU handles (`TextureHandle`, `SoundHandle`) serialize as raw IDs (invalid after reload)
- `ParticleEmitter` internal pool state (config only)
- `SpriteAnimator.lastEvent` (transient)

## Full Example

```swift
struct Position: Component { var x: Float; var y: Float }
struct Velocity: Component { var dx: Float; var dy: Float }
struct Health: Component { var hp: Int }

final class MovementSystem: System {
    func update(context: SystemContext) {
        context.world.forEach { (e: Entity, pos: inout Position, vel: inout Velocity) in
            pos.x += vel.dx * Float(context.deltaTime)
            pos.y += vel.dy * Float(context.deltaTime)
        }
    }
}

final class GameScene: Scene {
    func didEnter(app: Application) {
        let world = app.world

        // Create entities
        let player = world.createEntity()
        world.addComponent(Position(x: 100, y: 200), to: player)
        world.addComponent(Velocity(dx: 0, dy: 0), to: player)
        world.addComponent(Health(hp: 100), to: player)
        world.setName("Player", for: player)
        world.addTag("friendly", to: player)

        // Spawn enemies from a prefab
        var enemyPrefab = Prefab()
        enemyPrefab.add(Position(x: 0, y: 0))
        enemyPrefab.add(Velocity(dx: -50, dy: 0))
        enemyPrefab.add(Health(hp: 30))
        enemyPrefab.withTag("enemy")

        for i in 0..<5 {
            let enemy = enemyPrefab.instantiate(in: world)
            world.addComponent(Position(x: 500 + Float(i) * 80, y: 200), to: enemy)
        }

        // Add systems (priority controls execution order)
        world.addSystem(MovementSystem())
    }
}
```

## Read-Only Queries

For cases where you don't need to mutate components, `forEachReadOnly` avoids `inout` overhead. Overloads support 1–8 component types (same as `forEach`).

```swift
// Non-mutating iteration — components are passed by value
world.forEachReadOnly { (entity: Entity, pos: Position, vel: Velocity) in
    print("Entity \(entity.index) at (\(pos.x), \(pos.y))")
}
```

---

## Event Bus

`Sources/Agilis/Core/World.swift`

Lightweight pub/sub for decoupled game logic. Separate from component lifecycle events (`onComponentAdded`/`onComponentRemoved`).

### Event Protocol

```swift
protocol Event {}
```

Structs recommended. No `Sendable` constraint (framework is single-threaded).

### World Event API

```swift
func on<T: Event>(_ type: T.Type, handler: (T) -> Void) -> Int  // Subscribe, returns handler index
func emit<T: Event>(_ event: T)                                   // Synchronous dispatch
func removeHandlers<T: Event>(for type: T.Type)                   // Remove all handlers for a type
func removeAllEventHandlers()                                      // Clear all event handlers
```

### Behavior

- **Synchronous** — handlers fire immediately during `emit()`
- **Re-entrant safe** — `emit()` iterates a snapshot; emitting from a handler works. Handlers added during emission don't fire for the current emit.
- **Type-keyed** — uses `ObjectIdentifier` for O(1) type dispatch

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

### Cleanup

Remove event handlers during scene exit to prevent dangling callbacks:

```swift
func willExit(app: Application) {
    app.world.removeAllEventHandlers()
}
```

---

## Component Access & Parallel Scheduling

`Sources/Agilis/Core/ComponentAccess.swift`

Systems can declare which component types they read and write, enabling automatic parallel execution of non-conflicting systems.

### ComponentAccess

```swift
struct ComponentAccess {
    init(reads: [any Component.Type] = [],
         writes: [any Component.Type] = [],
         mutatesEntities: Bool = false,
         emitsEvents: Bool = false)
}
```

### System Declaration

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

### Default Behavior

Systems without explicit `componentAccess` get the maximally conservative default (`mutatesEntities: true, emitsEvents: true`), forcing sequential execution. Only systems that explicitly declare access can run in parallel.

### Parallel Scheduling

Opt-in via `world.parallelSchedulingEnabled = true` and `Application.runAsync()`:

```swift
world.parallelSchedulingEnabled = true
try await app.runAsync()
```

The `SystemScheduler` builds execution stages: systems within each stage run concurrently via `TaskGroup`, while stages execute sequentially. Two systems can share a stage if:

1. Neither declares `mutatesEntities: true`
2. Neither declares `emitsEvents: true`
3. Their write sets don't overlap each other's read or write sets

Uses `ComponentBitset` (256-bit, 4x UInt64) for O(1) conflict detection. CommandBuffers are flushed in priority order after each stage.

See [Application](application.md) for `runAsync()` details.

---

## Storage Architecture

Components are stored in **sparse sets** — one per component type. Each sparse set maintains a dense contiguous array for fast iteration and a sparse array for O(1) entity-to-index lookup.

| Operation | Complexity |
|-----------|-----------|
| Create entity | O(1) |
| Destroy entity | O(c) where c = number of component types on entity |
| Add component | O(1) |
| Get component | O(1) |
| forEach query | O(n) where n = size of smallest component set in query |
| System update | O(s) where s = number of systems |
