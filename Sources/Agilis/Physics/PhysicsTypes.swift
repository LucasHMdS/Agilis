

/// The type of a rigid body, controlling how it participates in physics.
public enum BodyType: Sendable, Equatable, Codable {
    /// Fully simulated: affected by gravity, forces, and collisions.
    case dynamic
    /// Moves programmatically but is not affected by forces or collisions.
    /// Pushes dynamic bodies without being pushed back.
    case kinematic
    /// Infinite mass, never moves. Use for walls, floors, platforms.
    case `static`
}

/// Contact information from a narrow-phase collision test.
public struct Contact: Sendable {
    /// Collision normal pointing from entity A toward entity B (unit vector).
    public let normal: Vector2
    /// How far the shapes overlap along the normal (positive value).
    public let penetration: Float
    /// Approximate contact point in world space.
    public let point: Vector2

    public init(normal: Vector2, penetration: Float, point: Vector2) {
        self.normal = normal
        self.penetration = penetration
        self.point = point
    }
}

/// Identifies a pair of entities involved in a collision.
/// Uses canonical ordering so (A, B) and (B, A) are the same pair.
public struct CollisionPair: Sendable, Hashable {
    public let entityA: Entity
    public let entityB: Entity

    public init(_ a: Entity, _ b: Entity) {
        if a.index < b.index || (a.index == b.index && a.generation < b.generation) {
            entityA = a
            entityB = b
        } else {
            entityA = b
            entityB = a
        }
    }
}

/// The phase of a collision event.
public enum CollisionEventType: Sendable, Equatable {
    /// First frame of contact between two entities.
    case began
    /// Continued contact from a previous frame.
    case ongoing
    /// Entities separated after being in contact.
    case ended
}

/// A collision event emitted by PhysicsWorld2D each frame.
public struct CollisionEvent: Sendable {
    public let entityA: Entity
    public let entityB: Entity
    public let type: CollisionEventType
    /// Contact info (nil for `.ended` events).
    public let contact: Contact?

    public init(entityA: Entity, entityB: Entity, type: CollisionEventType, contact: Contact?) {
        self.entityA = entityA
        self.entityB = entityB
        self.type = type
        self.contact = contact
    }
}

// MARK: - Joint Events

/// The type of a joint lifecycle event.
public enum JointEventType: Sendable, Equatable {
    /// The joint was destroyed because its constraint force/torque exceeded its limit.
    case broken
}

/// A joint event emitted by PhysicsWorld2D.
public struct JointEvent: Sendable {
    /// Handle of the joint that generated this event.
    public let handle: JointHandle
    /// First entity in the joint.
    public let entityA: Entity
    /// Second entity in the joint.
    public let entityB: Entity
    /// The type of event.
    public let type: JointEventType

    public init(handle: JointHandle, entityA: Entity, entityB: Entity, type: JointEventType) {
        self.handle = handle
        self.entityA = entityA
        self.entityB = entityB
        self.type = type
    }
}
