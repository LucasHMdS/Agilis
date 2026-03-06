/// An RGBA color with components in the 0-255 range.
public struct Color: Sendable, Hashable, Codable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Create a color from normalized float components (0.0-1.0).
    public init(rf: Float, gf: Float, bf: Float, af: Float = 1.0) {
        self.r = UInt8(clamp(rf, min: 0, max: 1) * 255)
        self.g = UInt8(clamp(gf, min: 0, max: 1) * 255)
        self.b = UInt8(clamp(bf, min: 0, max: 1) * 255)
        self.a = UInt8(clamp(af, min: 0, max: 1) * 255)
    }

    // MARK: - Common Colors

    public static let white   = Color(r: 255, g: 255, b: 255)
    public static let black   = Color(r: 0, g: 0, b: 0)
    public static let red     = Color(r: 255, g: 0, b: 0)
    public static let green   = Color(r: 0, g: 255, b: 0)
    public static let blue    = Color(r: 0, g: 0, b: 255)
    public static let yellow  = Color(r: 255, g: 255, b: 0)
    public static let cyan    = Color(r: 0, g: 255, b: 255)
    public static let magenta = Color(r: 255, g: 0, b: 255)
    public static let gray    = Color(r: 128, g: 128, b: 128)
    public static let clear   = Color(r: 0, g: 0, b: 0, a: 0)

    public static let cornflowerBlue = Color(r: 100, g: 149, b: 237)
    public static let darkGray = Color(r: 40, g: 40, b: 40)

    // MARK: - Interpolation

    /// Linearly interpolates between two colors component-wise.
    /// `t` is clamped to 0...1. Returns `a` when t=0, `b` when t=1.
    public static func lerp(_ a: Color, _ b: Color, t: Float) -> Color {
        let t = clamp(t, min: 0, max: 1)
        return Color(
            r: UInt8(Float(a.r) + (Float(b.r) - Float(a.r)) * t),
            g: UInt8(Float(a.g) + (Float(b.g) - Float(a.g)) * t),
            b: UInt8(Float(a.b) + (Float(b.b) - Float(a.b)) * t),
            a: UInt8(Float(a.a) + (Float(b.a) - Float(a.a)) * t)
        )
    }
}
