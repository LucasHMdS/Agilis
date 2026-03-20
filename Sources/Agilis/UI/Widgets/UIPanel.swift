/// A visible container with a background and optional border.
public class UIPanel: UIContainer, @unchecked Sendable {
    deinit {}

    public var backgroundColor: Color?
    public var borderColor: Color?
    public var borderThickness: Float = 0

    public init(layout: UILayout = .vertical(), padding: Float = 16) {
        super.init()
        self.layout = layout
        self.padding = padding
    }

    override public func render(renderer: any RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        // Draw background
        let bg = backgroundColor ?? theme.panelColor
        renderer.drawRect(frame, color: bg)

        // Draw border
        if borderThickness > 0 {
            let border = borderColor ?? theme.borderColor
            renderer.drawRectOutline(frame, color: border, thickness: borderThickness)
        }

        // Render children on top
        super.render(renderer: renderer, theme: theme)
    }
}
