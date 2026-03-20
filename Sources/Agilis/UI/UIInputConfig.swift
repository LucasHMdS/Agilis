/// Configurable input bindings for UI navigation.
///
/// Supports optional keyboard and/or gamepad configurations. Mouse input
/// is always active and not configurable through this struct.
///
/// ## Usage
/// ```swift
/// // Keyboard only (default)
/// let ui = UIContext(font: font)
///
/// // Keyboard + gamepad
/// let ui = UIContext(font: font)
/// ui.inputConfig = .keyboardAndGamepad
///
/// // Custom gamepad bindings
/// var config = UIInputConfig.keyboardAndGamepad
/// config.gamepad?.confirm = [.faceDown, .start]
/// ui.inputConfig = config
/// ```
public struct UIInputConfig: Sendable {

    /// Keyboard bindings. Set to `nil` to disable keyboard UI navigation.
    public var keyboard: KeyboardConfig?

    /// Gamepad bindings. Set to `nil` to disable gamepad UI navigation.
    public var gamepad: GamepadConfig?

    public init(keyboard: KeyboardConfig? = .default, gamepad: GamepadConfig? = nil) {
        self.keyboard = keyboard
        self.gamepad = gamepad
    }

    /// Default: keyboard enabled with standard keys, gamepad disabled.
    public static let `default` = UIInputConfig()

    /// Keyboard + gamepad 0 with standard bindings.
    public static let keyboardAndGamepad = UIInputConfig(keyboard: .default, gamepad: .default)

    // MARK: - Keyboard Config

    public struct KeyboardConfig: Sendable {
        public var confirm: [Key]
        public var cancel: [Key]
        public var up: [Key]
        public var down: [Key]
        public var left: [Key]
        public var right: [Key]
        public var nextFocus: [Key]
        /// Prev focus uses Shift + nextFocus keys. This flag enables that behavior.
        public var shiftForPrevFocus: Bool

        public init(
            confirm: [Key] = [.enter, .space],
            cancel: [Key] = [.escape],
            up: [Key] = [.up],
            down: [Key] = [.down],
            left: [Key] = [.left],
            right: [Key] = [.right],
            nextFocus: [Key] = [.tab],
            shiftForPrevFocus: Bool = true
        ) {
            self.confirm = confirm
            self.cancel = cancel
            self.up = up
            self.down = down
            self.left = left
            self.right = right
            self.nextFocus = nextFocus
            self.shiftForPrevFocus = shiftForPrevFocus
        }

        public static let `default` = KeyboardConfig()
    }

    // MARK: - Gamepad Config

    public struct GamepadConfig: Sendable {
        /// Which gamepad index to use (0 = player 1).
        public var gamepadIndex: Int
        public var confirm: [GamepadButton]
        public var cancel: [GamepadButton]
        public var up: [GamepadButton]
        public var down: [GamepadButton]
        public var left: [GamepadButton]
        public var right: [GamepadButton]
        public var nextFocus: [GamepadButton]
        public var prevFocus: [GamepadButton]

        public init(
            gamepadIndex: Int = 0,
            confirm: [GamepadButton] = [.faceDown],
            cancel: [GamepadButton] = [.faceRight],
            up: [GamepadButton] = [.dpadUp],
            down: [GamepadButton] = [.dpadDown],
            left: [GamepadButton] = [.dpadLeft],
            right: [GamepadButton] = [.dpadRight],
            nextFocus: [GamepadButton] = [.rightBumper],
            prevFocus: [GamepadButton] = [.leftBumper]
        ) {
            self.gamepadIndex = gamepadIndex
            self.confirm = confirm
            self.cancel = cancel
            self.up = up
            self.down = down
            self.left = left
            self.right = right
            self.nextFocus = nextFocus
            self.prevFocus = prevFocus
        }

        public static let `default` = GamepadConfig()
    }

    // MARK: - Query Helpers

    /// Returns true if any confirm binding was pressed this frame.
    func isConfirmPressed(input: InputManager) -> Bool {
        if let kb = keyboard {
            for key in kb.confirm where input.isKeyPressed(key) { return true }
        }
        if let gp = gamepad {
            for btn in gp.confirm where input.isGamepadButtonPressed(gp.gamepadIndex, btn) { return true }
        }
        return false
    }

    /// Returns true if any cancel binding was pressed this frame.
    func isCancelPressed(input: InputManager) -> Bool {
        if let kb = keyboard {
            for key in kb.cancel where input.isKeyPressed(key) { return true }
        }
        if let gp = gamepad {
            for btn in gp.cancel where input.isGamepadButtonPressed(gp.gamepadIndex, btn) { return true }
        }
        return false
    }

    /// Returns true if any up binding was pressed this frame.
    func isUpPressed(input: InputManager) -> Bool {
        if let kb = keyboard {
            for key in kb.up where input.isKeyPressed(key) { return true }
        }
        if let gp = gamepad {
            for btn in gp.up where input.isGamepadButtonPressed(gp.gamepadIndex, btn) { return true }
        }
        return false
    }

    /// Returns true if any down binding was pressed this frame.
    func isDownPressed(input: InputManager) -> Bool {
        if let kb = keyboard {
            for key in kb.down where input.isKeyPressed(key) { return true }
        }
        if let gp = gamepad {
            for btn in gp.down where input.isGamepadButtonPressed(gp.gamepadIndex, btn) { return true }
        }
        return false
    }

    /// Returns true if any left binding is held this frame.
    func isLeftDown(input: InputManager) -> Bool {
        if let kb = keyboard {
            for key in kb.left where input.isKeyDown(key) { return true }
        }
        if let gp = gamepad {
            for btn in gp.left where input.isGamepadButtonDown(gp.gamepadIndex, btn) { return true }
        }
        return false
    }

    /// Returns true if any right binding is held this frame.
    func isRightDown(input: InputManager) -> Bool {
        if let kb = keyboard {
            for key in kb.right where input.isKeyDown(key) { return true }
        }
        if let gp = gamepad {
            for btn in gp.right where input.isGamepadButtonDown(gp.gamepadIndex, btn) { return true }
        }
        return false
    }

    /// Returns true if any next-focus binding was pressed this frame.
    func isNextFocusPressed(input: InputManager) -> Bool {
        if let kb = keyboard {
            let shiftHeld = input.isKeyDown(.leftShift)
            if kb.shiftForPrevFocus && shiftHeld {
                // Shift+Tab is prev focus, not next
            } else {
                for key in kb.nextFocus where input.isKeyPressed(key) { return true }
            }
        }
        if let gp = gamepad {
            for btn in gp.nextFocus where input.isGamepadButtonPressed(gp.gamepadIndex, btn) { return true }
        }
        return false
    }

    /// Returns true if any prev-focus binding was pressed this frame.
    func isPrevFocusPressed(input: InputManager) -> Bool {
        if let kb = keyboard {
            if kb.shiftForPrevFocus && input.isKeyDown(.leftShift) {
                for key in kb.nextFocus where input.isKeyPressed(key) { return true }
            }
        }
        if let gp = gamepad {
            for btn in gp.prevFocus where input.isGamepadButtonPressed(gp.gamepadIndex, btn) { return true }
        }
        return false
    }
}
