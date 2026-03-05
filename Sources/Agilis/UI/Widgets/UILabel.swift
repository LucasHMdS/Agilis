import AgilisCore

/// A text label widget.
public class UILabel: UINode, @unchecked Sendable {
    public var text: String { didSet { if text != oldValue { cachedTextSize = nil } } }
    public var fontSize: Float { didSet { if fontSize != oldValue { cachedTextSize = nil } } }
    public var color: Color?
    public var alignment: TextAlignment

    /// Cached text measurement, set by the layout engine.
    internal var cachedTextSize: Size?

    public init(_ text: String, fontSize: Float = 20, color: Color? = nil,
                alignment: TextAlignment = .left) {
        self.text = text
        self.fontSize = fontSize
        self.color = color
        self.alignment = alignment
        super.init()
    }

    public override func sizeThatFits(_ available: Size) -> Size {
        let textSize = cachedTextSize ?? Size(width: 100, height: fontSize + 4)
        return Size(width: textSize.width, height: textSize.height)
    }

    public override func render(renderer: RenderBackend, theme: UITheme) {
        guard isVisible else { return }
        let textColor = color ?? theme.textColor
        let textWidth = cachedTextSize?.width ?? 0

        let xOffset: Float
        switch alignment {
        case .left:   xOffset = 0
        case .center: xOffset = (frame.width - textWidth) / 2
        case .right:  xOffset = frame.width - textWidth
        }

        renderer.drawText(text,
                          position: Vector2(x: frame.x + xOffset, y: frame.y),
                          font: theme.font,
                          size: fontSize,
                          color: textColor)
    }
}
