import AgilisCore

/// A scrollable container that clips its children to its bounds.
public class UIScrollContainer: UIContainer, @unchecked Sendable {
    /// Current scroll offset (positive values scroll content upward).
    public var scrollOffset: Vector2 = .zero

    /// Scroll speed multiplier for mouse wheel.
    public var scrollSpeed: Float = 30

    /// Whether to show scroll bar indicators.
    public var showScrollBar: Bool = true

    /// Maximum height reported by sizeThatFits. When set, the container will
    /// scroll if its content exceeds this height. If nil, it reports its full
    /// content height (no scrolling in a layout context).
    public var maxHeight: Float?

    private let scrollBarWidth: Float = 6

    public override func sizeThatFits(_ available: Size) -> Size {
        let contentSize = super.sizeThatFits(available)
        if let maxH = maxHeight {
            return Size(width: contentSize.width, height: min(contentSize.height, maxH))
        }
        return contentSize
    }

    public override func update(context: UIContext, deltaTime: Double) {
        guard isVisible, let app = context.app else { return }
        let input = app.input

        // Scroll on mouse wheel when mouse is over the container
        if frame.contains(input.mousePosition) {
            let delta = input.mouseScrollDelta
            if delta != 0 {
                scrollOffset.y -= delta * scrollSpeed
                clampScroll()
            }
        }

        // Update children with adjusted context
        for child in children where child.isVisible {
            child.update(context: context, deltaTime: deltaTime)
        }
    }

    public override func render(renderer: RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        // Draw background
        renderer.drawRect(frame, color: theme.panelColor)

        // Clip to container bounds
        renderer.beginClip(frame)

        // Render children offset by scroll (recursively offset all descendants)
        for child in children where child.isVisible {
            offsetFrames(child, dy: -scrollOffset.y)
            child.render(renderer: renderer, theme: theme)
            offsetFrames(child, dy: scrollOffset.y)
        }

        renderer.endClip()

        // Draw scroll bar indicator
        if showScrollBar {
            let contentHeight = computeContentHeight()
            if contentHeight > frame.height {
                let ratio = frame.height / contentHeight
                let barHeight = max(frame.height * ratio, 20)
                let maxScroll = contentHeight - frame.height
                let scrollRatio = maxScroll > 0 ? scrollOffset.y / maxScroll : 0
                let barY = frame.y + (frame.height - barHeight) * scrollRatio

                let barRect = Rect(
                    x: frame.x + frame.width - scrollBarWidth - 2,
                    y: barY,
                    width: scrollBarWidth,
                    height: barHeight
                )
                renderer.drawRect(barRect, color: Color(r: 100, g: 100, b: 100, a: 150))
            }
        }
    }

    private func offsetFrames(_ node: UINode, dy: Float) {
        node.frame = Rect(x: node.frame.x, y: node.frame.y + dy,
                          width: node.frame.width, height: node.frame.height)
        if let container = node as? UIContainer {
            for child in container.children {
                offsetFrames(child, dy: dy)
            }
        }
    }

    private func computeContentHeight() -> Float {
        guard let last = children.last(where: \.isVisible) else { return 0 }
        return last.frame.y + last.frame.height - frame.y + padding
    }

    private func clampScroll() {
        let contentHeight = computeContentHeight()
        let maxScroll = max(0, contentHeight - frame.height)
        scrollOffset.y = clamp(scrollOffset.y, min: 0, max: maxScroll)
    }
}
