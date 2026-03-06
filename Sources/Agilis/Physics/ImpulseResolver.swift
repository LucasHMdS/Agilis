

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Impulse-based collision resolution.
///
/// Provides two operations:
/// 1. **Velocity resolution** — computes and applies impulses to change velocities
///    so bodies bounce/slide correctly.
/// 2. **Penetration correction** — nudges positions apart to prevent overlap.
public enum ImpulseResolver {

    /// Apply impulse-based collision response to two bodies.
    ///
    /// Modifies the linear velocities of both bodies based on the collision normal,
    /// their masses, restitution (bounciness), and friction. Does NOT modify positions.
    ///
    /// - Parameters:
    ///   - contact: Narrow-phase contact (normal points A → B).
    ///   - velocityA: Linear velocity of body A (modified in place).
    ///   - velocityB: Linear velocity of body B (modified in place).
    ///   - inverseMassA: Inverse mass of body A (0 for static/kinematic).
    ///   - inverseMassB: Inverse mass of body B (0 for static/kinematic).
    ///   - restitution: Combined restitution coefficient (0 = no bounce, 1 = perfect bounce).
    ///   - friction: Combined friction coefficient.
    public static func resolveVelocity(
        contact: Contact,
        velocityA: inout Vector2,
        velocityB: inout Vector2,
        inverseMassA: Float,
        inverseMassB: Float,
        restitution: Float,
        friction: Float
    ) {
        let totalInvMass = inverseMassA + inverseMassB
        guard totalInvMass > 0 else { return }

        let relativeVelocity = velocityB - velocityA
        let velAlongNormal = relativeVelocity.dot(contact.normal)

        // Bodies already moving apart — no impulse needed
        if velAlongNormal > 0 { return }

        // Normal impulse magnitude
        let j = -(1 + restitution) * velAlongNormal / totalInvMass

        let impulse = contact.normal * j
        velocityA -= impulse * inverseMassA
        velocityB += impulse * inverseMassB

        // Friction (tangential impulse)
        let relVelAfter = velocityB - velocityA
        let tangentComponent = relVelAfter - contact.normal * relVelAfter.dot(contact.normal)
        let tangentLen = tangentComponent.length
        if tangentLen < PhysicsConstants.Tolerance.vectorLength { return }

        let tangentDir = tangentComponent / tangentLen
        let jt = -relVelAfter.dot(tangentDir) / totalInvMass

        // Coulomb's law: clamp friction impulse magnitude
        let frictionImpulse: Vector2
        if abs(jt) < j * friction {
            // Static friction: cancel tangential velocity
            frictionImpulse = tangentDir * jt
        } else {
            // Dynamic friction: apply proportional to normal impulse
            frictionImpulse = tangentDir * (-j * friction)
        }

        velocityA -= frictionImpulse * inverseMassA
        velocityB += frictionImpulse * inverseMassB
    }

    /// Correct position overlap by pushing bodies apart.
    ///
    /// Uses a small slop threshold to avoid jitter from floating-point imprecision,
    /// and a correction percentage to smooth out the adjustment over frames.
    ///
    /// - Parameters:
    ///   - contact: Narrow-phase contact (normal points A → B).
    ///   - positionA: Position of body A (modified in place).
    ///   - positionB: Position of body B (modified in place).
    ///   - inverseMassA: Inverse mass of body A (0 for static/kinematic).
    ///   - inverseMassB: Inverse mass of body B (0 for static/kinematic).
    ///   - slop: Minimum penetration threshold before correction is applied. Default: 0.01.
    ///   - percent: Fraction of penetration to correct each frame. Default: 0.4.
    public static func correctPenetration(
        contact: Contact,
        positionA: inout Vector2,
        positionB: inout Vector2,
        inverseMassA: Float,
        inverseMassB: Float,
        slop: Float = 0.01,
        percent: Float = 0.4
    ) {
        let totalInvMass = inverseMassA + inverseMassB
        guard totalInvMass > 0 else { return }

        let correctionMag = max(contact.penetration - slop, 0) * percent / totalInvMass
        let correction = contact.normal * correctionMag
        positionA -= correction * inverseMassA
        positionB += correction * inverseMassB
    }
}
