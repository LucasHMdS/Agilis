

/// Maximum number of gamepads supported.
private let maxGamepads = 4

/// Manages input state with press/release detection and action mapping.
///
/// Supports keyboard, mouse, and gamepad input. Call `update()` once per
/// frame before processing game logic. The manager tracks current and
/// previous frame state to detect press/release transitions.
///
/// Press/release transitions are accumulated across render frames and
/// persist until consumed by `consumeTransitions()`, which should be
/// called at the end of each fixed-timestep tick. This ensures quick
/// presses are never lost even when frames run faster than the tick rate.
///
/// ## Action Mapping
/// Register named actions bound to keys, mouse buttons, and/or gamepad buttons:
/// ```swift
/// app.input.registerAction("jump", keys: [.space], gamepadButtons: [.faceDown])
/// if app.input.isActionJustActivated("jump") { ... }
/// ```
public final class InputManager: @unchecked Sendable {
    private var backend: (any InputBackend)?

    // Current "held" state (updated per frame via polling)
    private var keyDownState: Set<Key> = []
    private var mouseDownState: Set<MouseButton> = []
    private var gamepadDownState: [Set<GamepadButton>] = Array(repeating: [], count: maxGamepads)

    // Accumulated transitions (persist across frames until consumed by a tick)
    private var pendingKeyPresses: Set<Key> = []
    private var pendingKeyReleases: Set<Key> = []
    private var pendingMousePresses: Set<MouseButton> = []
    private var pendingMouseReleases: Set<MouseButton> = []
    private var pendingGamepadPresses: [Set<GamepadButton>] = Array(repeating: [], count: maxGamepads)
    private var pendingGamepadReleases: [Set<GamepadButton>] = Array(repeating: [], count: maxGamepads)

    // Action mapping
    private var actions: [String: InputAction] = [:]

    /// Dead zone threshold for analog stick axes. Values with absolute magnitude
    /// below this threshold are reported as 0. Default: 0.1.
    public var gamepadDeadZone: Float = 0.1

    public init() {}

    /// Bind an input backend. Called by Application after the window is created.
    internal func bind(_ backend: any InputBackend) {
        self.backend = backend
    }

    /// The character typed this frame (for text input), or nil if none.
    public private(set) var charPressed: Character?

    /// Call once per frame before processing game logic.
    /// Polls platform state and accumulates press/release transitions.
    public func update() {
        guard let backend else { return }

        // --- Keyboard ---
        let oldKeyDown = keyDownState
        keyDownState = []
        for key in Key.allCases {
            if backend.isKeyDown(key) {
                keyDownState.insert(key)
            }
        }

        // Detect transitions from polled state changes
        for key in keyDownState where !oldKeyDown.contains(key) {
            pendingKeyPresses.insert(key)
        }
        for key in oldKeyDown where !keyDownState.contains(key) {
            pendingKeyReleases.insert(key)
        }

        // Also check platform-level pressed flags for DOWN+UP in same poll
        for key in Key.allCases {
            if backend.keyPressed(key) && !keyDownState.contains(key) {
                // Key was pressed and released within this single poll
                pendingKeyPresses.insert(key)
                pendingKeyReleases.insert(key)
            }
        }

        // --- Mouse ---
        let oldMouseDown = mouseDownState
        mouseDownState = []
        for button in MouseButton.allCases {
            if backend.isMouseButtonDown(button) {
                mouseDownState.insert(button)
            }
        }

        for button in mouseDownState where !oldMouseDown.contains(button) {
            pendingMousePresses.insert(button)
        }
        for button in oldMouseDown where !mouseDownState.contains(button) {
            pendingMouseReleases.insert(button)
        }

        for button in MouseButton.allCases {
            if backend.mouseButtonPressed(button) && !mouseDownState.contains(button) {
                pendingMousePresses.insert(button)
                pendingMouseReleases.insert(button)
            }
        }

        // --- Gamepads ---
        for gamepad in 0..<maxGamepads {
            let oldDown = gamepadDownState[gamepad]
            gamepadDownState[gamepad] = []
            guard backend.isGamepadAvailable(gamepad) else { continue }
            for button in GamepadButton.allCases {
                if backend.isGamepadButtonDown(gamepad, button) {
                    gamepadDownState[gamepad].insert(button)
                }
            }

            for button in gamepadDownState[gamepad] where !oldDown.contains(button) {
                pendingGamepadPresses[gamepad].insert(button)
            }
            for button in oldDown where !gamepadDownState[gamepad].contains(button) {
                pendingGamepadReleases[gamepad].insert(button)
            }
        }

        charPressed = backend.charPressed()
    }

    /// Clear accumulated press/release transitions after a fixed-timestep tick.
    /// Called by Application at the end of each tick so transitions don't fire
    /// on subsequent ticks.
    internal func consumeTransitions() {
        pendingKeyPresses.removeAll(keepingCapacity: true)
        pendingKeyReleases.removeAll(keepingCapacity: true)
        pendingMousePresses.removeAll(keepingCapacity: true)
        pendingMouseReleases.removeAll(keepingCapacity: true)
        for i in 0..<maxGamepads {
            pendingGamepadPresses[i].removeAll(keepingCapacity: true)
            pendingGamepadReleases[i].removeAll(keepingCapacity: true)
        }
    }

    // MARK: - Keyboard

    /// True while the key is held down.
    public func isKeyDown(_ key: Key) -> Bool {
        keyDownState.contains(key)
    }

    /// True only on the frame the key was first pressed.
    public func isKeyPressed(_ key: Key) -> Bool {
        pendingKeyPresses.contains(key)
    }

    /// True only on the frame the key was released.
    public func isKeyReleased(_ key: Key) -> Bool {
        pendingKeyReleases.contains(key)
    }

    // MARK: - Mouse

    /// True while the mouse button is held down.
    public func isMouseButtonDown(_ button: MouseButton) -> Bool {
        mouseDownState.contains(button)
    }

    /// True only on the frame the button was first pressed.
    public func isMouseButtonPressed(_ button: MouseButton) -> Bool {
        pendingMousePresses.contains(button)
    }

    /// True only on the frame the button was released.
    public func isMouseButtonReleased(_ button: MouseButton) -> Bool {
        pendingMouseReleases.contains(button)
    }

    /// Current mouse position in screen coordinates.
    public var mousePosition: Vector2 {
        backend?.mousePosition() ?? .zero
    }

    /// Mouse movement since last frame.
    public var mouseDelta: Vector2 {
        backend?.mouseDelta() ?? .zero
    }

    /// Mouse scroll wheel delta.
    public var mouseScrollDelta: Float {
        backend?.mouseScrollDelta() ?? 0
    }

    // MARK: - Gamepad

    /// Whether a gamepad is connected at the given index (0–3).
    public func isGamepadConnected(_ gamepad: Int) -> Bool {
        guard gamepad >= 0 && gamepad < maxGamepads else { return false }
        return backend?.isGamepadAvailable(gamepad) ?? false
    }

    /// Human-readable name of the connected gamepad, or nil if not connected.
    public func gamepadName(_ gamepad: Int) -> String? {
        guard gamepad >= 0 && gamepad < maxGamepads else { return nil }
        return backend?.gamepadName(gamepad)
    }

    /// True while the gamepad button is held down.
    public func isGamepadButtonDown(_ gamepad: Int, _ button: GamepadButton) -> Bool {
        guard gamepad >= 0 && gamepad < maxGamepads else { return false }
        return gamepadDownState[gamepad].contains(button)
    }

    /// True only on the frame the gamepad button was first pressed.
    public func isGamepadButtonPressed(_ gamepad: Int, _ button: GamepadButton) -> Bool {
        guard gamepad >= 0 && gamepad < maxGamepads else { return false }
        return pendingGamepadPresses[gamepad].contains(button)
    }

    /// True only on the frame the gamepad button was released.
    public func isGamepadButtonReleased(_ gamepad: Int, _ button: GamepadButton) -> Bool {
        guard gamepad >= 0 && gamepad < maxGamepads else { return false }
        return pendingGamepadReleases[gamepad].contains(button)
    }

    /// Returns the axis value for a gamepad, with dead zone applied.
    ///
    /// Values with absolute magnitude below `gamepadDeadZone` are returned as 0.
    /// Returns 0 if the gamepad is not connected.
    /// Stick axes range from -1.0 to 1.0. Trigger ranges vary by controller.
    public func gamepadAxis(_ gamepad: Int, _ axis: GamepadAxis) -> Float {
        guard let backend, gamepad >= 0 && gamepad < maxGamepads else { return 0 }
        guard backend.isGamepadAvailable(gamepad) else { return 0 }
        let raw = backend.gamepadAxisValue(gamepad, axis)
        return abs(raw) < gamepadDeadZone ? 0 : raw
    }

    /// Returns the stick position as a Vector2, with dead zone applied per-axis.
    ///
    /// - Parameters:
    ///   - gamepad: Gamepad index (0–3).
    ///   - stick: Which stick to read (.left or .right).
    /// - Returns: Stick position with X (-1 = left, 1 = right) and Y (-1 = up, 1 = down).
    public func gamepadStick(_ gamepad: Int, _ stick: GamepadStick) -> Vector2 {
        let xAxis: GamepadAxis
        let yAxis: GamepadAxis
        switch stick {
        case .left:
            xAxis = .leftX
            yAxis = .leftY
        case .right:
            xAxis = .rightX
            yAxis = .rightY
        }
        return Vector2(x: gamepadAxis(gamepad, xAxis), y: gamepadAxis(gamepad, yAxis))
    }

    // MARK: - Action Mapping

    /// Register a named action bound to keys, mouse buttons, and/or gamepad buttons.
    ///
    /// An action is considered active when **any** of its bound inputs are active (OR logic).
    /// Gamepad buttons are checked on gamepad 0 (player 1) for action queries.
    public func registerAction(
        _ name: String,
        keys: [Key] = [],
        mouseButtons: [MouseButton] = [],
        gamepadButtons: [GamepadButton] = []
    ) {
        actions[name] = InputAction(keys: keys, mouseButtons: mouseButtons, gamepadButtons: gamepadButtons)
    }

    /// True while any binding for this action is active.
    public func isActionActive(_ name: String) -> Bool {
        guard let action = actions[name] else { return false }
        return action.keys.contains(where: { isKeyDown($0) })
            || action.mouseButtons.contains(where: { isMouseButtonDown($0) })
            || action.gamepadButtons.contains(where: { isGamepadButtonDown(0, $0) })
    }

    /// True only on the frame the action was first activated.
    public func isActionJustActivated(_ name: String) -> Bool {
        guard let action = actions[name] else { return false }
        return action.keys.contains(where: { isKeyPressed($0) })
            || action.mouseButtons.contains(where: { isMouseButtonPressed($0) })
            || action.gamepadButtons.contains(where: { isGamepadButtonPressed(0, $0) })
    }

    /// True only on the frame the action was deactivated.
    public func isActionJustDeactivated(_ name: String) -> Bool {
        guard let action = actions[name] else { return false }
        let anyCurrentlyActive = action.keys.contains(where: { isKeyDown($0) })
            || action.mouseButtons.contains(where: { isMouseButtonDown($0) })
            || action.gamepadButtons.contains(where: { isGamepadButtonDown(0, $0) })
        let anyWasReleased = action.keys.contains(where: { isKeyReleased($0) })
            || action.mouseButtons.contains(where: { isMouseButtonReleased($0) })
            || action.gamepadButtons.contains(where: { isGamepadButtonReleased(0, $0) })
        return !anyCurrentlyActive && anyWasReleased
    }
}

struct InputAction {
    let keys: [Key]
    let mouseButtons: [MouseButton]
    let gamepadButtons: [GamepadButton]
}
