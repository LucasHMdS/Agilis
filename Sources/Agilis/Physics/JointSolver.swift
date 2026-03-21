#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Sequential-impulse constraint solver for physics joints.
///
/// Implements the Projected Gauss-Seidel algorithm used by Box2D:
/// 1. **Pre-solve**: compute effective masses, bias terms, and warm-start impulses
/// 2. **Velocity solve**: iteratively correct velocity constraint violations
/// 3. **Position solve**: directly correct positional errors
///
/// All methods are stateless — joint state is mutated through `inout Joint2D`.
internal enum JointSolver {

    /// Baumgarte stabilization factor. Higher = faster error correction, but less stable.
    static let baumgarteBeta: Float = 0.2

    /// Positional slop — small positional error allowed to prevent jitter.
    static let linearSlop: Float = 0.005

    /// Angular slop in radians (~0.3 degrees).
    static let angularSlop: Float = 0.005

    // MARK: - Pre-Solve

    // Compute constraint data for a joint. Called once per frame per joint.
    static func preSolve(
        joint: inout Joint2D,
        transformA: Transform2D,
        transformB: Transform2D,
        velocityA _: Velocity2D,
        velocityB _: Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D,
        dt: Float
    ) {
        switch joint.definition {
        case .revolute(let def):
            preSolveRevolute(
                joint: &joint,
                def: def,
                transformA: transformA,
                transformB: transformB,
                bodyA: bodyA,
                bodyB: bodyB,
                dt: dt
            )

        case .distance(let def):
            preSolveDistance(
                joint: &joint,
                def: def,
                transformA: transformA,
                transformB: transformB,
                bodyA: bodyA,
                bodyB: bodyB,
                dt: dt
            )

        case .weld(let def):
            preSolveWeld(
                joint: &joint,
                def: def,
                transformA: transformA,
                transformB: transformB,
                bodyA: bodyA,
                bodyB: bodyB,
                dt: dt
            )

        case .prismatic(let def):
            preSolvePrismatic(
                joint: &joint,
                def: def,
                transformA: transformA,
                transformB: transformB,
                bodyA: bodyA,
                bodyB: bodyB,
                dt: dt
            )

        case .rope(let def):
            preSolveRope(
                joint: &joint,
                def: def,
                transformA: transformA,
                transformB: transformB,
                bodyA: bodyA,
                bodyB: bodyB,
                dt: dt
            )

        case .motor(let def):
            preSolveMotor(
                joint: &joint,
                def: def,
                transformA: transformA,
                transformB: transformB,
                bodyA: bodyA,
                bodyB: bodyB,
                dt: dt
            )
        }
    }

    // MARK: - Warm Start

    // Apply accumulated impulse from previous frame. Called once after pre-solve.
    static func warmStart(
        joint: inout Joint2D,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        switch joint.definition {
        case .revolute:
            // Apply accumulated linear impulse
            let p = joint.accumulatedImpulse
            velocityA.linear.x -= mA * p.x
            velocityA.linear.y -= mA * p.y
            velocityA.angular -= iA * crossVV(joint.rA, p)
            velocityB.linear.x += mB * p.x
            velocityB.linear.y += mB * p.y
            velocityB.angular += iB * crossVV(joint.rB, p)

            // Apply accumulated limit + motor impulse
            let angularImpulse = joint.accumulatedMotorImpulse
                + joint.accumulatedLimitImpulse
            velocityA.angular -= iA * angularImpulse
            velocityB.angular += iB * angularImpulse

        case .distance:
            let p = joint.currentAxis * joint.accumulatedScalarImpulse
            velocityA.linear.x -= mA * p.x
            velocityA.linear.y -= mA * p.y
            velocityA.angular -= iA * crossVV(joint.rA, p)
            velocityB.linear.x += mB * p.x
            velocityB.linear.y += mB * p.y
            velocityB.angular += iB * crossVV(joint.rB, p)

        case .weld:
            // Apply accumulated linear impulse
            let p = joint.accumulatedImpulse
            velocityA.linear.x -= mA * p.x
            velocityA.linear.y -= mA * p.y
            let weldAngA = crossVV(joint.rA, p) + joint.accumulatedAngularImpulse
            velocityA.angular -= iA * weldAngA
            velocityB.linear.x += mB * p.x
            velocityB.linear.y += mB * p.y
            let weldAngB = crossVV(joint.rB, p) + joint.accumulatedAngularImpulse
            velocityB.angular += iB * weldAngB

        case .prismatic:
            warmStartPrismatic(
                joint: &joint,
                velocityA: &velocityA,
                velocityB: &velocityB,
                mA: mA,
                mB: mB,
                iA: iA,
                iB: iB
            )

        case .rope:
            // Same pattern as distance
            let p = joint.currentAxis * joint.accumulatedScalarImpulse
            velocityA.linear.x -= mA * p.x
            velocityA.linear.y -= mA * p.y
            velocityA.angular -= iA * crossVV(joint.rA, p)
            velocityB.linear.x += mB * p.x
            velocityB.linear.y += mB * p.y
            velocityB.angular += iB * crossVV(joint.rB, p)

        case .motor:
            // Apply accumulated linear + angular impulses
            let p = joint.accumulatedImpulse
            velocityA.linear.x -= mA * p.x
            velocityA.linear.y -= mA * p.y
            velocityA.angular -= iA * joint.accumulatedAngularImpulse
            velocityB.linear.x += mB * p.x
            velocityB.linear.y += mB * p.y
            velocityB.angular += iB * joint.accumulatedAngularImpulse
        }
    }

    // MARK: - Velocity Solve

    // Solve velocity constraints for a joint. Called N times per frame.
    static func solveVelocity(
        joint: inout Joint2D,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        switch joint.definition {
        case .revolute(let def):
            solveVelocityRevolute(
                joint: &joint,
                def: def,
                velocityA: &velocityA,
                velocityB: &velocityB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .distance:
            solveVelocityDistance(
                joint: &joint,
                velocityA: &velocityA,
                velocityB: &velocityB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .weld:
            solveVelocityWeld(
                joint: &joint,
                velocityA: &velocityA,
                velocityB: &velocityB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .prismatic(let def):
            solveVelocityPrismatic(
                joint: &joint,
                def: def,
                velocityA: &velocityA,
                velocityB: &velocityB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .rope(let def):
            solveVelocityRope(
                joint: &joint,
                def: def,
                velocityA: &velocityA,
                velocityB: &velocityB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .motor(let def):
            solveVelocityMotor(
                joint: &joint,
                def: def,
                velocityA: &velocityA,
                velocityB: &velocityB,
                bodyA: bodyA,
                bodyB: bodyB
            )
        }
    }

    // MARK: - Position Solve

    // Solve position constraints for a joint. Called M times per frame.
    // Returns the magnitude of the positional error.
    static func solvePosition(
        joint: inout Joint2D,
        transformA: inout Transform2D,
        transformB: inout Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) -> Float {
        switch joint.definition {
        case .revolute(let def):
            return solvePositionRevolute(
                joint: &joint,
                def: def,
                transformA: &transformA,
                transformB: &transformB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .distance(let def):
            return solvePositionDistance(
                joint: &joint,
                def: def,
                transformA: &transformA,
                transformB: &transformB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .weld:
            return solvePositionWeld(
                joint: &joint,
                transformA: &transformA,
                transformB: &transformB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .prismatic(let def):
            return solvePositionPrismatic(
                joint: &joint,
                def: def,
                transformA: &transformA,
                transformB: &transformB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .rope(let def):
            return solvePositionRope(
                joint: &joint,
                def: def,
                transformA: &transformA,
                transformB: &transformB,
                bodyA: bodyA,
                bodyB: bodyB
            )

        case .motor:
            return 0 // Motor joint is purely velocity-driven
        }
    }

    // MARK: - Revolute Joint

    private static func preSolveRevolute(
        joint: inout Joint2D,
        def: RevoluteJointDef,
        transformA: Transform2D,
        transformB: Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D,
        dt: Float
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Compute rotated anchor offsets
        joint.rA = rotateVector(
            joint.localAnchorA,
            angle: transformA.rotation
        )
        joint.rB = rotateVector(
            joint.localAnchorB,
            angle: transformB.rotation
        )

        // Build 2x2 effective mass matrix K
        let rAyAy = iA * joint.rA.y * joint.rA.y
        let rByBy = iB * joint.rB.y * joint.rB.y
        let k11 = mA + mB + rAyAy + rByBy
        let k12 = -iA * joint.rA.x * joint.rA.y
            - iB * joint.rB.x * joint.rB.y
        let rAxAx = iA * joint.rA.x * joint.rA.x
        let rBxBx = iB * joint.rB.x * joint.rB.x
        let k22 = mA + mB + rAxAx + rBxBx
        joint.effectiveMass = invert2x2((k11, k12, k12, k22))

        // Effective angular mass for limits/motor
        let totalInvI = iA + iB
        joint.effectiveAngularMass = totalInvI > 0 ? 1.0 / totalInvI : 0

        // Position error bias
        let posA = transformA.position + joint.rA
        let posB = transformB.position + joint.rB
        let posError = posB - posA
        joint.bias = posError * (baumgarteBeta / dt)

        // Angle limit state
        if def.enableLimit {
            let angle = transformB.rotation - transformA.rotation - joint.referenceAngle
            if def.upperAngle - def.lowerAngle < 2.0 * angularSlop {
                joint.limitState = .equal
            } else if angle <= def.lowerAngle {
                joint.limitState = .atLower
            } else if angle >= def.upperAngle {
                joint.limitState = .atUpper
            } else {
                joint.limitState = .inactive
                joint.accumulatedLimitImpulse = 0
            }
        } else {
            joint.limitState = .inactive
            joint.accumulatedLimitImpulse = 0
        }

        if !def.enableMotor {
            joint.accumulatedMotorImpulse = 0
        }
    }

    private static func solveVelocityRevolute(
        joint: inout Joint2D,
        def: RevoluteJointDef,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Motor constraint
        if def.enableMotor && joint.limitState != .equal {
            let cdot = velocityB.angular - velocityA.angular - def.motorSpeed
            var lambda = -joint.effectiveAngularMass * cdot
            let oldImpulse = joint.accumulatedMotorImpulse
            // Already per-step scale handled by iteration
            let maxImpulse = def.maxMotorTorque
            joint.accumulatedMotorImpulse = clampFloat(
                oldImpulse + lambda,
                -maxImpulse,
                maxImpulse
            )
            lambda = joint.accumulatedMotorImpulse - oldImpulse

            velocityA.angular -= iA * lambda
            velocityB.angular += iB * lambda
        }

        // Angle limit constraint
        if def.enableLimit && joint.limitState != .inactive {
            let cdot = velocityB.angular - velocityA.angular
            var lambda = -joint.effectiveAngularMass * cdot

            switch joint.limitState {
            case .atLower:
                let oldImpulse = joint.accumulatedLimitImpulse
                joint.accumulatedLimitImpulse = max(oldImpulse + lambda, 0)
                lambda = joint.accumulatedLimitImpulse - oldImpulse

            case .atUpper:
                let oldImpulse = joint.accumulatedLimitImpulse
                joint.accumulatedLimitImpulse = min(oldImpulse + lambda, 0)
                lambda = joint.accumulatedLimitImpulse - oldImpulse

            case .equal:
                // Lock angle — no clamping needed
                break

            case .inactive:
                break
            }

            velocityA.angular -= iA * lambda
            velocityB.angular += iB * lambda
        }

        // Point-to-point constraint (2 DOF)
        let cdot = Vector2(
            x: velocityB.linear.x + (-velocityB.angular * joint.rB.y)
             - velocityA.linear.x - (-velocityA.angular * joint.rA.y),
            y: velocityB.linear.y + (velocityB.angular * joint.rB.x)
             - velocityA.linear.y - (velocityA.angular * joint.rA.x)
        )

        let rhs = Vector2(
            x: -(cdot.x + joint.bias.x),
            y: -(cdot.y + joint.bias.y)
        )
        let impulse = mul2x2(joint.effectiveMass, rhs)

        joint.accumulatedImpulse.x += impulse.x
        joint.accumulatedImpulse.y += impulse.y

        // Track constraint force for break detection
        let accImpX = joint.accumulatedImpulse.x
        let accImpY = joint.accumulatedImpulse.y
        joint.constraintForce = sqrtf(
            accImpX * accImpX + accImpY * accImpY
        )
        joint.constraintTorque = abs(joint.accumulatedLimitImpulse)
            + abs(joint.accumulatedMotorImpulse)

        velocityA.linear.x -= mA * impulse.x
        velocityA.linear.y -= mA * impulse.y
        velocityA.angular -= iA * crossVV(joint.rA, impulse)
        velocityB.linear.x += mB * impulse.x
        velocityB.linear.y += mB * impulse.y
        velocityB.angular += iB * crossVV(joint.rB, impulse)
    }

    private static func solvePositionRevolute(
        joint: inout Joint2D,
        def: RevoluteJointDef,
        transformA: inout Transform2D,
        transformB: inout Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) -> Float {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Recompute rotated anchors from current transforms
        let rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        let rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        // Positional error
        let posError = (transformB.position + rB)
            - (transformA.position + rA)
        let errorLen = sqrtf(
            posError.x * posError.x + posError.y * posError.y
        )

        // Rebuild effective mass for current configuration
        let k11 = mA + mB + iA * rA.y * rA.y
            + iB * rB.y * rB.y
        let k12 = -iA * rA.x * rA.y
            - iB * rB.x * rB.y
        let k22 = mA + mB + iA * rA.x * rA.x
            + iB * rB.x * rB.x
        let invK = invert2x2((k11, k12, k12, k22))

        let negPosError = Vector2(x: -posError.x, y: -posError.y)
        let correction = mul2x2(invK, negPosError)

        transformA.position.x -= mA * correction.x
        transformA.position.y -= mA * correction.y
        transformA.rotation -= iA * crossVV(rA, correction)
        transformB.position.x += mB * correction.x
        transformB.position.y += mB * correction.y
        transformB.rotation += iB * crossVV(rB, correction)

        // Angular position correction for limits
        var angularError: Float = 0
        if def.enableLimit {
            let angle = transformB.rotation
                - transformA.rotation - joint.referenceAngle
            var angularCorrection: Float = 0

            if joint.limitState == .atLower || joint.limitState == .equal {
                let err = angle - def.lowerAngle
                angularError = max(angularError, -err)
                let c = clampFloat(err + angularSlop, -0.2, 0.0)
                angularCorrection = -joint.effectiveAngularMass * c
            }
            if joint.limitState == .atUpper || joint.limitState == .equal {
                let err = angle - def.upperAngle
                angularError = max(angularError, err)
                let c = clampFloat(err - angularSlop, 0.0, 0.2)
                angularCorrection = -joint.effectiveAngularMass * c
            }

            transformA.rotation -= iA * angularCorrection
            transformB.rotation += iB * angularCorrection
        }

        return max(errorLen, angularError)
    }

    // MARK: - Distance Joint

    private static func preSolveDistance(
        joint: inout Joint2D,
        def: DistanceJointDef,
        transformA: Transform2D,
        transformB: Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D,
        dt: Float
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Compute rotated anchor offsets
        joint.rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        joint.rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        // Direction vector from A to B
        let worldA = transformA.position + joint.rA
        let worldB = transformB.position + joint.rB
        let u = worldB - worldA
        let currentLength = sqrtf(u.x * u.x + u.y * u.y)

        if currentLength > linearSlop {
            joint.currentAxis = Vector2(
                x: u.x / currentLength,
                y: u.y / currentLength
            )
        } else {
            joint.currentAxis = .zero
        }

        // Cross products for effective mass
        let crA = crossVV(joint.rA, joint.currentAxis)
        let crB = crossVV(joint.rB, joint.currentAxis)
        let invEffMass = mA + mB
            + iA * crA * crA + iB * crB * crB

        let restLength = def.length

        if def.frequencyHz > 0 && dt > 0 {
            // Spring mode
            let totalMass = invEffMass > 0 ? 1.0 / invEffMass : 0
            let omega = 2.0 * Float.pi * def.frequencyHz
            let d = 2.0 * totalMass * def.dampingRatio * omega
            let k = totalMass * omega * omega

            // Gamma and bias for soft constraint
            let h = dt
            joint.springGamma = h * (d + h * k)
            if joint.springGamma > 0 {
                joint.springGamma = 1.0 / joint.springGamma
            } else {
                joint.springGamma = 0
            }

            let lengthError = currentLength - restLength
            joint.springBias = lengthError * h * k * joint.springGamma

            let effectiveMass = invEffMass + joint.springGamma
            joint.effectiveScalarMass = effectiveMass > 0
                ? 1.0 / effectiveMass : 0
        } else {
            // Rigid mode
            joint.springGamma = 0
            joint.springBias = 0
            joint.effectiveScalarMass = invEffMass > 0
                ? 1.0 / invEffMass : 0

            // Baumgarte bias for rigid constraint
            if dt > 0 {
                let lengthError = currentLength - restLength
                joint.springBias = lengthError * baumgarteBeta / dt
            }
        }
    }

    private static func solveVelocityDistance(
        joint: inout Joint2D,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Relative velocity along constraint axis
        let vpA = Vector2(
            x: velocityA.linear.x + (-velocityA.angular * joint.rA.y),
            y: velocityA.linear.y + (velocityA.angular * joint.rA.x)
        )
        let vpB = Vector2(
            x: velocityB.linear.x + (-velocityB.angular * joint.rB.y),
            y: velocityB.linear.y + (velocityB.angular * joint.rB.x)
        )
        let relX = vpB.x - vpA.x
        let relY = vpB.y - vpA.y
        let cdot = relX * joint.currentAxis.x
            + relY * joint.currentAxis.y

        let lambda: Float
        if joint.springGamma > 0 {
            // Spring mode
            let springTerm = joint.springGamma
                * joint.accumulatedScalarImpulse
            lambda = -joint.effectiveScalarMass
                * (cdot + joint.springBias + springTerm)
        } else {
            // Rigid mode
            lambda = -joint.effectiveScalarMass
                * (cdot + joint.springBias)
        }

        joint.accumulatedScalarImpulse += lambda

        // Track constraint force for break detection
        joint.constraintForce = abs(joint.accumulatedScalarImpulse)

        let p = Vector2(
            x: joint.currentAxis.x * lambda,
            y: joint.currentAxis.y * lambda
        )
        velocityA.linear.x -= mA * p.x
        velocityA.linear.y -= mA * p.y
        velocityA.angular -= iA * crossVV(joint.rA, p)
        velocityB.linear.x += mB * p.x
        velocityB.linear.y += mB * p.y
        velocityB.angular += iB * crossVV(joint.rB, p)
    }

    private static func solvePositionDistance(
        joint: inout Joint2D,
        def: DistanceJointDef,
        transformA: inout Transform2D,
        transformB: inout Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) -> Float {
        // Skip position correction for spring joints (handled by velocity solver)
        if def.frequencyHz > 0 { return 0 }

        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        let rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        let rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        let worldA = transformA.position + rA
        let worldB = transformB.position + rB
        let u = worldB - worldA
        let currentLength = sqrtf(u.x * u.x + u.y * u.y)

        guard currentLength > linearSlop else { return 0 }

        let axis = Vector2(
            x: u.x / currentLength,
            y: u.y / currentLength
        )
        let error = currentLength - def.length

        let crA = crossVV(rA, axis)
        let crB = crossVV(rB, axis)
        let invEffMass = mA + mB
            + iA * crA * crA + iB * crB * crB
        guard invEffMass > 0 else { return abs(error) }

        let lambda = -error / invEffMass
        let p = Vector2(x: axis.x * lambda, y: axis.y * lambda)

        transformA.position.x -= mA * p.x
        transformA.position.y -= mA * p.y
        transformA.rotation -= iA * crossVV(rA, p)
        transformB.position.x += mB * p.x
        transformB.position.y += mB * p.y
        transformB.rotation += iB * crossVV(rB, p)

        return abs(error)
    }

    // MARK: - Weld Joint

    private static func preSolveWeld(
        joint: inout Joint2D,
        def: WeldJointDef,
        transformA: Transform2D,
        transformB: Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D,
        dt: Float
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Compute rotated anchor offsets
        joint.rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        joint.rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        // Build 2x2 effective mass matrix K (same as revolute)
        let k11 = mA + mB
            + iA * joint.rA.y * joint.rA.y
            + iB * joint.rB.y * joint.rB.y
        let k12 = -iA * joint.rA.x * joint.rA.y
            - iB * joint.rB.x * joint.rB.y
        let k22 = mA + mB
            + iA * joint.rA.x * joint.rA.x
            + iB * joint.rB.x * joint.rB.x
        joint.effectiveMass = invert2x2((k11, k12, k12, k22))

        // Angular effective mass
        let totalInvI = iA + iB

        if def.frequencyHz > 0 && dt > 0 {
            // Soft angular constraint
            let totalMass = totalInvI > 0 ? 1.0 / totalInvI : 0
            let omega = 2.0 * Float.pi * def.frequencyHz
            let d = 2.0 * totalMass * def.dampingRatio * omega
            let k = totalMass * omega * omega
            let h = dt

            joint.springGamma = h * (d + h * k)
            if joint.springGamma > 0 {
                joint.springGamma = 1.0 / joint.springGamma
            } else {
                joint.springGamma = 0
            }

            let angleError = transformB.rotation
                - transformA.rotation - joint.referenceAngle
            joint.angularBias = angleError * h * k
                * joint.springGamma

            joint.effectiveAngularMass = totalInvI + joint.springGamma
            if joint.effectiveAngularMass > 0 {
                joint.effectiveAngularMass = 1.0
                    / joint.effectiveAngularMass
            } else {
                joint.effectiveAngularMass = 0
            }
        } else {
            // Rigid angular constraint
            joint.springGamma = 0
            joint.effectiveAngularMass = totalInvI > 0
                ? 1.0 / totalInvI : 0

            // Baumgarte bias
            if dt > 0 {
                let angleError = transformB.rotation
                    - transformA.rotation - joint.referenceAngle
                joint.angularBias = angleError * baumgarteBeta / dt
            }
        }

        // Position error bias
        let posA = transformA.position + joint.rA
        let posB = transformB.position + joint.rB
        let posError = posB - posA
        joint.bias = posError * (baumgarteBeta / dt)
    }

    private static func solveVelocityWeld(
        joint: inout Joint2D,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Angular constraint
        let cdotAngular = velocityB.angular - velocityA.angular
        let lambdaAngular: Float
        if joint.springGamma > 0 {
            let springTerm = joint.springGamma
                * joint.accumulatedAngularImpulse
            lambdaAngular = -joint.effectiveAngularMass
                * (cdotAngular + joint.angularBias + springTerm)
        } else {
            lambdaAngular = -joint.effectiveAngularMass
                * (cdotAngular + joint.angularBias)
        }
        joint.accumulatedAngularImpulse += lambdaAngular

        velocityA.angular -= iA * lambdaAngular
        velocityB.angular += iB * lambdaAngular

        // Point-to-point constraint (2 DOF) — same as revolute
        let cdot = Vector2(
            x: velocityB.linear.x + (-velocityB.angular * joint.rB.y)
             - velocityA.linear.x - (-velocityA.angular * joint.rA.y),
            y: velocityB.linear.y + (velocityB.angular * joint.rB.x)
             - velocityA.linear.y - (velocityA.angular * joint.rA.x)
        )

        let rhs = Vector2(
            x: -(cdot.x + joint.bias.x),
            y: -(cdot.y + joint.bias.y)
        )
        let impulse = mul2x2(joint.effectiveMass, rhs)
        joint.accumulatedImpulse.x += impulse.x
        joint.accumulatedImpulse.y += impulse.y

        // Track constraint force for break detection
        let weldAccX = joint.accumulatedImpulse.x
        let weldAccY = joint.accumulatedImpulse.y
        joint.constraintForce = sqrtf(
            weldAccX * weldAccX + weldAccY * weldAccY
        )
        joint.constraintTorque = abs(joint.accumulatedAngularImpulse)

        velocityA.linear.x -= mA * impulse.x
        velocityA.linear.y -= mA * impulse.y
        velocityA.angular -= iA * crossVV(joint.rA, impulse)
        velocityB.linear.x += mB * impulse.x
        velocityB.linear.y += mB * impulse.y
        velocityB.angular += iB * crossVV(joint.rB, impulse)
    }

    private static func solvePositionWeld(
        joint: inout Joint2D,
        transformA: inout Transform2D,
        transformB: inout Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) -> Float {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Recompute rotated anchors
        let rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        let rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        // Positional error
        let posError = (transformB.position + rB)
            - (transformA.position + rA)
        let linearError = sqrtf(
            posError.x * posError.x + posError.y * posError.y
        )

        // Angular error
        let angleError = transformB.rotation
            - transformA.rotation - joint.referenceAngle
        let angularError = abs(angleError)

        // Correct angular error
        let totalInvI = iA + iB
        if totalInvI > 0 {
            let angularCorrection = -angleError / totalInvI
            transformA.rotation -= iA * angularCorrection
            transformB.rotation += iB * angularCorrection
        }

        // Correct positional error
        let k11 = mA + mB + iA * rA.y * rA.y
            + iB * rB.y * rB.y
        let k12 = -iA * rA.x * rA.y
            - iB * rB.x * rB.y
        let k22 = mA + mB + iA * rA.x * rA.x
            + iB * rB.x * rB.x
        let invK = invert2x2((k11, k12, k12, k22))
        let negPosErr = Vector2(x: -posError.x, y: -posError.y)
        let correction = mul2x2(invK, negPosErr)

        transformA.position.x -= mA * correction.x
        transformA.position.y -= mA * correction.y
        transformA.rotation -= iA * crossVV(rA, correction)
        transformB.position.x += mB * correction.x
        transformB.position.y += mB * correction.y
        transformB.rotation += iB * crossVV(rB, correction)

        return max(linearError, angularError)
    }
    // MARK: - Prismatic Joint

    private static func preSolvePrismatic(
        joint: inout Joint2D,
        def: PrismaticJointDef,
        transformA: Transform2D,
        transformB: Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D,
        dt: Float
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Compute rotated anchor offsets
        joint.rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        joint.rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        // World-space axis and perpendicular
        let worldAxis = rotateVector(
            joint.localAxisA,
            angle: transformA.rotation
        )
        let perp = Vector2(x: -worldAxis.y, y: worldAxis.x)
        joint.currentAxis = worldAxis

        // Displacement from anchor A to anchor B
        let d = (transformB.position + joint.rB)
            - (transformA.position + joint.rA)

        // Perpendicular constraint effective mass: dot(d, perp) = 0
        let s1 = crossVV(d + joint.rA, perp)
        let s2 = crossVV(joint.rB, perp)
        let invEffMassPerp = mA + mB
            + iA * s1 * s1 + iB * s2 * s2
        joint.effectiveScalarMass = invEffMassPerp > 0
            ? 1.0 / invEffMassPerp : 0

        // Angular lock effective mass
        let totalInvI = iA + iB
        joint.effectiveAngularMass = totalInvI > 0 ? 1.0 / totalInvI : 0

        // Perpendicular bias
        // dot(d, perp)
        let perpError = perp.x * d.x + perp.y * d.y
        joint.bias.x = perpError * (baumgarteBeta / dt)

        // Angular bias
        let angleError = transformB.rotation
            - transformA.rotation - joint.referenceAngle
        joint.angularBias = angleError * (baumgarteBeta / dt)

        // Translation limit state
        if def.enableLimit {
            // dot(d, axis)
            let translation = worldAxis.x * d.x
                + worldAxis.y * d.y
            let limitRange = def.upperTranslation
                - def.lowerTranslation
            if limitRange < 2.0 * linearSlop {
                joint.limitState = .equal
            } else if translation <= def.lowerTranslation {
                joint.limitState = .atLower
            } else if translation >= def.upperTranslation {
                joint.limitState = .atUpper
            } else {
                joint.limitState = .inactive
                joint.accumulatedLimitImpulse = 0
            }
        } else {
            joint.limitState = .inactive
            joint.accumulatedLimitImpulse = 0
        }

        if !def.enableMotor {
            joint.accumulatedMotorImpulse = 0
        }
    }

    private static func warmStartPrismatic(
        joint: inout Joint2D,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        mA: Float,
        mB: Float,
        iA: Float,
        iB: Float
    ) {
        let worldAxis = joint.currentAxis
        let perp = Vector2(x: -worldAxis.y, y: worldAxis.x)

        // Perpendicular impulse
        let pPerp = Vector2(
            x: perp.x * joint.accumulatedScalarImpulse,
            y: perp.y * joint.accumulatedScalarImpulse
        )
        // Limit + motor impulse along axis
        let axisImpulse = joint.accumulatedLimitImpulse
            + joint.accumulatedMotorImpulse
        let pAxis = Vector2(
            x: worldAxis.x * axisImpulse,
            y: worldAxis.y * axisImpulse
        )

        let totalP = Vector2(
            x: pPerp.x + pAxis.x,
            y: pPerp.y + pAxis.y
        )

        velocityA.linear.x -= mA * totalP.x
        velocityA.linear.y -= mA * totalP.y
        let warmAngA = crossVV(joint.rA, totalP)
            + joint.accumulatedAngularImpulse
        velocityA.angular -= iA * warmAngA
        velocityB.linear.x += mB * totalP.x
        velocityB.linear.y += mB * totalP.y
        let warmAngB = crossVV(joint.rB, totalP)
            + joint.accumulatedAngularImpulse
        velocityB.angular += iB * warmAngB
    }

    private static func solveVelocityPrismatic(
        joint: inout Joint2D,
        def: PrismaticJointDef,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        let worldAxis = joint.currentAxis
        let perp = Vector2(x: -worldAxis.y, y: worldAxis.x)

        // Velocity of anchor points
        let vpA = Vector2(
            x: velocityA.linear.x + (-velocityA.angular * joint.rA.y),
            y: velocityA.linear.y + (velocityA.angular * joint.rA.x)
        )
        let vpB = Vector2(
            x: velocityB.linear.x + (-velocityB.angular * joint.rB.y),
            y: velocityB.linear.y + (velocityB.angular * joint.rB.x)
        )
        let relVel = Vector2(x: vpB.x - vpA.x, y: vpB.y - vpA.y)

        // Motor constraint (along axis)
        if def.enableMotor && joint.limitState != .equal {
            let cdotMotor = relVel.x * worldAxis.x
                + relVel.y * worldAxis.y - def.motorSpeed
            let crA = crossVV(joint.rA, worldAxis)
            let crB = crossVV(joint.rB, worldAxis)
            let invMassMotor = mA + mB
                + iA * crA * crA + iB * crB * crB
            let effMassMotor = invMassMotor > 0
                ? 1.0 / invMassMotor : 0

            var lambdaMotor = -effMassMotor * cdotMotor
            let oldMotor = joint.accumulatedMotorImpulse
            joint.accumulatedMotorImpulse = clampFloat(
                oldMotor + lambdaMotor,
                -def.maxMotorForce,
                def.maxMotorForce
            )
            lambdaMotor = joint.accumulatedMotorImpulse - oldMotor

            let pMotor = Vector2(
                x: worldAxis.x * lambdaMotor,
                y: worldAxis.y * lambdaMotor
            )
            velocityA.linear.x -= mA * pMotor.x
            velocityA.linear.y -= mA * pMotor.y
            velocityA.angular -= iA * crossVV(joint.rA, pMotor)
            velocityB.linear.x += mB * pMotor.x
            velocityB.linear.y += mB * pMotor.y
            velocityB.angular += iB * crossVV(joint.rB, pMotor)
        }

        // Translation limit constraint (along axis)
        if def.enableLimit && joint.limitState != .inactive {
            // Recompute relative velocity after motor
            let vpA2 = Vector2(
                x: velocityA.linear.x + (-velocityA.angular * joint.rA.y),
                y: velocityA.linear.y + (velocityA.angular * joint.rA.x)
            )
            let vpB2 = Vector2(
                x: velocityB.linear.x + (-velocityB.angular * joint.rB.y),
                y: velocityB.linear.y + (velocityB.angular * joint.rB.x)
            )
            let relVel2 = Vector2(
                x: vpB2.x - vpA2.x,
                y: vpB2.y - vpA2.y
            )
            let cdotLimit = relVel2.x * worldAxis.x
                + relVel2.y * worldAxis.y

            let crA = crossVV(joint.rA, worldAxis)
            let crB = crossVV(joint.rB, worldAxis)
            let invMassLimit = mA + mB
                + iA * crA * crA + iB * crB * crB
            let effMassLimit = invMassLimit > 0
                ? 1.0 / invMassLimit : 0

            var lambdaLimit = -effMassLimit * cdotLimit

            switch joint.limitState {
            case .atLower:
                let oldImpulse = joint.accumulatedLimitImpulse
                joint.accumulatedLimitImpulse = max(oldImpulse + lambdaLimit, 0)
                lambdaLimit = joint.accumulatedLimitImpulse - oldImpulse

            case .atUpper:
                let oldImpulse = joint.accumulatedLimitImpulse
                joint.accumulatedLimitImpulse = min(oldImpulse + lambdaLimit, 0)
                lambdaLimit = joint.accumulatedLimitImpulse - oldImpulse

            case .equal:
                // Lock translation
                break

            case .inactive:
                break
            }

            let pLimit = Vector2(
                x: worldAxis.x * lambdaLimit,
                y: worldAxis.y * lambdaLimit
            )
            velocityA.linear.x -= mA * pLimit.x
            velocityA.linear.y -= mA * pLimit.y
            velocityA.angular -= iA * crossVV(joint.rA, pLimit)
            velocityB.linear.x += mB * pLimit.x
            velocityB.linear.y += mB * pLimit.y
            velocityB.angular += iB * crossVV(joint.rB, pLimit)
        }

        // Angular lock constraint
        let cdotAngular = velocityB.angular - velocityA.angular
        let lambdaAngular = -joint.effectiveAngularMass
            * (cdotAngular + joint.angularBias)
        joint.accumulatedAngularImpulse += lambdaAngular

        velocityA.angular -= iA * lambdaAngular
        velocityB.angular += iB * lambdaAngular

        // Perpendicular constraint
        // Recompute velocity after angular + limit corrections
        let vpA3 = Vector2(
            x: velocityA.linear.x + (-velocityA.angular * joint.rA.y),
            y: velocityA.linear.y + (velocityA.angular * joint.rA.x)
        )
        let vpB3 = Vector2(
            x: velocityB.linear.x + (-velocityB.angular * joint.rB.y),
            y: velocityB.linear.y + (velocityB.angular * joint.rB.x)
        )
        let relVel3 = Vector2(
            x: vpB3.x - vpA3.x,
            y: vpB3.y - vpA3.y
        )
        let cdotPerp = relVel3.x * perp.x
            + relVel3.y * perp.y

        let lambdaPerp = -joint.effectiveScalarMass
            * (cdotPerp + joint.bias.x)
        joint.accumulatedScalarImpulse += lambdaPerp

        let pPerp = Vector2(
            x: perp.x * lambdaPerp,
            y: perp.y * lambdaPerp
        )
        velocityA.linear.x -= mA * pPerp.x
        velocityA.linear.y -= mA * pPerp.y
        velocityA.angular -= iA * crossVV(joint.rA, pPerp)
        velocityB.linear.x += mB * pPerp.x
        velocityB.linear.y += mB * pPerp.y
        velocityB.angular += iB * crossVV(joint.rB, pPerp)

        // Track constraint force for break detection
        let totalLinear = abs(joint.accumulatedScalarImpulse)
            + abs(joint.accumulatedLimitImpulse)
            + abs(joint.accumulatedMotorImpulse)
        joint.constraintForce = totalLinear
        joint.constraintTorque = abs(joint.accumulatedAngularImpulse)
    }

    private static func solvePositionPrismatic(
        joint: inout Joint2D,
        def: PrismaticJointDef,
        transformA: inout Transform2D,
        transformB: inout Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) -> Float {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        let rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        let rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)
        let d = (transformB.position + rB)
            - (transformA.position + rA)

        let worldAxis = rotateVector(
            joint.localAxisA,
            angle: transformA.rotation
        )
        let perp = Vector2(x: -worldAxis.y, y: worldAxis.x)

        // Perpendicular error
        let perpError = perp.x * d.x + perp.y * d.y
        var linearError = abs(perpError)

        // Angular error
        let angleError = transformB.rotation
            - transformA.rotation - joint.referenceAngle
        let angularError = abs(angleError)

        // Correct perpendicular error
        let s1 = crossVV(d + rA, perp)
        let s2 = crossVV(rB, perp)
        let invEffMassPerp = mA + mB
            + iA * s1 * s1 + iB * s2 * s2
        if invEffMassPerp > 0 {
            let lambdaPerp = -perpError / invEffMassPerp
            let pPerp = Vector2(x: perp.x * lambdaPerp, y: perp.y * lambdaPerp)
            transformA.position.x -= mA * pPerp.x
            transformA.position.y -= mA * pPerp.y
            transformA.rotation -= iA * crossVV(rA, pPerp)
            transformB.position.x += mB * pPerp.x
            transformB.position.y += mB * pPerp.y
            transformB.rotation += iB * crossVV(rB, pPerp)
        }

        // Correct angular error
        let totalInvI = iA + iB
        if totalInvI > 0 {
            let angularCorrection = -angleError / totalInvI
            transformA.rotation -= iA * angularCorrection
            transformB.rotation += iB * angularCorrection
        }

        // Correct translation limit violations
        if def.enableLimit {
            let translation = worldAxis.x * d.x
                + worldAxis.y * d.y
            var limitError: Float = 0

            if joint.limitState == .atLower || joint.limitState == .equal {
                let err = translation - def.lowerTranslation
                linearError = max(linearError, -err)
                let c = clampFloat(err + linearSlop, -0.2, 0.0)
                limitError = c
            }
            if joint.limitState == .atUpper || joint.limitState == .equal {
                let err = translation - def.upperTranslation
                linearError = max(linearError, err)
                let c = clampFloat(err - linearSlop, 0.0, 0.2)
                limitError = c
            }

            if abs(limitError) > 0 {
                let crA = crossVV(rA, worldAxis)
                let crB = crossVV(rB, worldAxis)
                let invMassLimit = mA + mB
                    + iA * crA * crA + iB * crB * crB
                if invMassLimit > 0 {
                    let lambdaLimit = -limitError / invMassLimit
                    let pLimit = Vector2(
                        x: worldAxis.x * lambdaLimit,
                        y: worldAxis.y * lambdaLimit
                    )
                    transformA.position.x -= mA * pLimit.x
                    transformA.position.y -= mA * pLimit.y
                    transformA.rotation -= iA * crossVV(rA, pLimit)
                    transformB.position.x += mB * pLimit.x
                    transformB.position.y += mB * pLimit.y
                    transformB.rotation += iB * crossVV(rB, pLimit)
                }
            }
        }

        return max(linearError, angularError)
    }

    // MARK: - Rope Joint

    private static func preSolveRope(
        joint: inout Joint2D,
        def: RopeJointDef,
        transformA: Transform2D,
        transformB: Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D,
        dt: Float
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Compute rotated anchor offsets
        joint.rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        joint.rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        // Direction vector from A to B
        let worldA = transformA.position + joint.rA
        let worldB = transformB.position + joint.rB
        let u = worldB - worldA
        let currentLength = sqrtf(u.x * u.x + u.y * u.y)

        if currentLength > linearSlop {
            joint.currentAxis = Vector2(
                x: u.x / currentLength,
                y: u.y / currentLength
            )
        } else {
            joint.currentAxis = .zero
        }

        // Check if rope is taut or slack
        if currentLength <= def.maxLength {
            // Slack — disable constraint
            joint.effectiveScalarMass = 0
            joint.accumulatedScalarImpulse = 0
            joint.springBias = 0
            return
        }

        // Taut — compute constraint
        let crA = crossVV(joint.rA, joint.currentAxis)
        let crB = crossVV(joint.rB, joint.currentAxis)
        let invEffMass = mA + mB
            + iA * crA * crA + iB * crB * crB
        joint.effectiveScalarMass = invEffMass > 0
            ? 1.0 / invEffMass : 0

        // Baumgarte bias
        if dt > 0 {
            let lengthError = currentLength - def.maxLength
            joint.springBias = lengthError * baumgarteBeta / dt
        }
    }

    private static func solveVelocityRope(
        joint: inout Joint2D,
        def _: RopeJointDef,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        // Skip if slack (effectiveScalarMass == 0)
        guard joint.effectiveScalarMass > 0 else { return }

        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Relative velocity along constraint axis
        let vpA = Vector2(
            x: velocityA.linear.x + (-velocityA.angular * joint.rA.y),
            y: velocityA.linear.y + (velocityA.angular * joint.rA.x)
        )
        let vpB = Vector2(
            x: velocityB.linear.x + (-velocityB.angular * joint.rB.y),
            y: velocityB.linear.y + (velocityB.angular * joint.rB.x)
        )
        let relX = vpB.x - vpA.x
        let relY = vpB.y - vpA.y
        let cdot = relX * joint.currentAxis.x
            + relY * joint.currentAxis.y

        let lambda = -joint.effectiveScalarMass
            * (cdot + joint.springBias)

        // Clamp: tension only (accumulated impulse <= 0, negative = pulling together)
        let oldImpulse = joint.accumulatedScalarImpulse
        joint.accumulatedScalarImpulse = min(oldImpulse + lambda, 0)
        let actualLambda = joint.accumulatedScalarImpulse - oldImpulse

        // Track constraint force for break detection
        joint.constraintForce = abs(joint.accumulatedScalarImpulse)

        let p = Vector2(
            x: joint.currentAxis.x * actualLambda,
            y: joint.currentAxis.y * actualLambda
        )
        velocityA.linear.x -= mA * p.x
        velocityA.linear.y -= mA * p.y
        velocityA.angular -= iA * crossVV(joint.rA, p)
        velocityB.linear.x += mB * p.x
        velocityB.linear.y += mB * p.y
        velocityB.angular += iB * crossVV(joint.rB, p)
    }

    private static func solvePositionRope(
        joint: inout Joint2D,
        def: RopeJointDef,
        transformA: inout Transform2D,
        transformB: inout Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) -> Float {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        let rA = rotateVector(joint.localAnchorA, angle: transformA.rotation)
        let rB = rotateVector(joint.localAnchorB, angle: transformB.rotation)

        let worldA = transformA.position + rA
        let worldB = transformB.position + rB
        let u = worldB - worldA
        let currentLength = sqrtf(u.x * u.x + u.y * u.y)

        // Only correct if stretched beyond maxLength
        let error = currentLength - def.maxLength
        guard error > linearSlop else { return 0 }
        guard currentLength > linearSlop else { return 0 }

        let axis = Vector2(x: u.x / currentLength, y: u.y / currentLength)
        let crA = crossVV(rA, axis)
        let crB = crossVV(rB, axis)
        let invEffMass = mA + mB + iA * crA * crA + iB * crB * crB
        guard invEffMass > 0 else { return error }

        let lambda = -error / invEffMass
        let p = Vector2(x: axis.x * lambda, y: axis.y * lambda)

        transformA.position.x -= mA * p.x
        transformA.position.y -= mA * p.y
        transformA.rotation -= iA * crossVV(rA, p)
        transformB.position.x += mB * p.x
        transformB.position.y += mB * p.y
        transformB.rotation += iB * crossVV(rB, p)

        return error
    }

    // MARK: - Motor Joint

    private static func preSolveMotor(
        joint: inout Joint2D,
        def: MotorJointDef,
        transformA: Transform2D,
        transformB: Transform2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D,
        dt: Float
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Motor joint acts at body centers — rA = rB = .zero
        joint.rA = .zero
        joint.rB = .zero

        // K matrix simplifies to (mA+mB) * Identity since rA = rB = .zero
        let totalInvMass = mA + mB
        if totalInvMass > 0 {
            let invM = 1.0 / totalInvMass
            joint.effectiveMass = (invM, 0, 0, invM)
        } else {
            joint.effectiveMass = (0, 0, 0, 0)
        }

        // Angular effective mass
        let totalInvI = iA + iB
        joint.effectiveAngularMass = totalInvI > 0 ? 1.0 / totalInvI : 0

        // Linear error: posB - (posA + rotate(linearOffset, rotA))
        let rotatedOffset = rotateVector(
            def.linearOffset,
            angle: transformA.rotation
        )
        let targetPos = transformA.position + rotatedOffset
        let linearError = transformB.position - targetPos

        // Angular error: rotB - rotA - angularOffset
        let angularError = transformB.rotation
            - transformA.rotation - def.angularOffset

        // Bias from correctionFactor (analogous to Baumgarte but user-tunable)
        if dt > 0 {
            let corrDt = def.correctionFactor / dt
            joint.bias = linearError * corrDt
            joint.angularBias = angularError * corrDt
        }
    }

    private static func solveVelocityMotor(
        joint: inout Joint2D,
        def: MotorJointDef,
        velocityA: inout Velocity2D,
        velocityB: inout Velocity2D,
        bodyA: RigidBody2D,
        bodyB: RigidBody2D
    ) {
        let mA = bodyA.effectiveInverseMass
        let mB = bodyB.effectiveInverseMass
        let iA = bodyA.effectiveInverseInertia
        let iB = bodyB.effectiveInverseInertia

        // Angular constraint
        let cdotAngular = velocityB.angular - velocityA.angular
        var lambdaAngular = -joint.effectiveAngularMass
            * (cdotAngular + joint.angularBias)

        // Clamp accumulated angular impulse magnitude to maxTorque
        let oldAngular = joint.accumulatedAngularImpulse
        joint.accumulatedAngularImpulse = clampFloat(
            oldAngular + lambdaAngular,
            -def.maxTorque,
            def.maxTorque
        )
        lambdaAngular = joint.accumulatedAngularImpulse - oldAngular

        velocityA.angular -= iA * lambdaAngular
        velocityB.angular += iB * lambdaAngular

        // Linear constraint (at body centers, so rA = rB = .zero)
        let cdotLinear = Vector2(
            x: velocityB.linear.x - velocityA.linear.x,
            y: velocityB.linear.y - velocityA.linear.y
        )
        let rhs = Vector2(
            x: -(cdotLinear.x + joint.bias.x),
            y: -(cdotLinear.y + joint.bias.y)
        )
        let lambdaLinear = mul2x2(joint.effectiveMass, rhs)

        // Clamp accumulated linear impulse magnitude to maxForce
        let oldImpulse = joint.accumulatedImpulse
        joint.accumulatedImpulse.x += lambdaLinear.x
        joint.accumulatedImpulse.y += lambdaLinear.y

        let motorAccX = joint.accumulatedImpulse.x
        let motorAccY = joint.accumulatedImpulse.y
        let mag = sqrtf(
            motorAccX * motorAccX + motorAccY * motorAccY
        )
        if mag > def.maxForce && mag > 0 {
            let scale = def.maxForce / mag
            joint.accumulatedImpulse.x *= scale
            joint.accumulatedImpulse.y *= scale
        }

        let actualLambda = Vector2(
            x: joint.accumulatedImpulse.x - oldImpulse.x,
            y: joint.accumulatedImpulse.y - oldImpulse.y
        )

        velocityA.linear.x -= mA * actualLambda.x
        velocityA.linear.y -= mA * actualLambda.y
        velocityB.linear.x += mB * actualLambda.x
        velocityB.linear.y += mB * actualLambda.y

        // Motor joints don't track constraint force for breaking
        joint.constraintForce = 0
        joint.constraintTorque = 0
    }
}

// MARK: - 2D Math Helpers

/// Scalar cross vector: w x r = (-w*r.y, w*r.x)
@inline(__always)
internal func crossSV(_ w: Float, _ r: Vector2) -> Vector2 {
    Vector2(x: -w * r.y, y: w * r.x)
}

/// Vector cross vector (2D): a x b = a.x*b.y - a.y*b.x
@inline(__always)
internal func crossVV(_ a: Vector2, _ b: Vector2) -> Float {
    a.x * b.y - a.y * b.x
}

/// Rotate a 2D vector by an angle.
@inline(__always)
internal func rotateVector(_ v: Vector2, angle: Float) -> Vector2 {
    let c = cosf(angle)
    let s = sinf(angle)
    return Vector2(x: v.x * c - v.y * s, y: v.x * s + v.y * c)
}

/// Invert a 2x2 matrix stored as (a, b, c, d):
/// | a b |   →   1/det * | d -b |
/// | c d |              | -c  a |
@inline(__always)
internal func invert2x2(
    _ m: (Float, Float, Float, Float)
) -> (Float, Float, Float, Float) {
    let det = m.0 * m.3 - m.1 * m.2
    let tolerance = PhysicsConstants.Tolerance.matrixDeterminant
    guard abs(det) > tolerance else {
        return (0, 0, 0, 0)
    }
    let invDet = 1.0 / det
    return (
        m.3 * invDet, -m.1 * invDet,
        -m.2 * invDet, m.0 * invDet
    )
}

/// Multiply a 2x2 matrix (a, b, c, d) by a vector.
@inline(__always)
internal func mul2x2(
    _ m: (Float, Float, Float, Float),
    _ v: Vector2
) -> Vector2 {
    Vector2(
        x: m.0 * v.x + m.1 * v.y,
        y: m.2 * v.x + m.3 * v.y
    )
}

/// Clamp a float between min and max.
@inline(__always)
internal func clampFloat(
    _ value: Float,
    _ minVal: Float,
    _ maxVal: Float
) -> Float {
    min(max(value, minVal), maxVal)
}
