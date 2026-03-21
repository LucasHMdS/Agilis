/// ECS system that updates all particle emitters each tick.
///
/// Handles emission (rate-based and burst), particle simulation (velocity,
/// gravity, damping, rotation), lifetime countdown, and dead particle removal.
///
/// Particles are stored internally within each `ParticleEmitter` component,
/// not as separate ECS entities.
///
/// ## Usage
/// ```swift
/// let particleSystem = ParticleSystem()
/// world.addSystem(particleSystem)
/// ```
///
/// The default priority of 200 places particles after physics (priority 100)
/// so emitter positions from `Transform2D` reflect physics-corrected values.
public final class ParticleSystem: System, @unchecked Sendable {

    deinit {}

    public var priority: Int { _priority }
    private let _priority: Int

    /// Reads Transform2D, writes ParticleEmitter (emission, physics, lifetime).
    /// Runs at priority 200, after PhysicsWorld2D (100). Can run in parallel with LightingSystem (300).
    public var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [Transform2D.self],
            writes: [ParticleEmitter.self]
        )
    }

    /// Creates a particle system.
    /// - Parameter priority: Execution priority (lower runs first). Default: 200.
    public init(priority: Int = 200) {
        self._priority = priority
    }

    public func update(context: SystemContext) {
        let world = context.world
        let dt = Float(context.deltaTime)

        world.forEach { (_: Entity, emitter: inout ParticleEmitter, transform: inout Transform2D) in
            let emitterPos = transform.position

            // --- Phase 1: Emit new particles ---

            // Rate-based emission
            if emitter.isEmitting && emitter.emissionRate > 0 {
                emitter.emissionAccumulator += emitter.emissionRate * dt
                while emitter.emissionAccumulator >= 1.0 && emitter.activeCount < emitter.maxParticles {
                    emitter.emissionAccumulator -= 1.0
                    emitter.spawnParticle(emitterPosition: emitterPos)
                }
                // Cap accumulator to prevent runaway spawning after long pauses
                if emitter.emissionAccumulator > Float(emitter.maxParticles) {
                    emitter.emissionAccumulator = Float(emitter.maxParticles)
                }
            }

            // Burst emission
            while emitter.burstQueue > 0 && emitter.activeCount < emitter.maxParticles {
                emitter.burstQueue -= 1
                emitter.spawnParticle(emitterPosition: emitterPos)
            }
            emitter.burstQueue = 0

            // --- Phase 2: Update existing particles ---

            var i = 0
            while i < emitter.activeCount {
                emitter.particles[i].lifetime -= dt

                // Remove dead particles via swap-remove
                if emitter.particles[i].lifetime <= 0 {
                    emitter.activeCount -= 1
                    if i < emitter.activeCount {
                        emitter.particles[i] = emitter.particles[emitter.activeCount]
                    }
                    continue
                }

                // Apply gravity
                emitter.particles[i].velocity += emitter.gravity * dt

                // Apply damping
                if emitter.damping > 0 {
                    let dampFactor = max(1.0 - emitter.damping * dt, 0)
                    emitter.particles[i].velocity *= dampFactor
                }

                // Integrate position
                emitter.particles[i].position += emitter.particles[i].velocity * dt

                // Integrate rotation
                emitter.particles[i].rotation += emitter.particles[i].angularVelocity * dt

                i += 1
            }
        }
    }
}
