import AgilisCore

/// Configuration for UI debug rendering.
public struct UIDebugRendererOptions: Sendable {
    /// Draw bounding rect outlines for each UI node.
    public var drawBounds: Bool
    /// Color for bounding rect outlines.
    public var boundsColor: Color
    /// Font size for node ID labels.
    public var fontSize: Float

    public init(
        drawBounds: Bool = true,
        boundsColor: Color = .cyan,
        fontSize: Float = 10
    ) {
        self.drawBounds = drawBounds
        self.boundsColor = boundsColor
        self.fontSize = fontSize
    }
}

extension RenderBackend {

    /// Draw debug overlays for a UI context.
    ///
    /// Shows bounding rectangles and node IDs for all UI nodes. Call in screen space
    /// (outside any camera block), typically after `uiContext.render()`.
    ///
    /// - Parameters:
    ///   - context: The UI context to debug.
    ///   - font: Font for node ID labels.
    ///   - options: Rendering options.
    public func drawUIDebug(
        context: UIContext,
        font: FontHandle,
        options: UIDebugRendererOptions = UIDebugRendererOptions()
    ) {
        drawUINodeDebug(node: context.root, font: font, options: options)
    }

    private func drawUINodeDebug(
        node: UINode,
        font: FontHandle,
        options: UIDebugRendererOptions
    ) {
        let frame = node.frame
        guard frame.width > 0 && frame.height > 0 else { return }

        if options.drawBounds {
            drawRectOutline(frame, color: options.boundsColor, thickness: 1)

            // Node ID label
            if !node.id.isEmpty {
                drawText(node.id,
                         position: Vector2(x: frame.x + 2, y: frame.y + 1),
                         font: font, size: options.fontSize, color: options.boundsColor)
            }
        }

        // Recurse into children if this is a container
        if let container = node as? UIContainer {
            for child in container.children {
                drawUINodeDebug(node: child, font: font, options: options)
            }
        }
    }
}
