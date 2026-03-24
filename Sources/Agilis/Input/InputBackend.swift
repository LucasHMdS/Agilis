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

    // Cursor & Mouse Capture
    func setCursorVisible(_ visible: Bool)
    func isCursorVisible() -> Bool
    func setMouseCaptured(_ captured: Bool)
    func isMouseCaptured() -> Bool

    // Touch
    func touchCount() -> Int
    func touch(at index: Int) -> TouchInfo?

    // Gamepad
    func isGamepadAvailable(_ gamepad: Int) -> Bool
    func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool
    func gamepadButtonPressed(_ gamepad: Int, _ button: GamepadButton) -> Bool
    func gamepadAxisValue(_ gamepad: Int, _ axis: GamepadAxis) -> Float
    func gamepadName(_ gamepad: Int) -> String?
    func setGamepadVibration(_ gamepad: Int, leftMotor: Float, rightMotor: Float)
}

// MARK: - Default Implementations

extension InputBackend {
    func touchCount() -> Int { 0 }
    func touch(at _: Int) -> TouchInfo? { nil }
    func keyPressed(_: Key) -> Bool { false }
    func mouseButtonPressed(_: MouseButton) -> Bool { false }
    func setCursorVisible(_: Bool) {}
    func isCursorVisible() -> Bool { true }
    func setMouseCaptured(_: Bool) {}
    func isMouseCaptured() -> Bool { false }
    func isGamepadAvailable(_: Int) -> Bool { false }
    func isGamepadButtonDown(_: Int, _: GamepadButton) -> Bool { false }
    func gamepadButtonPressed(_: Int, _: GamepadButton) -> Bool { false }
    func gamepadAxisValue(_: Int, _: GamepadAxis) -> Float { 0 }
    func gamepadName(_: Int) -> String? { nil }
    func setGamepadVibration(_: Int, leftMotor _: Float, rightMotor _: Float) {}
}

// MARK: - NativeInput Conformance

extension NativeInput: InputBackend {}
