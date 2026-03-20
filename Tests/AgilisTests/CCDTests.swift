@testable import Agilis
import Testing

@Suite("CCD Integration Tests")
struct CCDTests {

    /// Helper: create a world with the physics system and run a number of ticks.
    private func runPhysics(
        gravity: Vector2 = .zero,
        cellSize: Float = 128,
        ticks: Int = 1,
        deltaTime: Double = 1.0 / 60.0,
        setup: (World, PhysicsWorld2D) -> Void
    ) -> (World, PhysicsWorld2D) {
        let world = World()
        let physics = PhysicsWorld2D(gravity: gravity, cellSize: cellSize)
        world.addSystem(physics)
        setup(world, physics)
        for _ in 0..<ticks {
            world.update(deltaTime: deltaTime)
        }
        return (world, physics)
    }

    // MARK: - Tunneling Prevention

    @Test("Fast circle through thin wall is blocked with CCD")
    func fastCircleThroughThinWallCCD() {
        // Circle at x=0 moving at 12000 px/s -> travels 200 px per tick at 1/60s
        // Thin wall (half-extents 2,50) at x=100 -- only 4px thick
        // Without CCD the circle would skip right over the wall
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 50)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 50)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 50)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // With CCD, bullet should be stopped at or before the wall
        #expect(pos.position.x < 100, "CCD bullet should not tunnel through the wall (x=\(pos.position.x))")
    }

    @Test("Fast circle through thin wall tunnels without CCD")
    func fastCircleThroughThinWallNoCCD() {
        // Same setup but useCCD = false -- should tunnel through
        // At 12000 px/s, bullet moves 200 px per tick, clearly past the 4px wall at x=100
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 50)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 50)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: false
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 50)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Without CCD, bullet should have tunneled past the wall (200 px displacement > wall thickness)
        #expect(pos.position.x > 102, "Without CCD, bullet should tunnel through (x=\(pos.position.x))")
    }

    @Test("Fast circle vs static circle blocked by CCD")
    func fastCircleVsStaticCircle() {
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let target = world.createEntity()
            world.setName("target", for: target)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: target)
            world.addComponent(Collider2D(shape: .circle(radius: 5)), to: target)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Should be clamped to before the target circle
        #expect(pos.position.x < 100, "CCD should prevent tunneling through circle (x=\(pos.position.x))")
    }

    @Test("Fast AABB through thin wall blocked by CCD")
    func fastAABBThroughThinWall() {
        let (world, _) = runPhysics { world, _ in
            let box = world.createEntity()
            world.setName("box", for: box)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: box)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: box)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: box)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: box
            )
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 4, y: 4))), to: box)

            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let box = world.entity(named: "box")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: box)!
        #expect(pos.position.x < 100, "CCD AABB should not tunnel through wall (x=\(pos.position.x))")
    }

    @Test("Fast circle vs polygon wall blocked by CCD")
    func fastCircleVsPolygon() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -2, y: -50), Vector2(x: 2, y: -50),
            Vector2(x: 2, y: 50), Vector2(x: -2, y: 50)
        ])

        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .polygon(poly)), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        #expect(pos.position.x < 100, "CCD circle should not tunnel through polygon (x=\(pos.position.x))")
    }

    // MARK: - Trigger & Layer Tests

    @Test("CCD body passes through trigger zone")
    func ccdBodyPassesThroughTrigger() {
        // Trigger zones should NOT block CCD bodies
        // Bullet moves 200 px per tick, trigger is at x=50 with half-extent 10
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let trigger = world.createEntity()
            world.setName("trigger", for: trigger)
            world.addComponent(Transform2D(position: Vector2(x: 50, y: 0)), to: trigger)
            world.addComponent(
                Collider2D(
                    shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
                    isTrigger: true
                ),
                to: trigger
            )
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Should pass through the trigger without being clamped (200 px displacement)
        #expect(pos.position.x > 100, "CCD should not clamp on trigger zones (x=\(pos.position.x))")
    }

    @Test("CCD respects layer mask filtering")
    func ccdRespectsLayerMask() {
        // Bullet on layer 2 (mask 2), wall on layer 4 (mask 4) -- incompatible
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(
                Collider2D(
                    shape: .circle(radius: 3),
                    layer: 2,
                    mask: 2
                ),
                to: bullet
            )

            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(
                Collider2D(
                    shape: .aabb(halfExtents: Vector2(x: 2, y: 50)),
                    layer: 4,
                    mask: 4
                ),
                to: wall
            )
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Mismatched layers: CCD should not clamp, bullet passes through
        #expect(
            pos.position.x > 102,
            "CCD should not clamp against non-colliding layers (x=\(pos.position.x))"
        )
    }

    // MARK: - Edge Cases

    @Test("CCD with zero displacement is skipped")
    func ccdZeroDisplacement() {
        // Bullet with zero velocity -- CCD should not crash or alter position
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 50, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 50, y: 0)), to: bullet)
            world.addComponent(Velocity2D(linear: .zero), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let wall = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: 60, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Position should remain at 50 (no movement, no CCD sweep)
        #expect(
            abs(pos.position.x - 50) < 0.1,
            "Zero velocity CCD body should stay put (x=\(pos.position.x))"
        )
    }

    @Test("Slow CCD body skips sweep (displacement < minimumExtent)")
    func ccdSlowBodySkips() {
        // Bullet moving slowly -- displacement per tick < circle radius, discrete is sufficient
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            // 60 px/s -> 1 px/tick, circle radius 5 -> sweep not needed
            world.addComponent(Velocity2D(linear: Vector2(x: 60, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 5)), to: bullet)

            let wall = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Slow body: displacement is ~1px, radius is 5 -> no CCD sweep, normal integration
        #expect(
            abs(pos.position.x - 1.0) < 0.5,
            "Slow CCD body should integrate normally (x=\(pos.position.x))"
        )
    }

    @Test("Two CCD bodies approaching same wall independently")
    func twoCCDBodiesApproachWall() {
        let (world, _) = runPhysics { world, _ in
            // Bullet 1 from the left (12000 px/s -> 200 px/tick)
            let b1 = world.createEntity()
            world.setName("b1", for: b1)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: -20)), to: b1)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: -20)), to: b1)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: b1)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: b1
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: b1)

            // Bullet 2 from the left, different y (18000 px/s -> 300 px/tick)
            let b2 = world.createEntity()
            world.setName("b2", for: b2)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 20)), to: b2)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 20)), to: b2)
            world.addComponent(Velocity2D(linear: Vector2(x: 18_000, y: 0)), to: b2)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: b2
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: b2)

            // Wall at x=200
            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 200, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 100))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let b1 = world.entity(named: "b1")!
        // swiftlint:disable:next force_unwrapping
        let b2 = world.entity(named: "b2")!
        // swiftlint:disable:next force_unwrapping
        let pos1 = world.getComponent(Transform2D.self, from: b1)!
        // swiftlint:disable:next force_unwrapping
        let pos2 = world.getComponent(Transform2D.self, from: b2)!

        #expect(pos1.position.x < 200, "Bullet 1 should be blocked by wall (x=\(pos1.position.x))")
        #expect(pos2.position.x < 200, "Bullet 2 should be blocked by wall (x=\(pos2.position.x))")
    }

    @Test("Fast falling body hits floor with CCD")
    func fastFallingBodyHitsFloor() {
        // High gravity, ball starts far above floor with fast downward velocity
        let (world, _) = runPhysics(gravity: Vector2(x: 0, y: 50_000)) { world, _ in
            let ball = world.createEntity()
            world.setName("ball", for: ball)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: ball)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 100, y: 0)), to: ball)
            world.addComponent(Velocity2D(linear: Vector2(x: 0, y: 30_000)), to: ball)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 1,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: ball
            )
            world.addComponent(Collider2D(shape: .circle(radius: 5)), to: ball)

            let floor = world.createEntity()
            world.setName("floor", for: floor)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 500)), to: floor)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 200, y: 10))), to: floor)
        }

        // swiftlint:disable:next force_unwrapping
        let ball = world.entity(named: "ball")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: ball)!
        // Ball should be stopped at or before the floor
        #expect(pos.position.y < 500, "CCD ball should not tunnel through floor (y=\(pos.position.y))")
    }

    // MARK: - CCD only applies to dynamic bodies

    @Test("Static body with useCCD flag does not trigger sweep")
    func staticBodyCCDIgnored() {
        // A static body with useCCD should not cause issues
        let (world, _) = runPhysics { world, _ in
            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(Velocity2D(), to: wall)
            world.addComponent(RigidBody2D(bodyType: .static, useCCD: true), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 10, y: 10))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let wall = world.entity(named: "wall")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: wall)!
        #expect(abs(pos.position.x - 100) < 0.01, "Static body should not move")
    }

    @Test("Collision event fires for CCD-clamped body")
    func ccdBodyGeneratesCollisionEvent() {
        var beganFired = false

        let (_, physics) = runPhysics { world, physics in
            let bullet = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let wall = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)

            physics.onCollisionBegan = { _ in beganFired = true }
        }

        // CCD clamps position, then narrow phase detects contact and fires event
        #expect(beganFired, "Collision event should fire for CCD-clamped body")
        #expect(!physics.events.isEmpty, "Events array should contain the collision")
    }

    // MARK: - Angular Sweep CCD

    @Test("Translating rotating rod detects wall via angular bounding circle")
    func translatingRotatingRodDetectsWall() {
        // A long thin rod (halfExtents 50x2) moving right AND spinning.
        // Bounding radius ~50. At 1/60s: position (200, 0), rotation 0.5 rad.
        // Wall placed far enough right (x=200, y=53) so the bounding circle at (0,0)
        // does NOT overlap the Minkowski-expanded wall at the start:
        //   Expanded wall: x [100, 300], y [-2, 108] -- start x=0 is outside.
        // Without angular sweep: sweptAABBVsAABB uses halfExtents (50,2),
        //   expanded wall y: [46, 60]. Sweep along y=0 misses (0 not in [46, 60]).
        // With angular sweep: bounding circle r=50 sweeps and hits at TOI ~0.5.
        let (world, _) = runPhysics { world, _ in
            let rod = world.createEntity()
            world.setName("rod", for: rod)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: rod)
            world.addComponent(
                PreviousTransform2D(position: Vector2(x: 0, y: 0), rotation: 0),
                to: rod
            )
            world.addComponent(
                Velocity2D(linear: Vector2(x: 12_000, y: 0), angular: 30),
                to: rod
            )
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: rod
            )
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 2))), to: rod)

            // Wall far enough right that bounding circle doesn't overlap at start
            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 200, y: 53)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 5))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let rod = world.entity(named: "rod")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: rod)!
        // Bounding circle sweep should detect the wall and clamp the rod well before x=200
        #expect(
            pos.position.x < 150,
            "Rotating rod should be clamped by angular CCD bounding circle (x=\(pos.position.x))"
        )
    }

    @Test("Angular displacement enters CCD sweep even with small translation")
    func angularDisplacementEntersCCDSweep() {
        // A rod with small linear velocity (below translational threshold) but high angular velocity.
        // Rod halfExtents (50, 2): minimumExtent = 4, boundingRadius ~50.
        // Velocity (200, 0), angular 60. At 1/60s: position (3.33, 0), rotation 1.0 rad.
        // Displacement = 3.33 < minimumExtent 4 -> translation alone does NOT trigger CCD.
        // Angular extent = 50 * 1.0 = 50 > 4 -> angular DOES trigger CCD.
        // Wall at (54, 0): expanded by r=50 -> x [2, 106]. Start x=0 is outside.
        // Bounding circle sweep TOI ~0.6. Rotation clamped to ~0.6 (< 1.0).
        let (world, _) = runPhysics { world, _ in
            let rod = world.createEntity()
            world.setName("rod", for: rod)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: rod)
            world.addComponent(
                PreviousTransform2D(position: Vector2(x: 0, y: 0), rotation: 0),
                to: rod
            )
            world.addComponent(
                Velocity2D(linear: Vector2(x: 200, y: 0), angular: 60),
                to: rod
            )
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: rod
            )
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 2))), to: rod)

            // Wall far enough that bounding circle at start (0,0) doesn't overlap
            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 54, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let rod = world.entity(named: "rod")!
        // swiftlint:disable:next force_unwrapping
        let transform = world.getComponent(Transform2D.self, from: rod)!
        // Without angular CCD: displacement 3.33 < extent 4, CCD skipped, rotation = 1.0.
        // With angular CCD: sweep fires, TOI ~0.6, rotation clamped to ~0.6.
        let fullAngularDisp: Float = 60.0 / 60.0 // 1.0 rad
        #expect(
            abs(transform.rotation) < fullAngularDisp - 0.1,
            "Angular CCD should enter sweep and clamp rotation (rot=\(transform.rotation))"
        )
    }

    @Test("Rotation is clamped alongside position when CCD triggers")
    func rotationClampedWithPosition() {
        // Fast-moving rotating body: both position and rotation should be clamped to TOI
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(
                PreviousTransform2D(position: Vector2(x: 0, y: 0), rotation: 0),
                to: bullet
            )
            world.addComponent(
                Velocity2D(linear: Vector2(x: 12_000, y: 0), angular: 30),
                to: bullet
            )
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            let wall = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: wall)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let transform = world.getComponent(Transform2D.self, from: bullet)!
        // At 1/60s: linear disp = 200px, angular disp = 0.5 rad
        // TOI should be approximately 0.475 (95/200)
        // Rotation should be clamped proportionally, not the full 0.5 rad
        let fullAngularDisp: Float = 30.0 / 60.0 // 0.5 rad
        #expect(
            abs(transform.rotation) < fullAngularDisp,
            "Rotation should be clamped to TOI fraction (rot=\(transform.rotation))"
        )
        #expect(
            abs(transform.rotation) > 0,
            "Rotation should be partially applied, not zero"
        )
    }

    @Test("Circle with angular velocity does not use bounding circle (exact path)")
    func circleAngularVelocityExact() {
        // Circle with high angular velocity should still use exact sweep, not bounding circle
        // (circles are rotationally symmetric -- angular velocity doesn't affect collision)
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(
                PreviousTransform2D(position: Vector2(x: 0, y: 0), rotation: 0),
                to: bullet
            )
            world.addComponent(
                Velocity2D(linear: Vector2(x: 12_000, y: 0), angular: 100),
                to: bullet
            )
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            // Wall far above -- only reachable if bounding circle were incorrectly used
            let wall = world.createEntity()
            world.setName("wall", for: wall)
            world.addComponent(Transform2D(position: Vector2(x: 50, y: 30)), to: wall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 2))), to: wall)

            // Actual wall that the circle should hit
            let realWall = world.createEntity()
            world.setName("realWall", for: realWall)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: realWall)
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 2, y: 50))), to: realWall)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Should be stopped by the real wall, not the distant wall
        #expect(pos.position.x < 100, "Circle should hit real wall (x=\(pos.position.x))")
    }

    // MARK: - Bilateral CCD

    @Test("Two CCD bullets approaching each other are both blocked")
    func bilateralCCDBulletsBlocked() {
        // Two bullets flying toward each other at high speed
        let (world, _) = runPhysics { world, _ in
            // Bullet A: moving right at 12000 px/s from x=0
            let bulletA = world.createEntity()
            world.setName("bulletA", for: bulletA)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bulletA)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bulletA)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bulletA)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bulletA
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bulletA)

            // Bullet B: moving left at 12000 px/s from x=200
            let bulletB = world.createEntity()
            world.setName("bulletB", for: bulletB)
            world.addComponent(Transform2D(position: Vector2(x: 200, y: 0)), to: bulletB)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 200, y: 0)), to: bulletB)
            world.addComponent(Velocity2D(linear: Vector2(x: -12_000, y: 0)), to: bulletB)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bulletB
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bulletB)
        }

        // swiftlint:disable:next force_unwrapping
        let bulletA = world.entity(named: "bulletA")!
        // swiftlint:disable:next force_unwrapping
        let bulletB = world.entity(named: "bulletB")!
        // swiftlint:disable:next force_unwrapping
        let posA = world.getComponent(Transform2D.self, from: bulletA)!
        // swiftlint:disable:next force_unwrapping
        let posB = world.getComponent(Transform2D.self, from: bulletB)!

        // Both should be clamped before they pass through each other
        // Without bilateral CCD: A ends at x=200, B ends at x=0 -- they pass through
        // With bilateral CCD: A should be around x=97, B around x=103
        #expect(
            posA.position.x < posB.position.x,
            "Bullets should not pass through each other (A=\(posA.position.x), B=\(posB.position.x))"
        )
    }

    @Test("CCD body vs non-CCD body uses existing behavior")
    func ccdVsNonCCDExistingBehavior() {
        // Fast CCD bullet vs slow non-CCD target
        let (world, _) = runPhysics { world, _ in
            let bullet = world.createEntity()
            world.setName("bullet", for: bullet)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bullet)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bullet)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bullet
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bullet)

            // Slow-moving target (no CCD)
            let target = world.createEntity()
            world.setName("target", for: target)
            world.addComponent(Transform2D(position: Vector2(x: 100, y: 0)), to: target)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 100, y: 0)), to: target)
            world.addComponent(Velocity2D(linear: Vector2(x: 60, y: 0)), to: target)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: false
                ),
                to: target
            )
            world.addComponent(Collider2D(shape: .circle(radius: 5)), to: target)
        }

        // swiftlint:disable:next force_unwrapping
        let bullet = world.entity(named: "bullet")!
        // swiftlint:disable:next force_unwrapping
        let pos = world.getComponent(Transform2D.self, from: bullet)!
        // Bullet should be blocked before reaching target position
        #expect(pos.position.x < 110, "CCD should block bullet near target (x=\(pos.position.x))")
    }

    @Test("Bilateral CCD with angular sweep combined")
    func bilateralCCDWithAngularSweep() {
        // Two rotating CCD bodies approaching each other
        let (world, _) = runPhysics { world, _ in
            let rodA = world.createEntity()
            world.setName("rodA", for: rodA)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: rodA)
            world.addComponent(
                PreviousTransform2D(position: Vector2(x: 0, y: 0), rotation: 0),
                to: rodA
            )
            world.addComponent(
                Velocity2D(linear: Vector2(x: 12_000, y: 0), angular: 10),
                to: rodA
            )
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: rodA
            )
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 20, y: 2))), to: rodA)

            let rodB = world.createEntity()
            world.setName("rodB", for: rodB)
            world.addComponent(Transform2D(position: Vector2(x: 200, y: 0)), to: rodB)
            world.addComponent(
                PreviousTransform2D(position: Vector2(x: 200, y: 0), rotation: 0),
                to: rodB
            )
            world.addComponent(
                Velocity2D(linear: Vector2(x: -12_000, y: 0), angular: -10),
                to: rodB
            )
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: rodB
            )
            world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 20, y: 2))), to: rodB)
        }

        // swiftlint:disable:next force_unwrapping
        let rodA = world.entity(named: "rodA")!
        // swiftlint:disable:next force_unwrapping
        let rodB = world.entity(named: "rodB")!
        // swiftlint:disable:next force_unwrapping
        let posA = world.getComponent(Transform2D.self, from: rodA)!
        // swiftlint:disable:next force_unwrapping
        let posB = world.getComponent(Transform2D.self, from: rodB)!

        #expect(
            posA.position.x < posB.position.x,
            "Rotating rods should not pass through each other (A=\(posA.position.x), B=\(posB.position.x))"
        )
    }

    @Test("Two CCD bodies moving in same direction do not falsely collide")
    func bilateralCCDSameDirection() {
        // Two bullets moving in the same direction at similar speeds -- should not collide
        let (world, _) = runPhysics { world, _ in
            let bulletA = world.createEntity()
            world.setName("bulletA", for: bulletA)
            world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: bulletA)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 0, y: 0)), to: bulletA)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bulletA)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bulletA
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bulletA)

            // Bullet B starts ahead, same speed -- maintaining gap
            let bulletB = world.createEntity()
            world.setName("bulletB", for: bulletB)
            world.addComponent(Transform2D(position: Vector2(x: 50, y: 0)), to: bulletB)
            world.addComponent(PreviousTransform2D(position: Vector2(x: 50, y: 0)), to: bulletB)
            world.addComponent(Velocity2D(linear: Vector2(x: 12_000, y: 0)), to: bulletB)
            world.addComponent(
                RigidBody2D(
                    mass: 1,
                    restitution: 0,
                    gravityScale: 0,
                    bodyType: .dynamic,
                    useCCD: true
                ),
                to: bulletB
            )
            world.addComponent(Collider2D(shape: .circle(radius: 3)), to: bulletB)
        }

        // swiftlint:disable:next force_unwrapping
        let bulletA = world.entity(named: "bulletA")!
        // swiftlint:disable:next force_unwrapping
        let bulletB = world.entity(named: "bulletB")!
        // swiftlint:disable:next force_unwrapping
        let posA = world.getComponent(Transform2D.self, from: bulletA)!
        // swiftlint:disable:next force_unwrapping
        let posB = world.getComponent(Transform2D.self, from: bulletB)!

        // Both should have moved their full displacement (200px each at 12000 px/s / 60fps)
        // Gap should remain ~50px
        let gap = posB.position.x - posA.position.x
        #expect(
            abs(gap - 50) < 5,
            "Same-direction bullets should maintain gap (gap=\(gap))"
        )
    }
}
