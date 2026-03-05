import AgilisCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// A 3x3 matrix for 2D transformations (translation, rotation, scale).
/// Stored in column-major order.
public struct Matrix3: Sendable, Equatable {
    public var c0: SIMD3<Float> // column 0
    public var c1: SIMD3<Float> // column 1
    public var c2: SIMD3<Float> // column 2

    public init(
        _ c0: SIMD3<Float>,
        _ c1: SIMD3<Float>,
        _ c2: SIMD3<Float>
    ) {
        self.c0 = c0
        self.c1 = c1
        self.c2 = c2
    }

    public static let identity = Matrix3(
        SIMD3(1, 0, 0),
        SIMD3(0, 1, 0),
        SIMD3(0, 0, 1)
    )

    public static func translation(_ tx: Float, _ ty: Float) -> Matrix3 {
        Matrix3(
            SIMD3(1, 0, 0),
            SIMD3(0, 1, 0),
            SIMD3(tx, ty, 1)
        )
    }

    public static func translation(_ v: Vector2) -> Matrix3 {
        translation(v.x, v.y)
    }

    public static func scale(_ sx: Float, _ sy: Float) -> Matrix3 {
        Matrix3(
            SIMD3(sx, 0, 0),
            SIMD3(0, sy, 0),
            SIMD3(0, 0, 1)
        )
    }

    public static func rotation(_ radians: Float) -> Matrix3 {
        let c = cosf(radians)
        let s = sinf(radians)
        return Matrix3(
            SIMD3(c, s, 0),
            SIMD3(-s, c, 0),
            SIMD3(0, 0, 1)
        )
    }

    public static func * (lhs: Matrix3, rhs: Matrix3) -> Matrix3 {
        Matrix3(
            lhs.c0 * rhs.c0.x + lhs.c1 * rhs.c0.y + lhs.c2 * rhs.c0.z,
            lhs.c0 * rhs.c1.x + lhs.c1 * rhs.c1.y + lhs.c2 * rhs.c1.z,
            lhs.c0 * rhs.c2.x + lhs.c1 * rhs.c2.y + lhs.c2 * rhs.c2.z
        )
    }

    public func transformPoint(_ point: Vector2) -> Vector2 {
        let x = c0.x * point.x + c1.x * point.y + c2.x
        let y = c0.y * point.x + c1.y * point.y + c2.y
        return Vector2(x: x, y: y)
    }
}
