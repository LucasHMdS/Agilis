/// Backend-provided raw input state. The InputManager reads from this each frame.
public protocol InputBackend: AnyObject, Sendable {
    func isKeyDown(_ key: Key) -> Bool
    func isMouseButtonDown(_ button: MouseButton) -> Bool
    func mousePosition() -> Vector2
    func mouseDelta() -> Vector2
    func mouseScrollDelta() -> Float

    /// Returns the next Unicode character typed this frame, or nil if none.
    func charPressed() -> Character?

    // MARK: - Gamepad

    /// Whether a gamepad at the given index (0–3) is connected.
    func isGamepadAvailable(_ gamepad: Int) -> Bool

    /// Whether a gamepad button is currently held down.
    func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool

    /// Raw axis value for a gamepad axis (typically -1.0 to 1.0).
    func gamepadAxisValue(_ gamepad: Int, _ axis: GamepadAxis) -> Float

    /// Human-readable name of the connected gamepad, or nil if not connected.
    func gamepadName(_ gamepad: Int) -> String?
}

// MARK: - Default Gamepad Implementations

// Defaults return "no gamepad" so existing backends compile without changes.
extension InputBackend {
    public func isGamepadAvailable(_ gamepad: Int) -> Bool { false }
    public func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool { false }
    public func gamepadAxisValue(_ gamepad: Int, _ axis: GamepadAxis) -> Float { 0 }
    public func gamepadName(_ gamepad: Int) -> String? { nil }
}
