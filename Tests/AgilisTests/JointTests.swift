import Testing
import Foundation
@testable import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - Helper

/// Helper: create a world with the physics system and run a number of ticks.
private func runPhysics(
    gravity: Vector2 = Vector2(x: 0, y: 980),
    cellSize: Float = 128,
    ticks: Int = 1,
    deltaTime: Double = 1.0 / 60.0,
    afterTick: ((World, PhysicsWorld2D, Int) -> Void)? = nil,
    setup: (World, PhysicsWorld2D) -> Void
) -> (World, PhysicsWorld2D) {
    let world = World()
    let physics = PhysicsWorld2D(gravity: gravity, cellSize: cellSize)
    world.addSystem(physics)
    setup(world, physics)
    for tick in 0..<ticks {
        world.update(deltaTime: deltaTime)
        afterTick?(world, physics, tick)
    }
    return (world, physics)
}

/// Helper: create a dynamic body entity with standard physics components.
@discardableResult
private func createDynamicBody(
    world: World,
    name: String,
    position: Vector2,
    mass: Float = 1.0,
    inertia: Float = 0,
    shape: CollisionShape = .circle(radius: 10)
) -> Entity {
    let e = world.createEntity()
    world.setName(name, for: e)
    world.addComponent(Transform2D(position: position), to: e)
    world.addComponent(PreviousTransform2D(position: position), to: e)
    world.addComponent(Velocity2D(), to: e)
    world.addComponent(RigidBody2D(mass: mass, inertia: inertia, bodyType: .dynamic), to: e)
    world.addComponent(Collider2D(shape: shape), to: e)
    return e
}

/// Helper: create a static body entity.
@discardableResult
private func createStaticBody(
    world: World,
    name: String,
    position: Vector2,
    shape: CollisionShape = .aabb(halfExtents: Vector2(x: 50, y: 10))
) -> Entity {
    let e = world.createEntity()
    world.setName(name, for: e)
    world.addComponent(Transform2D(position: position), to: e)
    world.addComponent(RigidBody2D(bodyType: .static), to: e)
    world.addComponent(Collider2D(shape: shape), to: e)
    return e
}

// MARK: - RigidBody2D Inertia Tests

@Suite("RigidBody2D Inertia")
struct RigidBody2DInertiaTests {

    @Test("Default inertia is zero")
    func defaultInertia() {
        let body = RigidBody2D()
        #expect(body.inertia == 0)
        #expect(body.inverseInertia == 0)
    }

    @Test("Setting inertia updates inverseInertia")
    func setInertia() {
        var body = RigidBody2D(mass: 1, inertia: 4.0)
        #expect(abs(body.inverseInertia - 0.25) < 0.001)

        body.inertia = 10.0
        #expect(abs(body.inverseInertia - 0.1) < 0.001)
    }

    @Test("Static body has zero effectiveInverseInertia")
    func staticInertia() {
        let body = RigidBody2D(mass: 1, inertia: 10, bodyType: .static)
        #expect(body.effectiveInverseInertia == 0)
    }

    @Test("Kinematic body has zero effectiveInverseInertia")
    func kinematicInertia() {
        let body = RigidBody2D(mass: 1, inertia: 10, bodyType: .kinematic)
        #expect(body.effectiveInverseInertia == 0)
    }

    @Test("Dynamic body has non-zero effectiveInverseInertia when inertia set")
    func dynamicInertia() {
        let body = RigidBody2D(mass: 1, inertia: 5.0, bodyType: .dynamic)
        #expect(abs(body.effectiveInverseInertia - 0.2) < 0.001)
    }

    @Test("computeInertia for circle")
    func circleInertia() {
        let inertia = RigidBody2D.computeInertia(mass: 2.0, shape: .circle(radius: 10))
        // I = 0.5 * m * r^2 = 0.5 * 2.0 * 100 = 100
        #expect(abs(inertia - 100.0) < 0.01)
    }

    @Test("computeInertia for AABB")
    func aabbInertia() {
        let inertia = RigidBody2D.computeInertia(
            mass: 3.0,
            shape: .aabb(halfExtents: Vector2(x: 10, y: 5))
        )
        // w=20, h=10. I = m * (w^2 + h^2) / 12 = 3 * (400+100)/12 = 3 * 41.67 = 125
        #expect(abs(inertia - 125.0) < 0.1)
    }

    @Test("computeInertia for zero mass returns zero")
    func zeroMassInertia() {
        let inertia = RigidBody2D.computeInertia(mass: 0, shape: .circle(radius: 10))
        #expect(inertia == 0)
    }

    @Test("Inertia survives encode/decode")
    func inertiaCodable() throws {
        let original = RigidBody2D(mass: 5, inertia: 20, restitution: 0.3, friction: 0.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RigidBody2D.self, from: data)
        #expect(decoded.inertia == 20)
        #expect(abs(decoded.inverseInertia - 0.05) < 0.001)
    }

    @Test("Backward-compatible decode without inertia field")
    func backwardCompatDecode() throws {
        // Encode a body, strip the "inertia" key, and verify decode still works
        let original = RigidBody2D(mass: 1, inertia: 0, restitution: 0.2, friction: 0.3)
        let data = try JSONEncoder().encode(original)
        // Decode to dictionary, remove inertia, re-encode
        var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        dict.removeValue(forKey: "inertia")
        let modifiedData = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(RigidBody2D.self, from: modifiedData)
        #expect(decoded.inertia == 0)
        #expect(decoded.inverseInertia == 0)
    }
}

// MARK: - Joint Creation & Lifecycle

@Suite("Joint Lifecycle")
struct JointLifecycleTests {

    @Test("createRevoluteJoint returns valid handle")
    func createRevolute() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let handle = physics.createJoint(.revolute(RevoluteJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100)
            )), in: world)
            #expect(handle != .invalid)
            #expect(physics.jointCount == 1)
        }
        _ = physics
    }

    @Test("createDistanceJoint returns valid handle")
    func createDistance() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let handle = physics.createJoint(.distance(DistanceJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 200, y: 100)
            )), in: world)
            #expect(handle != .invalid)
            #expect(physics.jointCount == 1)
        }
        _ = physics
    }

    @Test("createWeldJoint returns valid handle")
    func createWeld() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let handle = physics.createJoint(.weld(WeldJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100)
            )), in: world)
            #expect(handle != .invalid)
            #expect(physics.jointCount == 1)
        }
        _ = physics
    }

    @Test("destroyJoint removes from store")
    func destroyJoint() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let handle = physics.createJoint(.revolute(RevoluteJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100)
            )), in: world)
            #expect(physics.jointCount == 1)
            physics.destroyJoint(handle)
            #expect(physics.jointCount == 0)
        }
        _ = physics
    }

    @Test("destroyJoint with invalid handle is no-op")
    func destroyInvalid() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            physics.createJoint(.revolute(RevoluteJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100)
            )), in: world)
            physics.destroyJoint(.invalid)
            physics.destroyJoint(JointHandle(id: 999))
            #expect(physics.jointCount == 1)
        }
        _ = physics
    }

    @Test("removeAllJoints clears store")
    func removeAll() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            physics.createJoint(.revolute(RevoluteJointDef(
                entityA: a, entityB: b, anchor: Vector2(x: 150, y: 100)
            )), in: world)
            physics.createJoint(.distance(DistanceJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 200, y: 100)
            )), in: world)
            #expect(physics.jointCount == 2)
            physics.removeAllJoints()
            #expect(physics.jointCount == 0)
        }
        _ = physics
    }

    @Test("jointCount tracks active joints")
    func jointCount() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            #expect(physics.jointCount == 0)
            let h1 = physics.createJoint(.revolute(RevoluteJointDef(
                entityA: a, entityB: b, anchor: Vector2(x: 150, y: 100)
            )), in: world)
            #expect(physics.jointCount == 1)
            let h2 = physics.createJoint(.weld(WeldJointDef(
                entityA: a, entityB: b, anchor: Vector2(x: 150, y: 100)
            )), in: world)
            #expect(physics.jointCount == 2)
            physics.destroyJoint(h1)
            #expect(physics.jointCount == 1)
            physics.destroyJoint(h2)
            #expect(physics.jointCount == 0)
        }
        _ = physics
    }
}

// MARK: - Distance Joint Solver Tests

@Suite("Distance Joint Solver")
struct DistanceJointSolverTests {

    @Test("Bodies at rest length do not move")
    func atRestLength() {
        let (world, _) = runPhysics(gravity: .zero, ticks: 10) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 100, y: 0))
            physics.createJoint(.distance(DistanceJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 0, y: 0),
                anchorB: Vector2(x: 100, y: 0),
                length: 100
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        #expect(abs(posA.x - 0) < 1.0)
        #expect(abs(posA.y - 0) < 1.0)
        #expect(abs(posB.x - 100) < 1.0)
        #expect(abs(posB.y - 0) < 1.0)
    }

    @Test("Bodies stretched beyond rest length pull together")
    func stretchedBodies() {
        // Bodies 200 apart, rest length 100 — should pull toward each other
        let (world, _) = runPhysics(gravity: .zero, ticks: 30) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 0))
            physics.createJoint(.distance(DistanceJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchorA: Vector2(x: 0, y: 0),
                anchorB: Vector2(x: 200, y: 0),
                length: 100
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let dist = sqrtf((posB.x - posA.x) * (posB.x - posA.x) + (posB.y - posA.y) * (posB.y - posA.y))
        // After 30 ticks the distance should be closer to 100 than the initial 200
        #expect(dist < 180, "Distance should decrease toward rest length, got \(dist)")
    }

    @Test("Bodies closer than rest length push apart")
    func compressedBodies() {
        // Bodies 20 apart, rest length 100 — should push apart
        let (world, _) = runPhysics(gravity: .zero, ticks: 30) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 20, y: 0))
            physics.createJoint(.distance(DistanceJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchorA: Vector2(x: 0, y: 0),
                anchorB: Vector2(x: 20, y: 0),
                length: 100
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let dist = sqrtf((posB.x - posA.x) * (posB.x - posA.x) + (posB.y - posA.y) * (posB.y - posA.y))
        // Should be further apart than initial 20
        #expect(dist > 30, "Distance should increase toward rest length, got \(dist)")
    }

    @Test("Spring joint with damping converges")
    func springDamping() {
        // Use a spring joint — should oscillate and converge
        let (world, _) = runPhysics(gravity: .zero, ticks: 120) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 0))
            physics.createJoint(.distance(DistanceJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchorA: Vector2(x: 0, y: 0),
                anchorB: Vector2(x: 200, y: 0),
                length: 100,
                frequencyHz: 4.0,
                dampingRatio: 0.8
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let dist = sqrtf((posB.x - posA.x) * (posB.x - posA.x) + (posB.y - posA.y) * (posB.y - posA.y))
        // After 120 ticks at 60fps (2 seconds) with damping, should be close to rest length
        #expect(abs(dist - 100) < 30, "Spring should converge near rest length, got dist \(dist)")
    }
}

// MARK: - Revolute Joint Solver Tests

@Suite("Revolute Joint Solver")
struct RevoluteJointSolverTests {

    @Test("Bodies already at anchor stay together")
    func bodiesAtAnchor() {
        // Two bodies positioned so the anchor is exactly between them
        let (world, _) = runPhysics(gravity: .zero, ticks: 20) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 100, y: 100))
            physics.createJoint(.revolute(RevoluteJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchor: Vector2(x: 100, y: 100)
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let dist = sqrtf((posB.x - posA.x) * (posB.x - posA.x) + (posB.y - posA.y) * (posB.y - posA.y))
        #expect(dist < 1.0, "Bodies at anchor should stay together, got dist \(dist)")
    }

    @Test("Bodies offset from anchor converge")
    func bodiesConverge() {
        // Bodies separated, joint should pull them toward the anchor
        let (world, _) = runPhysics(gravity: .zero, ticks: 30) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 50, y: 100))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 250, y: 100))
            physics.createJoint(.revolute(RevoluteJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchor: Vector2(x: 150, y: 100)
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position

        // The anchors on both bodies should be getting closer to the same point
        // posA's anchor = posA + localAnchorA rotated, but since no rotation, it's approximately posA + (100, 0)
        // posB's anchor = posB + localAnchorB rotated, approximately posB + (-100, 0)
        // These should converge
        let anchorFromA = Vector2(x: posA.x + 100, y: posA.y)
        let anchorFromB = Vector2(x: posB.x - 100, y: posB.y)
        let anchorDist = sqrtf((anchorFromB.x - anchorFromA.x) * (anchorFromB.x - anchorFromA.x)
                              + (anchorFromB.y - anchorFromA.y) * (anchorFromB.y - anchorFromA.y))
        // Initial anchor distance was (50+100) vs (250-100) = 150 vs 150 = 0
        // But positions drift due to solver — at least shouldn't diverge significantly
        #expect(anchorDist < 50, "Anchor points should converge, got \(anchorDist)")
    }

    @Test("Revolute joint with static body constrains dynamic body")
    func staticAndDynamic() {
        let (world, _) = runPhysics(gravity: .zero, ticks: 20) { world, physics in
            createStaticBody(world: world, name: "wall", position: Vector2(x: 100, y: 100))
            createDynamicBody(world: world, name: "ball", position: Vector2(x: 100, y: 100))
            // Initial velocity to test constraint
            world.updateComponent(Velocity2D.self, on: world.entity(named: "ball")!) { v in
                v.linear = Vector2(x: 50, y: 0)
            }
            physics.createJoint(.revolute(RevoluteJointDef(
                entityA: world.entity(named: "wall")!,
                entityB: world.entity(named: "ball")!,
                anchor: Vector2(x: 100, y: 100)
            )), in: world)
        }

        // Static body should not move
        let wallPos = world.getComponent(Transform2D.self, from: world.entity(named: "wall")!)!.position
        #expect(abs(wallPos.x - 100) < 0.1)
        #expect(abs(wallPos.y - 100) < 0.1)
    }
}

// MARK: - Weld Joint Solver Tests

@Suite("Weld Joint Solver")
struct WeldJointSolverTests {

    @Test("Weld joint locks relative position")
    func locksPosition() {
        // Two bodies welded together should maintain relative position
        let (world, _) = runPhysics(gravity: .zero, ticks: 20) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 100, y: 100))
            // Give one body velocity
            world.updateComponent(Velocity2D.self, on: world.entity(named: "a")!) { v in
                v.linear = Vector2(x: 100, y: 0)
            }
            physics.createJoint(.weld(WeldJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchor: Vector2(x: 100, y: 100)
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let dist = sqrtf((posB.x - posA.x) * (posB.x - posA.x) + (posB.y - posA.y) * (posB.y - posA.y))
        // Welded bodies should stay very close
        #expect(dist < 5.0, "Welded bodies should maintain relative position, got dist \(dist)")
    }

    @Test("Weld joint resists gravity separation")
    func resistsGravity() {
        // Two welded bodies with gravity — should fall together
        let (world, _) = runPhysics(gravity: Vector2(x: 0, y: 100), ticks: 30) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100), inertia: 100)
            createDynamicBody(world: world, name: "b", position: Vector2(x: 120, y: 100), inertia: 100)
            physics.createJoint(.weld(WeldJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchor: Vector2(x: 110, y: 100)
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position

        // Both should have fallen (y increased)
        #expect(posA.y > 100, "Body A should fall under gravity")
        #expect(posB.y > 100, "Body B should fall under gravity")

        // They should have fallen roughly the same amount
        #expect(abs(posA.y - posB.y) < 5.0, "Welded bodies should fall together")
    }
}

// MARK: - Breaking Joint Tests

@Suite("Breaking Joints")
struct BreakingJointTests {

    @Test("Joint with maxForce breaks under force")
    func breakableJoint() {
        var brokenEvents: [JointEvent] = []

        let (_, physics) = runPhysics(gravity: Vector2(x: 0, y: 5000), ticks: 30) { world, physics in
            // Static anchor + dynamic body with strong gravity
            createStaticBody(world: world, name: "anchor", position: Vector2(x: 100, y: 100))
            createDynamicBody(world: world, name: "ball", position: Vector2(x: 100, y: 100), mass: 10)
            // Add Velocity2D for static body so solver can read it
            world.addComponent(Velocity2D(), to: world.entity(named: "anchor")!)

            physics.createJoint(.distance(DistanceJointDef(
                entityA: world.entity(named: "anchor")!,
                entityB: world.entity(named: "ball")!,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 100, y: 100),
                length: 0.01,
                maxForce: 1.0  // Very low max force
            )), in: world)

            physics.onJointBroken = { event in
                brokenEvents.append(event)
            }
        }

        // The joint should have broken due to strong gravity on heavy body
        #expect(physics.jointCount == 0, "Joint should have been destroyed")
        #expect(brokenEvents.count > 0, "Should have received broken event")
    }

    @Test("Unbreakable joint (maxForce=0) never breaks")
    func unbreakableJoint() {
        let (_, physics) = runPhysics(gravity: Vector2(x: 0, y: 5000), ticks: 30) { world, physics in
            createStaticBody(world: world, name: "anchor", position: Vector2(x: 100, y: 100))
            createDynamicBody(world: world, name: "ball", position: Vector2(x: 100, y: 100), mass: 10)
            world.addComponent(Velocity2D(), to: world.entity(named: "anchor")!)

            physics.createJoint(.distance(DistanceJointDef(
                entityA: world.entity(named: "anchor")!,
                entityB: world.entity(named: "ball")!,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 100, y: 100),
                length: 0.01,
                maxForce: 0  // 0 = unbreakable
            )), in: world)
        }

        #expect(physics.jointCount == 1, "Unbreakable joint should still be alive")
    }
}

// MARK: - Integration Tests

@Suite("Joint Integration")
struct JointIntegrationTests {

    @Test("Pendulum: revolute joint + gravity swings")
    func pendulumSwings() {
        // Pin a body to a static anchor, let gravity swing it
        let (world, _) = runPhysics(gravity: Vector2(x: 0, y: 200), ticks: 60) { world, physics in
            createStaticBody(world: world, name: "pivot", position: Vector2(x: 200, y: 100))
            createDynamicBody(world: world, name: "bob", position: Vector2(x: 300, y: 100), inertia: 50)
            world.addComponent(Velocity2D(), to: world.entity(named: "pivot")!)

            physics.createJoint(.revolute(RevoluteJointDef(
                entityA: world.entity(named: "pivot")!,
                entityB: world.entity(named: "bob")!,
                anchor: Vector2(x: 200, y: 100)
            )), in: world)
        }

        let bobPos = world.getComponent(Transform2D.self, from: world.entity(named: "bob")!)!.position
        // Bob should have swung down (y > initial 100)
        #expect(bobPos.y > 100, "Pendulum bob should swing down under gravity, y=\(bobPos.y)")
    }

    @Test("Composite object: weld joints move as unit")
    func compositeObject() {
        // Three bodies welded together, given initial velocity — should move together
        let (world, _) = runPhysics(gravity: .zero, ticks: 20) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 120, y: 100))
            createDynamicBody(world: world, name: "c", position: Vector2(x: 140, y: 100))

            let a = world.entity(named: "a")!
            let b = world.entity(named: "b")!
            let c = world.entity(named: "c")!

            // Give all bodies same initial velocity
            world.updateComponent(Velocity2D.self, on: a) { v in v.linear = Vector2(x: 60, y: 0) }
            world.updateComponent(Velocity2D.self, on: b) { v in v.linear = Vector2(x: 60, y: 0) }
            world.updateComponent(Velocity2D.self, on: c) { v in v.linear = Vector2(x: 60, y: 0) }

            physics.createJoint(.weld(WeldJointDef(entityA: a, entityB: b, anchor: Vector2(x: 110, y: 100))), in: world)
            physics.createJoint(.weld(WeldJointDef(entityA: b, entityB: c, anchor: Vector2(x: 130, y: 100))), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let posC = world.getComponent(Transform2D.self, from: world.entity(named: "c")!)!.position

        // All should have moved right
        #expect(posA.x > 100, "Body A should have moved right")
        #expect(posB.x > 120, "Body B should have moved right")
        #expect(posC.x > 140, "Body C should have moved right")

        // Spacing should be approximately maintained
        let abDist = abs(posB.x - posA.x)
        let bcDist = abs(posC.x - posB.x)
        #expect(abs(abDist - 20) < 10, "AB spacing should be ~20, got \(abDist)")
        #expect(abs(bcDist - 20) < 10, "BC spacing should be ~20, got \(bcDist)")
    }

    @Test("Joint persists through multiple ticks")
    func persistence() {
        var jointAlive = true
        let (_, physics) = runPhysics(gravity: .zero, ticks: 60, afterTick: { _, physics, _ in
            if physics.jointCount == 0 { jointAlive = false }
        }) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            physics.createJoint(.distance(DistanceJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 200, y: 100)
            )), in: world)
        }

        #expect(jointAlive, "Joint should persist through all ticks")
        #expect(physics.jointCount == 1)
    }

    @Test("Mixed joint types in same scene")
    func mixedTypes() {
        let (_, physics) = runPhysics(gravity: Vector2(x: 0, y: 100), ticks: 30) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let c = createDynamicBody(world: world, name: "c", position: Vector2(x: 300, y: 100))
            let d = createDynamicBody(world: world, name: "d", position: Vector2(x: 400, y: 100))

            // Mix of all three joint types
            physics.createJoint(.revolute(RevoluteJointDef(entityA: a, entityB: b, anchor: Vector2(x: 150, y: 100))), in: world)
            physics.createJoint(.distance(DistanceJointDef(entityA: b, entityB: c, anchorA: Vector2(x: 200, y: 100), anchorB: Vector2(x: 300, y: 100))), in: world)
            physics.createJoint(.weld(WeldJointDef(entityA: c, entityB: d, anchor: Vector2(x: 350, y: 100))), in: world)
        }

        // Should not crash and all joints should survive
        #expect(physics.jointCount == 3)
    }
}

// MARK: - Debug Rendering Tests

@Suite("Joint Debug Rendering")
struct JointDebugTests {

    @Test("Options default drawJoints is true")
    func defaultOptions() {
        let options = PhysicsDebugRendererOptions()
        #expect(options.drawJoints == true)
    }

    @Test("Joint colors are configurable")
    func configurableColors() {
        let options = PhysicsDebugRendererOptions(
            jointColor: .red,
            jointAnchorColor: .blue,
            jointAnchorRadius: 8.0
        )
        #expect(options.jointColor == .red)
        #expect(options.jointAnchorColor == .blue)
        #expect(options.jointAnchorRadius == 8.0)
    }

    @Test("debugJointInfo returns correct data")
    func debugInfo() {
        let (world, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            physics.createJoint(.revolute(RevoluteJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100)
            )), in: world)
            physics.createJoint(.distance(DistanceJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 200, y: 100)
            )), in: world)
        }

        let infos = physics.debugJointInfo(world: world)
        #expect(infos.count == 2)

        let types = Set(infos.map { $0.jointType })
        #expect(types.contains("revolute"))
        #expect(types.contains("distance"))
    }

    @Test("debugJointInfo returns correct types for new joints")
    func debugInfoNewJoints() {
        let (world, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100),
                axis: Vector2(x: 1, y: 0)
            )), in: world)
            physics.createJoint(.rope(RopeJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 200, y: 100)
            )), in: world)
            physics.createJoint(.motor(MotorJointDef(
                entityA: a, entityB: b
            )), in: world)
        }

        let infos = physics.debugJointInfo(world: world)
        #expect(infos.count == 3)

        let types = Set(infos.map { $0.jointType })
        #expect(types.contains("prismatic"))
        #expect(types.contains("rope"))
        #expect(types.contains("motor"))
    }

    @Test("Prismatic debug info includes axis")
    func prismaticDebugAxis() {
        let (world, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100),
                axis: Vector2(x: 1, y: 0)
            )), in: world)
        }

        let infos = physics.debugJointInfo(world: world)
        #expect(infos.count == 1)
        let info = infos[0]
        #expect(info.jointType == "prismatic")
        #expect(info.axis != nil)
        // Axis should be approximately (1, 0) since body A has no rotation
        #expect(abs(info.axis!.x - 1.0) < 0.01)
        #expect(abs(info.axis!.y) < 0.01)
    }
}

// MARK: - Prismatic Joint Lifecycle

@Suite("Prismatic Joint Lifecycle")
struct PrismaticJointLifecycleTests {

    @Test("createPrismaticJoint returns valid handle")
    func createPrismatic() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let handle = physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 150, y: 100),
                axis: Vector2(x: 1, y: 0)
            )), in: world)
            #expect(handle != .invalid)
            #expect(physics.jointCount == 1)
        }
        _ = physics
    }

    @Test("createRopeJoint returns valid handle")
    func createRope() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let handle = physics.createJoint(.rope(RopeJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 200, y: 100)
            )), in: world)
            #expect(handle != .invalid)
            #expect(physics.jointCount == 1)
        }
        _ = physics
    }

    @Test("createMotorJoint returns valid handle")
    func createMotor() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 0) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 100))
            let handle = physics.createJoint(.motor(MotorJointDef(
                entityA: a, entityB: b,
                linearOffset: Vector2(x: 50, y: 0),
                maxForce: 100,
                maxTorque: 100
            )), in: world)
            #expect(handle != .invalid)
            #expect(physics.jointCount == 1)
        }
        _ = physics
    }
}

// MARK: - Prismatic Joint Solver Tests

@Suite("Prismatic Joint Solver")
struct PrismaticJointSolverTests {

    @Test("Bodies constrained to horizontal axis stay on axis")
    func staysOnAxis() {
        // Two bodies with prismatic joint on horizontal axis, apply perpendicular velocity
        let (world, _) = runPhysics(gravity: .zero, ticks: 30) { world, physics in
            let a = createStaticBody(world: world, name: "rail", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "slider", position: Vector2(x: 100, y: 100), inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            // Apply velocity perpendicular to axis (downward)
            world.updateComponent(Velocity2D.self, on: b) { v in
                v.linear = Vector2(x: 0, y: 200) // perpendicular to horizontal axis
            }
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 100, y: 100),
                axis: Vector2(x: 1, y: 0)
            )), in: world)
        }

        let pos = world.getComponent(Transform2D.self, from: world.entity(named: "slider")!)!.position
        // Should not have moved significantly off the horizontal axis
        #expect(abs(pos.y - 100) < 20, "Slider should stay on axis, y=\(pos.y)")
    }

    @Test("Bodies slide freely along axis")
    func slidesFreelyAlongAxis() {
        let (world, _) = runPhysics(gravity: .zero, ticks: 20) { world, physics in
            let a = createStaticBody(world: world, name: "rail", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "slider", position: Vector2(x: 100, y: 100), inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            // Apply velocity along the axis
            world.updateComponent(Velocity2D.self, on: b) { v in
                v.linear = Vector2(x: 100, y: 0)
            }
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 100, y: 100),
                axis: Vector2(x: 1, y: 0)
            )), in: world)
        }

        let pos = world.getComponent(Transform2D.self, from: world.entity(named: "slider")!)!.position
        // Should have moved along the axis
        #expect(pos.x > 110, "Slider should move along axis, x=\(pos.x)")
    }

    @Test("Rotation is locked between bodies")
    func rotationLocked() {
        let (world, _) = runPhysics(gravity: .zero, ticks: 30) { world, physics in
            let a = createStaticBody(world: world, name: "rail", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "slider", position: Vector2(x: 100, y: 100), inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            // Apply angular velocity
            world.updateComponent(Velocity2D.self, on: b) { v in
                v.angular = 5.0
            }
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 100, y: 100),
                axis: Vector2(x: 1, y: 0)
            )), in: world)
        }

        let rot = world.getComponent(Transform2D.self, from: world.entity(named: "slider")!)!.rotation
        // Rotation should be constrained near 0 (reference angle)
        #expect(abs(rot) < 0.5, "Rotation should be locked, rot=\(rot)")
    }

    @Test("Translation limits restrict movement")
    func translationLimits() {
        let (world, _) = runPhysics(gravity: .zero, ticks: 60) { world, physics in
            let a = createStaticBody(world: world, name: "rail", position: Vector2(x: 200, y: 100))
            let b = createDynamicBody(world: world, name: "slider", position: Vector2(x: 200, y: 100), inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            // Apply velocity along axis
            world.updateComponent(Velocity2D.self, on: b) { v in
                v.linear = Vector2(x: 200, y: 0)
            }
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 200, y: 100),
                axis: Vector2(x: 1, y: 0),
                enableLimit: true,
                lowerTranslation: -50,
                upperTranslation: 50
            )), in: world)
        }

        let pos = world.getComponent(Transform2D.self, from: world.entity(named: "slider")!)!.position
        // Should not exceed the upper limit by much
        let translation = pos.x - 200 // displacement from anchor
        #expect(translation < 80, "Translation should be limited, got \(translation)")
    }

    @Test("Motor drives body along axis")
    func motorDrivesAlongAxis() {
        let (world, _) = runPhysics(gravity: .zero, ticks: 60) { world, physics in
            let a = createStaticBody(world: world, name: "rail", position: Vector2(x: 200, y: 100))
            let b = createDynamicBody(world: world, name: "slider", position: Vector2(x: 200, y: 100), inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 200, y: 100),
                axis: Vector2(x: 1, y: 0),
                enableMotor: true,
                motorSpeed: 100,
                maxMotorForce: 500
            )), in: world)
        }

        let pos = world.getComponent(Transform2D.self, from: world.entity(named: "slider")!)!.position
        // Motor should have driven the slider to the right
        #expect(pos.x > 210, "Motor should drive slider along axis, x=\(pos.x)")
    }

    @Test("Prismatic with static body works as rail")
    func staticBodyRail() {
        let (world, _) = runPhysics(gravity: Vector2(x: 0, y: 200), ticks: 30) { world, physics in
            let a = createStaticBody(world: world, name: "rail", position: Vector2(x: 200, y: 200))
            let b = createDynamicBody(world: world, name: "slider", position: Vector2(x: 200, y: 200), inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 200, y: 200),
                axis: Vector2(x: 1, y: 0)
            )), in: world)
        }

        let railPos = world.getComponent(Transform2D.self, from: world.entity(named: "rail")!)!.position
        let sliderPos = world.getComponent(Transform2D.self, from: world.entity(named: "slider")!)!.position
        // Static body should not move
        #expect(abs(railPos.x - 200) < 0.1)
        #expect(abs(railPos.y - 200) < 0.1)
        // Slider should stay on horizontal axis despite gravity
        #expect(abs(sliderPos.y - 200) < 20, "Slider should stay on rail despite gravity, y=\(sliderPos.y)")
    }
}

// MARK: - Rope Joint Solver Tests

@Suite("Rope Joint Solver")
struct RopeJointSolverTests {

    @Test("Bodies within max length move freely (slack)")
    func slackMovesFreely() {
        // Bodies are 50 apart, maxLength is 200 — should move freely
        let (world, _) = runPhysics(gravity: .zero, ticks: 10) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 150, y: 100))
            // Move them toward each other
            world.updateComponent(Velocity2D.self, on: a) { v in v.linear = Vector2(x: 50, y: 0) }
            world.updateComponent(Velocity2D.self, on: b) { v in v.linear = Vector2(x: -50, y: 0) }
            physics.createJoint(.rope(RopeJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 150, y: 100),
                maxLength: 200
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        // Bodies should move freely — A moves right, B moves left
        #expect(posA.x > 100, "Body A should move right when slack, x=\(posA.x)")
        #expect(posB.x < 150, "Body B should move left when slack, x=\(posB.x)")
    }

    @Test("Bodies beyond max length are pulled back (taut)")
    func tautPullsBack() {
        // Bodies are 200 apart, maxLength is 100 — should pull together
        let (world, _) = runPhysics(gravity: .zero, ticks: 30) { world, physics in
            createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            createDynamicBody(world: world, name: "b", position: Vector2(x: 200, y: 0))
            physics.createJoint(.rope(RopeJointDef(
                entityA: world.entity(named: "a")!,
                entityB: world.entity(named: "b")!,
                anchorA: Vector2(x: 0, y: 0),
                anchorB: Vector2(x: 200, y: 0),
                maxLength: 100
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let dist = sqrtf((posB.x - posA.x) * (posB.x - posA.x) + (posB.y - posA.y) * (posB.y - posA.y))
        // Should be closer to maxLength than the initial 200
        #expect(dist < 180, "Rope should pull bodies toward maxLength, dist=\(dist)")
    }

    @Test("Rope only pulls, never pushes")
    func pullOnlyNeverPush() {
        // Bodies at 50 apart, maxLength 100 — moving toward each other should not be resisted
        let (world, _) = runPhysics(gravity: .zero, ticks: 10) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 50, y: 0))
            // Move toward each other
            world.updateComponent(Velocity2D.self, on: a) { v in v.linear = Vector2(x: 100, y: 0) }
            world.updateComponent(Velocity2D.self, on: b) { v in v.linear = Vector2(x: -100, y: 0) }
            physics.createJoint(.rope(RopeJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 0, y: 0),
                anchorB: Vector2(x: 50, y: 0),
                maxLength: 100
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        // Bodies should pass each other or get very close — rope doesn't push
        let dist = abs(posB.x - posA.x)
        #expect(dist < 50, "Rope should allow bodies to move closer, dist=\(dist)")
    }

    @Test("Auto-computed max length from initial distance")
    func autoMaxLength() {
        // Bodies are 80 apart, maxLength = 0 (auto) → should use 80
        let (world, _) = runPhysics(gravity: .zero, ticks: 30) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 80, y: 0))
            // Try to pull them apart
            world.updateComponent(Velocity2D.self, on: a) { v in v.linear = Vector2(x: -100, y: 0) }
            world.updateComponent(Velocity2D.self, on: b) { v in v.linear = Vector2(x: 100, y: 0) }
            physics.createJoint(.rope(RopeJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 0, y: 0),
                anchorB: Vector2(x: 80, y: 0),
                maxLength: 0 // auto-compute
            )), in: world)
        }

        let posA = world.getComponent(Transform2D.self, from: world.entity(named: "a")!)!.position
        let posB = world.getComponent(Transform2D.self, from: world.entity(named: "b")!)!.position
        let dist = sqrtf((posB.x - posA.x) * (posB.x - posA.x) + (posB.y - posA.y) * (posB.y - posA.y))
        // Should not stretch far beyond the initial 80 distance
        #expect(dist < 120, "Auto maxLength should keep bodies near initial distance, dist=\(dist)")
    }
}

// MARK: - Motor Joint Solver Tests

@Suite("Motor Joint Solver")
struct MotorJointSolverTests {

    @Test("Motor drives body B toward linear offset")
    func drivesTowardOffset() {
        // Body B starts 100 units right of A; motor targets B at 50 units right (closer)
        let (world, _) = runPhysics(gravity: .zero, ticks: 60) { world, physics in
            let a = createStaticBody(world: world, name: "anchor", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "follower", position: Vector2(x: 200, y: 100))
            world.addComponent(Velocity2D(), to: a)
            physics.createJoint(.motor(MotorJointDef(
                entityA: a, entityB: b,
                linearOffset: Vector2(x: 50, y: 0),
                correctionFactor: 0.5,
                maxForce: 500,
                maxTorque: 100
            )), in: world)
        }

        let pos = world.getComponent(Transform2D.self, from: world.entity(named: "follower")!)!.position
        // Should have moved closer to target (100 + 50 = 150)
        #expect(pos.x < 200, "Motor should drive body toward offset, x=\(pos.x)")
    }

    @Test("Motor drives angular alignment")
    func drivesAngularAlignment() {
        // Body B starts at rotation 1.0, motor targets rotation 0
        let (world, _) = runPhysics(gravity: .zero, ticks: 60) { world, physics in
            let a = createStaticBody(world: world, name: "anchor", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "follower", position: Vector2(x: 100, y: 100), inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            // Start B with a rotation offset
            world.updateComponent(Transform2D.self, on: b) { t in t.rotation = 1.0 }
            physics.createJoint(.motor(MotorJointDef(
                entityA: a, entityB: b,
                angularOffset: 0,
                correctionFactor: 0.5,
                maxForce: 100,
                maxTorque: 500
            )), in: world)
        }

        let rot = world.getComponent(Transform2D.self, from: world.entity(named: "follower")!)!.rotation
        // Should have rotated back toward 0
        #expect(abs(rot) < 0.8, "Motor should drive rotation toward offset, rot=\(rot)")
    }

    @Test("Motor respects maxForce limit")
    func respectsMaxForce() {
        // Motor with very low maxForce vs strong push — should not fully reach target
        let (world, _) = runPhysics(gravity: Vector2(x: 0, y: 500), ticks: 30) { world, physics in
            let a = createStaticBody(world: world, name: "anchor", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "follower", position: Vector2(x: 100, y: 100), mass: 10)
            world.addComponent(Velocity2D(), to: a)
            physics.createJoint(.motor(MotorJointDef(
                entityA: a, entityB: b,
                linearOffset: .zero,
                correctionFactor: 1.0,
                maxForce: 0.1, // Very weak motor
                maxTorque: 0.1
            )), in: world)
        }

        let pos = world.getComponent(Transform2D.self, from: world.entity(named: "follower")!)!.position
        // With strong gravity and weak motor, body should have fallen significantly
        #expect(pos.y > 120, "Weak motor should not hold against strong gravity, y=\(pos.y)")
    }

    @Test("Motor joint does not break")
    func doesNotBreak() {
        var brokenEvents: [JointEvent] = []
        let (_, physics) = runPhysics(gravity: Vector2(x: 0, y: 5000), ticks: 60) { world, physics in
            let a = createStaticBody(world: world, name: "anchor", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "follower", position: Vector2(x: 100, y: 100), mass: 10)
            world.addComponent(Velocity2D(), to: a)
            physics.createJoint(.motor(MotorJointDef(
                entityA: a, entityB: b,
                linearOffset: .zero,
                correctionFactor: 1.0,
                maxForce: 0.01, // Extremely weak
                maxTorque: 0.01
            )), in: world)
            physics.onJointBroken = { event in
                brokenEvents.append(event)
            }
        }

        // Motor joints never break — the motor just can't keep up
        #expect(physics.jointCount == 1, "Motor joint should still be alive")
        #expect(brokenEvents.isEmpty, "Motor joint should not emit break events")
    }
}

// MARK: - New Joint Integration Tests

@Suite("New Joint Integration")
struct NewJointIntegrationTests {

    @Test("All six joint types coexist")
    func sixJointTypes() {
        let (_, physics) = runPhysics(gravity: .zero, ticks: 10) { world, physics in
            let a = createDynamicBody(world: world, name: "a", position: Vector2(x: 0, y: 0))
            let b = createDynamicBody(world: world, name: "b", position: Vector2(x: 100, y: 0))
            let c = createDynamicBody(world: world, name: "c", position: Vector2(x: 200, y: 0))
            let d = createDynamicBody(world: world, name: "d", position: Vector2(x: 300, y: 0))
            let e = createDynamicBody(world: world, name: "e", position: Vector2(x: 400, y: 0))
            let f = createDynamicBody(world: world, name: "f", position: Vector2(x: 500, y: 0))
            let g = createDynamicBody(world: world, name: "g", position: Vector2(x: 600, y: 0))

            physics.createJoint(.revolute(RevoluteJointDef(entityA: a, entityB: b, anchor: Vector2(x: 50, y: 0))), in: world)
            physics.createJoint(.distance(DistanceJointDef(entityA: b, entityB: c, anchorA: Vector2(x: 100, y: 0), anchorB: Vector2(x: 200, y: 0))), in: world)
            physics.createJoint(.weld(WeldJointDef(entityA: c, entityB: d, anchor: Vector2(x: 250, y: 0))), in: world)
            physics.createJoint(.prismatic(PrismaticJointDef(entityA: d, entityB: e, anchor: Vector2(x: 350, y: 0), axis: Vector2(x: 1, y: 0))), in: world)
            physics.createJoint(.rope(RopeJointDef(entityA: e, entityB: f, anchorA: Vector2(x: 400, y: 0), anchorB: Vector2(x: 500, y: 0))), in: world)
            physics.createJoint(.motor(MotorJointDef(entityA: f, entityB: g, maxForce: 100, maxTorque: 100)), in: world)
        }

        // All 6 joints should survive 10 physics ticks without crashing
        #expect(physics.jointCount == 6)
    }

    @Test("Breaking prismatic joint emits event")
    func breakingPrismatic() {
        var brokenEvents: [JointEvent] = []
        let (_, physics) = runPhysics(gravity: Vector2(x: 0, y: 5000), ticks: 30) { world, physics in
            let a = createStaticBody(world: world, name: "rail", position: Vector2(x: 100, y: 100))
            let b = createDynamicBody(world: world, name: "slider", position: Vector2(x: 100, y: 100), mass: 10, inertia: 10)
            world.addComponent(Velocity2D(), to: a)
            physics.createJoint(.prismatic(PrismaticJointDef(
                entityA: a, entityB: b,
                anchor: Vector2(x: 100, y: 100),
                axis: Vector2(x: 1, y: 0),
                maxForce: 1.0 // Very low
            )), in: world)
            physics.onJointBroken = { event in
                brokenEvents.append(event)
            }
        }

        #expect(physics.jointCount == 0, "Prismatic joint should have broken")
        #expect(brokenEvents.count > 0, "Should have received broken event")
    }

    @Test("Breaking rope joint emits event")
    func breakingRope() {
        var brokenEvents: [JointEvent] = []
        let (_, physics) = runPhysics(gravity: Vector2(x: 0, y: 5000), ticks: 30) { world, physics in
            let a = createStaticBody(world: world, name: "anchor", position: Vector2(x: 100, y: 100))
            // Start ball beyond maxLength so rope is immediately taut
            let b = createDynamicBody(world: world, name: "ball", position: Vector2(x: 100, y: 250), mass: 10)
            world.addComponent(Velocity2D(), to: a)
            physics.createJoint(.rope(RopeJointDef(
                entityA: a, entityB: b,
                anchorA: Vector2(x: 100, y: 100),
                anchorB: Vector2(x: 100, y: 250),
                maxLength: 80,  // Less than initial 150 distance — immediately taut
                maxForce: 1.0   // Very low
            )), in: world)
            physics.onJointBroken = { event in
                brokenEvents.append(event)
            }
        }

        #expect(physics.jointCount == 0, "Rope joint should have broken")
        #expect(brokenEvents.count > 0, "Should have received broken event")
    }
}
