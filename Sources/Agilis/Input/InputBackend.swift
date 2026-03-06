/// Protocol for input backends.
///
/// Abstracts platform input polling so that test mocks can stand in for
/// the concrete ``NativeInput`` without requiring a platform window.
protocol InputBackend: AnyObject, Sendable {

    // Keyboard
    func isKeyDown(_ key: Key) -> Bool
    func keyPressed(_ key: Key) -> Bool
    func charPressed() -> Character?

    // Mouse
    func isMouseButtonDown(_ button: MouseButton) -> Bool
    func mouseButtonPressed(_ button: MouseButton) -> Bool
    func mousePosition() -> Vector2
    func mouseDelta() -> Vector2
    func mouseScrollDelta() -> Float

    // Gamepad
    func isGamepadAvailable(_ gamepad: Int) -> Bool
    func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool
    func gamepadAxisValue(_ gamepad: Int, _ axis: GamepadAxis) -> Float
    func gamepadName(_ gamepad: Int) -> String?
}

// MARK: - Default Implementations

extension InputBackend {
    func keyPressed(_ key: Key) -> Bool { false }
    func mouseButtonPressed(_ button: MouseButton) -> Bool { false }
    func isGamepadAvailable(_ gamepad: Int) -> Bool { false }
    func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool { false }
    func gamepadAxisValue(_ gamepad: Int, _ axis: GamepadAxis) -> Float { 0 }
    func gamepadName(_ gamepad: Int) -> String? { nil }
}

// MARK: - NativeInput Conformance

extension NativeInput: InputBackend {}
