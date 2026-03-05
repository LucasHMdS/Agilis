import AgilisCore
import RaylibC

/// Raylib implementation of the InputBackend protocol.
public final class RaylibInputBackend: InputBackend {
    public init() {}

    public func isKeyDown(_ key: Key) -> Bool {
        IsKeyDown(Int32(key.rawValue))
    }

    public func isMouseButtonDown(_ button: AgilisCore.MouseButton) -> Bool {
        IsMouseButtonDown(Int32(button.rawValue))
    }

    public func mousePosition() -> AgilisCore.Vector2 {
        let pos = GetMousePosition()
        return AgilisCore.Vector2(x: pos.x, y: pos.y)
    }

    public func mouseDelta() -> AgilisCore.Vector2 {
        let delta = GetMouseDelta()
        return AgilisCore.Vector2(x: delta.x, y: delta.y)
    }

    public func mouseScrollDelta() -> Float {
        GetMouseWheelMove()
    }

    public func charPressed() -> Character? {
        let code = GetCharPressed()
        guard code > 0, let scalar = Unicode.Scalar(UInt32(code)) else { return nil }
        return Character(scalar)
    }

    // MARK: - Gamepad

    public func isGamepadAvailable(_ gamepad: Int) -> Bool {
        IsGamepadAvailable(Int32(gamepad))
    }

    public func isGamepadButtonDown(_ gamepad: Int, _ button: AgilisCore.GamepadButton) -> Bool {
        IsGamepadButtonDown(Int32(gamepad), Int32(button.rawValue))
    }

    public func gamepadAxisValue(_ gamepad: Int, _ axis: AgilisCore.GamepadAxis) -> Float {
        GetGamepadAxisMovement(Int32(gamepad), Int32(axis.rawValue))
    }

    public func gamepadName(_ gamepad: Int) -> String? {
        guard IsGamepadAvailable(Int32(gamepad)) else { return nil }
        guard let cString = GetGamepadName(Int32(gamepad)) else { return nil }
        return String(cString: cString)
    }
}
