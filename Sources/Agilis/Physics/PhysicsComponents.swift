#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - Transform2D

/// 2D transform: position, rotation, and scale.
///
/// This is the standard position component for entities using the physics system.
/// The physics pipeline reads and writes `position` and `rotation` each tick.
public struct Transform2D: Component, Sendable, SerializableComponent {
    public static let componentName = "Transform2D"

    /// Position in world space.
    public var position: Vector2
    /// Rotation in radians (counter-clockwise positive).
    public var rotation: Float
    /// Scale factor.
    public var scale: Vector2

    public init(
        position: Vector2 = .zero,
        rotation: Float = 0,
        scale: Vector2 = .one
    ) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    /// Builds a 3x3 transformation matrix: scale -> rotate -> translate.
    public var matrix: Matrix3 {
        let s = Matrix3.scale(scale.x, scale.y)
        let r = Matrix3.rotation(rotation)
        let t = Matrix3.translation(position)
        return t * r * s
    }
}

// MARK: - PreviousTransform2D

/// Snapshot of the previous frame's transform, used for interpolated rendering.
///
/// The physics system automatically copies `Transform2D` into this component
/// before integrating velocities each tick.
public struct PreviousTransform2D: Component, Sendable, SerializableComponent {
    public static let componentName = "PreviousTransform2D"

    public var position: Vector2
    public var rotation: Float

    public init(position: Vector2 = .zero, rotation: Float = 0) {
        self.position = position
        self.rotation = rotation
    }
}

// MARK: - Velocity2D

/// Linear and angular velocity.
public struct Velocity2D: Component, Sendable, SerializableComponent {
    public static let componentName = "Velocity2D"

    /// Linear velocity in pixels per second.
    public var linear: Vector2
    /// Angular velocity in radians per second.
    public var angular: Float

    public init(linear: Vector2 = .zero, angular: Float = 0) {
        self.linear = linear
        self.angular = angular
    }
}

// MARK: - RigidBody2D

/// Rigid body properties for physics simulation.
///
/// Controls how an entity responds to gravity, collisions, and forces.
/// Static and kinematic bodies have an effective inverse mass of 0.
///
/// ## Moment of Inertia
///
/// Set `inertia` to enable angular physics response from joints and constraints.
/// Default `0` means infinite rotational mass (no angular impulse applied),
/// which preserves backward compatibility. Use `computeInertia(mass:shape:)`
/// for automatic computation based on shape geometry.
public struct RigidBody2D: Component, Sendable, SerializableComponent {
    public static let componentName = "RigidBody2D"

    /// Mass of the body in arbitrary units.
    public var mass: Float
    /// Inverse mass (1/mass). 0 for static/kinematic bodies or zero-mass bodies.
    public var inverseMass: Float {
        (bodyType == .dynamic && mass > 0) ? 1.0 / mass : 0
    }
    /// Moment of inertia (rotational mass). Higher values resist angular acceleration more.
    /// Default `0` means infinite rotational mass — no angular impulse is applied by joints.
    /// For joints to affect rotation, set this explicitly or use `computeInertia(mass:shape:)`.
    public var inertia: Float
    /// Inverse moment of inertia (1/inertia). 0 for static/kinematic or zero-inertia bodies.
    public var inverseInertia: Float {
        (bodyType == .dynamic && inertia > 0) ? 1.0 / inertia : 0
    }
    /// Bounciness: 0 = no bounce, 1 = perfect bounce.
    public var restitution: Float
    /// Coefficient of friction (0 = frictionless, 1 = high friction).
    public var friction: Float
    /// Multiplier applied to world gravity. 0 = no gravity.
    public var gravityScale: Float
    /// Controls how this body participates in physics.
    public var bodyType: BodyType
    /// Linear velocity damping per second. 0 = no damping.
    public var linearDamping: Float
    /// Enable Continuous Collision Detection for this body.
    /// When true, fast-moving dynamic bodies are swept to prevent tunneling through thin geometry.
    /// Default false for backward compatibility and performance.
    public var useCCD: Bool

    public init(
        mass: Float = 1,
        inertia: Float = 0,
        restitution: Float = 0.2,
        friction: Float = 0.3,
        gravityScale: Float = 1,
        bodyType: BodyType = .dynamic,
        linearDamping: Float = 0,
        useCCD: Bool = false
    ) {
        self.mass = mass
        self.inertia = inertia
        self.restitution = restitution
        self.friction = friction
        self.gravityScale = gravityScale
        self.bodyType = bodyType
        self.linearDamping = linearDamping
        self.useCCD = useCCD
    }

    /// The effective inverse mass, accounting for body type.
    /// Returns 0 for static and kinematic bodies.
    public var effectiveInverseMass: Float {
        switch bodyType {
        case .dynamic: return inverseMass
        case .kinematic, .static: return 0
        }
    }

    /// The effective inverse inertia, accounting for body type.
    /// Returns 0 for static and kinematic bodies.
    public var effectiveInverseInertia: Float {
        switch bodyType {
        case .dynamic: return inverseInertia
        case .kinematic, .static: return 0
        }
    }

    /// Compute the moment of inertia for a collision shape with the given mass.
    ///
    /// - Circle: `I = 0.5 * m * r²`
    /// - AABB: `I = m * (w² + h²) / 12`
    /// - Polygon: area-weighted vertex formula
    ///
    /// - Parameters:
    ///   - mass: The body mass.
    ///   - shape: The collision shape to compute inertia for.
    /// - Returns: The scalar moment of inertia.
    public static func computeInertia(mass: Float, shape: CollisionShape) -> Float {
        guard mass > 0 else { return 0 }
        switch shape {
        case .circle(let radius):
            return 0.5 * mass * radius * radius

        case .aabb(let halfExtents):
            let w = halfExtents.x * 2
            let h = halfExtents.y * 2
            return mass * (w * w + h * h) / 12.0

        case .polygon(let poly):
            return computePolygonInertia(mass: mass, vertices: poly.vertices)
        }
    }

    /// Compute moment of inertia for a convex polygon using the area-weighted vertex formula.
    private static func computePolygonInertia(mass: Float, vertices: [Vector2]) -> Float {
        let n = vertices.count
        guard n >= 3 else { return mass }

        var numerator: Float = 0
        var denominator: Float = 0
        for i in 0..<n {
            let v1 = vertices[i]
            let v2 = vertices[(i + 1) % n]
            let cross = abs(v1.x * v2.y - v1.y * v2.x)
            numerator += cross * (v1.dot(v1) + v1.dot(v2) + v2.dot(v2))
            denominator += cross
        }
        guard denominator > 0 else { return mass }
        return mass * numerator / (6.0 * denominator)
    }

    // MARK: - Codable (skip inverseMass, inverseInertia — recomputed)

    private enum CodingKeys: String, CodingKey {
        case mass, inertia, restitution, friction, gravityScale, bodyType, linearDamping, useCCD
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mass, forKey: .mass)
        try container.encode(inertia, forKey: .inertia)
        try container.encode(restitution, forKey: .restitution)
        try container.encode(friction, forKey: .friction)
        try container.encode(gravityScale, forKey: .gravityScale)
        try container.encode(bodyType, forKey: .bodyType)
        try container.encode(linearDamping, forKey: .linearDamping)
        try container.encode(useCCD, forKey: .useCCD)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mass = try container.decode(Float.self, forKey: .mass)
        let inertia = try container.decodeIfPresent(Float.self, forKey: .inertia) ?? 0
        let restitution = try container.decode(Float.self, forKey: .restitution)
        let friction = try container.decode(Float.self, forKey: .friction)
        let gravityScale = try container.decode(Float.self, forKey: .gravityScale)
        let bodyType = try container.decode(BodyType.self, forKey: .bodyType)
        let linearDamping = try container.decode(Float.self, forKey: .linearDamping)
        let useCCD = try container.decodeIfPresent(Bool.self, forKey: .useCCD) ?? false
        self.init(
            mass: mass,
            inertia: inertia,
            restitution: restitution,
            friction: friction,
            gravityScale: gravityScale,
            bodyType: bodyType,
            linearDamping: linearDamping,
            useCCD: useCCD
        )
    }
}

// MARK: - Collider2D

/// Collision shape attached to an entity.
///
/// Entities need both a `Transform2D` and a `Collider2D` to participate
/// in collision detection. Add a `RigidBody2D` for physics response;
/// without one, the entity is treated as static.
public struct Collider2D: Component, Sendable, SerializableComponent {
    public static let componentName = "Collider2D"

    /// The collision shape in local space.
    public var shape: CollisionShape
    /// Offset from the entity's `Transform2D.position`.
    public var offset: Vector2
    /// If true, generates collision events but no physics response.
    public var isTrigger: Bool
    /// Bitmask: which collision layer(s) this entity belongs to.
    public var layer: UInt32
    /// Bitmask: which layers this entity can collide with.
    public var mask: UInt32

    public init(
        shape: CollisionShape,
        offset: Vector2 = .zero,
        isTrigger: Bool = false,
        layer: UInt32 = 1,
        mask: UInt32 = 0xFFFF_FFFF
    ) {
        self.shape = shape
        self.offset = offset
        self.isTrigger = isTrigger
        self.layer = layer
        self.mask = mask
    }
}
