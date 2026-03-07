@testable import Agilis
import Testing

@Suite("Impulse Resolver Tests")
struct ImpulseResolverTests {

    // MARK: - Velocity Resolution

    @Test("Equal mass head-on collision with perfect bounce: velocities swap")
    func equalMassSwap() {
        var velA = Vector2(x: 10, y: 0)
        var velB = Vector2(x: -10, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0), // A -> B
            penetration: 1,
            point: Vector2(x: 5, y: 0)
        )

        ImpulseResolver.resolveVelocity(
            contact: contact,
            velocityA: &velA, velocityB: &velB,
            inverseMassA: 1, inverseMassB: 1,
            restitution: 1.0, friction: 0
        )

        // With restitution=1 and equal mass, velocities should swap
        #expect(abs(velA.x - (-10)) < 0.1)
        #expect(abs(velB.x - 10) < 0.1)
    }

    @Test("Wall collision: velocity reflects")
    func wallBounce() {
        var velA = Vector2(x: 10, y: 0)
        var velB = Vector2(x: 0, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0),
            penetration: 1,
            point: Vector2(x: 5, y: 0)
        )

        // B is static (inverseMass = 0)
        ImpulseResolver.resolveVelocity(
            contact: contact,
            velocityA: &velA, velocityB: &velB,
            inverseMassA: 1, inverseMassB: 0,
            restitution: 1.0, friction: 0
        )

        // A should bounce back
        #expect(abs(velA.x - (-10)) < 0.1)
        // B should not move
        #expect(abs(velB.x) < 0.01)
    }

    @Test("Restitution 0: no bounce")
    func noBounce() {
        var velA = Vector2(x: 10, y: 0)
        var velB = Vector2(x: 0, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0),
            penetration: 1,
            point: Vector2(x: 5, y: 0)
        )

        ImpulseResolver.resolveVelocity(
            contact: contact,
            velocityA: &velA, velocityB: &velB,
            inverseMassA: 1, inverseMassB: 0,
            restitution: 0, friction: 0
        )

        // A should stop (no bounce)
        #expect(abs(velA.x) < 0.1)
    }

    @Test("Bodies already separating: no impulse applied")
    func alreadySeparating() {
        var velA = Vector2(x: -5, y: 0)
        var velB = Vector2(x: 5, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0),
            penetration: 1,
            point: Vector2(x: 0, y: 0)
        )

        let origA = velA
        let origB = velB

        ImpulseResolver.resolveVelocity(
            contact: contact,
            velocityA: &velA, velocityB: &velB,
            inverseMassA: 1, inverseMassB: 1,
            restitution: 0.5, friction: 0
        )

        // Velocities should be unchanged
        #expect(abs(velA.x - origA.x) < 0.001)
        #expect(abs(velB.x - origB.x) < 0.001)
    }

    @Test("Both static: no velocity change")
    func bothStatic() {
        var velA = Vector2(x: 5, y: 0)
        var velB = Vector2(x: -5, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0),
            penetration: 1,
            point: Vector2(x: 0, y: 0)
        )

        ImpulseResolver.resolveVelocity(
            contact: contact,
            velocityA: &velA, velocityB: &velB,
            inverseMassA: 0, inverseMassB: 0,
            restitution: 1, friction: 0
        )

        // Nothing should change when both have zero inverse mass
        #expect(abs(velA.x - 5) < 0.001)
        #expect(abs(velB.x - (-5)) < 0.001)
    }

    @Test("Friction reduces tangential velocity")
    func frictionEffect() {
        // Ball sliding along a floor
        var velA = Vector2(x: 10, y: 5) // Moving right and down
        var velB = Vector2(x: 0, y: 0)  // Static floor

        // Normal points from A toward B (ball above, floor below).
        // Ball is moving into B (y velocity is positive, moving down toward floor).
        let floorContact = Contact(
            normal: Vector2(x: 0, y: 1),
            penetration: 1,
            point: Vector2(x: 0, y: 0)
        )

        ImpulseResolver.resolveVelocity(
            contact: floorContact,
            velocityA: &velA, velocityB: &velB,
            inverseMassA: 1, inverseMassB: 0,
            restitution: 0, friction: 0.5
        )

        // Normal component (y) should be resolved
        #expect(abs(velA.y) < 0.5)
        // Tangential component (x) should be reduced by friction
        #expect(velA.x < 10)
    }

    // MARK: - Penetration Correction

    @Test("Penetration correction pushes bodies apart")
    func penetrationCorrection() {
        var posA = Vector2(x: 0, y: 0)
        var posB = Vector2(x: 8, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0),
            penetration: 2,
            point: Vector2(x: 4, y: 0)
        )

        ImpulseResolver.correctPenetration(
            contact: contact,
            positionA: &posA, positionB: &posB,
            inverseMassA: 1, inverseMassB: 1,
            slop: 0, percent: 1.0
        )

        // Both should move apart equally (equal mass)
        #expect(posA.x < 0)
        #expect(posB.x > 8)
        // Total correction should be the penetration
        let separation = posB.x - posA.x
        #expect(abs(separation - 10) < 0.1)
    }

    @Test("Penetration correction: static body doesn't move")
    func staticBodyNoPenetrationMove() {
        var posA = Vector2(x: 0, y: 0)
        var posB = Vector2(x: 8, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0),
            penetration: 2,
            point: Vector2(x: 4, y: 0)
        )

        // B is static
        ImpulseResolver.correctPenetration(
            contact: contact,
            positionA: &posA, positionB: &posB,
            inverseMassA: 1, inverseMassB: 0,
            slop: 0, percent: 1.0
        )

        // B should not move
        #expect(abs(posB.x - 8) < 0.001)
        // A should move all the correction
        #expect(posA.x < 0)
    }

    @Test("Slop prevents jitter for small penetrations")
    func slopPreventsJitter() {
        var posA = Vector2(x: 0, y: 0)
        var posB = Vector2(x: 10, y: 0)
        let contact = Contact(
            normal: Vector2(x: 1, y: 0),
            penetration: 0.005, // Below slop threshold
            point: Vector2(x: 5, y: 0)
        )

        ImpulseResolver.correctPenetration(
            contact: contact,
            positionA: &posA, positionB: &posB,
            inverseMassA: 1, inverseMassB: 1,
            slop: 0.01, percent: 0.4
        )

        // No correction should be applied
        #expect(abs(posA.x) < 0.001)
        #expect(abs(posB.x - 10) < 0.001)
    }
}
