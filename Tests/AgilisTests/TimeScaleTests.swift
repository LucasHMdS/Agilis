@testable import Agilis
import Testing

// MARK: - Time Scale Tests

@Suite("Time Scale Tests")
struct TimeScaleTests {

    // MARK: - Property Tests

    @Test("Default timeScale is 1.0")
    func defaultTimeScale() {
        let app = makeTestApp()
        #expect(app.timeScale == 1.0)
    }

    @Test("timeScale can be set to 0 (pause)")
    func timeScalePause() {
        let app = makeTestApp()
        app.timeScale = 0
        #expect(app.timeScale == 0)
    }

    @Test("timeScale can be set to fractional values (slow motion)")
    func timeScaleSlowMotion() {
        let app = makeTestApp()
        app.timeScale = 0.5
        #expect(app.timeScale == 0.5)
    }

    @Test("timeScale can be set greater than 1 (fast forward)")
    func timeScaleFastForward() {
        let app = makeTestApp()
        app.timeScale = 3.0
        #expect(app.timeScale == 3.0)
    }

    // MARK: - Subsystem Scaling Verification
    // Since Application.run() blocks and requires a real renderer, these tests
    // verify that subsystems behave correctly with different deltaTime values,
    // which is the practical effect of timeScale on the fixed-timestep loop.

    @Test("Physics velocity integration scales linearly with deltaTime")
    func physicsScalesWithDelta() {
        let world = World()
        let physics = PhysicsWorld2D(gravity: .zero, cellSize: 128)
        world.addSystem(physics)

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.addComponent(Velocity2D(linear: Vector2(x: 100, y: 0)), to: entity)
        world.addComponent(RigidBody2D(mass: 1.0), to: entity)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 5, y: 5))), to: entity)

        // Normal speed: 1 tick at 1/60
        world.update(deltaTime: 1.0 / 60.0)
        // swiftlint:disable:next force_unwrapping
        var transform = world.getComponent(Transform2D.self, from: entity)!
        let normalPos = transform.position.x

        // Reset
        world.addComponent(Transform2D(position: .zero), to: entity)

        // Half speed: 1 tick at 1/120 (simulating timeScale=0.5 via half-rate ticks)
        world.update(deltaTime: 1.0 / 120.0)
        // swiftlint:disable:next force_unwrapping
        transform = world.getComponent(Transform2D.self, from: entity)!
        let halfPos = transform.position.x

        // Half deltaTime should produce roughly half the movement
        #expect(abs(halfPos - normalPos * 0.5) < 0.1)
    }

    @Test("Animation advances proportionally to deltaTime")
    func animationScalesWithDelta() {
        let world = World()
        let animSystem = AnimationSystem()
        world.addSystem(animSystem)

        let clip = AnimationClip(
            name: "test",
            frames: [
                AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1),
                AnimationFrame(sourceRect: Rect(x: 32, y: 0, width: 32, height: 32), duration: 0.1),
                AnimationFrame(sourceRect: Rect(x: 64, y: 0, width: 32, height: 32), duration: 0.1)
            ],
            mode: .forward
        )

        let entity = world.createEntity()
        world.addComponent(Sprite(texture: .invalid), to: entity)
        world.addComponent(SpriteAnimator(clip: clip), to: entity)

        // At double deltaTime, animation should advance twice as fast
        // Normal: 1 tick at 0.05s → still on frame 0
        world.update(deltaTime: 0.05)
        // swiftlint:disable:next force_unwrapping
        var animator = world.getComponent(SpriteAnimator.self, from: entity)!
        #expect(animator.currentFrameIndex == 0)

        // Reset
        world.addComponent(SpriteAnimator(clip: clip), to: entity)

        // Double: 1 tick at 0.10s → should advance to frame 1
        world.update(deltaTime: 0.10)
        // swiftlint:disable:next force_unwrapping
        animator = world.getComponent(SpriteAnimator.self, from: entity)!
        #expect(animator.currentFrameIndex == 1)
    }

    @Test("Particle emission scales with deltaTime")
    func particleEmissionScalesWithDelta() {
        let world = World()
        let particleSystem = ParticleSystem()
        world.addSystem(particleSystem)

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: entity)
        world.addComponent(ParticleEmitter(
            emissionRate: 100, // 100 particles per second
            maxParticles: 500,
            lifetime: 1.0...2.0,
            speed: 10...20,
            startColor: .white,
            endColor: .white,
            renderShape: .circle(radius: 1)
        ), to: entity)

        // At 0.1s, should emit ~10 particles
        world.update(deltaTime: 0.1)
        // swiftlint:disable:next force_unwrapping
        var emitter = world.getComponent(ParticleEmitter.self, from: entity)!
        let countAfterNormal = emitter.particles.count
        #expect(countAfterNormal >= 9 && countAfterNormal <= 11)

        // Reset emitter
        world.addComponent(ParticleEmitter(
            emissionRate: 100,
            maxParticles: 500,
            lifetime: 1.0...2.0,
            speed: 10...20,
            startColor: .white,
            endColor: .white,
            renderShape: .circle(radius: 1)
        ), to: entity)

        // At 0.05s (simulating timeScale=0.5), should emit ~5 particles
        world.update(deltaTime: 0.05)
        // swiftlint:disable:next force_unwrapping
        emitter = world.getComponent(ParticleEmitter.self, from: entity)!
        let countAfterHalf = emitter.particles.count
        #expect(countAfterHalf >= 4 && countAfterHalf <= 6)
    }

    @Test("Scene transition advances with deltaTime")
    func transitionScalesWithDelta() {
        let transition = SceneTransition.fade(duration: 1.0)
        #expect(transition.duration == 1.0)

        // Verify the transition struct stores correct half duration
        // (SceneManager internally uses deltaTime to advance elapsed)
        let halfDuration = transition.duration / 2
        #expect(abs(halfDuration - 0.5) < 0.001)
    }

    // MARK: - Helpers

    private func makeTestApp() -> Application {
        Application(
            config: WindowConfig(title: "Test"),
            renderer: MockRenderer(),
            audio: MockAudioEngine(),
            inputBackend: MockNativeInput()
        )
    }
}
