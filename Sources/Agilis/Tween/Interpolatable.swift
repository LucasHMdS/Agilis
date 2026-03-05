import AgilisCore

/// A type that supports linear interpolation between two values.
///
/// Conforming types can be used as tween start/end values.
/// Built-in conformances: `Float`, `Vector2`, `Color`.
///
/// ## Usage
/// ```swift
/// let mid = start.interpolated(to: end, t: 0.5)
/// ```
public protocol Interpolatable: Sendable {
    /// Linearly interpolate from `self` to `target` at normalized time `t`.
    ///
    /// `t` is typically in [0, 1] but may exceed that range for elastic/back easings.
    func interpolated(to target: Self, t: Float) -> Self
}

// MARK: - Built-in Conformances

extension Float: Interpolatable {
    public func interpolated(to target: Float, t: Float) -> Float {
        self + (target - self) * t
    }
}

extension Vector2: Interpolatable {
    public func interpolated(to target: Vector2, t: Float) -> Vector2 {
        self.lerp(to: target, t: t)
    }
}

extension Color: Interpolatable {
    public func interpolated(to target: Color, t: Float) -> Color {
        Color.lerp(self, target, t: t)
    }
}
