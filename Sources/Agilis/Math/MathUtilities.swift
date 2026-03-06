/// Linearly interpolates between two values.
public func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
    a + (b - a) * t
}

/// Clamps a value to a range.
public func clamp(_ value: Float, min minVal: Float, max maxVal: Float) -> Float {
    Swift.min(Swift.max(value, minVal), maxVal)
}

/// Converts degrees to radians.
public func degreesToRadians(_ degrees: Float) -> Float {
    degrees * .pi / 180.0
}

/// Converts radians to degrees.
public func radiansToDegrees(_ radians: Float) -> Float {
    radians * 180.0 / .pi
}
