# Physics

## PhysicsWorld2D

`Sources/Agilis/Physics/PhysicsWorld2D.swift`

The main physics system. Conforms to `System` and runs the full simulation pipeline each fixed-timestep tick.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `gravity` | `Vector2` | Gravity in pixels/s^2 (default: `(0, 980)`) |
| `events` | `[CollisionEvent]` | Collision events from the most recent tick |
| `onCollisionBegan` | `((CollisionEvent) -> Void)?` | Callback for new collisions |
| `onCollisionEnded` | `((CollisionEvent) -> Void)?` | Callback when collisions end |
| `velocityIterations` | `Int` | Joint solver velocity iterations per tick (default: `6`) |
| `positionIterations` | `Int` | Joint solver position iterations per tick (default: `2`) |
| `jointEvents` | `[JointEvent]` | Joint events from the most recent tick |
| `onJointBroken` | `((JointEvent) -> Void)?` | Callback when a joint breaks |
| `jointCount` | `Int` | Number of active joints |

### Setup

```swift
let physics = PhysicsWorld2D(
    gravity: Vector2(x: 0, y: 980),   // pixels/s^2
    cellSize: 64,                       // spatial hash grid cell size
    priority: 100                       // runs after gameplay systems
)
world.addSystem(physics)
```

### Pipeline

Each tick, the system executes:

1. Store `PreviousTransform2D` (for interpolated rendering)
2. Apply gravity and damping to dynamic bodies
3. Integrate velocity into position
4. **CCD sweep** — clamp fast-moving `useCCD` bodies to earliest time of impact (prevents tunneling)
5. Broad phase: spatial hash grid finds candidate pairs
6. Narrow phase: SAT collision tests, filtered by layer/mask
7. Impulse resolution + penetration correction
8. **Joint constraint solving** (pre-solve, warm start, velocity iterations, position iterations, break detection)
9. Generate collision events (began/ongoing/ended)
10. **Generate joint events** (broken joints, callbacks)

---

## Components

### Transform2D

`Sources/Agilis/Physics/PhysicsComponents.swift`

Standard position component for physics entities.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `position` | `Vector2` | `.zero` | World-space position |
| `rotation` | `Float` | `0` | Rotation in radians |
| `scale` | `Vector2` | `.one` | Scale factor |
| `matrix` | `Matrix3` | (computed) | Scale -> rotate -> translate |

### PreviousTransform2D

Snapshot of the previous frame's transform. Auto-updated by `PhysicsWorld2D` before integration.

| Property | Type | Default |
|----------|------|---------|
| `position` | `Vector2` | `.zero` |
| `rotation` | `Float` | `0` |

### Velocity2D

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `linear` | `Vector2` | `.zero` | Linear velocity in pixels/s |
| `angular` | `Float` | `0` | Angular velocity in rad/s |

### RigidBody2D

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `mass` | `Float` | `1` | Mass in arbitrary units |
| `inverseMass` | `Float` | (computed) | 1/mass, 0 for static/kinematic |
| `inertia` | `Float` | `0` | Moment of inertia (rotational mass). 0 = no angular response from joints |
| `inverseInertia` | `Float` | (computed) | 1/inertia, 0 when inertia is 0 |
| `effectiveInverseInertia` | `Float` | (computed) | Returns 0 for static/kinematic, `inverseInertia` for dynamic |
| `restitution` | `Float` | `0.2` | Bounciness (0-1) |
| `friction` | `Float` | `0.3` | Friction coefficient (0-1) |
| `gravityScale` | `Float` | `1` | Gravity multiplier (0 = no gravity) |
| `bodyType` | `BodyType` | `.dynamic` | `.dynamic`, `.static`, or `.kinematic` |
| `linearDamping` | `Float` | `0` | Velocity damping per second |
| `useCCD` | `Bool` | `false` | Enable continuous collision detection (prevents tunneling) |

#### Computing Inertia

Use the static helper to compute moment of inertia from a shape:

```swift
let inertia = RigidBody2D.computeInertia(mass: 5.0, shape: .circle(radius: 16))
// Circle:  I = 0.5 * m * r^2
// AABB:    I = m * (w^2 + h^2) / 12
// Polygon: area-weighted vertex formula
```

### Collider2D

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `shape` | `CollisionShape` | (required) | The collision shape |
| `offset` | `Vector2` | `.zero` | Offset from Transform2D position |
| `isTrigger` | `Bool` | `false` | Events only, no physics response |
| `layer` | `UInt32` | `1` | Which layer(s) this entity is on |
| `mask` | `UInt32` | `0xFFFFFFFF` | Which layers this entity collides with |

---

## Collision Shapes

`Sources/Agilis/Physics/CollisionShape.swift`

```swift
public enum CollisionShape: Sendable, Equatable {
    case aabb(halfExtents: Vector2)    // half-width, half-height
    case circle(radius: Float)
    case polygon(ConvexPolygon)        // convex, precomputed normals
}
```

### ConvexPolygon

```swift
let triangle = ConvexPolygon(vertices: [
    Vector2(x: 0, y: -30),
    Vector2(x: 26, y: 15),
    Vector2(x: -26, y: 15)
])
// Normals and local bounds are computed automatically
```

Vertices must be in counter-clockwise winding order (math coordinates). In screen coordinates (Y-down), this appears visually clockwise.

---

## Body Types

| Type | Gravity | Forces | Collision Response |
|------|---------|--------|-------------------|
| `.dynamic` | Yes | Yes | Pushed by other bodies |
| `.static` | No | No | Never moves |
| `.kinematic` | No | No | Pushes dynamic bodies |

Entities without a `RigidBody2D` are treated as static.

---

## Collision Layers

Two entities collide only if each entity's layer overlaps with the other's mask:

```swift
(a.layer & b.mask) != 0 && (b.layer & a.mask) != 0
```

Example:

```swift
struct PhysicsLayers {
    static let player: UInt32     = 1 << 0
    static let enemy: UInt32      = 1 << 1
    static let projectile: UInt32 = 1 << 2
}

// Player collides with enemies
world.addComponent(Collider2D(
    shape: .circle(radius: 16),
    layer: PhysicsLayers.player,
    mask: PhysicsLayers.enemy
), to: player)
```

---

## Collision Events

Events are available via `physics.events` or callbacks:

```swift
// Polling
for event in physics.events {
    switch event.type {
    case .began:   // First frame of contact
    case .ongoing: // Continued contact
    case .ended:   // Entities separated
    }
}

// Callbacks
physics.onCollisionBegan = { event in
    print("\(event.entityA) hit \(event.entityB)")
}
```

---

## Triggers

Set `isTrigger: true` on a `Collider2D` to generate collision events without physics response. Useful for zones, pickups, and damage areas.

```swift
world.addComponent(Collider2D(
    shape: .aabb(halfExtents: Vector2(x: 32, y: 32)),
    isTrigger: true
), to: pickupZone)
```

---

## NarrowPhase

`Sources/Agilis/Physics/NarrowPhase.swift`

Low-level collision detection for direct use outside the physics system:

```swift
let contact = NarrowPhase.test(
    shapeA: .circle(radius: 10), posA: posA, rotA: 0,
    shapeB: .aabb(halfExtents: Vector2(x: 20, y: 20)), posB: posB, rotB: 0
)
if let contact = contact {
    print("Normal: \(contact.normal), Depth: \(contact.penetration)")
}
```

All 6 shape pair combinations are handled. Rotated AABBs are automatically promoted to polygons.

---

## Continuous Collision Detection (CCD)

`Sources/Agilis/Physics/SweptCollision.swift`

Opt-in swept shape testing that prevents fast-moving bodies from tunneling through thin colliders. At high velocities, a body can move far enough in a single frame to skip entirely past a thin wall. CCD sweeps the body from its previous position to its integrated position, finds the earliest time of impact (TOI), and clamps the position there.

### Enabling CCD

Set `useCCD: true` on a `RigidBody2D`:

```swift
world.addComponent(RigidBody2D(
    mass: 1,
    gravityScale: 0,
    bodyType: .dynamic,
    useCCD: true
), to: bullet)
```

CCD only applies to **dynamic** bodies. Static and kinematic bodies are ignored even if `useCCD` is set.

### How It Works

After velocity integration (pipeline step 3), the system:

1. Collects all CCD-enabled dynamic bodies whose translational displacement or angular sweep extent exceeds their shape's minimum extent
2. For each CCD body, sweeps against all collidable entities (with AABB pre-filtering)
3. Computes the earliest time of impact (TOI) using `SweptCollision.timeOfImpact()` — when the candidate is also a CCD body, uses relative velocity (subtracts candidate's displacement from sweep endpoint)
4. Clamps the body's position and rotation to the TOI point (with a tiny nudge past contact so the narrow phase detects overlap)

The discrete narrow phase then runs normally at the corrected position, generating proper contacts, impulse response, and collision events.

### SweptCollision API

Stateless geometry module (same pattern as `NarrowPhase`, `SpatialQuery`):

```swift
// Unified dispatcher — returns TOI in [0,1] or nil
// Single-rotation sweep (exact for circle/AABB pairs)
SweptCollision.timeOfImpact(
    movingShape: .circle(radius: 3),
    startPos: prevPos,
    endPos: currentPos,
    movingRot: rotation,
    staticShape: .aabb(halfExtents: Vector2(x: 2, y: 50)),
    staticPos: wallPos,
    staticRot: 0
) // → Float? (e.g., 0.47)

// Angular sweep (rotation-aware, conservative bounding circle for non-circles)
SweptCollision.timeOfImpact(
    movingShape: .aabb(halfExtents: Vector2(x: 50, y: 2)),
    startPos: prevPos,
    endPos: currentPos,
    startRot: prevRotation,
    endRot: currentRotation,
    staticShape: .aabb(halfExtents: Vector2(x: 2, y: 50)),
    staticPos: wallPos,
    staticRot: 0
) // → Float? — uses bounding circle when angular displacement > 0

// Helpers
SweptCollision.minimumExtent(of: shape)         // smallest dimension (early-out threshold)
SweptCollision.boundingRadius(of: shape)         // center-to-farthest-point (polygon fallback)
SweptCollision.angularSweepExtent(of: shape,
    angularDisplacement: dRot)                   // max arc distance from rotation
```

### Shape Pair Support

| Moving \ Static | Circle | AABB | Polygon |
|---|---|---|---|
| **Circle** | Exact (Minkowski + ray) | Exact (expanded AABB + corners) | Exact (edge offset + vertex circles) |
| **AABB** | Exact (rounded rect) | Exact (Minkowski difference) | Conservative (bounding circle) |
| **Polygon** | Conservative | Conservative | Conservative |

Circle and AABB pairs use exact Minkowski-based algorithms. Polygon-involving pairs use a conservative bounding circle fallback — may clamp slightly early but guarantees no tunneling.

### Behavior Details

- **Triggers skipped** — CCD does not prevent passing through trigger zones
- **Layer/mask respected** — uses the same `shouldCollide` bidirectional check as discrete collision
- **Early-out** — bodies with translational displacement less than `minimumExtent(of: shape)` AND angular sweep extent less than the same threshold skip the sweep entirely
- **Angular sweep** — non-circle shapes with angular velocity use a conservative bounding circle to prevent rotational tunneling. Rotation is clamped alongside position at the time of impact. Circles are rotationally symmetric and always use exact path regardless of angular velocity.
- **Bilateral CCD** — when two CCD-enabled dynamic bodies approach each other, each sweep accounts for the other's displacement using relative velocity. This prevents two fast-moving CCD bodies from passing through each other.
- **Collision events fire** — the narrow phase detects contact at the clamped position and generates events normally

### Usage

```swift
// Fast-moving bullet with CCD
let bullet = world.createEntity()
world.addComponent(Transform2D(position: gunTip), to: bullet)
world.addComponent(PreviousTransform2D(position: gunTip), to: bullet)
world.addComponent(Velocity2D(linear: aimDir * 5000), to: bullet)
world.addComponent(RigidBody2D(
    mass: 0.1, gravityScale: 0, bodyType: .dynamic, useCCD: true
), to: bullet)
world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

// The bullet will not tunnel through thin walls
```

### Performance

CCD adds a brute-force sweep per CCD body per tick. Use it only for bodies that actually need tunneling prevention (bullets, fast projectiles). Slow-moving bodies automatically skip the sweep when displacement is small relative to shape size.

---

## Ray Casting & Spatial Queries

Query the physics world for intersections without running the full collision pipeline.

### Raycast

```swift
// Closest hit along a ray
func raycast(world: World, origin: Vector2, direction: Vector2,
             maxDistance: Float, layerMask: UInt32 = 0xFFFFFFFF) -> RaycastHit?

// All hits along a ray, sorted by distance
func raycastAll(world: World, origin: Vector2, direction: Vector2,
                maxDistance: Float, layerMask: UInt32 = 0xFFFFFFFF) -> [RaycastHit]
```

### Point Query

```swift
// All entities containing a point
func pointQuery(world: World, point: Vector2,
                layerMask: UInt32 = 0xFFFFFFFF) -> [PointQueryResult]
```

### Area Query

```swift
// All entities overlapping a rectangle
func areaQuery(world: World, rect: Rect,
               layerMask: UInt32 = 0xFFFFFFFF) -> [AreaQueryResult]
```

### Result Types

| Type | Properties |
|------|------------|
| `RaycastHit` | `entity`, `point` (world-space), `normal` (outward), `distance` |
| `PointQueryResult` | `entity` |
| `AreaQueryResult` | `entity` |

### Layer Mask Filtering

Single mask check: `collider.layer & layerMask != 0`. No bidirectional check (queries are not entities).

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

---

## Physics Joints

`Sources/Agilis/Physics/Joint2D.swift`, `JointStore.swift`, `JointSolver.swift`

Constrain pairs of entities with physics joints. Six joint types are available: revolute (pin/hinge), distance (spring), weld (fixed), prismatic (slider), rope (max distance), and motor (driven offset). Joints use a sequential impulse solver with warm starting, Baumgarte stabilization, and iterative velocity/position correction.

### Joint Handle

Joints are referenced by opaque handles:

```swift
public struct JointHandle: Sendable, Hashable {
    public let id: UInt32
    public static let invalid = JointHandle(id: 0)
}
```

### Creating Joints

```swift
let handle = physics.createJoint(.revolute(RevoluteJointDef(
    entityA: wall, entityB: door,
    anchor: Vector2(x: 100, y: 200)
)), in: world)
```

### Destroying Joints

```swift
physics.destroyJoint(handle)
physics.removeAllJoints()
```

### Revolute Joint (Pin/Hinge)

Constrains two bodies to rotate around a shared anchor point. Supports optional angle limits and a motor.

```swift
let hinge = physics.createJoint(.revolute(RevoluteJointDef(
    entityA: wall, entityB: door,
    anchor: Vector2(x: 100, y: 200),
    enableLimit: true,
    lowerAngle: -Float.pi / 2,
    upperAngle: Float.pi / 2,
    enableMotor: true,
    motorSpeed: 2.0,
    maxMotorTorque: 100.0,
    maxForce: 500.0   // 0 = unbreakable
)), in: world)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entityA` | `Entity` | (required) | First body |
| `entityB` | `Entity` | (required) | Second body |
| `anchor` | `Vector2` | (required) | Shared anchor in world space |
| `localAnchorA/B` | `Vector2?` | `nil` | Override local anchors (computed from `anchor` if nil) |
| `enableLimit` | `Bool` | `false` | Enable angle limits |
| `lowerAngle` | `Float` | `0` | Lower angle limit (radians) |
| `upperAngle` | `Float` | `0` | Upper angle limit (radians) |
| `enableMotor` | `Bool` | `false` | Enable motor |
| `motorSpeed` | `Float` | `0` | Target motor angular velocity (rad/s) |
| `maxMotorTorque` | `Float` | `0` | Maximum motor torque |
| `maxForce` | `Float` | `0` | Breaking force threshold (0 = unbreakable) |
| `maxTorque` | `Float` | `0` | Breaking torque threshold (0 = unbreakable) |

### Distance Joint (Spring)

Maintains a fixed or spring-like distance between two anchor points.

```swift
let spring = physics.createJoint(.distance(DistanceJointDef(
    entityA: anchor, entityB: player,
    anchorA: Vector2(x: 200, y: 0),
    anchorB: Vector2(x: 200, y: 100),
    frequencyHz: 2.0,     // 0 = rigid constraint
    dampingRatio: 0.5     // 0 = no damping, 1 = critical
)), in: world)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entityA` | `Entity` | (required) | First body |
| `entityB` | `Entity` | (required) | Second body |
| `anchorA` | `Vector2` | (required) | Anchor on body A in world space |
| `anchorB` | `Vector2` | (required) | Anchor on body B in world space |
| `localAnchorA/B` | `Vector2?` | `nil` | Override local anchors (computed from anchors if nil) |
| `length` | `Float` | `0` | Rest length (0 = computed from initial positions) |
| `frequencyHz` | `Float` | `0` | Spring frequency in Hz (0 = rigid) |
| `dampingRatio` | `Float` | `0.7` | Damping ratio (0 = undamped, 1 = critical) |
| `maxForce` | `Float` | `0` | Breaking force threshold (0 = unbreakable) |

### Weld Joint (Fixed)

Locks two bodies together with no relative movement. With `frequencyHz > 0`, acts as a soft weld.

```swift
let weld = physics.createJoint(.weld(WeldJointDef(
    entityA: body, entityB: turret,
    anchor: Vector2(x: 150, y: 150),
    maxForce: 1000.0  // breakable weld
)), in: world)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entityA` | `Entity` | (required) | First body |
| `entityB` | `Entity` | (required) | Second body |
| `anchor` | `Vector2` | (required) | Shared anchor in world space |
| `localAnchorA/B` | `Vector2?` | `nil` | Override local anchors (computed from `anchor` if nil) |
| `referenceAngle` | `Float?` | `nil` | Target relative angle (nil = computed from initial rotations) |
| `frequencyHz` | `Float` | `0` | Angular spring frequency (0 = rigid) |
| `dampingRatio` | `Float` | `0.7` | Angular spring damping |
| `maxForce` | `Float` | `0` | Breaking force threshold (0 = unbreakable) |
| `maxTorque` | `Float` | `0` | Breaking torque threshold (0 = unbreakable) |

### Prismatic Joint (Slider)

Constrains two bodies to slide along a fixed axis. Locks relative rotation. Supports translation limits and a motor.

```swift
let slider = physics.createJoint(.prismatic(PrismaticJointDef(
    entityA: rail, entityB: platform,
    anchor: Vector2(x: 200, y: 100),
    axis: Vector2(x: 1, y: 0),       // horizontal axis
    enableLimit: true,
    lowerTranslation: -100,
    upperTranslation: 100,
    enableMotor: true,
    motorSpeed: 50.0,
    maxMotorForce: 200.0
)), in: world)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entityA` | `Entity` | (required) | First body (defines axis frame) |
| `entityB` | `Entity` | (required) | Second body (slides along axis) |
| `anchor` | `Vector2` | (required) | Shared anchor in world space |
| `axis` | `Vector2` | (required) | Sliding axis in world space |
| `localAnchorA/B` | `Vector2?` | `nil` | Override local anchors |
| `localAxisA` | `Vector2?` | `nil` | Override axis in body A's local frame |
| `referenceAngle` | `Float?` | `nil` | Target relative angle (nil = computed) |
| `enableLimit` | `Bool` | `false` | Enable translation limits |
| `lowerTranslation` | `Float` | `0` | Lower translation limit |
| `upperTranslation` | `Float` | `0` | Upper translation limit |
| `enableMotor` | `Bool` | `false` | Enable motor |
| `motorSpeed` | `Float` | `0` | Target motor speed along axis |
| `maxMotorForce` | `Float` | `0` | Maximum motor force |
| `maxForce` | `Float` | `0` | Breaking force threshold (0 = unbreakable) |
| `maxTorque` | `Float` | `0` | Breaking torque threshold (0 = unbreakable) |

### Rope Joint (Max Distance)

Enforces a maximum distance between two anchors. Only pulls when stretched — goes slack when closer. Unlike a distance joint, a rope joint never pushes bodies apart.

```swift
let rope = physics.createJoint(.rope(RopeJointDef(
    entityA: anchor, entityB: ball,
    anchorA: Vector2(x: 200, y: 100),
    anchorB: Vector2(x: 200, y: 300),
    maxLength: 250                     // 0 = auto from initial distance
)), in: world)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entityA` | `Entity` | (required) | First body |
| `entityB` | `Entity` | (required) | Second body |
| `anchorA` | `Vector2` | (required) | Anchor on body A in world space |
| `anchorB` | `Vector2` | (required) | Anchor on body B in world space |
| `localAnchorA/B` | `Vector2?` | `nil` | Override local anchors |
| `maxLength` | `Float` | `0` | Maximum distance (0 = computed from initial positions) |
| `maxForce` | `Float` | `0` | Breaking force threshold (0 = unbreakable) |

### Motor Joint (Driven Offset)

Drives body B toward a target position and angle offset relative to body A. Does NOT support breaking — `maxForce`/`maxTorque` limit the motor's output power; the joint simply fails to reach its target when overloaded.

```swift
let motor = physics.createJoint(.motor(MotorJointDef(
    entityA: platform, entityB: follower,
    linearOffset: Vector2(x: 50, y: 0),  // target pos of B in A's local frame
    angularOffset: 0,                      // target angle relative to A
    correctionFactor: 0.3,                 // 0-1, stiffness
    maxForce: 500.0,                       // motor power limit
    maxTorque: 200.0
)), in: world)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `entityA` | `Entity` | (required) | Reference body |
| `entityB` | `Entity` | (required) | Driven body |
| `linearOffset` | `Vector2` | `.zero` | Target position of B relative to A (A's local frame) |
| `angularOffset` | `Float` | `0` | Target angle of B relative to A |
| `correctionFactor` | `Float` | `0.3` | Correction stiffness (0 = none, 1 = max) |
| `maxForce` | `Float` | `1.0` | Maximum motor force (NOT breaking) |
| `maxTorque` | `Float` | `1.0` | Maximum motor torque (NOT breaking) |

### Joint Events

Joints that exceed their `maxForce` or `maxTorque` are automatically destroyed, generating a `JointEvent`. Motor joints do not break.

```swift
physics.onJointBroken = { event in
    print("Joint \(event.handle.id) broke between \(event.entityA) and \(event.entityB)")
}

// Or poll events directly
for event in physics.jointEvents {
    if event.type == .broken { /* handle break */ }
}
```

### Entity Cleanup

When an entity participating in a joint is destroyed or loses its `Transform2D`, all its joints are automatically marked for destruction and cleaned up at the end of the tick.

### Solver Configuration

The joint solver runs iteratively for convergence:

| Property | Default | Description |
|----------|---------|-------------|
| `velocityIterations` | `6` | Iterations for velocity-level constraint solving |
| `positionIterations` | `2` | Iterations for position-level error correction |

Higher iteration counts improve accuracy at the cost of performance. The defaults work well for most games.

### Full Example

```swift
let physics = PhysicsWorld2D(gravity: Vector2(x: 0, y: 980))
world.addSystem(physics)

// Pendulum: static anchor + dynamic bob
let anchor = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 400, y: 100)), to: anchor)
world.addComponent(RigidBody2D(bodyType: .static), to: anchor)

let bob = world.createEntity()
world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: bob)
world.addComponent(Velocity2D(), to: bob)
let mass: Float = 2.0
let shape: CollisionShape = .circle(radius: 16)
world.addComponent(RigidBody2D(
    mass: mass,
    inertia: RigidBody2D.computeInertia(mass: mass, shape: shape)
), to: bob)
world.addComponent(Collider2D(shape: shape), to: bob)

// Pin bob to anchor
let joint = physics.createJoint(.revolute(RevoluteJointDef(
    entityA: anchor, entityB: bob,
    anchor: Vector2(x: 400, y: 100)
)), in: world)

// Breaking joint callback
physics.onJointBroken = { event in
    print("Joint broke!")
}
```

---

## Physics Debug Rendering

`Sources/Agilis/Physics/PhysicsDebugRenderer.swift`

Visualize colliders, contacts, velocities, surface normals, and joints for debugging.

### RenderBackend Extension

```swift
// Colliders, contacts, velocities, normals
func drawPhysicsDebug(world: World, events: [CollisionEvent],
                      options: PhysicsDebugRendererOptions = PhysicsDebugRendererOptions())

// Joints (anchor points and connection lines)
func drawJointsDebug(physics: PhysicsWorld2D, world: World,
                     options: PhysicsDebugRendererOptions = PhysicsDebugRendererOptions())
```

Call at the end of `render()` so overlays appear on top.

### PhysicsDebugRendererOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `drawColliders` | `Bool` | `true` | Draw collider outlines |
| `drawContacts` | `Bool` | `true` | Draw contact points |
| `drawVelocities` | `Bool` | `false` | Draw velocity vectors |
| `drawNormals` | `Bool` | `false` | Draw contact normals |
| `drawJoints` | `Bool` | `true` | Draw joint connections and anchors |
| `drawCCDPaths` | `Bool` | `false` | Draw CCD sweep paths (previous to current position) |
| `jointColor` | `Color` | light blue | Color for joint connection lines |
| `jointAnchorColor` | `Color` | gold | Color for joint anchor points |
| `jointAnchorRadius` | `Float` | `4.0` | Radius of anchor point circles |
| `ccdPathColor` | `Color` | orange-red | Color for CCD sweep path lines |

Body type colors: dynamic = cyan, kinematic = yellow, static = gray, trigger = green.

Joint visualization per type:
- **Revolute**: Lines from body centers to shared anchor + anchor circle
- **Distance**: Line between two world anchors + anchor circles at each end
- **Weld**: X mark at anchor + lines to both body centers
- **Prismatic**: Lines from body centers to anchor + axis line through anchor + anchor circle
- **Rope**: Line between anchors + anchor circles + diamond at midpoint
- **Motor**: Line from body A to body B + cross at A + circle at B

### Usage

```swift
// Basic debug draw (colliders + contacts + joints)
app.renderer.drawPhysicsDebug(world: app.world, events: physics.events)
app.renderer.drawJointsDebug(physics: physics, world: app.world)

// With custom options
var options = PhysicsDebugRendererOptions()
options.drawVelocities = true
options.drawNormals = true
app.renderer.drawPhysicsDebug(world: app.world, events: physics.events, options: options)
app.renderer.drawJointsDebug(physics: physics, world: app.world, options: options)
```

---

## SpatialQuery

`Sources/Agilis/Physics/SpatialQuery.swift`

Pure geometry functions for ray intersection, point tests, and area overlap — usable without the full physics system.

- **Ray**: `rayVsAABB`, `rayVsCircle`, `rayVsPolygon`
- **Point**: `pointInAABB`, `pointInCircle`, `pointInPolygon`
- **Area**: `rectOverlapsAABB`, `rectOverlapsCircle`, `rectOverlapsPolygon`
- **Dispatchers**: `raycast(shape:)`, `pointTest(shape:)`, `areaTest(shape:)` — handle rotation (AABB promoted to polygon)

All functions are winding-direction agnostic.
