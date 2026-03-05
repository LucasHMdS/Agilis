import Testing
@testable import Agilis

// MARK: - Vector2

@Suite("Vector2 Tests")
struct Vector2Tests {
    @Test func defaultInit() {
        let v = Vector2()
        #expect(v.x == 0)
        #expect(v.y == 0)
    }

    @Test func constants() {
        #expect(Vector2.zero == Vector2(x: 0, y: 0))
        #expect(Vector2.one == Vector2(x: 1, y: 1))
        #expect(Vector2.unitX == Vector2(x: 1, y: 0))
        #expect(Vector2.unitY == Vector2(x: 0, y: 1))
    }

    @Test func addition() {
        let result = Vector2(x: 1, y: 2) + Vector2(x: 3, y: 4)
        #expect(result == Vector2(x: 4, y: 6))
    }

    @Test func subtraction() {
        let result = Vector2(x: 5, y: 3) - Vector2(x: 2, y: 1)
        #expect(result == Vector2(x: 3, y: 2))
    }

    @Test func scalarMultiplication() {
        #expect(Vector2(x: 2, y: 3) * 3 == Vector2(x: 6, y: 9))
        #expect(3 * Vector2(x: 2, y: 3) == Vector2(x: 6, y: 9))
    }

    @Test func componentMultiplication() {
        let result = Vector2(x: 2, y: 3) * Vector2(x: 4, y: 5)
        #expect(result == Vector2(x: 8, y: 15))
    }

    @Test func scalarDivision() {
        let result = Vector2(x: 10, y: 6) / 2
        #expect(result == Vector2(x: 5, y: 3))
    }

    @Test func negation() {
        let result = -Vector2(x: 3, y: -7)
        #expect(result == Vector2(x: -3, y: 7))
    }

    @Test func compoundAssignment() {
        var v = Vector2(x: 1, y: 2)
        v += Vector2(x: 3, y: 4)
        #expect(v == Vector2(x: 4, y: 6))

        v -= Vector2(x: 1, y: 1)
        #expect(v == Vector2(x: 3, y: 5))

        v *= 2
        #expect(v == Vector2(x: 6, y: 10))
    }

    @Test func length() {
        #expect(Vector2(x: 3, y: 4).length == 5)
        #expect(Vector2.zero.length == 0)
    }

    @Test func lengthSquared() {
        #expect(Vector2(x: 3, y: 4).lengthSquared == 25)
    }

    @Test func normalized() {
        let n = Vector2(x: 0, y: 5).normalized
        #expect(n == Vector2(x: 0, y: 1))
    }

    @Test func normalizedZero() {
        #expect(Vector2.zero.normalized == .zero)
    }

    @Test func dot() {
        #expect(Vector2(x: 1, y: 0).dot(Vector2(x: 0, y: 1)) == 0) // perpendicular
        #expect(Vector2(x: 2, y: 3).dot(Vector2(x: 4, y: 5)) == 23)
    }

    @Test func cross() {
        #expect(Vector2(x: 1, y: 0).cross(Vector2(x: 0, y: 1)) == 1)
        #expect(Vector2(x: 0, y: 1).cross(Vector2(x: 1, y: 0)) == -1)
    }

    @Test func distance() {
        let d = Vector2(x: 0, y: 0).distance(to: Vector2(x: 3, y: 4))
        #expect(d == 5)
    }

    @Test func lerp() {
        let a = Vector2(x: 0, y: 0)
        let b = Vector2(x: 10, y: 20)
        #expect(a.lerp(to: b, t: 0) == a)
        #expect(a.lerp(to: b, t: 1) == b)
        #expect(a.lerp(to: b, t: 0.5) == Vector2(x: 5, y: 10))
    }

    @Test func hashable() {
        let a = Vector2(x: 1, y: 2)
        let b = Vector2(x: 1, y: 2)
        let c = Vector2(x: 3, y: 4)
        let set: Set<Vector2> = [a, b, c]
        #expect(set.count == 2)
    }
}

// MARK: - Size

@Suite("Size Tests")
struct SizeTests {
    @Test func defaultInit() {
        let s = Size()
        #expect(s.width == 0)
        #expect(s.height == 0)
    }

    @Test func zero() {
        #expect(Size.zero == Size(width: 0, height: 0))
    }

    @Test func customInit() {
        let s = Size(width: 800, height: 600)
        #expect(s.width == 800)
        #expect(s.height == 600)
    }
}

// MARK: - Rect

@Suite("Rect Tests")
struct RectTests {
    @Test func defaultInit() {
        let r = Rect()
        #expect(r.x == 0 && r.y == 0 && r.width == 0 && r.height == 0)
    }

    @Test func originSizeInit() {
        let r = Rect(origin: Vector2(x: 10, y: 20), size: Size(width: 100, height: 50))
        #expect(r.x == 10)
        #expect(r.y == 20)
        #expect(r.width == 100)
        #expect(r.height == 50)
    }

    @Test func originAndSizeProperties() {
        var r = Rect(x: 5, y: 10, width: 100, height: 50)
        #expect(r.origin == Vector2(x: 5, y: 10))
        #expect(r.size == Size(width: 100, height: 50))

        r.origin = Vector2(x: 20, y: 30)
        #expect(r.x == 20)
        #expect(r.y == 30)

        r.size = Size(width: 200, height: 100)
        #expect(r.width == 200)
        #expect(r.height == 100)
    }

    @Test func minMaxValues() {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        #expect(r.minX == 10)
        #expect(r.maxX == 110)
        #expect(r.minY == 20)
        #expect(r.maxY == 70)
    }

    @Test func center() {
        let r = Rect(x: 0, y: 0, width: 100, height: 50)
        #expect(r.center == Vector2(x: 50, y: 25))
    }

    @Test func containsPoint() {
        let r = Rect(x: 10, y: 10, width: 100, height: 50)
        #expect(r.contains(Vector2(x: 50, y: 30)))  // inside
        #expect(r.contains(Vector2(x: 10, y: 10)))  // top-left corner
        #expect(r.contains(Vector2(x: 110, y: 60))) // bottom-right corner
        #expect(!r.contains(Vector2(x: 5, y: 5)))   // outside
        #expect(!r.contains(Vector2(x: 111, y: 30))) // just past right edge
    }

    @Test func intersects() {
        let a = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(a.intersects(Rect(x: 5, y: 5, width: 10, height: 10)))    // overlap
        #expect(!a.intersects(Rect(x: 20, y: 20, width: 10, height: 10))) // no overlap
        #expect(!a.intersects(Rect(x: 10, y: 0, width: 10, height: 10)))  // touching edge = no overlap
    }

    @Test func intersection() {
        let a = Rect(x: 0, y: 0, width: 10, height: 10)
        let b = Rect(x: 5, y: 5, width: 10, height: 10)

        let overlap = a.intersection(b)
        #expect(overlap != nil)
        #expect(overlap?.x == 5)
        #expect(overlap?.y == 5)
        #expect(overlap?.width == 5)
        #expect(overlap?.height == 5)

        let noOverlap = a.intersection(Rect(x: 20, y: 20, width: 5, height: 5))
        #expect(noOverlap == nil)
    }
}

// MARK: - Color

@Suite("Color Tests")
struct ColorTests {
    @Test func directInit() {
        let c = Color(r: 100, g: 150, b: 200, a: 128)
        #expect(c.r == 100)
        #expect(c.g == 150)
        #expect(c.b == 200)
        #expect(c.a == 128)
    }

    @Test func defaultAlpha() {
        let c = Color(r: 10, g: 20, b: 30)
        #expect(c.a == 255)
    }

    @Test func fromNormalized() {
        let c = Color(rf: 1.0, gf: 0.0, bf: 0.0, af: 0.5)
        #expect(c.r == 255)
        #expect(c.g == 0)
        #expect(c.b == 0)
        #expect(c.a == 127 || c.a == 128)
    }

    @Test func normalizedClamping() {
        let c = Color(rf: 2.0, gf: -1.0, bf: 0.5)
        #expect(c.r == 255) // clamped to 1.0
        #expect(c.g == 0)   // clamped to 0.0
        #expect(c.a == 255) // default alpha
    }

    @Test func predefinedColors() {
        #expect(Color.white == Color(r: 255, g: 255, b: 255))
        #expect(Color.black == Color(r: 0, g: 0, b: 0))
        #expect(Color.red == Color(r: 255, g: 0, b: 0))
        #expect(Color.green == Color(r: 0, g: 255, b: 0))
        #expect(Color.blue == Color(r: 0, g: 0, b: 255))
        #expect(Color.clear == Color(r: 0, g: 0, b: 0, a: 0))
    }
}

// MARK: - Matrix3

@Suite("Matrix3 Tests")
struct Matrix3Tests {
    @Test func identity() {
        let m = Matrix3.identity
        #expect(m.c0 == SIMD3<Float>(1, 0, 0))
        #expect(m.c1 == SIMD3<Float>(0, 1, 0))
        #expect(m.c2 == SIMD3<Float>(0, 0, 1))
    }

    @Test func identityTransform() {
        let point = Vector2(x: 5, y: 10)
        let result = Matrix3.identity.transformPoint(point)
        #expect(result == point)
    }

    @Test func translation() {
        let m = Matrix3.translation(3, 7)
        let result = m.transformPoint(Vector2(x: 1, y: 2))
        #expect(result.x == 4)
        #expect(result.y == 9)
    }

    @Test func translationFromVector() {
        let m = Matrix3.translation(Vector2(x: 10, y: 20))
        let result = m.transformPoint(.zero)
        #expect(result == Vector2(x: 10, y: 20))
    }

    @Test func scale() {
        let m = Matrix3.scale(2, 3)
        let result = m.transformPoint(Vector2(x: 5, y: 4))
        #expect(result.x == 10)
        #expect(result.y == 12)
    }

    @Test func rotation90Degrees() {
        let m = Matrix3.rotation(.pi / 2) // 90 degrees
        let result = m.transformPoint(Vector2(x: 1, y: 0))
        // After 90° CCW rotation, (1,0) -> (0,1)
        #expect(abs(result.x) < 0.0001)
        #expect(abs(result.y - 1) < 0.0001)
    }

    @Test func matrixMultiplication() {
        let translate = Matrix3.translation(5, 0)
        let scale = Matrix3.scale(2, 2)
        let combined = translate * scale // first scale, then translate
        let result = combined.transformPoint(Vector2(x: 1, y: 0))
        // scale(1,0) = (2,0), then translate = (7,0)
        #expect(abs(result.x - 7) < 0.0001)
        #expect(abs(result.y) < 0.0001)
    }

    @Test func equatable() {
        #expect(Matrix3.identity == Matrix3.identity)
        #expect(Matrix3.identity != Matrix3.translation(1, 0))
    }
}

// MARK: - Math Utilities

@Suite("Math Utilities Tests")
struct MathUtilitiesTests {
    @Test func lerpFunction() {
        #expect(Agilis.lerp(0, 10, t: 0) == 0)
        #expect(Agilis.lerp(0, 10, t: 1) == 10)
        #expect(Agilis.lerp(0, 10, t: 0.5) == 5)
        #expect(Agilis.lerp(-10, 10, t: 0.5) == 0)
    }

    @Test func clampFunction() {
        #expect(clamp(5, min: 0, max: 10) == 5)
        #expect(clamp(-5, min: 0, max: 10) == 0)
        #expect(clamp(15, min: 0, max: 10) == 10)
        #expect(clamp(0, min: 0, max: 10) == 0)   // at min
        #expect(clamp(10, min: 0, max: 10) == 10)  // at max
    }

    @Test func degreesRadiansConversion() {
        #expect(abs(degreesToRadians(180) - .pi) < 0.0001)
        #expect(abs(degreesToRadians(90) - .pi / 2) < 0.0001)
        #expect(abs(degreesToRadians(0)) < 0.0001)

        #expect(abs(radiansToDegrees(.pi) - 180) < 0.0001)
        #expect(abs(radiansToDegrees(.pi / 2) - 90) < 0.0001)
    }

    @Test func roundTrip() {
        let degrees: Float = 45
        let result = radiansToDegrees(degreesToRadians(degrees))
        #expect(abs(result - degrees) < 0.0001)
    }
}
