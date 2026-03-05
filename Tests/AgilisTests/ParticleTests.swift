import Testing
@testable import Agilis

// MARK: - Mock Renderer for Particles

/// Records drawCircle, drawRect, and drawSprite calls for verification.
final class ParticleSpyRenderer: @unchecked Sendable, RenderBackend {
    var drawnCircles: [(center: Vector2, radius: Float, color: Color)] = []
    var drawnRects: [(rect: Rect, color: Color)] = []
    var drawnSprites: [Sprite] = []

    func drawCircle(center: Vector2, radius: Float, color: Color) {
        drawnCircles.append((center: center, radius: radius, color: color))
    }
    func drawRect(_ rect: Rect, color: Color) {
        drawnRects.append((rect: rect, color: color))
    }
    func drawSprite(_ sprite: Sprite) {
        drawnSprites.append(sprite)
    }

    // RenderBackend stubs
    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {}
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {}
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {}
    func loadDefaultFont() -> FontHandle { .invalid }
    func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
    func destroyFont(_ handle: FontHandle) {}
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {}
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size { .zero }
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { Size(width: 800, height: 600) }
}

// MARK: - Color.lerp Tests

@Suite("Color.lerp Tests")
struct ColorLerpTests {

    @Test("t=0 returns start color")
    func lerpAtZero() {
        let result = Color.lerp(.red, .blue, t: 0)
        #expect(result == .red)
    }

    @Test("t=1 returns end color")
    func lerpAtOne() {
        let result = Color.lerp(.red, .blue, t: 1)
        #expect(result == .blue)
    }

    @Test("t=0.5 returns midpoint")
    func lerpAtHalf() {
        let a = Color(r: 0, g: 0, b: 0, a: 0)
        let b = Color(r: 200, g: 100, b: 50, a: 254)
        let result = Color.lerp(a, b, t: 0.5)
        #expect(result.r == 100)
        #expect(result.g == 50)
        #expect(result.b == 25)
        #expect(result.a == 127)
    }

    @Test("Interpolates alpha channel")
    func lerpAlpha() {
        let a = Color(r: 255, g: 255, b: 255, a: 255)
        let b = Color(r: 255, g: 255, b: 255, a: 0)
        let result = Color.lerp(a, b, t: 0.5)
        #expect(result.a == 127)
    }

    @Test("Clamps t below 0")
    func lerpClampBelow() {
        let result = Color.lerp(.white, .black, t: -1.0)
        #expect(result == .white)
    }

    @Test("Clamps t above 1")
    func lerpClampAbove() {
        let result = Color.lerp(.white, .black, t: 2.0)
        #expect(result == .black)
    }

    @Test("Identical colors returns same")
    func lerpIdentical() {
        let result = Color.lerp(.red, .red, t: 0.5)
        #expect(result == .red)
    }
}

// MARK: - Particle Tests

@Suite("Particle Tests")
struct ParticleTests {

    @Test("normalizedAge at spawn is 0")
    func ageAtSpawn() {
        let p = Particle(position: .zero, velocity: .zero, lifetime: 2.0,
                         maxLifetime: 2.0, scale: 1.0, rotation: 0, angularVelocity: 0)
        #expect(p.normalizedAge == 0)
    }

    @Test("normalizedAge at half lifetime is 0.5")
    func ageAtHalf() {
        let p = Particle(position: .zero, velocity: .zero, lifetime: 1.0,
                         maxLifetime: 2.0, scale: 1.0, rotation: 0, angularVelocity: 0)
        #expect(p.normalizedAge == 0.5)
    }

    @Test("normalizedAge when lifetime is zero is 1.0")
    func ageAtDeath() {
        let p = Particle(position: .zero, velocity: .zero, lifetime: 0,
                         maxLifetime: 2.0, scale: 1.0, rotation: 0, angularVelocity: 0)
        #expect(p.normalizedAge == 1.0)
    }

    @Test("normalizedAge with zero maxLifetime returns 1.0")
    func ageZeroMax() {
        let p = Particle(position: .zero, velocity: .zero, lifetime: 0,
                         maxLifetime: 0, scale: 1.0, rotation: 0, angularVelocity: 0)
        #expect(p.normalizedAge == 1.0)
    }
}

// MARK: - EmissionShape Tests

@Suite("EmissionShape Tests")
struct EmissionShapeTests {

    @Test("Point shape always returns zero offset")
    func pointShape() {
        for _ in 0..<50 {
            let p = ParticleEmitter.randomPointInShape(.point)
            #expect(p.x == 0 && p.y == 0)
        }
    }

    @Test("Circle shape returns points within radius")
    func circleShape() {
        let radius: Float = 10.0
        for _ in 0..<100 {
            let p = ParticleEmitter.randomPointInShape(.circle(radius: radius))
            let dist = p.length
            #expect(dist <= radius + 0.001)
        }
    }

    @Test("Ring shape returns points on the circle edge")
    func ringShape() {
        let radius: Float = 20.0
        for _ in 0..<100 {
            let p = ParticleEmitter.randomPointInShape(.ring(radius: radius))
            let dist = p.length
            #expect(abs(dist - radius) < 0.01)
        }
    }

    @Test("Rect shape returns points within bounds")
    func rectShape() {
        let w: Float = 30.0
        let h: Float = 20.0
        for _ in 0..<100 {
            let p = ParticleEmitter.randomPointInShape(.rect(width: w, height: h))
            #expect(p.x >= -w / 2 && p.x <= w / 2)
            #expect(p.y >= -h / 2 && p.y <= h / 2)
        }
    }
}

// MARK: - ParticleEmitter Tests

@Suite("ParticleEmitter Tests")
struct ParticleEmitterTests {

    @Test("Default init has sensible values")
    func defaultInit() {
        let emitter = ParticleEmitter()
        #expect(emitter.emissionRate == 10)
        #expect(emitter.maxParticles == 100)
        #expect(emitter.isEmitting == true)
        #expect(emitter.worldSpace == true)
        #expect(emitter.activeParticleCount == 0)
    }

    @Test("Starts with zero active particles")
    func zeroActive() {
        let emitter = ParticleEmitter(maxParticles: 500)
        #expect(emitter.activeParticleCount == 0)
    }

    @Test("burst queues particles")
    func burstQueues() {
        var emitter = ParticleEmitter()
        emitter.burst(count: 10)
        #expect(emitter.burstQueue == 10)
    }

    @Test("Multiple bursts accumulate")
    func burstAccumulates() {
        var emitter = ParticleEmitter()
        emitter.burst(count: 5)
        emitter.burst(count: 3)
        #expect(emitter.burstQueue == 8)
    }

    @Test("clear removes all particles")
    func clearParticles() {
        var emitter = ParticleEmitter(maxParticles: 10)
        for _ in 0..<5 {
            emitter.spawnParticle(emitterPosition: .zero)
        }
        #expect(emitter.activeParticleCount == 5)
        emitter.clear()
        #expect(emitter.activeParticleCount == 0)
    }

    @Test("spawnParticle respects maxParticles")
    func spawnCapped() {
        var emitter = ParticleEmitter(maxParticles: 3)
        for _ in 0..<10 {
            emitter.spawnParticle(emitterPosition: .zero)
        }
        #expect(emitter.activeParticleCount == 3)
    }

    @Test("spawnParticle world space adds emitter position")
    func spawnWorldSpace() {
        var emitter = ParticleEmitter(
            maxParticles: 1,
            emissionShape: .point,
            worldSpace: true
        )
        emitter.spawnParticle(emitterPosition: Vector2(x: 100, y: 200))
        #expect(emitter.particles[0].position.x == 100)
        #expect(emitter.particles[0].position.y == 200)
    }

    @Test("spawnParticle local space uses offset only")
    func spawnLocalSpace() {
        var emitter = ParticleEmitter(
            maxParticles: 1,
            emissionShape: .point,
            worldSpace: false
        )
        emitter.spawnParticle(emitterPosition: Vector2(x: 100, y: 200))
        #expect(emitter.particles[0].position.x == 0)
        #expect(emitter.particles[0].position.y == 0)
    }
}

// MARK: - ParticleSystem Integration Tests

/// Helper to create a world with ParticleSystem and run N ticks.
@discardableResult
private func runParticles(
    ticks: Int = 1,
    deltaTime: Double = 1.0 / 60.0,
    setup: (World) -> Entity
) -> (World, Entity) {
    let world = World()
    let system = ParticleSystem()
    world.addSystem(system)
    let entity = setup(world)
    for _ in 0..<ticks {
        world.update(deltaTime: deltaTime)
    }
    return (world, entity)
}

@Suite("ParticleSystem Integration Tests")
struct ParticleSystemTests {

    @Test("Priority defaults to 200")
    func defaultPriority() {
        let system = ParticleSystem()
        #expect(system.priority == 200)
    }

    @Test("Custom priority")
    func customPriority() {
        let system = ParticleSystem(priority: 50)
        #expect(system.priority == 50)
    }

    @Test("Emission rate spawns particles over time")
    func emissionRate() {
        let (world, e) = runParticles(ticks: 60, deltaTime: 1.0 / 60.0) { world in
            let e = world.createEntity()
            world.addComponent(Transform2D(position: .zero), to: e)
            world.addComponent(ParticleEmitter(
                emissionRate: 60,
                maxParticles: 100,
                lifetime: 10.0...10.0
            ), to: e)
            return e
        }

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        // 60 rate * 60 ticks * (1/60 dt) = ~60 particles
        #expect(emitter.activeParticleCount >= 55)
        #expect(emitter.activeParticleCount <= 65)
    }

    @Test("Burst spawns exact count")
    func burstSpawn() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 100,
            lifetime: 10.0...10.0
        )
        emitter.burst(count: 25)
        world.addComponent(emitter, to: e)

        world.update(deltaTime: 1.0 / 60.0)

        let updated = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(updated.activeParticleCount == 25)
    }

    @Test("Burst capped by maxParticles")
    func burstCapped() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 10,
            lifetime: 10.0...10.0
        )
        emitter.burst(count: 50)
        world.addComponent(emitter, to: e)

        world.update(deltaTime: 1.0 / 60.0)

        let updated = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(updated.activeParticleCount == 10)
    }

    @Test("Lifetime countdown kills particles")
    func lifetimeKills() {
        let (world, e) = runParticles(ticks: 1, deltaTime: 1.0) { world in
            let e = world.createEntity()
            world.addComponent(Transform2D(position: .zero), to: e)
            var emitter = ParticleEmitter(
                emissionRate: 0,
                maxParticles: 10,
                lifetime: 0.5...0.5
            )
            emitter.burst(count: 5)
            world.addComponent(emitter, to: e)
            return e
        }

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        // Particles had 0.5s lifetime, dt=1.0s → all dead
        #expect(emitter.activeParticleCount == 0)
    }

    @Test("Velocity integration moves particles")
    func velocityIntegration() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(ParticleEmitter(
            emissionRate: 0,
            maxParticles: 1,
            lifetime: 10.0...10.0,
            speed: 100...100,
            angle: 0...0, // right
            emissionShape: .point
        ), to: e)

        // Burst one particle
        world.updateComponent(ParticleEmitter.self, on: e) { $0.burst(count: 1) }

        world.update(deltaTime: 1.0)

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(emitter.activeParticleCount == 1)
        // speed=100, angle=0, dt=1.0 → x should be ~100
        #expect(emitter.particles[0].position.x > 90)
    }

    @Test("Gravity accelerates particles")
    func gravityEffect() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(ParticleEmitter(
            emissionRate: 0,
            maxParticles: 1,
            lifetime: 10.0...10.0,
            speed: 0...0,
            gravity: Vector2(x: 0, y: 100),
            emissionShape: .point
        ), to: e)

        world.updateComponent(ParticleEmitter.self, on: e) { $0.burst(count: 1) }

        world.update(deltaTime: 1.0)

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        // Gravity 100 px/s², dt=1.0 → velocity.y = 100, position.y = 100
        #expect(emitter.particles[0].velocity.y > 90)
        #expect(emitter.particles[0].position.y > 90)
    }

    @Test("Damping reduces velocity")
    func dampingEffect() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(ParticleEmitter(
            emissionRate: 0,
            maxParticles: 1,
            lifetime: 10.0...10.0,
            speed: 100...100,
            angle: 0...0,
            damping: 0.5,
            emissionShape: .point
        ), to: e)

        world.updateComponent(ParticleEmitter.self, on: e) { $0.burst(count: 1) }

        world.update(deltaTime: 1.0)

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        // speed=100, damping=0.5, dt=1.0 → velocity.x = 100 * (1 - 0.5) = 50
        #expect(emitter.particles[0].velocity.x > 40)
        #expect(emitter.particles[0].velocity.x < 60)
    }

    @Test("Dead particles are swap-removed")
    func swapRemove() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 10,
            lifetime: 1.0...1.0
        )
        emitter.burst(count: 5)
        world.addComponent(emitter, to: e)

        // Tick 1: spawn 5 particles (lifetime=1.0, dt=0.5 → all alive)
        world.update(deltaTime: 0.5)
        let after1 = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(after1.activeParticleCount == 5)

        // Tick 2: dt=0.6 → lifetime goes to -0.1, all die
        world.update(deltaTime: 0.6)
        let after2 = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(after2.activeParticleCount == 0)
    }

    @Test("Zero emission rate spawns nothing")
    func zeroRate() {
        let (world, e) = runParticles(ticks: 60) { world in
            let e = world.createEntity()
            world.addComponent(Transform2D(position: .zero), to: e)
            world.addComponent(ParticleEmitter(
                emissionRate: 0,
                maxParticles: 100
            ), to: e)
            return e
        }

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(emitter.activeParticleCount == 0)
    }

    @Test("isEmitting false stops rate emission")
    func notEmitting() {
        let (world, e) = runParticles(ticks: 60) { world in
            let e = world.createEntity()
            world.addComponent(Transform2D(position: .zero), to: e)
            world.addComponent(ParticleEmitter(
                emissionRate: 60,
                maxParticles: 100,
                isEmitting: false
            ), to: e)
            return e
        }

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(emitter.activeParticleCount == 0)
    }

    @Test("isEmitting false still allows burst")
    func burstWhileNotEmitting() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 100,
            lifetime: 10.0...10.0,
            isEmitting: false
        )
        emitter.burst(count: 10)
        world.addComponent(emitter, to: e)

        world.update(deltaTime: 1.0 / 60.0)

        let updated = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(updated.activeParticleCount == 10)
    }

    @Test("Zero maxParticles never spawns")
    func zeroMax() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        var emitter = ParticleEmitter(
            emissionRate: 100,
            maxParticles: 0,
            lifetime: 10.0...10.0
        )
        emitter.burst(count: 50)
        world.addComponent(emitter, to: e)

        world.update(deltaTime: 1.0)

        let updated = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(updated.activeParticleCount == 0)
    }

    @Test("Angular velocity updates rotation")
    func angularVelocityRotation() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(ParticleEmitter(
            emissionRate: 0,
            maxParticles: 1,
            lifetime: 10.0...10.0,
            speed: 0...0,
            angularVelocity: 1.0...1.0,
            emissionShape: .point
        ), to: e)

        world.updateComponent(ParticleEmitter.self, on: e) { $0.burst(count: 1) }

        world.update(deltaTime: 1.0)

        let emitter = world.getComponent(ParticleEmitter.self, from: e)!
        #expect(abs(emitter.particles[0].rotation - 1.0) < 0.01)
    }

    @Test("Multiple emitters update independently")
    func multipleEmitters() {
        let world = World()
        let system = ParticleSystem()
        world.addSystem(system)

        let e1 = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e1)
        var em1 = ParticleEmitter(emissionRate: 0, maxParticles: 10, lifetime: 10.0...10.0)
        em1.burst(count: 3)
        world.addComponent(em1, to: e1)

        let e2 = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e2)
        var em2 = ParticleEmitter(emissionRate: 0, maxParticles: 10, lifetime: 10.0...10.0)
        em2.burst(count: 7)
        world.addComponent(em2, to: e2)

        world.update(deltaTime: 1.0 / 60.0)

        let updated1 = world.getComponent(ParticleEmitter.self, from: e1)!
        let updated2 = world.getComponent(ParticleEmitter.self, from: e2)!
        #expect(updated1.activeParticleCount == 3)
        #expect(updated2.activeParticleCount == 7)
    }
}

// MARK: - Particle Rendering Tests

@Suite("Particle Rendering Tests")
struct ParticleRenderingTests {

    @Test("drawParticles with zero active particles draws nothing")
    func drawNothing() {
        let renderer = ParticleSpyRenderer()
        let emitter = ParticleEmitter(emissionRate: 0)
        renderer.drawParticles(emitter, at: .zero)
        #expect(renderer.drawnCircles.isEmpty)
        #expect(renderer.drawnRects.isEmpty)
        #expect(renderer.drawnSprites.isEmpty)
    }

    @Test("Circle shape calls drawCircle for each particle")
    func drawCircles() {
        let renderer = ParticleSpyRenderer()
        var emitter = ParticleEmitter(
            maxParticles: 5,
            lifetime: 10.0...10.0,
            renderShape: .circle(radius: 4)
        )
        for _ in 0..<3 {
            emitter.spawnParticle(emitterPosition: .zero)
        }
        renderer.drawParticles(emitter, at: .zero)
        #expect(renderer.drawnCircles.count == 3)
    }

    @Test("Rect shape calls drawRect for each particle")
    func drawRects() {
        let renderer = ParticleSpyRenderer()
        var emitter = ParticleEmitter(
            maxParticles: 5,
            lifetime: 10.0...10.0,
            renderShape: .rect(width: 8, height: 8)
        )
        for _ in 0..<2 {
            emitter.spawnParticle(emitterPosition: .zero)
        }
        renderer.drawParticles(emitter, at: .zero)
        #expect(renderer.drawnRects.count == 2)
    }

    @Test("Sprite shape calls drawSprite for each particle")
    func drawSprites() {
        let renderer = ParticleSpyRenderer()
        let tex = TextureHandle(id: 42)
        var emitter = ParticleEmitter(
            maxParticles: 5,
            lifetime: 10.0...10.0,
            renderShape: .sprite(texture: tex, sourceRect: Rect(x: 0, y: 0, width: 16, height: 16))
        )
        for _ in 0..<2 {
            emitter.spawnParticle(emitterPosition: .zero)
        }
        renderer.drawParticles(emitter, at: .zero)
        #expect(renderer.drawnSprites.count == 2)
        #expect(renderer.drawnSprites[0].texture.id == 42)
    }

    @Test("Interpolates color based on particle age")
    func colorInterpolation() {
        let renderer = ParticleSpyRenderer()
        var emitter = ParticleEmitter(
            maxParticles: 1,
            lifetime: 2.0...2.0,
            speed: 0...0,
            startColor: Color(r: 200, g: 200, b: 200, a: 200),
            endColor: Color(r: 0, g: 0, b: 0, a: 0),
            renderShape: .circle(radius: 4),
            worldSpace: true
        )
        emitter.spawnParticle(emitterPosition: .zero)
        // Manually set lifetime to half → normalizedAge = 0.5
        emitter.particles[0].lifetime = 1.0

        renderer.drawParticles(emitter, at: .zero)

        #expect(renderer.drawnCircles.count == 1)
        let color = renderer.drawnCircles[0].color
        #expect(color.r == 100)
        #expect(color.a == 100)
    }

    @Test("Interpolates scale based on particle age")
    func scaleInterpolation() {
        let renderer = ParticleSpyRenderer()
        var emitter = ParticleEmitter(
            maxParticles: 1,
            lifetime: 2.0...2.0,
            speed: 0...0,
            startScale: 2.0...2.0,
            endScale: 0.0,
            renderShape: .circle(radius: 10),
            worldSpace: true
        )
        emitter.spawnParticle(emitterPosition: .zero)
        // Half life → scale = lerp(2.0, 0.0, t=0.5) = 1.0
        emitter.particles[0].lifetime = 1.0

        renderer.drawParticles(emitter, at: .zero)

        #expect(renderer.drawnCircles.count == 1)
        // radius = 10 * scale(1.0) = 10
        #expect(abs(renderer.drawnCircles[0].radius - 10.0) < 0.01)
    }

    @Test("Local space offsets by emitter position")
    func localSpaceOffset() {
        let renderer = ParticleSpyRenderer()
        var emitter = ParticleEmitter(
            maxParticles: 1,
            lifetime: 10.0...10.0,
            speed: 0...0,
            emissionShape: .point,
            renderShape: .circle(radius: 4),
            worldSpace: false
        )
        emitter.spawnParticle(emitterPosition: .zero) // particle at (0,0) local

        renderer.drawParticles(emitter, at: Vector2(x: 50, y: 75))

        #expect(renderer.drawnCircles.count == 1)
        #expect(renderer.drawnCircles[0].center.x == 50)
        #expect(renderer.drawnCircles[0].center.y == 75)
    }

    @Test("World space uses particle position directly")
    func worldSpaceDirect() {
        let renderer = ParticleSpyRenderer()
        var emitter = ParticleEmitter(
            maxParticles: 1,
            lifetime: 10.0...10.0,
            speed: 0...0,
            emissionShape: .point,
            renderShape: .circle(radius: 4),
            worldSpace: true
        )
        emitter.spawnParticle(emitterPosition: Vector2(x: 100, y: 200))

        // Draw at different emitter position — should NOT affect world-space particles
        renderer.drawParticles(emitter, at: Vector2(x: 999, y: 999))

        #expect(renderer.drawnCircles.count == 1)
        #expect(renderer.drawnCircles[0].center.x == 100)
        #expect(renderer.drawnCircles[0].center.y == 200)
    }

    @Test("Sprite uses center origin")
    func spriteOrigin() {
        let renderer = ParticleSpyRenderer()
        let srcRect = Rect(x: 0, y: 0, width: 32, height: 32)
        var emitter = ParticleEmitter(
            maxParticles: 1,
            lifetime: 10.0...10.0,
            speed: 0...0,
            renderShape: .sprite(texture: TextureHandle(id: 1), sourceRect: srcRect),
            worldSpace: true
        )
        emitter.spawnParticle(emitterPosition: .zero)

        renderer.drawParticles(emitter, at: .zero)

        #expect(renderer.drawnSprites.count == 1)
        #expect(renderer.drawnSprites[0].origin.x == 16)
        #expect(renderer.drawnSprites[0].origin.y == 16)
    }
}
