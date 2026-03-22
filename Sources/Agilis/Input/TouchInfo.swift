/// Phase of a touch event.
public enum TouchPhase: Int, Sendable {
    case began = 0
    case moved = 1
    case ended = 2
    case cancelled = 3
}

/// Information about a single touch point.
public struct TouchInfo: Sendable {
    /// Unique identifier for this touch (stable across began→moved→ended).
    public let id: Int
    /// Position in screen coordinates (origin top-left).
    public let position: Vector2
    /// Current phase of the touch.
    public let phase: TouchPhase
}
