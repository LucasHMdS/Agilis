

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - EmissionShape

/// Defines the spatial region where new particles spawn, relative to the emitter position.
public enum EmissionShape: Sendable, Equatable, Codable {
    /// All particles spawn at the emitter's center point.
    case point
    /// Particles spawn at random positions within a circle of the given radius.
    case circle(radius: Float)
    /// Particles spawn on the edge of a circle of the given radius.
    case ring(radius: Float)
    /// Particles spawn at random positions within a rectangle centered on the emitter.
    case rect(width: Float, height: Float)
}

// MARK: - ParticleRenderShape

/// Defines the visual appearance of each particle.
public enum ParticleRenderShape: Sendable, Equatable, Codable {
    /// Each particle is drawn as a filled circle. Actual radius = base radius * scale.
    case circle(radius: Float)
    /// Each particle is drawn as a filled rectangle. Actual size = base size * scale.
    case rect(width: Float, height: Float)
    /// Each particle is drawn as a textured sprite.
    case sprite(texture: TextureHandle, sourceRect: Rect)
}

// MARK: - ParticleEmitter

/// ECS component that defines a particle emitter and stores its particle pool.
///
/// Attach to an entity alongside a `Transform2D`. The `ParticleSystem` updates
/// all emitters each tick (spawning, simulation, cleanup). Rendering is handled
/// separately via `renderer.drawParticles(emitter, at: position)` in your
/// scene's `render()` method.
///
/// ## Example
/// ```swift
/// let entity = world.createEntity()
/// world.addComponent(Transform2D(position: Vector2(x: 400, y: 300)), to: entity)
/// world.addComponent(ParticleEmitter(
///     emissionRate: 50,
///     maxParticles: 200,
///     lifetime: 0.5...1.5,
///     speed: 50...100,
///     startColor: .yellow,
///     endColor: Color(r: 255, g: 0, b: 0, a: 0),
///     renderShape: .circle(radius: 3)
/// ), to: entity)
/// ```
public struct ParticleEmitter: Component, Sendable, SerializableComponent {
    public static let componentName = "ParticleEmitter"


    // MARK: - Emission Control

    /// Particles emitted per second. Set to 0 for burst-only emitters.
    public var emissionRate: Float

    /// Maximum number of live particles at any time.
    public var maxParticles: Int

    /// Whether the emitter is actively emitting particles (rate-based).
    /// Burst emission works regardless of this flag.
    public var isEmitting: Bool

    // MARK: - Particle Lifetime

    /// Range for randomized particle lifetime in seconds.
    public var lifetime: ClosedRange<Float>

    // MARK: - Particle Motion

    /// Range for initial particle speed in pixels per second.
    public var speed: ClosedRange<Float>

    /// Range for emission direction in radians.
    /// 0 = right, π/2 = down (screen coords), π = left, -π/2 = up.
    public var angle: ClosedRange<Float>

    /// Gravity applied to all particles in pixels/s². Independent of PhysicsWorld2D.
    public var gravity: Vector2

    /// Velocity damping factor per second. 0 = no damping.
    /// Applied as `velocity *= (1 - damping * dt)` each tick.
    public var damping: Float

    // MARK: - Particle Appearance

    /// Color at spawn (normalized age = 0).
    public var startColor: Color

    /// Color at death (normalized age = 1).
    public var endColor: Color

    /// Range for randomized initial scale.
    public var startScale: ClosedRange<Float>

    /// Scale at death. Interpolates from spawn scale to this value.
    public var endScale: Float

    /// Range for randomized angular velocity in radians per second.
    public var angularVelocity: ClosedRange<Float>

    // MARK: - Shapes

    /// Where particles spawn relative to the emitter position.
    public var emissionShape: EmissionShape

    /// How each particle is rendered.
    public var renderShape: ParticleRenderShape

    // MARK: - Space Mode

    /// If true (default), particles get world-space positions at spawn and move
    /// independently of the emitter. If false, positions are relative to the emitter.
    public var worldSpace: Bool

    // MARK: - Internal Pool State

    internal var particles: [Particle]
    internal var activeCount: Int
    internal var emissionAccumulator: Float
    internal var burstQueue: Int

    // MARK: - Public Read-Only

    /// The number of currently alive particles.
    public var activeParticleCount: Int { activeCount }

    // MARK: - Init

    public init(
        emissionRate: Float = 10,
        maxParticles: Int = 100,
        lifetime: ClosedRange<Float> = 1.0...2.0,
        speed: ClosedRange<Float> = 50...100,
        angle: ClosedRange<Float> = 0...(2 * .pi),
        gravity: Vector2 = .zero,
        damping: Float = 0,
        startColor: Color = .white,
        endColor: Color = Color(r: 255, g: 255, b: 255, a: 0),
        startScale: ClosedRange<Float> = 1.0...1.0,
        endScale: Float = 1.0,
        angularVelocity: ClosedRange<Float> = 0...0,
        emissionShape: EmissionShape = .point,
        renderShape: ParticleRenderShape = .circle(radius: 4),
        worldSpace: Bool = true,
        isEmitting: Bool = true
    ) {
        self.emissionRate = emissionRate
        self.maxParticles = maxParticles
        self.lifetime = lifetime
        self.speed = speed
        self.angle = angle
        self.gravity = gravity
        self.damping = damping
        self.startColor = startColor
        self.endColor = endColor
        self.startScale = startScale
        self.endScale = endScale
        self.angularVelocity = angularVelocity
        self.emissionShape = emissionShape
        self.renderShape = renderShape
        self.worldSpace = worldSpace
        self.isEmitting = isEmitting

        self.particles = []
        self.particles.reserveCapacity(maxParticles)
        self.activeCount = 0
        self.emissionAccumulator = 0
        self.burstQueue = 0
    }

    // MARK: - Public API

    /// Queue a burst of particles to be emitted on the next update tick.
    /// Multiple calls accumulate. Actual count is capped by maxParticles.
    public mutating func burst(count: Int) {
        burstQueue += count
    }

    /// Remove all active particles immediately.
    public mutating func clear() {
        activeCount = 0
    }

    // MARK: - Internal Spawn Helpers

    /// Compute a random spawn offset based on the emission shape.
    internal static func randomPointInShape(_ shape: EmissionShape) -> Vector2 {
        switch shape {
        case .point:
            return .zero

        case .circle(let radius):
            let r = radius * Float.random(in: 0...1).squareRoot()
            let a = Float.random(in: 0...(2 * .pi))
            return Vector2(x: r * cosf(a), y: r * sinf(a))

        case .ring(let radius):
            let a = Float.random(in: 0...(2 * .pi))
            return Vector2(x: radius * cosf(a), y: radius * sinf(a))

        case .rect(let width, let height):
            return Vector2(
                x: Float.random(in: -width / 2...width / 2),
                y: Float.random(in: -height / 2...height / 2)
            )
        }
    }

    /// Spawn a single particle with randomized properties.
    internal mutating func spawnParticle(emitterPosition: Vector2) {
        guard activeCount < maxParticles else { return }

        let spawnOffset = Self.randomPointInShape(emissionShape)
        let spawnAngle = Float.random(in: angle)
        let spawnSpeed = Float.random(in: speed)
        let spawnLifetime = Float.random(in: lifetime)
        let spawnScale = Float.random(in: startScale)
        let spawnAngularVel = Float.random(in: angularVelocity)

        let velocity = Vector2(
            x: cosf(spawnAngle) * spawnSpeed,
            y: sinf(spawnAngle) * spawnSpeed
        )

        let position: Vector2
        if worldSpace {
            position = emitterPosition + spawnOffset
        } else {
            position = spawnOffset
        }

        let particle = Particle(
            position: position,
            velocity: velocity,
            lifetime: spawnLifetime,
            maxLifetime: spawnLifetime,
            scale: spawnScale,
            rotation: 0,
            angularVelocity: spawnAngularVel
        )

        if activeCount < particles.count {
            particles[activeCount] = particle
        } else {
            particles.append(particle)
        }
        activeCount += 1
    }

    // MARK: - Codable (config only — internal pool state is not serialized)

    private enum CodingKeys: String, CodingKey {
        case emissionRate, maxParticles, isEmitting
        case lifetime, speed, angle, gravity, damping
        case startColor, endColor, startScale, endScale, angularVelocity
        case emissionShape, renderShape, worldSpace
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(emissionRate, forKey: .emissionRate)
        try container.encode(maxParticles, forKey: .maxParticles)
        try container.encode(isEmitting, forKey: .isEmitting)
        try container.encode(lifetime, forKey: .lifetime)
        try container.encode(speed, forKey: .speed)
        try container.encode(angle, forKey: .angle)
        try container.encode(gravity, forKey: .gravity)
        try container.encode(damping, forKey: .damping)
        try container.encode(startColor, forKey: .startColor)
        try container.encode(endColor, forKey: .endColor)
        try container.encode(startScale, forKey: .startScale)
        try container.encode(endScale, forKey: .endScale)
        try container.encode(angularVelocity, forKey: .angularVelocity)
        try container.encode(emissionShape, forKey: .emissionShape)
        try container.encode(renderShape, forKey: .renderShape)
        try container.encode(worldSpace, forKey: .worldSpace)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            emissionRate: try container.decode(Float.self, forKey: .emissionRate),
            maxParticles: try container.decode(Int.self, forKey: .maxParticles),
            lifetime: try container.decode(ClosedRange<Float>.self, forKey: .lifetime),
            speed: try container.decode(ClosedRange<Float>.self, forKey: .speed),
            angle: try container.decode(ClosedRange<Float>.self, forKey: .angle),
            gravity: try container.decode(Vector2.self, forKey: .gravity),
            damping: try container.decode(Float.self, forKey: .damping),
            startColor: try container.decode(Color.self, forKey: .startColor),
            endColor: try container.decode(Color.self, forKey: .endColor),
            startScale: try container.decode(ClosedRange<Float>.self, forKey: .startScale),
            endScale: try container.decode(Float.self, forKey: .endScale),
            angularVelocity: try container.decode(ClosedRange<Float>.self, forKey: .angularVelocity),
            emissionShape: try container.decode(EmissionShape.self, forKey: .emissionShape),
            renderShape: try container.decode(ParticleRenderShape.self, forKey: .renderShape),
            worldSpace: try container.decode(Bool.self, forKey: .worldSpace),
            isEmitting: try container.decode(Bool.self, forKey: .isEmitting)
        )
    }
}
