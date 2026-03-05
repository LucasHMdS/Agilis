import AgilisCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// The main 2D physics system.
///
/// Runs the full physics simulation pipeline each fixed-timestep tick:
/// gravity, velocity integration, broad-phase spatial hashing, narrow-phase
/// collision detection (SAT), impulse-based response, joint constraint solving,
/// penetration correction, and collision event generation.
///
/// ## Usage
///
/// ```swift
/// let physics = PhysicsWorld2D(gravity: Vector2(x: 0, y: 980))
/// world.addSystem(physics)
///
/// // Optional: listen for collision events
/// physics.onCollisionBegan = { event in
///     print("Collision: \(event.entityA) vs \(event.entityB)")
/// }
///
/// // Create a revolute (pin) joint
/// let joint = physics.createJoint(.revolute(RevoluteJointDef(
///     entityA: wall, entityB: door,
///     anchor: Vector2(x: 100, y: 200)
/// )), in: world)
/// ```
///
/// Entities need `Transform2D` + `Collider2D` to participate in collision detection.
/// Add `RigidBody2D` and `Velocity2D` for physics response; without them,
/// entities are treated as static.
public final class PhysicsWorld2D: System, @unchecked Sendable {

    // MARK: - System Conformance

    public var priority: Int { _priority }
    private let _priority: Int

    /// Reads RigidBody2D/Collider2D, writes Transform2D/PreviousTransform2D/Velocity2D.
    /// Depends on: none (runs at priority 100, after gameplay systems at 0).
    /// Depended on by: AnimationSystem (50, runs before physics), ParticleSystem (200), LightingSystem (300).
    /// Writes PreviousTransform2D before integration so interpolated rendering works.
    public var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [RigidBody2D.self, Collider2D.self],
            writes: [Transform2D.self, PreviousTransform2D.self, Velocity2D.self]
        )
    }

    // MARK: - Configuration

    /// Gravity applied to dynamic bodies each tick (pixels/s^2).
    /// Typical 2D platformer: `Vector2(x: 0, y: 980)`.
    public var gravity: Vector2

    /// Number of velocity constraint iterations per physics step.
    /// Higher values improve joint stability at the cost of performance. Default: 6.
    public var velocityIterations: Int = 6

    /// Number of position constraint iterations per physics step.
    /// Higher values reduce positional drift in joints. Default: 2.
    public var positionIterations: Int = 2

    // MARK: - Collision Events

    /// Collision events from the most recent physics step.
    /// Read this from other systems or scene code to react to collisions.
    public private(set) var events: [CollisionEvent] = []

    /// Called for each new collision (first frame of contact).
    public var onCollisionBegan: ((CollisionEvent) -> Void)?

    /// Called when two previously colliding entities separate.
    public var onCollisionEnded: ((CollisionEvent) -> Void)?

    // MARK: - Joint System

    /// Joint storage and lifecycle management.
    private let jointStore = JointStore()

    /// Joint events from the most recent physics step (broken joints).
    public private(set) var jointEvents: [JointEvent] = []

    /// Called when a joint breaks due to exceeding its force/torque limit.
    public var onJointBroken: ((JointEvent) -> Void)?

    // MARK: - Internal State

    private let grid: SpatialHashGrid
    private let tracker: ContactTracker

    // MARK: - CCD Reusable Buffers

    /// Pre-allocated buffers for CCD sweep, cleared each frame to avoid per-tick allocation.
    private var ccdBodies: [CCDBodyData] = []
    private var ccdBodyLookup: [Entity: CCDBodyInfo] = [:]

    // MARK: - Init

    /// Creates a new physics world.
    ///
    /// - Parameters:
    ///   - gravity: Gravity vector in pixels/s^2. Default: `(0, 980)`.
    ///   - cellSize: Spatial hash grid cell size. Default: 64.
    ///   - priority: System execution priority (lower runs first). Default: 100.
    public init(
        gravity: Vector2 = Vector2(x: 0, y: 980),
        cellSize: Float = 64,
        priority: Int = 100
    ) {
        self.gravity = gravity
        self._priority = priority
        self.grid = SpatialHashGrid(cellSize: cellSize)
        self.tracker = ContactTracker()
    }

    // MARK: - Joint Management

    /// Create a physics joint connecting two entities.
    ///
    /// Both entities must have `Transform2D` components. At least one should have
    /// `RigidBody2D` and `Velocity2D` for meaningful constraint solving.
    ///
    /// - Parameters:
    ///   - definition: The joint configuration.
    ///   - world: The ECS world containing the entities.
    /// - Returns: A handle to the created joint, or `.invalid` if creation failed.
    @discardableResult
    public func createJoint(_ definition: JointDefinition, in world: World) -> JointHandle {
        jointStore.create(definition: definition, world: world)
    }

    /// Destroy a joint by its handle.
    ///
    /// Has no effect if the handle is invalid or already destroyed.
    public func destroyJoint(_ handle: JointHandle) {
        jointStore.destroy(handle: handle)
    }

    /// The number of active joints.
    public var jointCount: Int { jointStore.count }

    /// Remove all joints.
    public func removeAllJoints() { jointStore.clear() }

    /// Get debug information for all active joints.
    ///
    /// Returns public-friendly data for debug rendering without exposing internal state.
    public func debugJointInfo(world: World) -> [JointDebugInfo] {
        jointStore.debugInfo(world: world)
    }

    // MARK: - System Lifecycle

    public func setup(world: World) {}

    public func update(context: SystemContext) {
        let world = context.world
        let dt = Float(context.deltaTime)

        // STEP 1: Store previous transforms for interpolated rendering
        world.forEach { (_: Entity, transform: inout Transform2D, prev: inout PreviousTransform2D) in
            prev.position = transform.position
            prev.rotation = transform.rotation
        }

        // STEP 2: Apply gravity and damping to dynamic bodies
        world.forEach { (_: Entity, vel: inout Velocity2D, body: inout RigidBody2D) in
            guard body.bodyType == .dynamic else { return }
            vel.linear += self.gravity * body.gravityScale * dt
            if body.linearDamping > 0 {
                vel.linear *= max(1.0 - body.linearDamping * dt, 0)
            }
        }

        // STEP 3: Integrate velocities -> update transforms
        world.forEach { (_: Entity, transform: inout Transform2D, vel: inout Velocity2D) in
            transform.position += vel.linear * dt
            transform.rotation += vel.angular * dt
        }

        // STEP 3.5: CCD sweep — clamp fast-moving bodies to prevent tunneling
        performCCDSweep(world: world)

        // STEP 4: Broad phase — rebuild spatial hash grid
        grid.clear()
        world.forEach { (entity: Entity, transform: inout Transform2D, collider: inout Collider2D) in
            let worldPos = transform.position + collider.offset
            let bounds = self.computeWorldBounds(
                shape: collider.shape, position: worldPos, rotation: transform.rotation
            )
            self.grid.insert(entity: entity, bounds: bounds)
        }

        // STEP 5: Get broad-phase pairs
        let broadPairs = grid.queryPairs()
        tracker.beginFrame()

        // STEP 6: Narrow phase + resolve
        for pair in broadPairs {
            let eA = pair.entityA
            let eB = pair.entityB

            // Fetch required components
            guard let tA = world.getComponent(Transform2D.self, from: eA),
                  let cA = world.getComponent(Collider2D.self, from: eA),
                  let tB = world.getComponent(Transform2D.self, from: eB),
                  let cB = world.getComponent(Collider2D.self, from: eB)
            else { continue }

            // Layer/mask filter
            guard shouldCollide(layerA: cA.layer, maskA: cA.mask,
                                layerB: cB.layer, maskB: cB.mask) else { continue }

            // Narrow phase
            let posA = tA.position + cA.offset
            let posB = tB.position + cB.offset

            guard let contact = NarrowPhase.test(
                shapeA: cA.shape, posA: posA, rotA: tA.rotation,
                shapeB: cB.shape, posB: posB, rotB: tB.rotation
            ) else { continue }

            // Record for event tracking
            tracker.recordCollision(pair: pair, contact: contact)

            // Skip physics response for triggers
            if cA.isTrigger || cB.isTrigger { continue }

            // Get rigid bodies (missing = treated as static)
            let bodyA = world.getComponent(RigidBody2D.self, from: eA)
            let bodyB = world.getComponent(RigidBody2D.self, from: eB)

            let invMassA = bodyA?.effectiveInverseMass ?? 0
            let invMassB = bodyB?.effectiveInverseMass ?? 0

            // Skip if both are effectively static
            guard invMassA > 0 || invMassB > 0 else { continue }

            // Combined material properties
            let restitution = min(bodyA?.restitution ?? 0, bodyB?.restitution ?? 0)
            let frictionA = bodyA?.friction ?? 0.3
            let frictionB = bodyB?.friction ?? 0.3
            let friction = sqrtf(frictionA * frictionB) // Geometric mean

            // Resolve velocity
            var velA = world.getComponent(Velocity2D.self, from: eA)?.linear ?? .zero
            var velB = world.getComponent(Velocity2D.self, from: eB)?.linear ?? .zero

            ImpulseResolver.resolveVelocity(
                contact: contact,
                velocityA: &velA, velocityB: &velB,
                inverseMassA: invMassA, inverseMassB: invMassB,
                restitution: restitution, friction: friction
            )

            // Write velocities back
            if invMassA > 0 {
                world.updateComponent(Velocity2D.self, on: eA) { v in v.linear = velA }
            }
            if invMassB > 0 {
                world.updateComponent(Velocity2D.self, on: eB) { v in v.linear = velB }
            }

            // Penetration correction
            var posACorrected = tA.position
            var posBCorrected = tB.position
            ImpulseResolver.correctPenetration(
                contact: contact,
                positionA: &posACorrected, positionB: &posBCorrected,
                inverseMassA: invMassA, inverseMassB: invMassB
            )
            if invMassA > 0 {
                world.updateComponent(Transform2D.self, on: eA) { t in t.position = posACorrected }
            }
            if invMassB > 0 {
                world.updateComponent(Transform2D.self, on: eB) { t in t.position = posBCorrected }
            }
        }

        // STEP 7: Joint constraint solving
        if jointStore.count > 0 {
            solveJoints(world: world, dt: dt)
        }

        // STEP 8: Generate collision events
        events = tracker.endFrame()
        for event in events {
            switch event.type {
            case .began: onCollisionBegan?(event)
            case .ended: onCollisionEnded?(event)
            case .ongoing: break
            }
        }

        // STEP 9: Generate joint events (broken joints)
        jointEvents = jointStore.flushDestroyedJoints()
        for event in jointEvents {
            if event.type == .broken {
                onJointBroken?(event)
            }
        }
    }

    // MARK: - Joint Solving

    /// Run the sequential-impulse constraint solver for all active joints.
    private func solveJoints(world: World, dt: Float) {
        let defaultBody = RigidBody2D(bodyType: .static)

        // PHASE 1: Pre-solve — compute constraint data and warm start
        jointStore.forEachJoint { joint in
            guard !joint.isMarkedForDestruction else { return }

            // Check entity liveness
            guard let tA = world.getComponent(Transform2D.self, from: joint.entityA),
                  let tB = world.getComponent(Transform2D.self, from: joint.entityB) else {
                joint.isMarkedForDestruction = true
                return
            }

            let vA = world.getComponent(Velocity2D.self, from: joint.entityA) ?? Velocity2D()
            let vB = world.getComponent(Velocity2D.self, from: joint.entityB) ?? Velocity2D()
            let bodyA = world.getComponent(RigidBody2D.self, from: joint.entityA) ?? defaultBody
            let bodyB = world.getComponent(RigidBody2D.self, from: joint.entityB) ?? defaultBody

            JointSolver.preSolve(joint: &joint,
                                 transformA: tA, transformB: tB,
                                 velocityA: vA, velocityB: vB,
                                 bodyA: bodyA, bodyB: bodyB, dt: dt)

            // Apply warm-start impulse
            var modVelA = vA
            var modVelB = vB
            JointSolver.warmStart(joint: &joint,
                                  velocityA: &modVelA, velocityB: &modVelB,
                                  bodyA: bodyA, bodyB: bodyB)

            world.updateComponent(Velocity2D.self, on: joint.entityA) { v in v = modVelA }
            world.updateComponent(Velocity2D.self, on: joint.entityB) { v in v = modVelB }
        }

        // PHASE 2: Velocity iterations
        for _ in 0..<velocityIterations {
            jointStore.forEachJoint { joint in
                guard !joint.isMarkedForDestruction else { return }

                guard var vA = world.getComponent(Velocity2D.self, from: joint.entityA),
                      var vB = world.getComponent(Velocity2D.self, from: joint.entityB) else { return }
                let bodyA = world.getComponent(RigidBody2D.self, from: joint.entityA) ?? defaultBody
                let bodyB = world.getComponent(RigidBody2D.self, from: joint.entityB) ?? defaultBody

                JointSolver.solveVelocity(joint: &joint,
                                          velocityA: &vA, velocityB: &vB,
                                          bodyA: bodyA, bodyB: bodyB)

                world.updateComponent(Velocity2D.self, on: joint.entityA) { v in v = vA }
                world.updateComponent(Velocity2D.self, on: joint.entityB) { v in v = vB }
            }
        }

        // PHASE 3: Position iterations
        for _ in 0..<positionIterations {
            var maxError: Float = 0
            jointStore.forEachJoint { joint in
                guard !joint.isMarkedForDestruction else { return }

                guard var tA = world.getComponent(Transform2D.self, from: joint.entityA),
                      var tB = world.getComponent(Transform2D.self, from: joint.entityB) else { return }
                let bodyA = world.getComponent(RigidBody2D.self, from: joint.entityA) ?? defaultBody
                let bodyB = world.getComponent(RigidBody2D.self, from: joint.entityB) ?? defaultBody

                let error = JointSolver.solvePosition(joint: &joint,
                                                      transformA: &tA, transformB: &tB,
                                                      bodyA: bodyA, bodyB: bodyB)
                maxError = max(maxError, error)

                world.updateComponent(Transform2D.self, on: joint.entityA) { t in t = tA }
                world.updateComponent(Transform2D.self, on: joint.entityB) { t in t = tB }
            }
            if maxError < JointSolver.linearSlop { break } // converged
        }

        // PHASE 4: Check for broken joints
        jointStore.forEachJoint { joint in
            guard !joint.isMarkedForDestruction else { return }
            switch joint.definition {
            case .revolute(let def):
                if def.maxForce > 0 && joint.constraintForce > def.maxForce {
                    joint.isMarkedForDestruction = true
                }
                if def.maxTorque > 0 && joint.constraintTorque > def.maxTorque {
                    joint.isMarkedForDestruction = true
                }
            case .distance(let def):
                if def.maxForce > 0 && joint.constraintForce > def.maxForce {
                    joint.isMarkedForDestruction = true
                }
            case .weld(let def):
                if def.maxForce > 0 && joint.constraintForce > def.maxForce {
                    joint.isMarkedForDestruction = true
                }
                if def.maxTorque > 0 && joint.constraintTorque > def.maxTorque {
                    joint.isMarkedForDestruction = true
                }
            case .prismatic(let def):
                if def.maxForce > 0 && joint.constraintForce > def.maxForce {
                    joint.isMarkedForDestruction = true
                }
                if def.maxTorque > 0 && joint.constraintTorque > def.maxTorque {
                    joint.isMarkedForDestruction = true
                }
            case .rope(let def):
                if def.maxForce > 0 && joint.constraintForce > def.maxForce {
                    joint.isMarkedForDestruction = true
                }
            case .motor:
                break // Motor joints do not break
            }
        }
    }

    // MARK: - Continuous Collision Detection

    /// Sweep CCD-enabled dynamic bodies from their previous position to the integrated position,
    /// clamping to the earliest time of impact to prevent tunneling through thin geometry.
    ///
    /// Supports angular sweep (rotation-aware CCD for non-circle shapes) and bilateral CCD
    /// (two moving CCD bodies use relative velocity to detect collisions between them).
    private func performCCDSweep(world: World) {
        // Reuse instance-level buffers to avoid per-tick allocation
        ccdBodies.removeAll(keepingCapacity: true)

        world.forEach { (entity: Entity, transform: inout Transform2D, prev: inout PreviousTransform2D,
                          _: inout Velocity2D, body: inout RigidBody2D, collider: inout Collider2D) in
            guard body.useCCD && body.bodyType == .dynamic else { return }

            let startPos = prev.position + collider.offset
            let endPos = transform.position + collider.offset
            let displacement = endPos - startPos

            // Early out: if both translational and angular displacement are small, discrete is sufficient
            let extent = SweptCollision.minimumExtent(of: collider.shape)
            let angularExtent = SweptCollision.angularSweepExtent(
                of: collider.shape,
                angularDisplacement: transform.rotation - prev.rotation
            )
            guard displacement.lengthSquared > extent * extent || angularExtent > extent else { return }

            ccdBodies.append(CCDBodyData(
                entity: entity, prevPos: prev.position,
                prevRotation: prev.rotation,
                shape: collider.shape, offset: collider.offset,
                layer: collider.layer, mask: collider.mask,
                rotation: transform.rotation
            ))
        }

        guard !ccdBodies.isEmpty else { return }

        // Build lookup for bilateral CCD — O(1) check if a candidate is also a CCD body
        ccdBodyLookup.removeAll(keepingCapacity: true)
        for body in ccdBodies {
            guard let transform = world.getComponent(Transform2D.self, from: body.entity) else { continue }
            ccdBodyLookup[body.entity] = CCDBodyInfo(
                prevPos: body.prevPos,
                prevRotation: body.prevRotation,
                currentPos: transform.position,
                offset: body.offset
            )
        }

        // For each CCD body, sweep against all collidable entities
        for ccdBody in ccdBodies {
            guard let transform = world.getComponent(Transform2D.self, from: ccdBody.entity) else { continue }

            let startPos = ccdBody.prevPos + ccdBody.offset
            let endPos = transform.position + ccdBody.offset

            // Compute swept AABB for broad-phase pre-filter
            // For rotating non-circle shapes, use bounding circle to ensure the filter
            // doesn't reject candidates the angular sweep would hit
            let angularDisp = abs(ccdBody.rotation - ccdBody.prevRotation)
            let startBounds: Rect
            let endBounds: Rect

            if angularDisp > 1e-6, case .circle = ccdBody.shape {
                // Circles don't need rotation-aware bounds
                startBounds = computeWorldBounds(shape: ccdBody.shape, position: startPos, rotation: 0)
                endBounds = computeWorldBounds(shape: ccdBody.shape, position: endPos, rotation: 0)
            } else if angularDisp > 1e-6 {
                // Use bounding circle for swept bounds when rotating
                let br = SweptCollision.boundingRadius(of: ccdBody.shape)
                startBounds = Rect(x: startPos.x - br, y: startPos.y - br, width: br * 2, height: br * 2)
                endBounds = Rect(x: endPos.x - br, y: endPos.y - br, width: br * 2, height: br * 2)
            } else {
                startBounds = computeWorldBounds(shape: ccdBody.shape, position: startPos, rotation: ccdBody.rotation)
                endBounds = computeWorldBounds(shape: ccdBody.shape, position: endPos, rotation: ccdBody.rotation)
            }

            let sweptMinX = min(startBounds.x, endBounds.x)
            let sweptMinY = min(startBounds.y, endBounds.y)
            let sweptMaxX = max(startBounds.x + startBounds.width, endBounds.x + endBounds.width)
            let sweptMaxY = max(startBounds.y + startBounds.height, endBounds.y + endBounds.height)

            var minTOI: Float = 1.0

            // Brute force scan (same pattern as PhysicsWorld2D+Queries)
            world.forEach { (candidate: Entity, candidateTransform: inout Transform2D, candidateCollider: inout Collider2D) in
                // Skip self
                guard candidate != ccdBody.entity else { return }

                // Skip triggers — CCD should not prevent passing through trigger zones
                guard !candidateCollider.isTrigger else { return }

                // Layer/mask filter
                guard shouldCollide(layerA: ccdBody.layer, maskA: ccdBody.mask,
                                    layerB: candidateCollider.layer, maskB: candidateCollider.mask) else { return }

                // Determine candidate position — bilateral CCD uses relative velocity
                let candidatePos: Vector2
                let adjustedEndPos: Vector2
                let candidateRot: Float

                if let candidateInfo = ccdBodyLookup[candidate] {
                    // Candidate is also a CCD body — use relative velocity approach.
                    // B is treated as stationary at its previous position;
                    // A's endpoint is adjusted to subtract B's displacement.
                    let bPrevPos = candidateInfo.prevPos + candidateCollider.offset
                    let bCurrPos = candidateInfo.currentPos + candidateCollider.offset
                    let bDisplacement = bCurrPos - bPrevPos
                    candidatePos = bPrevPos
                    adjustedEndPos = endPos - bDisplacement
                    candidateRot = candidateInfo.prevRotation
                } else {
                    // Non-CCD candidate — stationary at current position (existing behavior)
                    candidatePos = candidateTransform.position + candidateCollider.offset
                    adjustedEndPos = endPos
                    candidateRot = candidateTransform.rotation
                }

                // Swept AABB pre-filter (uses original bounds, conservative for bilateral case)
                let candidateBounds = self.computeWorldBounds(
                    shape: candidateCollider.shape, position: candidatePos, rotation: candidateRot
                )
                let cMinX = candidateBounds.x
                let cMinY = candidateBounds.y
                let cMaxX = cMinX + candidateBounds.width
                let cMaxY = cMinY + candidateBounds.height

                guard sweptMinX <= cMaxX && sweptMaxX >= cMinX &&
                      sweptMinY <= cMaxY && sweptMaxY >= cMinY else { return }

                // Perform swept collision test with rotation-aware overload
                guard let toi = SweptCollision.timeOfImpact(
                    movingShape: ccdBody.shape,
                    startPos: startPos,
                    endPos: adjustedEndPos,
                    startRot: ccdBody.prevRotation,
                    endRot: ccdBody.rotation,
                    staticShape: candidateCollider.shape,
                    staticPos: candidatePos,
                    staticRot: candidateRot
                ) else { return }

                // Track earliest TOI (skip TOI=0 — already overlapping at start)
                if toi > 0 && toi < minTOI {
                    minTOI = toi
                }
            }

            // Clamp position and rotation to earliest time of impact
            if minTOI < 1.0 {
                let clampedPos = Vector2(
                    x: ccdBody.prevPos.x + (transform.position.x - ccdBody.prevPos.x) * minTOI,
                    y: ccdBody.prevPos.y + (transform.position.y - ccdBody.prevPos.y) * minTOI
                )
                // Interpolate rotation to the same TOI
                let clampedRot = ccdBody.prevRotation + (ccdBody.rotation - ccdBody.prevRotation) * minTOI

                // Push slightly past TOI so the narrow phase detects a small penetration
                // and generates a proper contact for impulse response and collision events.
                let disp = transform.position - ccdBody.prevPos
                let dispLen = disp.length
                if dispLen > 1e-6 {
                    let skinNudge = disp * (SweptCollision.skinWidth / dispLen)
                    world.updateComponent(Transform2D.self, on: ccdBody.entity) { t in
                        t.position = clampedPos + skinNudge
                        t.rotation = clampedRot
                    }
                } else {
                    world.updateComponent(Transform2D.self, on: ccdBody.entity) { t in
                        t.position = clampedPos
                        t.rotation = clampedRot
                    }
                }
            }
        }
    }

    // MARK: - Bounds Computation

    /// Compute the world-space AABB for a collision shape.
    private func computeWorldBounds(shape: CollisionShape, position: Vector2, rotation: Float) -> Rect {
        switch shape {
        case .aabb(let half):
            if abs(rotation) < 1e-6 {
                return Rect(x: position.x - half.x, y: position.y - half.y,
                            width: half.x * 2, height: half.y * 2)
            }
            // Rotated AABB: compute bounding box of rotated corners
            return rotatedRectBounds(half: half, position: position, rotation: rotation)

        case .circle(let r):
            return Rect(x: position.x - r, y: position.y - r,
                        width: r * 2, height: r * 2)

        case .polygon(let poly):
            if abs(rotation) < 1e-6 {
                // Local bounds + position offset
                let lb = poly.localBounds
                return Rect(x: lb.x + position.x, y: lb.y + position.y,
                            width: lb.width, height: lb.height)
            }
            // Rotate vertices and compute enclosing AABB
            return rotatedPolygonBounds(vertices: poly.vertices, position: position, rotation: rotation)
        }
    }

    /// Compute the AABB of a rotated rectangle.
    private func rotatedRectBounds(half: Vector2, position: Vector2, rotation: Float) -> Rect {
        let c = abs(cosf(rotation))
        let s = abs(sinf(rotation))
        let newHalfX = half.x * c + half.y * s
        let newHalfY = half.x * s + half.y * c
        return Rect(x: position.x - newHalfX, y: position.y - newHalfY,
                    width: newHalfX * 2, height: newHalfY * 2)
    }

    /// Compute the AABB of rotated polygon vertices.
    private func rotatedPolygonBounds(vertices: [Vector2], position: Vector2, rotation: Float) -> Rect {
        let cosR = cosf(rotation)
        let sinR = sinf(rotation)

        var v = vertices[0]
        var minX = v.x * cosR - v.y * sinR + position.x
        var maxX = minX
        var minY = v.x * sinR + v.y * cosR + position.y
        var maxY = minY

        for i in 1..<vertices.count {
            v = vertices[i]
            let wx = v.x * cosR - v.y * sinR + position.x
            let wy = v.x * sinR + v.y * cosR + position.y
            if wx < minX { minX = wx }
            if wx > maxX { maxX = wx }
            if wy < minY { minY = wy }
            if wy > maxY { maxY = wy }
        }

        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - CCD Data Types

/// Per-body data collected for CCD sweep. Stored in a reusable buffer on PhysicsWorld2D.
private struct CCDBodyData {
    let entity: Entity
    let prevPos: Vector2
    let prevRotation: Float
    let shape: CollisionShape
    let offset: Vector2
    let layer: UInt32
    let mask: UInt32
    let rotation: Float
}

/// Lookup entry for bilateral CCD. Stored in a reusable dictionary on PhysicsWorld2D.
private struct CCDBodyInfo {
    let prevPos: Vector2
    let prevRotation: Float
    let currentPos: Vector2
    let offset: Vector2
}
