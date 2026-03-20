@testable import Agilis
import Testing

@Suite("Physics Component Tests")
struct PhysicsComponentTests {

    // MARK: - Transform2D

    @Test("Transform2D default values")
    func transformDefaults() {
        let t = Transform2D()
        #expect(t.position == .zero)
        #expect(t.rotation == 0)
        #expect(t.scale == .one)
    }

    @Test("Transform2D identity matrix")
    func transformIdentityMatrix() {
        let t = Transform2D()
        let m = t.matrix
        // Should be identity
        let point = Vector2(x: 5, y: 10)
        let result = m.transformPoint(point)
        #expect(abs(result.x - point.x) < 0.001)
        #expect(abs(result.y - point.y) < 0.001)
    }

    @Test("Transform2D translation matrix")
    func transformTranslation() {
        let t = Transform2D(position: Vector2(x: 100, y: 200))
        let m = t.matrix
        let point = Vector2(x: 0, y: 0)
        let result = m.transformPoint(point)
        #expect(abs(result.x - 100) < 0.001)
        #expect(abs(result.y - 200) < 0.001)
    }

    @Test("Transform2D rotation matrix")
    func transformRotation() {
        // 90 degrees CCW
        let t = Transform2D(rotation: .pi / 2)
        let m = t.matrix
        let point = Vector2(x: 1, y: 0)
        let result = m.transformPoint(point)
        #expect(abs(result.x - 0) < 0.01)
        #expect(abs(result.y - 1) < 0.01)
    }

    @Test("Transform2D scale matrix")
    func transformScale() {
        let t = Transform2D(scale: Vector2(x: 2, y: 3))
        let m = t.matrix
        let point = Vector2(x: 5, y: 10)
        let result = m.transformPoint(point)
        #expect(abs(result.x - 10) < 0.001)
        #expect(abs(result.y - 30) < 0.001)
    }

    @Test("Transform2D combined translation + rotation")
    func transformCombined() {
        // Translate to (10, 0), then rotate 90 degrees
        let t = Transform2D(position: Vector2(x: 10, y: 0), rotation: .pi / 2)
        let m = t.matrix
        // Point (1, 0) should be rotated to (0, 1) then translated to (10, 1)
        let result = m.transformPoint(Vector2(x: 1, y: 0))
        #expect(abs(result.x - 10) < 0.01)
        #expect(abs(result.y - 1) < 0.01)
    }

    // MARK: - PreviousTransform2D

    @Test("PreviousTransform2D default values")
    func prevTransformDefaults() {
        let p = PreviousTransform2D()
        #expect(p.position == .zero)
        #expect(p.rotation == 0)
    }

    // MARK: - Velocity2D

    @Test("Velocity2D default values")
    func velocityDefaults() {
        let v = Velocity2D()
        #expect(v.linear == .zero)
        #expect(v.angular == 0)
    }

    // MARK: - RigidBody2D

    @Test("RigidBody2D default values")
    func rigidBodyDefaults() {
        let body = RigidBody2D()
        #expect(body.mass == 1)
        #expect(abs(body.inverseMass - 1.0) < 0.001)
        #expect(body.restitution == 0.2)
        #expect(body.friction == 0.3)
        #expect(body.gravityScale == 1)
        #expect(body.bodyType == .dynamic)
        #expect(body.linearDamping == 0)
    }

    @Test("RigidBody2D inverseMass computed correctly")
    func inverseMassComputation() {
        let body = RigidBody2D(mass: 4)
        #expect(abs(body.inverseMass - 0.25) < 0.001)
    }

    @Test("Static body has zero effective inverse mass")
    func staticBodyInverseMass() {
        let body = RigidBody2D(mass: 5, bodyType: .static)
        #expect(body.effectiveInverseMass == 0)
    }

    @Test("Kinematic body has zero effective inverse mass")
    func kinematicBodyInverseMass() {
        let body = RigidBody2D(mass: 3, bodyType: .kinematic)
        #expect(body.effectiveInverseMass == 0)
    }

    @Test("Dynamic body has nonzero effective inverse mass")
    func dynamicBodyInverseMass() {
        let body = RigidBody2D(mass: 2, bodyType: .dynamic)
        #expect(abs(body.effectiveInverseMass - 0.5) < 0.001)
    }

    @Test("Mass setter updates inverse mass")
    func massSetterUpdatesInverse() {
        var body = RigidBody2D(mass: 1)
        body.mass = 4
        #expect(abs(body.inverseMass - 0.25) < 0.001)
    }

    // MARK: - Collider2D

    @Test("Collider2D default values")
    func colliderDefaults() {
        let c = Collider2D(shape: .circle(radius: 10))
        #expect(c.offset == .zero)
        #expect(c.isTrigger == false)
        #expect(c.layer == 1)
        #expect(c.mask == 0xFFFF_FFFF)
    }

    // MARK: - BodyType

    @Test("BodyType equality")
    func bodyTypeEquality() {
        // swiftlint:disable:next identical_operands
        #expect(BodyType.dynamic == BodyType.dynamic)
        // swiftlint:disable:next identical_operands
        #expect(BodyType.static == BodyType.static)
        // swiftlint:disable:next identical_operands
        #expect(BodyType.kinematic == BodyType.kinematic)
        #expect(BodyType.dynamic != BodyType.static)
    }
}
