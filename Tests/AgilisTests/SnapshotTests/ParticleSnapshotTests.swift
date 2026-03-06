import Testing
@testable import Agilis

@Suite("Particle Snapshots", .serialized)
struct ParticleSnapshotTests {

    @Test("Circle particles")
    func circleParticles() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)

        var emitter = ParticleEmitter(
            emissionRate: 0, maxParticles: 20,
            lifetime: 1.0...1.0,
            speed: 100...100,
            angle: 0...0,
            startColor: Color(r: 255, g: 200, b: 0),
            endColor: Color(r: 255, g: 0, b: 0, a: 0),
            emissionShape: .point,
            renderShape: .circle(radius: 5),
            isEmitting: false
        )
        emitter.burst(count: 10)
        world.addComponent(emitter, to: entity)

        // Tick the particle system once
        let particleSystem = ParticleSystem()
        world.addSystem(particleSystem)
        world.update(deltaTime: 0.016)

        // Read back the emitter after tick
        let updatedEmitter = world.getComponent(ParticleEmitter.self, from: entity)!

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticles(updatedEmitter, at: Vector2(x: 160, y: 120))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Particles", name: "circle-particles")
    }

    @Test("Rectangle particles")
    func rectParticles() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)

        var emitter = ParticleEmitter(
            emissionRate: 0, maxParticles: 15,
            lifetime: 1.0...1.0,
            speed: 80...80,
            angle: 0...0,
            startColor: Color(r: 0, g: 200, b: 255),
            endColor: Color(r: 0, g: 50, b: 255, a: 0),
            emissionShape: .point,
            renderShape: .rect(width: 10, height: 6),
            isEmitting: false
        )
        emitter.burst(count: 8)
        world.addComponent(emitter, to: entity)

        let particleSystem = ParticleSystem()
        world.addSystem(particleSystem)
        world.update(deltaTime: 0.016)

        let updatedEmitter = world.getComponent(ParticleEmitter.self, from: entity)!

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticles(updatedEmitter, at: Vector2(x: 160, y: 120))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Particles", name: "rect-particles")
    }

    @Test("Color interpolation over lifetime")
    func colorInterpolation() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)

        var emitter = ParticleEmitter(
            emissionRate: 0, maxParticles: 20,
            lifetime: 2.0...2.0,
            speed: 60...60,
            angle: 0...0,
            startColor: Color(r: 0, g: 255, b: 0),
            endColor: Color(r: 255, g: 0, b: 0),
            emissionShape: .point,
            renderShape: .circle(radius: 8),
            isEmitting: false
        )
        emitter.burst(count: 10)
        world.addComponent(emitter, to: entity)

        let particleSystem = ParticleSystem()
        world.addSystem(particleSystem)
        // Multiple ticks to show color gradient at different ages
        for _ in 0..<5 {
            world.update(deltaTime: 0.1)
        }
        // Burst more so particles exist at different ages
        world.updateComponent(ParticleEmitter.self, on: entity) { e in
            e.burst(count: 5)
        }
        world.update(deltaTime: 0.1)

        let updatedEmitter = world.getComponent(ParticleEmitter.self, from: entity)!

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticles(updatedEmitter, at: Vector2(x: 160, y: 120))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Particles", name: "particle-color-lerp")
    }

    @Test("Scale interpolation over lifetime")
    func scaleInterpolation() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)

        var emitter = ParticleEmitter(
            emissionRate: 0, maxParticles: 20,
            lifetime: 2.0...2.0,
            speed: 50...50,
            angle: 0...0,
            startColor: .white,
            endColor: .white,
            startScale: 2.0...2.0,
            endScale: 0.1,
            emissionShape: .point,
            renderShape: .circle(radius: 6),
            isEmitting: false
        )
        emitter.burst(count: 10)
        world.addComponent(emitter, to: entity)

        let particleSystem = ParticleSystem()
        world.addSystem(particleSystem)
        for _ in 0..<5 {
            world.update(deltaTime: 0.1)
        }
        world.updateComponent(ParticleEmitter.self, on: entity) { e in
            e.burst(count: 5)
        }
        world.update(deltaTime: 0.1)

        let updatedEmitter = world.getComponent(ParticleEmitter.self, from: entity)!

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticles(updatedEmitter, at: Vector2(x: 160, y: 120))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Particles", name: "particle-scale-lerp")
    }

    @Test("Emission shape debug rendering")
    func emissionShapeDebug() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let world = World()

        // Point emitter
        let e1 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 60, y: 60)), to: e1)
        world.addComponent(ParticleEmitter(
            emissionShape: .point, renderShape: .circle(radius: 3)
        ), to: e1)

        // Circle emitter
        let e2 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 60)), to: e2)
        world.addComponent(ParticleEmitter(
            emissionShape: .circle(radius: 30), renderShape: .circle(radius: 3)
        ), to: e2)

        // Rect emitter
        let e3 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 260, y: 60)), to: e3)
        world.addComponent(ParticleEmitter(
            emissionShape: .rect(width: 50, height: 30), renderShape: .circle(radius: 3)
        ), to: e3)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticleDebug(world: world, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Particles", name: "emission-shape-debug")
    }
}
