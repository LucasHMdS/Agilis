import PlatformC

/// Thin Swift wrapper over the PlatformC input functions.
///
/// Provides the same interface that InputManager expects for polling
/// keyboard, mouse, and gamepad state each frame.
final class NativeInput: @unchecked Sendable {
    private let window: OpaquePointer  // PlatformWindow*

    init(window: OpaquePointer) {
        self.window = window
    }

    // MARK: - Keyboard

    func isKeyDown(_ key: Key) -> Bool {
        platform_is_key_down(window, Int32(key.rawValue))
    }

    func keyPressed(_ key: Key) -> Bool {
        platform_key_pressed(window, Int32(key.rawValue))
    }

    func charPressed() -> Character? {
        let codepoint = platform_char_pressed(window)
        guard codepoint != 0, let scalar = Unicode.Scalar(codepoint) else { return nil }
        return Character(scalar)
    }

    // MARK: - Mouse

    func isMouseButtonDown(_ button: MouseButton) -> Bool {
        platform_is_mouse_button_down(window, Int32(button.rawValue))
    }

    func mouseButtonPressed(_ button: MouseButton) -> Bool {
        platform_mouse_button_pressed(window, Int32(button.rawValue))
    }

    func mousePosition() -> Vector2 {
        Vector2(x: platform_mouse_x(window), y: platform_mouse_y(window))
    }

    func mouseDelta() -> Vector2 {
        Vector2(x: platform_mouse_dx(window), y: platform_mouse_dy(window))
    }

    func mouseScrollDelta() -> Float {
        platform_mouse_scroll(window)
    }

    // MARK: - Gamepad

    func isGamepadAvailable(_ gamepad: Int) -> Bool {
        platform_is_gamepad_available(Int32(gamepad))
    }

    func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool {
        platform_is_gamepad_button_down(Int32(gamepad), Int32(button.rawValue))
    }

    func gamepadAxisValue(_ gamepad: Int, _ axis: GamepadAxis) -> Float {
        platform_gamepad_axis(Int32(gamepad), Int32(axis.rawValue))
    }

    func gamepadName(_ gamepad: Int) -> String? {
        guard let name = platform_gamepad_name(Int32(gamepad)) else { return nil }
        return String(cString: name)
    }
}
