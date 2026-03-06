import Testing
@testable import Agilis

/// A mock input backend with gamepad support for testing.
/// Extends the pattern from InputTests.swift's MockNativeInput.
final class MockGamepadBackend: @unchecked Sendable, InputBackend {
    // Keyboard / mouse (minimal, for mixed action tests)
    var keysDown: Set<Key> = []
    var mouseButtonsDown: Set<MouseButton> = []
    func isKeyDown(_ key: Key) -> Bool { keysDown.contains(key) }
    func isMouseButtonDown(_ button: MouseButton) -> Bool { mouseButtonsDown.contains(button) }
    func mousePosition() -> Vector2 { .zero }
    func mouseDelta() -> Vector2 { .zero }
    func mouseScrollDelta() -> Float { 0 }
    func charPressed() -> Character? { nil }

    // Gamepad state
    var gamepadsAvailable: Set<Int> = []
    var gamepadButtons: [Int: Set<GamepadButton>] = [:]
    var gamepadAxes: [Int: [GamepadAxis: Float]] = [:]
    var gamepadNames: [Int: String] = [:]

    func isGamepadAvailable(_ gamepad: Int) -> Bool {
        gamepadsAvailable.contains(gamepad)
    }

    func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool {
        gamepadButtons[gamepad]?.contains(button) ?? false
    }

    func gamepadAxisValue(_ gamepad: Int, _ axis: GamepadAxis) -> Float {
        gamepadAxes[gamepad]?[axis] ?? 0
    }

    func gamepadName(_ gamepad: Int) -> String? {
        guard gamepadsAvailable.contains(gamepad) else { return nil }
        return gamepadNames[gamepad]
    }
}

// MARK: - Gamepad Button Tests

@Suite("Gamepad Button Tests")
struct GamepadButtonTests {

    @Test("GamepadButton enum has correct raw values")
    func rawValues() {
        #expect(GamepadButton.unknown.rawValue == 0)
        #expect(GamepadButton.dpadUp.rawValue == 1)
        #expect(GamepadButton.dpadRight.rawValue == 2)
        #expect(GamepadButton.dpadDown.rawValue == 3)
        #expect(GamepadButton.dpadLeft.rawValue == 4)
        #expect(GamepadButton.faceUp.rawValue == 5)
        #expect(GamepadButton.faceRight.rawValue == 6)
        #expect(GamepadButton.faceDown.rawValue == 7)
        #expect(GamepadButton.faceLeft.rawValue == 8)
        #expect(GamepadButton.leftBumper.rawValue == 9)
        #expect(GamepadButton.leftTrigger.rawValue == 10)
        #expect(GamepadButton.rightBumper.rawValue == 11)
        #expect(GamepadButton.rightTrigger.rawValue == 12)
        #expect(GamepadButton.select.rawValue == 13)
        #expect(GamepadButton.home.rawValue == 14)
        #expect(GamepadButton.start.rawValue == 15)
        #expect(GamepadButton.leftStick.rawValue == 16)
        #expect(GamepadButton.rightStick.rawValue == 17)
    }

    @Test("GamepadButton CaseIterable has 18 cases")
    func caseCount() {
        #expect(GamepadButton.allCases.count == 18)
    }

    @Test("GamepadAxis enum has correct raw values")
    func axisRawValues() {
        #expect(GamepadAxis.leftX.rawValue == 0)
        #expect(GamepadAxis.leftY.rawValue == 1)
        #expect(GamepadAxis.rightX.rawValue == 2)
        #expect(GamepadAxis.rightY.rawValue == 3)
        #expect(GamepadAxis.leftTrigger.rawValue == 4)
        #expect(GamepadAxis.rightTrigger.rawValue == 5)
    }

    @Test("GamepadAxis CaseIterable has 6 cases")
    func axisCaseCount() {
        #expect(GamepadAxis.allCases.count == 6)
    }
}

// MARK: - Gamepad Connection Tests

@Suite("Gamepad Connection Tests")
struct GamepadConnectionTests {

    @Test("No gamepads connected by default")
    func noGamepads() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        #expect(!input.isGamepadConnected(0))
        #expect(!input.isGamepadConnected(1))
        #expect(!input.isGamepadConnected(2))
        #expect(!input.isGamepadConnected(3))
    }

    @Test("Gamepad connected detection")
    func gamepadConnected() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0, 2]

        #expect(input.isGamepadConnected(0))
        #expect(!input.isGamepadConnected(1))
        #expect(input.isGamepadConnected(2))
        #expect(!input.isGamepadConnected(3))
    }

    @Test("Out of range gamepad index returns false")
    func outOfRange() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        #expect(!input.isGamepadConnected(-1))
        #expect(!input.isGamepadConnected(4))
        #expect(!input.isGamepadConnected(100))
    }

    @Test("Gamepad name when connected")
    func gamepadName() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadNames[0] = "Xbox Wireless Controller"

        #expect(input.gamepadName(0) == "Xbox Wireless Controller")
        #expect(input.gamepadName(1) == nil) // Not connected
    }

    @Test("Gamepad name out of range returns nil")
    func gamepadNameOutOfRange() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        #expect(input.gamepadName(-1) == nil)
        #expect(input.gamepadName(5) == nil)
    }
}

// MARK: - Gamepad Button State Tests

@Suite("Gamepad Button State Tests")
struct GamepadButtonStateTests {

    @Test("Button down")
    func buttonDown() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadButtons[0] = [.faceDown, .dpadUp]
        input.update()

        #expect(input.isGamepadButtonDown(0, .faceDown))
        #expect(input.isGamepadButtonDown(0, .dpadUp))
        #expect(!input.isGamepadButtonDown(0, .faceRight))
    }

    @Test("Button pressed (transition)")
    func buttonPressed() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]

        // Frame 1: no buttons
        input.update()
        #expect(!input.isGamepadButtonPressed(0, .faceDown))
        input.consumeTransitions()

        // Frame 2: press A
        backend.gamepadButtons[0] = [.faceDown]
        input.update()
        #expect(input.isGamepadButtonPressed(0, .faceDown))
        input.consumeTransitions()

        // Frame 3: still held — not "just pressed"
        input.update()
        #expect(!input.isGamepadButtonPressed(0, .faceDown))
        #expect(input.isGamepadButtonDown(0, .faceDown))
    }

    @Test("Button released (transition)")
    func buttonReleased() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]

        // Frame 1: press
        backend.gamepadButtons[0] = [.start]
        input.update()
        input.consumeTransitions()

        // Frame 2: release
        backend.gamepadButtons[0] = []
        input.update()
        #expect(input.isGamepadButtonReleased(0, .start))
        #expect(!input.isGamepadButtonDown(0, .start))
        input.consumeTransitions()

        // Frame 3: no longer "just released"
        input.update()
        #expect(!input.isGamepadButtonReleased(0, .start))
    }

    @Test("Multiple buttons simultaneously")
    func multipleButtons() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadButtons[0] = [.faceDown, .faceRight, .leftBumper]
        input.update()

        #expect(input.isGamepadButtonDown(0, .faceDown))
        #expect(input.isGamepadButtonDown(0, .faceRight))
        #expect(input.isGamepadButtonDown(0, .leftBumper))
        #expect(!input.isGamepadButtonDown(0, .faceUp))
    }

    @Test("Multiple gamepads have independent state")
    func multipleGamepads() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0, 1]
        backend.gamepadButtons[0] = [.faceDown]
        backend.gamepadButtons[1] = [.faceUp]
        input.update()

        #expect(input.isGamepadButtonDown(0, .faceDown))
        #expect(!input.isGamepadButtonDown(0, .faceUp))
        #expect(!input.isGamepadButtonDown(1, .faceDown))
        #expect(input.isGamepadButtonDown(1, .faceUp))
    }

    @Test("Disconnected gamepad returns no button state")
    func disconnectedGamepad() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        // Gamepad not in gamepadsAvailable, but has button data
        backend.gamepadButtons[0] = [.faceDown]
        input.update()

        #expect(!input.isGamepadButtonDown(0, .faceDown))
    }

    @Test("Button queries for out of range gamepad return false")
    func buttonOutOfRange() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        input.update()
        #expect(!input.isGamepadButtonDown(-1, .faceDown))
        #expect(!input.isGamepadButtonDown(4, .faceDown))
        #expect(!input.isGamepadButtonPressed(-1, .faceDown))
        #expect(!input.isGamepadButtonReleased(5, .start))
    }
}

// MARK: - Gamepad Axis Tests

@Suite("Gamepad Axis Tests")
struct GamepadAxisTests {

    @Test("Axis reading with dead zone applied")
    func axisWithDeadZone() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [
            .leftX: 0.05,   // Below dead zone (0.1)
            .leftY: -0.8,   // Above dead zone
            .rightX: 0.15,  // Above dead zone
        ]

        #expect(input.gamepadAxis(0, .leftX) == 0)       // Filtered by dead zone
        #expect(input.gamepadAxis(0, .leftY) == -0.8)     // Passed through
        #expect(abs(input.gamepadAxis(0, .rightX) - 0.15) < 0.001) // Passed through
    }

    @Test("Axis at exact dead zone boundary is zero")
    func axisAtDeadZone() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [.leftX: 0.1] // Exactly at dead zone

        // abs(0.1) < 0.1 is false, so it should NOT be filtered
        // Actually abs(0.1) is not < 0.1, it's equal, so the condition `abs(raw) < deadZone` is false
        #expect(abs(input.gamepadAxis(0, .leftX) - 0.1) < 0.001)
    }

    @Test("Custom dead zone")
    func customDeadZone() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [.leftX: 0.15]

        // Default dead zone (0.1): passes through
        #expect(abs(input.gamepadAxis(0, .leftX) - 0.15) < 0.001)

        // Raise dead zone to 0.2: filtered
        input.gamepadDeadZone = 0.2
        #expect(input.gamepadAxis(0, .leftX) == 0)
    }

    @Test("Zero dead zone passes all values")
    func zeroDeadZone() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        input.gamepadDeadZone = 0
        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [.leftX: 0.001]

        #expect(abs(input.gamepadAxis(0, .leftX) - 0.001) < 0.0001)
    }

    @Test("Negative axis values respect dead zone")
    func negativeAxisDeadZone() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [
            .leftX: -0.05,  // Below dead zone (abs)
            .leftY: -0.5,   // Above dead zone
        ]

        #expect(input.gamepadAxis(0, .leftX) == 0)
        #expect(input.gamepadAxis(0, .leftY) == -0.5)
    }

    @Test("Axis for disconnected gamepad returns 0")
    func axisDisconnected() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadAxes[0] = [.leftX: 0.9]
        // Gamepad not available
        #expect(input.gamepadAxis(0, .leftX) == 0)
    }

    @Test("Axis for out of range gamepad returns 0")
    func axisOutOfRange() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        #expect(input.gamepadAxis(-1, .leftX) == 0)
        #expect(input.gamepadAxis(4, .leftY) == 0)
    }
}

// MARK: - Gamepad Stick Tests

@Suite("Gamepad Stick Tests")
struct GamepadStickTests {

    @Test("Left stick returns Vector2")
    func leftStick() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [.leftX: 0.7, .leftY: -0.3]

        let stick = input.gamepadStick(0, .left)
        #expect(abs(stick.x - 0.7) < 0.001)
        #expect(abs(stick.y - (-0.3)) < 0.001)
    }

    @Test("Right stick returns Vector2")
    func rightStick() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [.rightX: -0.5, .rightY: 1.0]

        let stick = input.gamepadStick(0, .right)
        #expect(abs(stick.x - (-0.5)) < 0.001)
        #expect(abs(stick.y - 1.0) < 0.001)
    }

    @Test("Stick applies dead zone per-axis")
    func stickDeadZone() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        backend.gamepadsAvailable = [0]
        backend.gamepadAxes[0] = [.leftX: 0.05, .leftY: 0.5]

        let stick = input.gamepadStick(0, .left)
        #expect(stick.x == 0)             // Below dead zone
        #expect(abs(stick.y - 0.5) < 0.001) // Above dead zone
    }

    @Test("Stick for disconnected gamepad returns zero")
    func stickDisconnected() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)

        let stick = input.gamepadStick(0, .left)
        #expect(stick == .zero)
    }
}

// MARK: - Gamepad Action Mapping Tests

@Suite("Gamepad Action Mapping Tests")
struct GamepadActionMappingTests {

    @Test("Action with gamepad button binding")
    func gamepadAction() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("jump", gamepadButtons: [.faceDown])

        backend.gamepadsAvailable = [0]

        input.update()
        #expect(!input.isActionActive("jump"))
        input.consumeTransitions()

        backend.gamepadButtons[0] = [.faceDown]
        input.update()
        #expect(input.isActionActive("jump"))
        #expect(input.isActionJustActivated("jump"))
        input.consumeTransitions()

        input.update()
        #expect(input.isActionActive("jump"))
        #expect(!input.isActionJustActivated("jump"))
    }

    @Test("Action deactivated via gamepad")
    func gamepadActionDeactivated() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("jump", gamepadButtons: [.faceDown])

        backend.gamepadsAvailable = [0]

        // Press
        backend.gamepadButtons[0] = [.faceDown]
        input.update()
        input.consumeTransitions()

        // Release
        backend.gamepadButtons[0] = []
        input.update()
        #expect(input.isActionJustDeactivated("jump"))
        #expect(!input.isActionActive("jump"))
        input.consumeTransitions()

        // Next frame
        input.update()
        #expect(!input.isActionJustDeactivated("jump"))
    }

    @Test("Mixed action: key + mouse + gamepad")
    func mixedAction() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("fire", keys: [.space], mouseButtons: [.left], gamepadButtons: [.rightTrigger])

        backend.gamepadsAvailable = [0]

        input.update()
        #expect(!input.isActionActive("fire"))

        // Activate via gamepad
        backend.gamepadButtons[0] = [.rightTrigger]
        input.update()
        #expect(input.isActionActive("fire"))

        // Release gamepad, activate via key
        backend.gamepadButtons[0] = []
        backend.keysDown = [.space]
        input.update()
        #expect(input.isActionActive("fire"))

        // Release key, activate via mouse
        backend.keysDown = []
        backend.mouseButtonsDown = [.left]
        input.update()
        #expect(input.isActionActive("fire"))
    }

    @Test("Action uses gamepad 0 for queries")
    func actionUsesGamepadZero() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("jump", gamepadButtons: [.faceDown])

        backend.gamepadsAvailable = [0, 1]

        // Only gamepad 1 has the button pressed
        backend.gamepadButtons[1] = [.faceDown]
        input.update()

        // Action mapping only checks gamepad 0
        #expect(!input.isActionActive("jump"))

        // Now gamepad 0 presses it
        backend.gamepadButtons[0] = [.faceDown]
        input.update()
        #expect(input.isActionActive("jump"))
    }

    @Test("registerAction with no gamepad buttons (backward compat)")
    func noGamepadButtons() {
        let backend = MockGamepadBackend()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("jump", keys: [.space])

        backend.keysDown = [.space]
        input.update()
        #expect(input.isActionActive("jump"))
    }
}

// MARK: - Default NativeInput Implementation Tests

@Suite("NativeInput Default Gamepad Tests")
struct NativeInputDefaultTests {

    /// A minimal backend that only implements the original methods (no gamepad overrides).
    /// Tests that the default implementations return "no gamepad" state.
    final class MinimalBackend: @unchecked Sendable, InputBackend {
        func isKeyDown(_ key: Key) -> Bool { false }
        func isMouseButtonDown(_ button: MouseButton) -> Bool { false }
        func mousePosition() -> Vector2 { .zero }
        func mouseDelta() -> Vector2 { .zero }
        func mouseScrollDelta() -> Float { 0 }
        func charPressed() -> Character? { nil }
        // NOTE: No gamepad methods — uses protocol defaults
    }

    @Test("Default isGamepadAvailable returns false")
    func defaultAvailable() {
        let backend = MinimalBackend()
        #expect(!backend.isGamepadAvailable(0))
        #expect(!backend.isGamepadAvailable(1))
    }

    @Test("Default isGamepadButtonDown returns false")
    func defaultButtonDown() {
        let backend = MinimalBackend()
        #expect(!backend.isGamepadButtonDown(0, .faceDown))
    }

    @Test("Default gamepadAxisValue returns 0")
    func defaultAxisValue() {
        let backend = MinimalBackend()
        #expect(backend.gamepadAxisValue(0, .leftX) == 0)
    }

    @Test("Default gamepadName returns nil")
    func defaultName() {
        let backend = MinimalBackend()
        #expect(backend.gamepadName(0) == nil)
    }

    @Test("InputManager with minimal backend has no gamepad input")
    func minimalBackendInputManager() {
        let backend = MinimalBackend()
        let input = InputManager()
        input.bind(backend)

        input.update()
        #expect(!input.isGamepadConnected(0))
        #expect(!input.isGamepadButtonDown(0, .faceDown))
        #expect(input.gamepadAxis(0, .leftX) == 0)
        #expect(input.gamepadStick(0, .left) == .zero)
    }
}
