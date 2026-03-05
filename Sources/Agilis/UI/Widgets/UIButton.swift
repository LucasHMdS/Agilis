import AgilisCore

/// A clickable button with text.
public class UIButton: UINode, @unchecked Sendable {
    public var text: String { didSet { if text != oldValue { cachedTextSize = nil } } }
    public var fontSize: Float { didSet { if fontSize != oldValue { cachedTextSize = nil } } }
    public var action: () -> Void

    /// Visual state.
    public enum State { case normal, hovered, pressed }
    public private(set) var state: State = .normal

    /// Cached text measurement, set by the layout engine.
    internal var cachedTextSize: Size?

    /// Horizontal padding around the text.
    public var horizontalPadding: Float = 24

    /// Vertical padding around the text.
    public var verticalPadding: Float = 12

    public init(_ text: String, fontSize: Float = 20, action: @escaping () -> Void = {}) {
        self.text = text
        self.fontSize = fontSize
        self.action = action
        super.init()
        self.isFocusable = true
    }

    public override func sizeThatFits(_ available: Size) -> Size {
        let textSize = cachedTextSize ?? Size(width: 100, height: fontSize + 4)
        return Size(width: textSize.width + horizontalPadding * 2,
                    height: textSize.height + verticalPadding * 2)
    }

    public override func update(context: UIContext, deltaTime: Double) {
        guard isVisible, let app = context.app else { return }
        let input = app.input
        let mousePos = input.mousePosition
        let isHovered = frame.contains(mousePos)

        if isHovered && input.isMouseButtonPressed(.left) {
            state = .pressed
        } else if state == .pressed && input.isMouseButtonReleased(.left) {
            state = isHovered ? .hovered : .normal
            if isHovered { action() }
        } else if isHovered {
            state = state == .pressed ? .pressed : .hovered
        } else {
            state = .normal
        }
    }

    public override func render(renderer: RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        let bgColor: Color
        switch state {
        case .normal:  bgColor = isFocused ? theme.buttonFocusColor : theme.buttonColor
        case .hovered: bgColor = theme.buttonHoverColor
        case .pressed: bgColor = theme.buttonPressColor
        }

        renderer.drawRect(frame, color: bgColor)

        // Draw text centered
        let textSize = cachedTextSize ?? Size(width: 0, height: fontSize)
        let textX = frame.x + (frame.width - textSize.width) / 2
        let textY = frame.y + (frame.height - textSize.height) / 2
        renderer.drawText(text,
                          position: Vector2(x: textX, y: textY),
                          font: theme.font,
                          size: fontSize,
                          color: theme.buttonTextColor)

        // Draw focus outline
        if isFocused {
            renderer.drawRectOutline(frame, color: theme.focusColor, thickness: 2)
        }
    }

    /// Called by UIContext when activated via keyboard.
    public func activate() {
        action()
    }
}
