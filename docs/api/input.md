# Input

## InputManager

`Sources/Agilis/Input/InputManager.swift`

Handles keyboard, mouse, gamepad, and action mapping. Polled once per frame by the game loop.

### Keyboard

```swift
// True while key is held down
func isKeyDown(_ key: Key) -> Bool

// True only on the frame the key was first pressed
func isKeyPressed(_ key: Key) -> Bool

// True only on the frame the key was released
func isKeyReleased(_ key: Key) -> Bool

// Character typed this frame (for text input)
var charPressed: Character?
```

### Mouse

```swift
// Button state
func isMouseButtonDown(_ button: MouseButton) -> Bool
func isMouseButtonPressed(_ button: MouseButton) -> Bool
func isMouseButtonReleased(_ button: MouseButton) -> Bool

// Position and movement
var mousePosition: Vector2      // Current screen position
var mouseDelta: Vector2         // Movement since last frame
var mouseScrollDelta: Float     // Scroll wheel delta
```

### Gamepad

Supports up to 4 gamepads. Button state follows the same press/release pattern as keyboard.

```swift
// Button state (gamepadIndex 0-3)
func isGamepadButtonDown(_ gamepadIndex: Int, _ button: GamepadButton) -> Bool
func isGamepadButtonPressed(_ gamepadIndex: Int, _ button: GamepadButton) -> Bool
func isGamepadButtonReleased(_ gamepadIndex: Int, _ button: GamepadButton) -> Bool

// Axes (dead zone applied automatically)
func gamepadAxis(_ gamepadIndex: Int, _ axis: GamepadAxis) -> Float

// Stick (returns Vector2 for left/right stick)
func gamepadStick(_ gamepadIndex: Int, _ stick: GamepadStick) -> Vector2

// Dead zone threshold (default 0.1)
var gamepadDeadZone: Float
```

### Action Mapping

Map logical actions to physical inputs. Actions check keyboard, mouse, and gamepad 0 (player 1) using OR logic.

```swift
// Register an action bound to keys, mouse buttons, and/or gamepad buttons
func registerAction(_ name: String, keys: [Key] = [],
                    mouseButtons: [MouseButton] = [],
                    gamepadButtons: [GamepadButton] = [])

// Query action state
func isActionActive(_ name: String) -> Bool           // Any bound input is held
func isActionJustActivated(_ name: String) -> Bool     // Any bound input was just pressed
func isActionJustDeactivated(_ name: String) -> Bool   // All bound inputs were just released
```

### Example

```swift
// Register actions in didEnter
app.input.registerAction("jump", keys: [.space, .w], gamepadButtons: [.faceDown])
app.input.registerAction("shoot", keys: [], mouseButtons: [.left])

// Query in update
if app.input.isActionJustActivated("jump") {
    player.jump()
}
if app.input.isActionActive("shoot") {
    player.fireContinuous()
}

// Direct gamepad queries
let moveX = app.input.gamepadAxis(0, .leftX)
let leftStick = app.input.gamepadStick(0, .left)
```

---

## Key

`Sources/Agilis/Input/Key.swift`

All available keys (raw values match platform key codes):

| Group | Keys |
|-------|------|
| Letters | `.a` through `.z` |
| Numbers | `.zero` through `.nine` |
| Function | `.f1` through `.f12` |
| Arrows | `.up`, `.down`, `.left`, `.right` |
| Special | `.space`, `.enter`, `.escape`, `.backspace`, `.tab`, `.delete`, `.insert` |
| Modifiers | `.leftShift`, `.leftControl`, `.leftAlt`, `.rightShift`, `.rightControl`, `.rightAlt` |

---

## MouseButton

Cases: `.left` (0), `.right` (1), `.middle` (2)

---

## GamepadButton

`Sources/Agilis/Input/GamepadButton.swift`

18 standard buttons:

| Group | Buttons |
|-------|---------|
| Face | `.faceUp`, `.faceRight`, `.faceDown`, `.faceLeft` |
| Bumpers | `.leftBumper`, `.rightBumper` |
| Triggers | `.leftTrigger`, `.rightTrigger` |
| Sticks | `.leftStick`, `.rightStick` |
| D-Pad | `.dpadUp`, `.dpadRight`, `.dpadDown`, `.dpadLeft` |
| Center | `.start`, `.select`, `.middle` |

---

## GamepadAxis

`Sources/Agilis/Input/GamepadAxis.swift`

6 axes: `.leftX`, `.leftY`, `.rightX`, `.rightY`, `.leftTrigger`, `.rightTrigger`

---

## GamepadStick

`Sources/Agilis/Input/GamepadStick.swift`

Cases: `.left`, `.right`

Used with `gamepadStick()` to get a `Vector2` for the stick position.

---

## InputBackend

`Sources/Agilis/Input/InputBackend.swift`

Protocol for raw input polling. Implement this to support a new platform:

```swift
protocol InputBackend: AnyObject, Sendable {
    func isKeyDown(_ key: Key) -> Bool
    func isMouseButtonDown(_ button: MouseButton) -> Bool
    func mousePosition() -> Vector2
    func mouseDelta() -> Vector2
    func mouseScrollDelta() -> Float
    func charPressed() -> Character?

    // Gamepad (default no-op implementations)
    func isGamepadButtonDown(_ gamepadIndex: Int, _ button: GamepadButton) -> Bool
    func gamepadAxisValue(_ gamepadIndex: Int, _ axis: GamepadAxis) -> Float
    func isGamepadConnected(_ gamepadIndex: Int) -> Bool
    func isShiftDown() -> Bool
}
```
