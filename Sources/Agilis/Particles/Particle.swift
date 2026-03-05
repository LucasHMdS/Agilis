import AgilisCore

/// Internal per-particle simulation state.
///
/// Particles are stored in a flat array inside `ParticleEmitter`, not as ECS entities.
/// Dead particles are swap-removed to keep the active portion contiguous.
struct Particle: Sendable {
    /// Current position (world-space if worldSpace=true, otherwise emitter-relative).
    var position: Vector2
    /// Current velocity in pixels per second.
    var velocity: Vector2
    /// Remaining lifetime in seconds. Particle dies when this reaches zero.
    var lifetime: Float
    /// Original lifetime at spawn. Used to compute normalized age.
    var maxLifetime: Float
    /// Initial uniform scale factor (randomized at spawn).
    var scale: Float
    /// Current rotation in radians.
    var rotation: Float
    /// Angular velocity in radians per second.
    var angularVelocity: Float

    /// Normalized age from 0.0 (just spawned) to 1.0 (about to die).
    var normalizedAge: Float {
        guard maxLifetime > 0 else { return 1.0 }
        return 1.0 - (lifetime / maxLifetime)
    }
}
