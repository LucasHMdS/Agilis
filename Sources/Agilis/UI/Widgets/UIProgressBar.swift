/// A display-only progress bar.
public class UIProgressBar: UINode, @unchecked Sendable {
    /// Progress value from 0.0 to 1.0.
    public var value: Float
    public var fillColor: Color?
    public var trackColor: Color?

    private let barHeight: Float = 16

    public init(value: Float = 0) {
        self.value = value
        super.init()
    }

    override public func sizeThatFits(_ available: Size) -> Size {
        Size(width: min(available.width, 200), height: barHeight)
    }

    override public func render(renderer: any RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        // Track
        let track = trackColor ?? theme.sliderTrackColor
        renderer.drawRect(frame, color: track)

        // Fill
        let fill = fillColor ?? theme.sliderFillColor
        let clamped = clamp(value, min: 0, max: 1)
        let fillRect = Rect(
            x: frame.x,
            y: frame.y,
            width: frame.width * clamped,
            height: frame.height
        )
        renderer.drawRect(fillRect, color: fill)

        // Border
        renderer.drawRectOutline(frame, color: theme.borderColor, thickness: 1)
    }
}
