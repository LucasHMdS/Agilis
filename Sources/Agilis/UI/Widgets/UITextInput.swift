import AgilisCore

/// A single-line text input field.
public class UITextInput: UINode, @unchecked Sendable {
    public var text: String
    public var placeholder: String
    public var fontSize: Float
    public var onChange: ((String) -> Void)?

    /// Cursor position (index into text).
    public var cursorIndex: Int = 0

    /// Blink timer for cursor visibility.
    private var blinkTimer: Double = 0
    private var showCursor: Bool = true

    /// Cached text measurement, set by the layout engine.
    internal var cachedTextSize: Size?

    private let horizontalPadding: Float = 8
    private let verticalPadding: Float = 6

    public init(_ placeholder: String = "", text: String = "", fontSize: Float = 18,
                onChange: ((String) -> Void)? = nil) {
        self.placeholder = placeholder
        self.text = text
        self.fontSize = fontSize
        self.onChange = onChange
        self.cursorIndex = text.count
        super.init()
        self.isFocusable = true
    }

    public override func sizeThatFits(_ available: Size) -> Size {
        return Size(width: min(available.width, 250),
                    height: fontSize + verticalPadding * 2 + 4)
    }

    public override func update(context: UIContext, deltaTime: Double) {
        guard isVisible, let app = context.app else { return }
        let input = app.input

        // Click to focus
        if frame.contains(input.mousePosition) && input.isMouseButtonPressed(.left) {
            context.setFocus(self)
        }

        guard isFocused else { return }

        // Blink cursor
        blinkTimer += deltaTime
        if blinkTimer >= 0.5 {
            blinkTimer = 0
            showCursor.toggle()
        }

        // Clamp cursor to valid range (text may have been modified externally)
        cursorIndex = min(cursorIndex, text.count)

        // Character input
        if let char = input.charPressed {
            let idx = text.index(text.startIndex, offsetBy: cursorIndex)
            text.insert(char, at: idx)
            cursorIndex += 1
            showCursor = true
            blinkTimer = 0
            onChange?(text)
            context.invalidateLayout()
        }

        // Backspace
        if input.isKeyPressed(.backspace) && cursorIndex > 0 {
            let idx = text.index(text.startIndex, offsetBy: cursorIndex - 1)
            text.remove(at: idx)
            cursorIndex -= 1
            showCursor = true
            blinkTimer = 0
            onChange?(text)
            context.invalidateLayout()
        }

        // Delete
        if input.isKeyPressed(.delete) && cursorIndex < text.count {
            let idx = text.index(text.startIndex, offsetBy: cursorIndex)
            text.remove(at: idx)
            showCursor = true
            blinkTimer = 0
            onChange?(text)
            context.invalidateLayout()
        }

        // Cursor movement
        if input.isKeyPressed(.left) && cursorIndex > 0 {
            cursorIndex -= 1
            showCursor = true
            blinkTimer = 0
        }
        if input.isKeyPressed(.right) && cursorIndex < text.count {
            cursorIndex += 1
            showCursor = true
            blinkTimer = 0
        }
    }

    public override func render(renderer: RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        // Background
        renderer.drawRect(frame, color: Color(r: 40, g: 40, b: 40))
        renderer.drawRectOutline(frame, color: theme.borderColor, thickness: 1)

        let textX = frame.x + horizontalPadding
        let textY = frame.y + verticalPadding

        if text.isEmpty {
            // Draw placeholder
            let placeholderColor = Color(r: 120, g: 120, b: 120)
            renderer.drawText(placeholder,
                              position: Vector2(x: textX, y: textY),
                              font: theme.font,
                              size: fontSize,
                              color: placeholderColor)
        } else {
            // Draw text
            renderer.drawText(text,
                              position: Vector2(x: textX, y: textY),
                              font: theme.font,
                              size: fontSize,
                              color: theme.textColor)
        }

        // Draw cursor when focused
        if isFocused && showCursor {
            let textBeforeCursor = String(text.prefix(cursorIndex))
            let cursorXSize = renderer.measureText(textBeforeCursor, font: theme.font, size: fontSize)
            let cursorX = textX + cursorXSize.width
            let cursorTop = Vector2(x: cursorX, y: frame.y + 4)
            let cursorBottom = Vector2(x: cursorX, y: frame.y + frame.height - 4)
            renderer.drawLine(from: cursorTop, to: cursorBottom,
                              color: theme.textColor, thickness: 1)
        }
    }
}
