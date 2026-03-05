import AgilisCore

/// Defines what property a tween animates and the start/end values.
///
/// Each case targets a specific component property. The tween system
/// reads the current value at creation time (for convenience methods)
/// and writes the interpolated value each tick.
public enum TweenTarget: @unchecked Sendable {
    // Transform2D targets
    /// Animate `Transform2D.position` between two values.
    case position(from: Vector2, to: Vector2)
    /// Animate `Transform2D.rotation` between two values (radians).
    case rotation(from: Float, to: Float)
    /// Animate `Transform2D.scale` between two values.
    case scale(from: Vector2, to: Vector2)

    // Sprite targets
    /// Animate `Sprite.tint` color between two values.
    case spriteColor(from: Color, to: Color)
    /// Animate `Sprite.tint.a` (alpha only) between two values (0–255 as Float).
    case spriteAlpha(from: Float, to: Float)

    // Custom target
    /// User-provided closure that receives the world, entity, and eased `t` value.
    ///
    /// Use for animating custom component properties:
    /// ```swift
    /// tweens.custom(entity, duration: 1.0) { world, entity, t in
    ///     world.updateComponent(Health.self, on: entity) { h in
    ///         h.current = lerp(0, 100, t: t)
    ///     }
    /// }
    /// ```
    case custom(apply: @Sendable (World, Entity, Float) -> Void)
}

/// A step in a tween sequence. Steps play one after another.
///
/// Each step reads the current component value when it starts,
/// enabling relative chaining (e.g., move to A, then from A to B).
///
/// ## Usage
/// ```swift
/// tweens.sequence(entity, steps: [
///     .moveTo(target: Vector2(x: 300, y: 200), duration: 0.3, easing: .cubicOut),
///     .wait(duration: 0.1),
///     .fadeOut(duration: 0.2, easing: .quadIn),
///     .callback { print("Done!") }
/// ], in: world)
/// ```
public enum TweenStep: @unchecked Sendable {
    /// Move to a target position.
    case moveTo(target: Vector2, duration: Float, easing: EasingFunction = .linear)
    /// Rotate to a target angle (radians).
    case rotateTo(target: Float, duration: Float, easing: EasingFunction = .linear)
    /// Scale to a target scale.
    case scaleTo(target: Vector2, duration: Float, easing: EasingFunction = .linear)
    /// Tint to a target color.
    case tintTo(target: Color, duration: Float, easing: EasingFunction = .linear)
    /// Fade to a target alpha (0–255 as Float).
    case fadeTo(alpha: Float, duration: Float, easing: EasingFunction = .linear)
    /// Fade to fully transparent (alpha 0).
    case fadeOut(duration: Float, easing: EasingFunction = .linear)
    /// Fade to fully opaque (alpha 255).
    case fadeIn(duration: Float, easing: EasingFunction = .linear)
    /// Wait (do nothing) for a duration.
    case wait(duration: Float)
    /// Execute a callback immediately, then advance to the next step.
    case callback(@Sendable () -> Void)
    /// Custom animation step with user-provided apply closure.
    case custom(duration: Float, easing: EasingFunction = .linear,
                apply: @Sendable (World, Entity, Float) -> Void)
}
