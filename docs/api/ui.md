# UI System

Agilis includes a retained-mode UI system for menus, HUDs, settings screens, and dialogs. Widgets persist as objects in a tree, with automatic layout, theming, and keyboard/mouse/gamepad navigation.

## Quick Start

```swift
final class MenuScene: Scene {
    private var ui: UIContext!

    func didEnter(app: Application) {
        let font = app.renderer.loadDefaultFont()
        ui = UIContext(font: font)

        let panel = UIContainer(id: "menu")
        panel.layout = .vertical(spacing: 16, alignment: .center)
        panel.add(UILabel("My Game", fontSize: 48))
        panel.add(UIButton("Play") { /* start game */ })
        panel.add(UIButton("Quit") { [weak app] in app?.quit() })
        ui.add(panel)

        let screen = app.renderer.screenSize
        panel.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)
    }

    func render(app: Application, interpolation: Double) {
        ui.render(renderer: app.renderer)
    }
}
```

---

## UIContext

`Sources/Agilis/UI/UIContext.swift`

The root manager for a UI tree. Each scene typically has one UIContext.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `root` | `UIContainer` | Root container (layout = `.manual`) |
| `focusedNode` | `UINode?` | Currently keyboard-focused node (read-only) |
| `font` | `FontHandle` | Font used for text rendering |
| `theme` | `UITheme` | Visual theme |
| `needsLayout` | `Bool` | Set to `true` to force layout recalculation |
| `inputConfig` | `UIInputConfig` | Configurable input bindings (default: `.default`) |
| `activeModal` | `UIModalDialog?` | Currently presented modal dialog (read-only) |

### Methods

```swift
init(font: FontHandle, theme: UITheme? = nil)   // Defaults to dark theme

func add(_ node: UINode) -> Self         // Add to root (chainable, sets needsLayout)
func update(app: Application, deltaTime: Double)  // Call in scene's update()
func render(renderer: RenderBackend)              // Call in scene's render()
func setFocus(_ node: UINode?)           // Programmatically set keyboard focus
func invalidateLayout()                  // Mark layout as dirty
func presentModal(_ modal: UIModalDialog)  // Show a modal dialog
func dismissModal()                        // Dismiss the active modal
```

### Navigation

Navigation is configurable via `UIInputConfig`. Default keyboard bindings:

| Action | Default Keys |
|--------|-------------|
| Next focus | Tab, Down |
| Previous focus | Shift+Tab, Up |
| Confirm | Enter, Space |
| Cancel | Escape |
| Adjust slider | Left, Right |

Mouse movement clears keyboard focus. Mouse clicks set focus on the clicked widget.

When a modal is active, focus is trapped within the modal's focusable nodes.

---

## UIInputConfig

`Sources/Agilis/UI/UIInputConfig.swift`

Configurable keyboard and gamepad bindings for UI navigation.

### Presets

```swift
UIInputConfig.default              // Keyboard only with standard keys
UIInputConfig.keyboardAndGamepad   // Keyboard + gamepad 0 with standard bindings
```

### Keyboard Config

```swift
public struct KeyboardConfig: Sendable {
    var confirm: [Key]       // default: [.enter, .space]
    var cancel: [Key]        // default: [.escape]
    var up: [Key]            // default: [.up]
    var down: [Key]          // default: [.down]
    var left: [Key]          // default: [.left]
    var right: [Key]         // default: [.right]
    var nextFocus: [Key]     // default: [.tab]
}
```

### Gamepad Config

```swift
public struct GamepadConfig: Sendable {
    var gamepadIndex: Int            // default: 0
    var confirm: [GamepadButton]     // default: [.faceDown]
    var cancel: [GamepadButton]      // default: [.faceRight]
    var up: [GamepadButton]          // default: [.dpadUp]
    var down: [GamepadButton]        // default: [.dpadDown]
    var left: [GamepadButton]        // default: [.dpadLeft]
    var right: [GamepadButton]       // default: [.dpadRight]
    var nextFocus: [GamepadButton]   // default: [.rightBumper]
    var prevFocus: [GamepadButton]   // default: [.leftBumper]
}
```

### Usage

```swift
let ui = UIContext(font: font)
ui.inputConfig = .keyboardAndGamepad  // Enable gamepad navigation

// Or customize:
var config = UIInputConfig.default
config.keyboard?.confirm = [.enter]   // Only Enter (not Space)
ui.inputConfig = config
```

---

## UINode

`Sources/Agilis/UI/UINode.swift`

Base class for all UI elements.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `id` | `String` | Auto-generated | Unique identifier |
| `frame` | `Rect` | Zero | Screen position/size (set by layout) |
| `isVisible` | `Bool` | `true` | Whether to render and update |
| `isFocusable` | `Bool` | `false` | Whether keyboard focus can land here |
| `isFocused` | `Bool` | `false` | Whether currently focused (read-only) |
| `parent` | `UINode?` | `nil` | Parent node (weak reference) |

### Override Points

```swift
func update(context: UIContext, deltaTime: Double)    // Input handling
func render(renderer: RenderBackend, theme: UITheme)  // Drawing
func sizeThatFits(_ available: Size) -> Size           // Preferred size
func renderOverlay(renderer: RenderBackend, theme: UITheme, screenSize: Size) // Z-ordered overlay
```

---

## UIContainer

`Sources/Agilis/UI/UIContainer.swift`

A node that can hold children. Subclass of `UINode`.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | `[UINode]` | `[]` | Child nodes (read-only) |
| `layout` | `UILayout` | `.vertical()` | Layout strategy |
| `padding` | `Float` | `0` | Inner padding |

### Methods

```swift
func add(_ child: UINode) -> Self    // Chainable
func remove(_ child: UINode)
func removeAll()
```

---

## UILayout

`Sources/Agilis/UI/UILayout.swift`

Layout strategy for containers.

```swift
enum UILayout {
    case vertical(spacing: Float = 8, alignment: HorizontalAlignment = .center)
    case horizontal(spacing: Float = 8, alignment: VerticalAlignment = .center)
    case manual    // Children positioned by their frame directly

    enum HorizontalAlignment { case leading, center, trailing }
    enum VerticalAlignment { case top, center, bottom }
}
```

**Vertical:** Stacks children top-to-bottom, centered vertically within bounds, with configurable horizontal alignment.

**Horizontal:** Stacks children left-to-right, centered horizontally within bounds, with configurable vertical alignment.

**Manual:** No automatic positioning. Set `child.frame` directly.

---

## UILayoutEngine

`Sources/Agilis/UI/UILayoutEngine.swift`

Performs a recursive layout pass. Called automatically by `UIContext.update()` when `needsLayout` is true.

```swift
static func performLayout(on container: UIContainer, in bounds: Rect,
                          renderer: RenderBackend, font: FontHandle)
```

The engine:
1. Measures text in all descendants (caches sizes on labels, buttons, etc.)
2. Applies the container's layout strategy to position children
3. Recurses into child containers

---

## UITheme

`Sources/Agilis/UI/UITheme.swift`

All visual properties for the UI.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `font` | `FontHandle` | Font for all text |
| `textColor` | `Color` | Default text color |
| `titleFontSize` | `Float` | Title size (32) |
| `bodyFontSize` | `Float` | Body size (20) |
| `buttonColor` | `Color` | Button normal background |
| `buttonHoverColor` | `Color` | Button hovered background |
| `buttonPressColor` | `Color` | Button pressed background |
| `buttonFocusColor` | `Color` | Button focused background |
| `buttonTextColor` | `Color` | Button text color |
| `panelColor` | `Color` | Panel background |
| `borderColor` | `Color` | Panel/input border |
| `sliderTrackColor` | `Color` | Slider track |
| `sliderFillColor` | `Color` | Slider fill |
| `sliderKnobColor` | `Color` | Slider knob |
| `toggleOnColor` | `Color` | Toggle on state |
| `toggleOffColor` | `Color` | Toggle off state |
| `focusColor` | `Color` | Focus indicator |
| `dropdownColor` | `Color` | Dropdown button background |
| `dropdownHoverColor` | `Color` | Dropdown hovered background |
| `dropdownOptionColor` | `Color` | Dropdown option list background |
| `dropdownHighlightColor` | `Color` | Dropdown highlighted option |
| `listSelectionColor` | `Color` | List view selected row |
| `modalOverlayColor` | `Color` | Modal semi-transparent overlay |
| `modalTitleColor` | `Color` | Modal title text |
| `modalTitleBarColor` | `Color` | Modal title bar background |
| `defaultPadding` | `Float` | Default padding (8) |
| `defaultSpacing` | `Float` | Default spacing (8) |

### Presets

```swift
let dark = UITheme.dark(font: font)    // White text on dark backgrounds
let light = UITheme.light(font: font)  // Dark text on light backgrounds
```

### Customization

```swift
var theme = UITheme.dark(font: font)
theme.buttonColor = Color(r: 40, g: 40, b: 40, a: 200)
theme.sliderFillColor = .green
let ui = UIContext(font: font, theme: theme)
```

---

## Widgets

### UILabel

`Sources/Agilis/UI/Widgets/UILabel.swift`

Static text display. Not focusable.

```swift
init(_ text: String, fontSize: Float = 20, color: Color? = nil, alignment: TextAlignment = .left)
```

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | Display text |
| `fontSize` | `Float` | Font size |
| `color` | `Color?` | Override color (nil = theme.textColor) |
| `alignment` | `TextAlignment` | `.left`, `.center`, `.right` |

---

### UIButton

`Sources/Agilis/UI/Widgets/UIButton.swift`

Clickable button with text. Focusable.

```swift
init(_ text: String, fontSize: Float = 20, action: @escaping () -> Void = {})
```

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | Button label |
| `fontSize` | `Float` | Font size |
| `action` | `() -> Void` | Click callback |
| `state` | `State` | `.normal`, `.hovered`, `.pressed` (read-only) |
| `horizontalPadding` | `Float` | Horizontal padding (24) |
| `verticalPadding` | `Float` | Vertical padding (12) |

Methods: `activate()` — triggers action (called by UIContext on keyboard activation)

---

### UIPanel

`Sources/Agilis/UI/Widgets/UIPanel.swift`

A visible container with background and optional border. Subclass of `UIContainer`.

```swift
init(layout: UILayout = .vertical(), padding: Float = 16)
```

| Property | Type | Description |
|----------|------|-------------|
| `backgroundColor` | `Color?` | Override (nil = theme.panelColor) |
| `borderColor` | `Color?` | Override (nil = theme.borderColor) |
| `borderThickness` | `Float` | Border width (0 = no border) |

---

### UISlider

`Sources/Agilis/UI/Widgets/UISlider.swift`

Horizontal slider with label and value display. Focusable.

```swift
init(_ label: String, value: Float = 0.5, range: ClosedRange<Float> = 0...1,
     fontSize: Float = 16, onChange: ((Float) -> Void)? = nil)
```

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Label text |
| `value` | `Float` | Current value |
| `range` | `ClosedRange<Float>` | Value range |
| `onChange` | `((Float) -> Void)?` | Value change callback |
| `stepFraction` | `Float` | Fraction per keyboard step (0.05) |

Methods: `adjustByStep(_ direction: Float)` — keyboard left/right adjustment

---

### UIToggle

`Sources/Agilis/UI/Widgets/UIToggle.swift`

Checkbox/switch widget. Focusable.

```swift
init(_ label: String, isOn: Bool = false, fontSize: Float = 16,
     onChange: ((Bool) -> Void)? = nil)
```

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Label text |
| `isOn` | `Bool` | Current state |
| `onChange` | `((Bool) -> Void)?` | State change callback |

Methods: `toggle()` — flips state and calls onChange

---

### UITextInput

`Sources/Agilis/UI/Widgets/UITextInput.swift`

Single-line text input field. Focusable.

```swift
init(_ placeholder: String = "", text: String = "", fontSize: Float = 18,
     onChange: ((String) -> Void)? = nil)
```

| Property | Type | Description |
|----------|------|-------------|
| `placeholder` | `String` | Placeholder text |
| `text` | `String` | Current text |
| `cursorIndex` | `Int` | Cursor position |
| `onChange` | `((String) -> Void)?` | Text change callback |

Supports: character input, Backspace, Delete, Left/Right cursor movement, blinking cursor.

---

### UIProgressBar

`Sources/Agilis/UI/Widgets/UIProgressBar.swift`

Display-only progress bar. Not focusable.

```swift
init(value: Float = 0)
```

| Property | Type | Description |
|----------|------|-------------|
| `value` | `Float` | Progress 0.0-1.0 |
| `fillColor` | `Color?` | Override fill color |
| `trackColor` | `Color?` | Override track color |

Default size: 200 x 16 pixels.

---

### UIImage

`Sources/Agilis/UI/Widgets/UIImage.swift`

Texture display widget. Not focusable.

```swift
init(texture: TextureHandle, tint: Color = .white, fixedSize: Size? = nil)
```

| Property | Type | Description |
|----------|------|-------------|
| `texture` | `TextureHandle` | Texture to display |
| `tint` | `Color` | Color tint |
| `fixedSize` | `Size?` | Override size (nil = texture size) |

---

### UIScrollContainer

`Sources/Agilis/UI/Widgets/UIScrollContainer.swift`

Scrollable container that clips children to its bounds. Subclass of `UIContainer`.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `scrollOffset` | `Vector2` | `.zero` | Current scroll position |
| `scrollSpeed` | `Float` | `30` | Mouse wheel speed multiplier |
| `showScrollBar` | `Bool` | `true` | Show scroll bar indicator |

Scrolls via mouse wheel when the cursor is over the container. Content is clipped using `beginClip`/`endClip`.

---

### UIDropdown

`Sources/Agilis/UI/Widgets/UIDropdown.swift`

Dropdown select widget. Focusable. Opens a popup list of options.

```swift
init(_ options: [String], selectedIndex: Int = 0, fontSize: Float = 16,
     onChange: ((Int) -> Void)? = nil)
```

| Property | Type | Description |
|----------|------|-------------|
| `options` | `[String]` | Available options |
| `selectedIndex` | `Int` | Currently selected index |
| `onChange` | `((Int) -> Void)?` | Selection change callback |
| `fontSize` | `Float` | Font size |
| `isOpen` | `Bool` | Whether popup is visible (read-only) |
| `maxVisibleOptions` | `Int` | Max options shown before scrolling (6) |

**Input**: Click to open/close. Click option to select. Arrow keys navigate when open. Keyboard/gamepad confirm opens/selects, cancel closes. Mouse wheel scrolls when open.

**Popup direction**: Opens downward by default. If insufficient space below, opens upward.

---

### UIListView

`Sources/Agilis/UI/Widgets/UIListView.swift`

Data-driven scrollable list. Focusable. Renders items directly (not child UINodes).

```swift
init(_ items: [String], selectedIndex: Int = 0, fontSize: Float = 16,
     onChange: ((Int) -> Void)? = nil)
```

| Property | Type | Description |
|----------|------|-------------|
| `items` | `[String]` | List items |
| `selectedIndex` | `Int` | Currently selected index |
| `onChange` | `((Int) -> Void)?` | Selection change callback |
| `fontSize` | `Float` | Font size |
| `rowHeight` | `Float` | Height per row (28) |
| `scrollOffset` | `Float` | Current scroll position |
| `scrollSpeed` | `Float` | Mouse wheel speed (30) |
| `showScrollBar` | `Bool` | Show scroll bar indicator (true) |

**Input**: Click to select. Mouse wheel scrolls. Arrow keys move selection when focused (auto-scrolls to keep selection visible).

---

### UIModalDialog

`Sources/Agilis/UI/Widgets/UIModalDialog.swift`

Modal dialog overlay. Blocks input to the normal UI tree when active.

```swift
init(title: String, fontSize: Float = 20)
```

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | Dialog title |
| `contentContainer` | `UIContainer` | Body area |
| `buttonContainer` | `UIContainer` | Action buttons at bottom |
| `onDismiss` | `(() -> Void)?` | Dismiss callback |
| `dismissOnCancel` | `Bool` | Cancel action dismisses (true) |
| `overlayColor` | `Color` | Background overlay color |
| `dialogWidth` | `Float` | Dialog width (400) |

### Methods

```swift
@discardableResult func addContent(_ node: UINode) -> Self
@discardableResult func addButton(_ text: String, action: @escaping () -> Void) -> Self
@discardableResult func addOKCancel(onOK: @escaping () -> Void,
                                     onCancel: @escaping () -> Void) -> Self
```

### Usage

```swift
let modal = UIModalDialog(title: "Confirm")
modal.addContent(UILabel("Are you sure?", fontSize: 18))
modal.addOKCancel(
    onOK: { [weak self] in
        self?.ui.dismissModal()
        // do something
    },
    onCancel: { [weak self] in self?.ui.dismissModal() }
)
ui.presentModal(modal)
```

When a modal is active:
- `UIContext.update()` only updates the modal (blocks normal tree input)
- `UIContext.render()` renders normal tree, then overlay, then modal
- Focus is trapped within the modal's focusable nodes
- Cancel action (from `inputConfig`) dismisses if `dismissOnCancel` is true
