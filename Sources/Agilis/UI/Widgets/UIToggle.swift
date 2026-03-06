

/// A toggle (checkbox/switch) widget.
public class UIToggle: UINode, @unchecked Sendable {
    public var label: String
    public var isOn: Bool
    public var onChange: ((Bool) -> Void)?
    public var fontSize: Float

    /// Cached label measurement, set by the layout engine.
    internal var cachedLabelSize: Size?

    private let boxSize: Float = 20

    public init(_ label: String, isOn: Bool = false, fontSize: Float = 16,
                onChange: ((Bool) -> Void)? = nil) {
        self.label = label
        self.isOn = isOn
        self.fontSize = fontSize
        self.onChange = onChange
        super.init()
        self.isFocusable = true
    }

    public override func sizeThatFits(_ available: Size) -> Size {
        let labelWidth = cachedLabelSize?.width ?? 100
        let labelHeight = cachedLabelSize?.height ?? (fontSize + 4)
        return Size(width: boxSize + 8 + labelWidth,
                    height: max(boxSize, labelHeight))
    }

    public override func update(context: UIContext, deltaTime: Double) {
        guard isVisible, let app = context.app else { return }
        let input = app.input
        if frame.contains(input.mousePosition) && input.isMouseButtonPressed(.left) {
            toggle()
        }
    }

    /// Toggle the state. Called by UIContext for keyboard activation.
    public func toggle() {
        isOn.toggle()
        onChange?(isOn)
    }

    public override func render(renderer: Renderer, theme: UITheme) {
        guard isVisible else { return }

        // Draw checkbox
        let boxY = frame.y + (frame.height - boxSize) / 2
        let boxRect = Rect(x: frame.x, y: boxY, width: boxSize, height: boxSize)

        let boxColor = isOn ? theme.toggleOnColor : theme.toggleOffColor
        renderer.drawRect(boxRect, color: boxColor)
        renderer.drawRectOutline(boxRect, color: theme.borderColor, thickness: 1)

        // Draw checkmark when on
        if isOn {
            let cx = boxRect.x + 4
            let cy = boxRect.y + boxSize / 2
            let mid = Vector2(x: cx + 4, y: boxRect.y + boxSize - 5)
            let end = Vector2(x: boxRect.x + boxSize - 4, y: boxRect.y + 5)
            renderer.drawLine(from: Vector2(x: cx, y: cy), to: mid,
                              color: .white, thickness: 2)
            renderer.drawLine(from: mid, to: end, color: .white, thickness: 2)
        }

        // Draw label
        let labelX = frame.x + boxSize + 8
        let labelY = frame.y + (frame.height - (cachedLabelSize?.height ?? fontSize)) / 2
        renderer.drawText(label,
                          position: Vector2(x: labelX, y: labelY),
                          font: theme.font,
                          size: fontSize,
                          color: theme.textColor)
    }
}
