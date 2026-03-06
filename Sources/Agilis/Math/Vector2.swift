/// A 2D vector with floating-point components.
public struct Vector2: Sendable, Hashable, Codable {
    public var x: Float
    public var y: Float

    @inlinable
    public init(x: Float = 0, y: Float = 0) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2(x: 0, y: 0)
    public static let one = Vector2(x: 1, y: 1)
    public static let unitX = Vector2(x: 1, y: 0)
    public static let unitY = Vector2(x: 0, y: 1)

    @inlinable
    public var length: Float {
        (x * x + y * y).squareRoot()
    }

    @inlinable
    public var lengthSquared: Float {
        x * x + y * y
    }

    @inlinable
    public var normalized: Vector2 {
        let len = length
        guard len > 0 else { return .zero }
        return Vector2(x: x / len, y: y / len)
    }

    @inlinable
    public func dot(_ other: Vector2) -> Float {
        x * other.x + y * other.y
    }

    @inlinable
    public func cross(_ other: Vector2) -> Float {
        x * other.y - y * other.x
    }

    @inlinable
    public func distance(to other: Vector2) -> Float {
        (self - other).length
    }

    @inlinable
    public func lerp(to target: Vector2, t: Float) -> Vector2 {
        Vector2(
            x: x + (target.x - x) * t,
            y: y + (target.y - y) * t
        )
    }

    // MARK: - Operators

    @inlinable
    public static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    @inlinable
    public static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    @inlinable
    public static func * (lhs: Vector2, rhs: Float) -> Vector2 {
        Vector2(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    @inlinable
    public static func * (lhs: Float, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs * rhs.x, y: lhs * rhs.y)
    }

    @inlinable
    public static func * (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x * rhs.x, y: lhs.y * rhs.y)
    }

    @inlinable
    public static func / (lhs: Vector2, rhs: Float) -> Vector2 {
        Vector2(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    @inlinable
    public static prefix func - (v: Vector2) -> Vector2 {
        Vector2(x: -v.x, y: -v.y)
    }

    @inlinable
    public static func += (lhs: inout Vector2, rhs: Vector2) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    @inlinable
    public static func -= (lhs: inout Vector2, rhs: Vector2) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }

    @inlinable
    public static func *= (lhs: inout Vector2, rhs: Float) {
        lhs.x *= rhs
        lhs.y *= rhs
    }
}
