import Testing
@testable import Agilis

@Suite("Physics Debug Snapshots", .serialized)
struct PhysicsDebugSnapshotTests {

    @Test("AABB collider debug outline")
    func aabbCollider() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 40, y: 25))), to: entity)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawPhysicsDebug(world: world)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PhysicsDebug", name: "aabb-collider")
    }

    @Test("Circle collider debug outline")
    func circleCollider() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)
        world.addComponent(Collider2D(shape: .circle(radius: 50)), to: entity)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawPhysicsDebug(world: world)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PhysicsDebug", name: "circle-collider")
    }

    @Test("Polygon collider debug outline")
    func polygonCollider() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)
        // Triangle polygon (CCW in math coords)
        let poly = ConvexPolygon(vertices: [
            Vector2(x: 0, y: -40),
            Vector2(x: 35, y: 30),
            Vector2(x: -35, y: 30)
        ])
        world.addComponent(Collider2D(shape: .polygon(poly)), to: entity)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawPhysicsDebug(world: world)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PhysicsDebug", name: "polygon-collider")
    }

    @Test("Body type colors — dynamic, static, kinematic")
    func bodyTypeColors() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()

        // Dynamic (cyan)
        let dyn = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 60, y: 120)), to: dyn)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 25, y: 25))), to: dyn)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: dyn)

        // Static (gray)
        let stat = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: stat)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 25, y: 25))), to: stat)
        world.addComponent(RigidBody2D(bodyType: .static), to: stat)

        // Kinematic (yellow)
        let kin = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 260, y: 120)), to: kin)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 25, y: 25))), to: kin)
        world.addComponent(RigidBody2D(bodyType: .kinematic), to: kin)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawPhysicsDebug(world: world)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PhysicsDebug", name: "body-type-colors")
    }

    @Test("Trigger collider shown in green")
    func triggerCollider() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)
        world.addComponent(
            Collider2D(shape: .aabb(halfExtents: Vector2(x: 40, y: 40)), isTrigger: true),
            to: entity
        )
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawPhysicsDebug(world: world)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PhysicsDebug", name: "trigger-collider")
    }

    @Test("Velocity vectors")
    func velocityVectors() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()

        let e1 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 120)), to: e1)
        world.addComponent(Collider2D(shape: .circle(radius: 20)), to: e1)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: e1)
        world.addComponent(Velocity2D(linear: Vector2(x: 200, y: -100)), to: e1)

        let e2 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 220, y: 120)), to: e2)
        world.addComponent(Collider2D(shape: .circle(radius: 20)), to: e2)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: e2)
        world.addComponent(Velocity2D(linear: Vector2(x: -150, y: 200)), to: e2)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var options = PhysicsDebugRendererOptions()
            options.drawVelocities = true
            r.drawPhysicsDebug(world: world, options: options)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PhysicsDebug", name: "velocity-vectors")
    }

    @Test("Rotated AABB collider")
    func rotatedCollider() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(
            Transform2D(position: Vector2(x: 160, y: 120), rotation: .pi / 4),
            to: entity
        )
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 25))), to: entity)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawPhysicsDebug(world: world)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PhysicsDebug", name: "rotated-aabb")
    }
}
