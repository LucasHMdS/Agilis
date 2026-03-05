/// Gamepad buttons. Raw values match raylib's GamepadButton enum.
///
/// Uses platform-neutral naming. Doc comments note common controller equivalents.
public enum GamepadButton: Int, Sendable, Hashable, CaseIterable {
    case unknown = 0

    // D-Pad
    /// D-Pad up.
    case dpadUp = 1
    /// D-Pad right.
    case dpadRight = 2
    /// D-Pad down.
    case dpadDown = 3
    /// D-Pad left.
    case dpadLeft = 4

    // Face buttons
    /// Top face button (Xbox: Y, PlayStation: Triangle, Nintendo: X).
    case faceUp = 5
    /// Right face button (Xbox: B, PlayStation: Circle, Nintendo: A).
    case faceRight = 6
    /// Bottom face button (Xbox: A, PlayStation: Cross, Nintendo: B).
    case faceDown = 7
    /// Left face button (Xbox: X, PlayStation: Square, Nintendo: Y).
    case faceLeft = 8

    // Bumpers & triggers (digital press)
    /// Left bumper (L1 / LB).
    case leftBumper = 9
    /// Left trigger digital press (L2 / LT). For analog value, use `GamepadAxis.leftTrigger`.
    case leftTrigger = 10
    /// Right bumper (R1 / RB).
    case rightBumper = 11
    /// Right trigger digital press (R2 / RT). For analog value, use `GamepadAxis.rightTrigger`.
    case rightTrigger = 12

    // Center buttons
    /// Select / Back / Share button.
    case select = 13
    /// Home / Guide / PS button.
    case home = 14
    /// Start / Menu / Options button.
    case start = 15

    // Stick clicks
    /// Left stick click (L3).
    case leftStick = 16
    /// Right stick click (R3).
    case rightStick = 17
}

/// Gamepad analog axes. Raw values match raylib's GamepadAxis enum.
///
/// Stick axes return values in the range -1.0 to 1.0.
/// Trigger axes return values in the range -1.0 to 1.0 (unpressed = -1, fully pressed = 1
/// on most controllers, but this varies — apply dead zone and normalize as needed).
public enum GamepadAxis: Int, Sendable, Hashable, CaseIterable {
    /// Left stick horizontal axis (-1.0 = left, 1.0 = right).
    case leftX = 0
    /// Left stick vertical axis (-1.0 = up, 1.0 = down).
    case leftY = 1
    /// Right stick horizontal axis (-1.0 = left, 1.0 = right).
    case rightX = 2
    /// Right stick vertical axis (-1.0 = up, 1.0 = down).
    case rightY = 3
    /// Left trigger analog value.
    case leftTrigger = 4
    /// Right trigger analog value.
    case rightTrigger = 5
}

/// Convenience enum for querying a stick's X/Y axes as a Vector2.
public enum GamepadStick: Sendable {
    /// Left analog stick.
    case left
    /// Right analog stick.
    case right
}
