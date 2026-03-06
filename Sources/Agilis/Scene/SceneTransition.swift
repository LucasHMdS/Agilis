

/// Describes how to animate between two scenes.
///
/// Use the static factory methods for common transition effects:
/// ```swift
/// app.sceneManager.replace(with: nextScene, transition: .fade(), app: app)
/// app.sceneManager.replace(with: nextScene, transition: .fade(duration: 1.0, color: .white), app: app)
/// ```
///
/// The transition has two phases of equal duration:
/// 1. **Fade out** — overlay alpha increases from 0 to 255 (screen covered)
/// 2. **Fade in** — overlay alpha decreases from 255 to 0 (new scene revealed)
///
/// The scene swap (`willExit`/`didEnter`) happens at the midpoint when the
/// screen is fully covered. The optional ``onMidpoint`` callback fires at
/// this point, allowing heavy loading work while the player can't see.
public struct SceneTransition: Sendable {
    /// Total duration of the transition in seconds (half fade-out + half fade-in).
    public let duration: Float

    /// The overlay color (default: black).
    public let color: Color

    /// Easing curve for the fade-out phase (0 → fully covered).
    public let fadeOutEasing: EasingFunction

    /// Easing curve for the fade-in phase (fully covered → 0).
    public let fadeInEasing: EasingFunction

    /// Optional callback invoked at the midpoint, when the screen is fully covered.
    /// Use this for asset loading or scene setup that should happen while the
    /// player cannot see the scene.
    public let onMidpoint: (@Sendable () -> Void)?

    /// Create a custom transition.
    public init(
        duration: Float = 0.5,
        color: Color = .black,
        fadeOutEasing: EasingFunction = .sineInOut,
        fadeInEasing: EasingFunction = .sineInOut,
        onMidpoint: (@Sendable () -> Void)? = nil
    ) {
        self.duration = duration
        self.color = color
        self.fadeOutEasing = fadeOutEasing
        self.fadeInEasing = fadeInEasing
        self.onMidpoint = onMidpoint
    }

    // MARK: - Factory Methods

    /// Fade to a color and back. The default scene transition.
    ///
    /// - Parameters:
    ///   - duration: Total transition time in seconds (default: 0.5).
    ///   - color: The overlay color to fade through (default: black).
    ///   - easing: Easing curve for both phases (default: sineInOut).
    ///   - onMidpoint: Optional callback at the midpoint.
    public static func fade(
        duration: Float = 0.5,
        color: Color = .black,
        easing: EasingFunction = .sineInOut,
        onMidpoint: (@Sendable () -> Void)? = nil
    ) -> SceneTransition {
        SceneTransition(
            duration: duration,
            color: color,
            fadeOutEasing: easing,
            fadeInEasing: easing,
            onMidpoint: onMidpoint
        )
    }

    /// Flash to white and back.
    ///
    /// - Parameters:
    ///   - duration: Total transition time in seconds (default: 0.4).
    ///   - easing: Easing curve for both phases (default: quadInOut).
    public static func flash(
        duration: Float = 0.4,
        easing: EasingFunction = .quadInOut
    ) -> SceneTransition {
        SceneTransition(
            duration: duration,
            color: .white,
            fadeOutEasing: easing,
            fadeInEasing: easing
        )
    }

    /// Instant transition with no animation. Equivalent to calling the
    /// non-transition `replace(with:app:)` method directly.
    public static let instant = SceneTransition(duration: 0)
}
