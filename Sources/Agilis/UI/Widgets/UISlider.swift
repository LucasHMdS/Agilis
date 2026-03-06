

/// A horizontal slider for adjusting a float value within a range.
public class UISlider: UINode, @unchecked Sendable {
    public var label: String
    public var value: Float
    public var range: ClosedRange<Float>
    public var onChange: ((Float) -> Void)?
    public var fontSize: Float

    /// Step size for keyboard adjustment (fraction of range).
    public var stepFraction: Float = 0.05

    private var isDragging = false

    /// Cached label measurement, set by the layout engine.
    internal var cachedLabelSize: Size?

    /// Height of the track.
    private let trackHeight: Float = 6
    /// Radius of the knob.
    private let knobRadius: Float = 8

    public init(_ label: String, value: Float = 0.5, range: ClosedRange<Float> = 0...1,
                fontSize: Float = 16, onChange: ((Float) -> Void)? = nil) {
        self.label = label
        self.value = value
        self.range = range
        self.fontSize = fontSize
        self.onChange = onChange
        super.init()
        self.isFocusable = true
    }

    public override func sizeThatFits(_ available: Size) -> Size {
        let labelHeight = cachedLabelSize?.height ?? (fontSize + 4)
        return Size(width: min(available.width, 250), height: labelHeight + 20)
    }

    public override func update(context: UIContext, deltaTime: Double) {
        guard isVisible, let app = context.app else { return }
        let input = app.input
        let mousePos = input.mousePosition
        let track = trackRect()

        if track.contains(mousePos) && input.isMouseButtonPressed(.left) {
            isDragging = true
        }
        if isDragging && !input.isMouseButtonDown(.left) {
            isDragging = false
        }
        if isDragging {
            let normalized = clamp((mousePos.x - track.x) / track.width, min: 0, max: 1)
            value = lerp(range.lowerBound, range.upperBound, t: normalized)
            onChange?(value)
        }
    }

    /// Adjust value by a step. Called by UIContext for keyboard control.
    public func adjustByStep(_ direction: Float) {
        let step = (range.upperBound - range.lowerBound) * stepFraction * direction
        value = clamp(value + step, min: range.lowerBound, max: range.upperBound)
        onChange?(value)
    }

    public override func render(renderer: any RenderBackend, theme: UITheme) {
        guard isVisible else { return }
        // Draw label
        let labelY = frame.y
        renderer.drawText(label,
                          position: Vector2(x: frame.x, y: labelY),
                          font: theme.font,
                          size: fontSize,
                          color: theme.textColor)

        // Draw value text
        let valueText = String(format: "%.2f", value)
        renderer.drawText(valueText,
                          position: Vector2(x: frame.x + frame.width - 50, y: labelY),
                          font: theme.font,
                          size: fontSize,
                          color: theme.textColor)

        // Draw track
        let track = trackRect()
        renderer.drawRect(track, color: theme.sliderTrackColor)

        // Draw fill
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let fillRect = Rect(x: track.x, y: track.y,
                            width: track.width * normalized, height: track.height)
        renderer.drawRect(fillRect, color: theme.sliderFillColor)

        // Draw knob
        let knobX = track.x + track.width * normalized
        let knobY = track.y + track.height / 2
        renderer.drawCircle(center: Vector2(x: knobX, y: knobY),
                            radius: knobRadius, color: theme.sliderKnobColor)

        // Focus indicator
        if isFocused {
            renderer.drawRectOutline(frame, color: theme.focusColor, thickness: 2)
        }
    }

    private func trackRect() -> Rect {
        let labelHeight = cachedLabelSize?.height ?? (fontSize + 4)
        let trackY = frame.y + labelHeight + 6
        return Rect(x: frame.x, y: trackY,
                    width: frame.width, height: trackHeight)
    }
}
