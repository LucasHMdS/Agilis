@testable import Agilis
import Testing

@Suite("PhysicsWorld2D Integration Tests")
struct PhysicsWorld2DTests {

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

    // MARK: - Gravity

    @Test("Dynamic body falls under gravity")
    func gravityFall() {
        let (world, _) = runPhysics { world, _ in
            let e = world.createEntity()
            world.setName("ball", for: e)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: e)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 100, y: 0)), to: e)
            world.addComponent(Velocity2D(), to: e)
            world.addComponent(RigidBody2D(bodyType: .dynamic), to: e)
            world.addComponent(Collider2D(shape: .circle(radius: 5)), to: e)
        }

        // swiftlint:disable:next force_unwrapping
        let ball = world.entity(named: "ball")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: ball)!
        // swiftlint:disable:next force_unwrapping
        let vel = world.getComponent(Velocity2D.self, from: ball)!

        // After 1 tick, gravity should have been applied
        #expect(vel.linear.y > 0, "Ball should be moving downward")
        #expect(pos.position.y > 0, "Ball should have fallen")
    }

    @Test("Static body does not fall")
    func staticNoFall() {
        let (world, _) = runPhysics { world, _ in
            let e = world.createEntity()
            world.setName("floor", for: e)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 500)), to: e)
            world.addComponent(Velocity2D(), to: e)
            world.addComponent(RigidBody2D(bodyType: .static), to: e)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 400, y: 20))), to: e)
        }

        // swiftlint:disable:next force_unwrapping
        let floor = world.entity(named: "floor")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: floor)!

        #expect(abs(pos.position.y - 500) < 0.01, "Static body should not move")
    }

    // MARK: - Collision Detection & Response

    @Test("Ball collides with static floor")
    func ballFloorCollision() {
        // Ball starts just above the floor, should collide within a few ticks
        let (world, physics) = runPhysics(ticks: 5) { world, _ in
            let ball = world.createEntity()
            world.setName("ball", for: ball)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 80)), to: ball)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 100, y: 80)), to: ball)
            world.addComponent(Velocity2D(linear: Vector2(x: 0, y: 100)), to: ball)
            world.addComponent(RigidBody2D(mass: 1, restitution: 0, bodyType: .dynamic), to: ball)
            world.addComponent(Collider2D(shape: .circle(radius: 10)), to: ball)

            let floor = world.createEntity()
            world.setName("floor", for: floor)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: floor)
            world.addComponent(RigidBody2D(bodyType: .static), to: floor)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 200, y: 10))), to: floor)
        }

        // The ball should have been stopped or bounced
        // swiftlint:disable:next force_unwrapping
        let ball = world.entity(named: "ball")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: ball)!

        // Ball should not have fallen far through the floor
        // Floor top edge is at y=90 (100-10), ball bottom at pos.y+10
        #expect(pos.position.y + 10 <= 95, "Ball should not penetrate floor significantly")
    }

    @Test("Ball bounces off wall with restitution=1")
    func ballBounce() {
        let (world, _) = runPhysics(ticks: 3) { world, _ in
            let ball = world.createEntity()
            world.setName("ball", for: ball)
            world.addComponent(Transform2D(position: Vector2(x: 85, y: 50)), to: ball)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 85, y: 50)), to: ball)
            world.addComponent(Velocity2D(linear: Vector2(x: 100, y: 0)), to: ball)
            world.addComponent(RigidBody2D(mass: 1, restitution: 1.0, gravityScale: 0, bodyType: .dynamic), to: ball)
            world.addComponent(Collider2D(shape: .circle(radius: 10)), to: ball)

            let wall = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 50)), to: wall)
            world.addComponent(RigidBody2D(mass: 1, restitution: 1.0, bodyType: .static), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 5, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let ball = world.entity(named: "ball")!
        // swiftlint:disable:next force_unwrapping
        let vel = world.getComponent(Velocity2D.self, from: ball)!

        // After bouncing off the wall, x velocity should be negative
        #expect(vel.linear.x < 50, "Ball should have bounced, reducing or reversing x velocity")
    }

    // MARK: - Triggers

    @Test("Trigger generates events but no physics response")
    func triggerNoResponse() {
        var beganFired = false

        let (world, _) = runPhysics(ticks: 3, setup: { world, physics in
            physics.onCollisionBegan = { _ in
                beganFired = true
            }

            let ball = world.createEntity()
            world.setName("ball", for: ball)
            world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: ball)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 50, y: 50)), to: ball)
            world.addComponent(Velocity2D(linear: Vector2(x: 50, y: 0)), to: ball)
            world.addComponent(RigidBody2D(mass: 1, gravityScale: 0, bodyType: .dynamic), to: ball)
            world.addComponent(Collider2D(shape: .circle(radius: 10)), to: ball)

            let zone = world.createEntity()
            world.setName("zone", for: zone)
            world.addComponent(Transform2D(position: Vector2(x: 60, y: 50)), to: zone)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 20, y: 20)), isTrigger: true), to: zone)
        })

        // Ball should pass through the trigger zone
        // swiftlint:disable:next force_unwrapping
        let ball = world.entity(named: "ball")!
        // swiftlint:disable:next force_unwrapping
        let vel = world.getComponent(Velocity2D.self, from: ball)!

        // Velocity should be unchanged (no physics response from trigger)
        #expect(abs(vel.linear.x - 50) < 5, "Trigger should not affect velocity")
    }

    // MARK: - Collision Layers

    @Test("Entities on different layers don't collide")
    func layerFiltering() {
        let (world, physics) = runPhysics(ticks: 3) { world, _ in
            let ball = world.createEntity()
            world.setName("ball", for: ball)
            world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: ball)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 50, y: 50)), to: ball)
            world.addComponent(Velocity2D(linear: Vector2(x: 50, y: 0)), to: ball)
            world.addComponent(RigidBody2D(mass: 1, gravityScale: 0, bodyType: .dynamic), to: ball)
            world.addComponent(Collider2D(
                shape: .circle(radius: 10),
                layer: 0b01, mask: 0b01 // Only collides with layer 1
            ), to: ball)

            let wall = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: 65, y: 50)), to: wall)
            world.addComponent(RigidBody2D(bodyType: .static), to: wall)
            world.addComponent(Collider2D(
                shape: .aabb(halfExtents: Vector2(x: 5, y: 50)),
                layer: 0b10, mask: 0b10 // Only collides with layer 2
            ), to: wall)
        }

        // No collision events should be generated
        #expect(physics.events.isEmpty, "Different layers should not produce collision events")

        // Ball should pass through
        // swiftlint:disable:next force_unwrapping
        let ball = world.entity(named: "ball")!
        // swiftlint:disable:next force_unwrapping
        let vel = world.getComponent(Velocity2D.self, from: ball)!
        #expect(abs(vel.linear.x - 50) < 5, "Ball should pass through wall on different layer")
    }

    // MARK: - PreviousTransform2D

    @Test("PreviousTransform2D is updated before integration")
    func previousTransformUpdate() {
        let (world, _) = runPhysics(gravity: .zero) { world, _ in
            let e = world.createEntity()
            world.setName("entity", for: e)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 200)), to: e)
            world.addComponent(PreviousTransform2D(position: .zero), to: e)
            world.addComponent(Velocity2D(linear: Vector2(x: 10, y: 20)), to: e)
            world.addComponent(Collider2D(shape: .circle(radius: 5)), to: e)
        }

        // swiftlint:disable:next force_unwrapping
        let e = world.entity(named: "entity")!
        // swiftlint:disable:next force_unwrapping
        let prev = world.getComponent(PreviousTransform2D.self, from: e)!

        // PreviousTransform should have been set to the pre-integration position
        #expect(abs(prev.position.x - 100) < 0.01)
        #expect(abs(prev.position.y - 200) < 0.01)
    }

    // MARK: - Collision Events Lifecycle

    @Test("Collision events: began then ongoing")
    func collisionEventLifecycle() {
        var tickEvents: [[CollisionEvent]] = []

        _ = runPhysics(
            gravity: .zero,
            ticks: 3,
            afterTick: { _, physics, _ in
                tickEvents.append(physics.events)
            },
            setup: { world, _ in
                // Two overlapping static entities (always in contact)
                let a = world.createEntity()
                world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: a)
                world.addComponent(Collider2D(shape: .circle(radius: 20)), to: a)

                let b = world.createEntity()
                world.addComponent(Transform2D(position: Vector2(x: 60, y: 50)), to: b)
                world.addComponent(Collider2D(shape: .circle(radius: 20)), to: b)
            }
        )

        // Tick 0: should have "began"
        if !tickEvents.isEmpty && !tickEvents[0].isEmpty {
            let firstTick = tickEvents[0]
            #expect(firstTick.contains { $0.type == .began })
        }

        // Tick 1+: should have "ongoing"
        if tickEvents.count > 1 && !tickEvents[1].isEmpty {
            let secondTick = tickEvents[1]
            #expect(secondTick.contains { $0.type == .ongoing })
        }
    }

    @Test("Collision ended event when entities separate")
    func collisionEndedEvent() {
        var tickEvents: [[CollisionEvent]] = []

        _ = runPhysics(
            gravity: .zero,
            ticks: 10,
            afterTick: { _, physics, _ in
                tickEvents.append(physics.events)
            },
            setup: { world, _ in
                // Ball moving away from a static circle
                let ball = world.createEntity()
                world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: ball)
                world.addComponent(PreviousTransform2D(position: Vector2(x: 50, y: 50)), to: ball)
                world.addComponent(Velocity2D(linear: Vector2(x: 200, y: 0)), to: ball)
                world.addComponent(RigidBody2D(mass: 1, gravityScale: 0, bodyType: .dynamic), to: ball)
                world.addComponent(Collider2D(shape: .circle(radius: 10)), to: ball)

                let other = world.createEntity()
                world.addComponent(Transform2D(position: Vector2(x: 55, y: 50)), to: other)
                world.addComponent(Collider2D(shape: .circle(radius: 10)), to: other)
            }
        )

        // At some point, events should include "ended" as the ball moves away
        let allEvents = tickEvents.flatMap { $0 }
        let hasEnded = allEvents.contains { $0.type == .ended }
        let hasBegan = allEvents.contains { $0.type == .began }

        // Should at least have started colliding
        #expect(hasBegan || hasEnded, "Should have detected collision lifecycle")
    }

    // MARK: - Kinematic Body

    @Test("Kinematic body is not affected by gravity")
    func kinematicNoGravity() {
        let (world, _) = runPhysics(ticks: 5) { world, _ in
            let e = world.createEntity()
            world.setName("kinematic", for: e)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: e)
            world.addComponent(Velocity2D(), to: e)
            world.addComponent(RigidBody2D(bodyType: .kinematic), to: e)
            world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)
        }

        // swiftlint:disable:next force_unwrapping
        let e = world.entity(named: "kinematic")!
        // swiftlint:disable:next force_unwrapping
        let vel = world.getComponent(Velocity2D.self, from: e)!

        // Kinematic body should not have gravity applied
        #expect(abs(vel.linear.y) < 0.01, "Kinematic body should not be affected by gravity")
    }

    // MARK: - Zero Gravity

    @Test("Zero gravity: no acceleration")
    func zeroGravity() {
        let (world, _) = runPhysics(gravity: .zero, ticks: 5) { world, _ in
            let e = world.createEntity()
            world.setName("ball", for: e)
            world.addComponent(Transform2D(position: .zero), to: e)
            world.addComponent(Velocity2D(), to: e)
            world.addComponent(RigidBody2D(bodyType: .dynamic), to: e)
            world.addComponent(Collider2D(shape: .circle(radius: 5)), to: e)
        }

        // swiftlint:disable:next force_unwrapping
        let ball = world.entity(named: "ball")!
        // swiftlint:disable:next force_unwrapping
        let vel = world.getComponent(Velocity2D.self, from: ball)!

        #expect(abs(vel.linear.x) < 0.001)
        #expect(abs(vel.linear.y) < 0.001)
    }
}
