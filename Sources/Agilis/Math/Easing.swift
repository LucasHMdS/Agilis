#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Standard easing functions for smooth interpolation.
///
/// All functions map an input `t` in [0, 1] to an output value.
/// At t=0 the result is 0, at t=1 the result is 1.
///
/// Use with `lerp` for animated transitions:
/// ```swift
/// let t = EasingFunction.cubicOut.apply(progress)
/// let value = lerp(startValue, endValue, t: t)
/// ```
public enum EasingFunction: Sendable, Equatable {
    case linear

    case quadIn, quadOut, quadInOut
    case cubicIn, cubicOut, cubicInOut
    case sineIn, sineOut, sineInOut
    case elasticIn, elasticOut, elasticInOut
    case bounceIn, bounceOut, bounceInOut
    case backIn, backOut, backInOut

    // Apply the easing function to a normalized time value.
    // - Parameter t: Input value, typically in [0, 1].
    // - Returns: The eased value.
    // swiftlint:disable:next cyclomatic_complexity
    public func apply(_ t: Float) -> Float {
        switch self {
        // Linear
        case .linear:
            return t

        // Quad
        case .quadIn:
            return t * t

        case .quadOut:
            return 1 - (1 - t) * (1 - t)

        case .quadInOut:
            if t < 0.5 {
                return 2 * t * t
            } else {
                return 1 - 2 * (1 - t) * (1 - t)
            }

        // Cubic
        case .cubicIn:
            return t * t * t

        case .cubicOut:
            let u = 1 - t
            return 1 - u * u * u

        case .cubicInOut:
            if t < 0.5 {
                return 4 * t * t * t
            } else {
                let u = 1 - t
                return 1 - 4 * u * u * u
            }

        // Sine
        case .sineIn:
            return 1 - cosf(t * .pi / 2)

        case .sineOut:
            return sinf(t * .pi / 2)

        case .sineInOut:
            return -(cosf(.pi * t) - 1) / 2

        // Elastic
        case .elasticIn:
            if t == 0 || t == 1 { return t }
            let c = (2 * .pi) / 3 as Float
            return -powf(2, 10 * t - 10) * sinf((t * 10 - 10.75) * c)

        case .elasticOut:
            if t == 0 || t == 1 { return t }
            let c = (2 * .pi) / 3 as Float
            return powf(2, -10 * t) * sinf((t * 10 - 0.75) * c) + 1

        case .elasticInOut:
            if t == 0 || t == 1 { return t }
            let c = (2 * .pi) / 4.5 as Float
            if t < 0.5 {
                return -(powf(2, 20 * t - 10) * sinf((20 * t - 11.125) * c)) / 2
            } else {
                return (powf(2, -20 * t + 10) * sinf((20 * t - 11.125) * c)) / 2 + 1
            }

        // Bounce
        case .bounceOut:
            return Self.bounceOutImpl(t)

        case .bounceIn:
            return 1 - Self.bounceOutImpl(1 - t)

        case .bounceInOut:
            if t < 0.5 {
                return (1 - Self.bounceOutImpl(1 - 2 * t)) / 2
            } else {
                return (1 + Self.bounceOutImpl(2 * t - 1)) / 2
            }

        // Back
        case .backIn:
            let c: Float = 1.70158
            return (c + 1) * t * t * t - c * t * t

        case .backOut:
            let c: Float = 1.70158
            let u = t - 1
            return 1 + (c + 1) * u * u * u + c * u * u

        case .backInOut:
            let c: Float = 1.70158 * 1.525
            if t < 0.5 {
                return (2 * t * 2 * t * ((c + 1) * 2 * t - c)) / 2
            } else {
                let u = 2 * t - 2
                return (u * u * ((c + 1) * u + c) + 2) / 2
            }
        }
    }

    private static func bounceOutImpl(_ t: Float) -> Float {
        let n: Float = 7.5625
        let d: Float = 2.75

        if t < 1 / d {
            return n * t * t
        } else if t < 2 / d {
            let u = t - 1.5 / d
            return n * u * u + 0.75
        } else if t < 2.5 / d {
            let u = t - 2.25 / d
            return n * u * u + 0.9375
        } else {
            let u = t - 2.625 / d
            return n * u * u + 0.984375
        }
    }
}

/// Apply an easing function to a normalized time value.
///
/// Convenience wrapper matching the `lerp`/`clamp` pattern:
/// ```swift
/// let eased = ease(.cubicOut, t: progress)
/// let value = lerp(start, end, t: eased)
/// ```
public func ease(_ function: EasingFunction, t: Float) -> Float {
    function.apply(t)
}
