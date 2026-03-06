

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - JointHandle

/// An opaque handle to a physics joint. Created by `PhysicsWorld2D.createJoint(_:in:)`.
///
/// Use this handle to destroy joints or query joint state from `PhysicsWorld2D`.
public struct JointHandle: Sendable, Hashable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    public static let invalid = JointHandle(id: 0)
}

// MARK: - Joint Definitions

/// Configuration for creating a physics joint.
///
/// Pass to `PhysicsWorld2D.createJoint(_:in:)` to instantiate.
///
/// ## Usage
/// ```swift
/// let joint = physics.createJoint(.revolute(RevoluteJointDef(
///     entityA: wall, entityB: door,
///     anchor: Vector2(x: 100, y: 200)
/// )), in: world)
/// ```
public enum JointDefinition: Sendable {
    case revolute(RevoluteJointDef)
    case distance(DistanceJointDef)
    case weld(WeldJointDef)
    case prismatic(PrismaticJointDef)
    case rope(RopeJointDef)
    case motor(MotorJointDef)
}

/// Revolute (pin/hinge) joint definition.
///
/// Constrains two bodies to rotate around a shared anchor point.
/// Optionally restricts rotation to an angle range and/or applies motor torque.
///
/// Use for: doors, chains, ragdolls, wheels, pendulums.
public struct RevoluteJointDef: Sendable {
    /// First body entity.
    public var entityA: Entity
    /// Second body entity.
    public var entityB: Entity
    /// Anchor point in world space. Local anchors are computed from this and the bodies' positions.
    public var anchor: Vector2
    /// Local anchor offset on body A. Computed from `anchor` if nil.
    public var localAnchorA: Vector2?
    /// Local anchor offset on body B. Computed from `anchor` if nil.
    public var localAnchorB: Vector2?

    // MARK: Angle Limits

    /// Enable angle limits.
    public var enableLimit: Bool
    /// Lower angle limit in radians.
    public var lowerAngle: Float
    /// Upper angle limit in radians.
    public var upperAngle: Float

    // MARK: Motor

    /// Enable motor.
    public var enableMotor: Bool
    /// Target motor angular velocity in radians/sec.
    public var motorSpeed: Float
    /// Maximum motor torque.
    public var maxMotorTorque: Float

    // MARK: Breaking

    /// Maximum constraint force before joint breaks. 0 = unbreakable.
    public var maxForce: Float
    /// Maximum constraint torque before joint breaks. 0 = unbreakable.
    public var maxTorque: Float

    public init(
        entityA: Entity,
        entityB: Entity,
        anchor: Vector2,
        localAnchorA: Vector2? = nil,
        localAnchorB: Vector2? = nil,
        enableLimit: Bool = false,
        lowerAngle: Float = 0,
        upperAngle: Float = 0,
        enableMotor: Bool = false,
        motorSpeed: Float = 0,
        maxMotorTorque: Float = 0,
        maxForce: Float = 0,
        maxTorque: Float = 0
    ) {
        self.entityA = entityA
        self.entityB = entityB
        self.anchor = anchor
        self.localAnchorA = localAnchorA
        self.localAnchorB = localAnchorB
        self.enableLimit = enableLimit
        self.lowerAngle = lowerAngle
        self.upperAngle = upperAngle
        self.enableMotor = enableMotor
        self.motorSpeed = motorSpeed
        self.maxMotorTorque = maxMotorTorque
        self.maxForce = maxForce
        self.maxTorque = maxTorque
    }
}

/// Distance (spring) joint definition.
///
/// Maintains a fixed or spring-like distance between two anchor points.
/// With `frequencyHz > 0`, acts as a soft spring with damping.
///
/// Use for: bridges, bungee cords, pendulums, suspension.
public struct DistanceJointDef: Sendable {
    /// First body entity.
    public var entityA: Entity
    /// Second body entity.
    public var entityB: Entity
    /// Anchor point on body A in world space.
    public var anchorA: Vector2
    /// Anchor point on body B in world space.
    public var anchorB: Vector2
    /// Local anchor offset on body A. Computed from `anchorA` if nil.
    public var localAnchorA: Vector2?
    /// Local anchor offset on body B. Computed from `anchorB` if nil.
    public var localAnchorB: Vector2?

    /// Rest length. 0 = computed from initial anchor positions.
    public var length: Float
    /// Spring frequency in Hz. 0 = rigid constraint (no spring).
    public var frequencyHz: Float
    /// Damping ratio. 0 = no damping, 1 = critical damping.
    public var dampingRatio: Float

    /// Maximum constraint force before joint breaks. 0 = unbreakable.
    public var maxForce: Float

    public init(
        entityA: Entity,
        entityB: Entity,
        anchorA: Vector2,
        anchorB: Vector2,
        localAnchorA: Vector2? = nil,
        localAnchorB: Vector2? = nil,
        length: Float = 0,
        frequencyHz: Float = 0,
        dampingRatio: Float = 0.7,
        maxForce: Float = 0
    ) {
        self.entityA = entityA
        self.entityB = entityB
        self.anchorA = anchorA
        self.anchorB = anchorB
        self.localAnchorA = localAnchorA
        self.localAnchorB = localAnchorB
        self.length = length
        self.frequencyHz = frequencyHz
        self.dampingRatio = dampingRatio
        self.maxForce = maxForce
    }
}

/// Weld (fixed) joint definition.
///
/// Locks two bodies together with no relative movement.
/// With `frequencyHz > 0`, acts as a soft weld that allows slight flex.
///
/// Use for: composite objects, breakable structures, rigid connections.
public struct WeldJointDef: Sendable {
    /// First body entity.
    public var entityA: Entity
    /// Second body entity.
    public var entityB: Entity
    /// Anchor point in world space.
    public var anchor: Vector2
    /// Local anchor offset on body A. Computed from `anchor` if nil.
    public var localAnchorA: Vector2?
    /// Local anchor offset on body B. Computed from `anchor` if nil.
    public var localAnchorB: Vector2?
    /// Reference angle (body B rotation - body A rotation). Computed from initial rotations if nil.
    public var referenceAngle: Float?

    /// Angular frequency for soft weld (Hz). 0 = fully rigid.
    public var frequencyHz: Float
    /// Damping ratio for soft weld.
    public var dampingRatio: Float

    /// Maximum constraint force before joint breaks. 0 = unbreakable.
    public var maxForce: Float
    /// Maximum constraint torque before joint breaks. 0 = unbreakable.
    public var maxTorque: Float

    public init(
        entityA: Entity,
        entityB: Entity,
        anchor: Vector2,
        localAnchorA: Vector2? = nil,
        localAnchorB: Vector2? = nil,
        referenceAngle: Float? = nil,
        frequencyHz: Float = 0,
        dampingRatio: Float = 0.7,
        maxForce: Float = 0,
        maxTorque: Float = 0
    ) {
        self.entityA = entityA
        self.entityB = entityB
        self.anchor = anchor
        self.localAnchorA = localAnchorA
        self.localAnchorB = localAnchorB
        self.referenceAngle = referenceAngle
        self.frequencyHz = frequencyHz
        self.dampingRatio = dampingRatio
        self.maxForce = maxForce
        self.maxTorque = maxTorque
    }
}

/// Prismatic (slider) joint definition.
///
/// Constrains two bodies to slide along a fixed axis defined in body A's local frame.
/// Locks relative rotation. Optionally restricts translation to a range and/or
/// applies a motor force along the axis.
///
/// Use for: elevators, sliding doors, pistons, rail-constrained objects.
public struct PrismaticJointDef: Sendable {
    /// First body entity.
    public var entityA: Entity
    /// Second body entity.
    public var entityB: Entity
    /// Anchor point in world space. Local anchors are computed from this and the bodies' positions.
    public var anchor: Vector2
    /// Local anchor offset on body A. Computed from `anchor` if nil.
    public var localAnchorA: Vector2?
    /// Local anchor offset on body B. Computed from `anchor` if nil.
    public var localAnchorB: Vector2?
    /// Sliding axis in world space (will be stored in body A's local frame).
    public var axis: Vector2
    /// Sliding axis in body A's local frame. Computed from `axis` and body A's rotation if nil.
    public var localAxisA: Vector2?
    /// Reference angle (body B rotation - body A rotation). Computed from initial rotations if nil.
    public var referenceAngle: Float?

    // MARK: Translation Limits

    /// Enable translation limits along the axis.
    public var enableLimit: Bool
    /// Lower translation limit (negative = toward body A direction).
    public var lowerTranslation: Float
    /// Upper translation limit.
    public var upperTranslation: Float

    // MARK: Motor

    /// Enable motor.
    public var enableMotor: Bool
    /// Target motor linear speed along the axis.
    public var motorSpeed: Float
    /// Maximum motor force.
    public var maxMotorForce: Float

    // MARK: Breaking

    /// Maximum constraint force before joint breaks. 0 = unbreakable.
    public var maxForce: Float
    /// Maximum constraint torque before joint breaks. 0 = unbreakable.
    public var maxTorque: Float

    public init(
        entityA: Entity,
        entityB: Entity,
        anchor: Vector2,
        axis: Vector2,
        localAnchorA: Vector2? = nil,
        localAnchorB: Vector2? = nil,
        localAxisA: Vector2? = nil,
        referenceAngle: Float? = nil,
        enableLimit: Bool = false,
        lowerTranslation: Float = 0,
        upperTranslation: Float = 0,
        enableMotor: Bool = false,
        motorSpeed: Float = 0,
        maxMotorForce: Float = 0,
        maxForce: Float = 0,
        maxTorque: Float = 0
    ) {
        self.entityA = entityA
        self.entityB = entityB
        self.anchor = anchor
        self.axis = axis
        self.localAnchorA = localAnchorA
        self.localAnchorB = localAnchorB
        self.localAxisA = localAxisA
        self.referenceAngle = referenceAngle
        self.enableLimit = enableLimit
        self.lowerTranslation = lowerTranslation
        self.upperTranslation = upperTranslation
        self.enableMotor = enableMotor
        self.motorSpeed = motorSpeed
        self.maxMotorForce = maxMotorForce
        self.maxForce = maxForce
        self.maxTorque = maxTorque
    }
}

/// Rope joint definition.
///
/// Enforces a maximum distance between two anchor points.
/// Only pulls when stretched beyond `maxLength` — goes slack when closer.
/// Unlike a distance joint, a rope joint never pushes bodies apart.
///
/// Use for: ropes, chains, tethers, leashes.
public struct RopeJointDef: Sendable {
    /// First body entity.
    public var entityA: Entity
    /// Second body entity.
    public var entityB: Entity
    /// Anchor point on body A in world space.
    public var anchorA: Vector2
    /// Anchor point on body B in world space.
    public var anchorB: Vector2
    /// Local anchor offset on body A. Computed from `anchorA` if nil.
    public var localAnchorA: Vector2?
    /// Local anchor offset on body B. Computed from `anchorB` if nil.
    public var localAnchorB: Vector2?
    /// Maximum distance between anchors. 0 = auto-computed from initial anchor positions.
    public var maxLength: Float

    // MARK: Breaking

    /// Maximum constraint force before joint breaks. 0 = unbreakable.
    public var maxForce: Float

    public init(
        entityA: Entity,
        entityB: Entity,
        anchorA: Vector2,
        anchorB: Vector2,
        localAnchorA: Vector2? = nil,
        localAnchorB: Vector2? = nil,
        maxLength: Float = 0,
        maxForce: Float = 0
    ) {
        self.entityA = entityA
        self.entityB = entityB
        self.anchorA = anchorA
        self.anchorB = anchorB
        self.localAnchorA = localAnchorA
        self.localAnchorB = localAnchorB
        self.maxLength = maxLength
        self.maxForce = maxForce
    }
}

/// Motor joint definition.
///
/// Drives body B toward a target position and angle offset relative to body A.
/// Uses configurable force and torque limits to control motor power.
/// The motor joint does NOT support breaking — `maxForce` and `maxTorque`
/// limit the motor's output power; when overloaded the joint simply fails
/// to reach its target.
///
/// Use for: moving platforms, smooth pursuit, drag-to-target, soft follow behavior.
public struct MotorJointDef: Sendable {
    /// First body entity (reference body).
    public var entityA: Entity
    /// Second body entity (driven body).
    public var entityB: Entity
    /// Target position of body B relative to body A, in body A's local frame.
    public var linearOffset: Vector2
    /// Target angle of body B relative to body A.
    public var angularOffset: Float
    /// Correction factor (0–1). Higher = stiffer, more aggressive correction.
    public var correctionFactor: Float
    /// Maximum motor force (limits motor output, NOT a breaking threshold).
    public var maxForce: Float
    /// Maximum motor torque (limits motor output, NOT a breaking threshold).
    public var maxTorque: Float

    public init(
        entityA: Entity,
        entityB: Entity,
        linearOffset: Vector2 = .zero,
        angularOffset: Float = 0,
        correctionFactor: Float = 0.3,
        maxForce: Float = 1.0,
        maxTorque: Float = 1.0
    ) {
        self.entityA = entityA
        self.entityB = entityB
        self.linearOffset = linearOffset
        self.angularOffset = angularOffset
        self.correctionFactor = correctionFactor
        self.maxForce = maxForce
        self.maxTorque = maxTorque
    }
}

// MARK: - Internal Joint Runtime State

/// Limit state for revolute joint angle constraints.
internal enum LimitState {
    case inactive
    case atLower
    case atUpper
    case equal  // lower == upper (locked angle)
}

/// Internal runtime state for an active joint.
///
/// Not exposed publicly — accessed via `JointHandle` through `PhysicsWorld2D`.
internal struct Joint2D {
    let handle: JointHandle
    let definition: JointDefinition
    var entityA: Entity
    var entityB: Entity

    // Local anchors (resolved from world-space anchors at creation time)
    var localAnchorA: Vector2
    var localAnchorB: Vector2

    // MARK: Warm-Starting Accumulated Impulses

    /// Accumulated linear impulse for position constraint.
    var accumulatedImpulse: Vector2 = .zero
    /// Accumulated angular impulse (weld joint).
    var accumulatedAngularImpulse: Float = 0
    /// Accumulated motor impulse (revolute joint).
    var accumulatedMotorImpulse: Float = 0
    /// Accumulated limit impulse (revolute joint angle limits).
    var accumulatedLimitImpulse: Float = 0
    /// Accumulated scalar impulse (distance joint).
    var accumulatedScalarImpulse: Float = 0

    // MARK: Pre-Computed Per Frame

    /// Rotated anchor offset for body A in world space.
    var rA: Vector2 = .zero
    /// Rotated anchor offset for body B in world space.
    var rB: Vector2 = .zero
    /// 2x2 effective mass matrix (a, b, c, d) for point constraints.
    var effectiveMass: (Float, Float, Float, Float) = (0, 0, 0, 0)
    /// Effective angular mass for angular constraints.
    var effectiveAngularMass: Float = 0
    /// 1D effective mass for distance constraint.
    var effectiveScalarMass: Float = 0
    /// Position error bias for Baumgarte stabilization.
    var bias: Vector2 = .zero
    /// Angular bias for Baumgarte stabilization.
    var angularBias: Float = 0
    /// Reference angle (body B rotation - body A rotation at creation time).
    var referenceAngle: Float = 0
    /// Current limit state for revolute joints.
    var limitState: LimitState = .inactive

    // MARK: Prismatic Joint

    /// Prismatic joint axis in body A's local frame.
    var localAxisA: Vector2 = .zero

    // MARK: Distance Joint Spring

    /// Spring softness factor (gamma).
    var springGamma: Float = 0
    /// Spring bias term.
    var springBias: Float = 0
    /// Normalized direction from anchor A to anchor B.
    var currentAxis: Vector2 = .zero

    // MARK: Break Detection

    /// Magnitude of constraint force applied this frame.
    var constraintForce: Float = 0
    /// Magnitude of constraint torque applied this frame.
    var constraintTorque: Float = 0
    /// Whether this joint should be destroyed at the end of the frame.
    var isMarkedForDestruction: Bool = false
}

// MARK: - Debug Info

/// Public-facing joint data for debug rendering.
///
/// Returned by `PhysicsWorld2D.debugJointInfo(world:)`.
public struct JointDebugInfo: Sendable {
    /// First entity in the joint.
    public let entityA: Entity
    /// Second entity in the joint.
    public let entityB: Entity
    /// World-space anchor position on body A.
    public let worldAnchorA: Vector2
    /// World-space anchor position on body B.
    public let worldAnchorB: Vector2
    /// The joint type name ("revolute", "distance", "weld", "prismatic", "rope", or "motor").
    public let jointType: String
    /// Prismatic joint axis direction in world space. Nil for non-prismatic joints.
    public let axis: Vector2?

    public init(
        entityA: Entity,
        entityB: Entity,
        worldAnchorA: Vector2,
        worldAnchorB: Vector2,
        jointType: String,
        axis: Vector2? = nil
    ) {
        self.entityA = entityA
        self.entityB = entityB
        self.worldAnchorA = worldAnchorA
        self.worldAnchorB = worldAnchorB
        self.jointType = jointType
        self.axis = axis
    }
}
