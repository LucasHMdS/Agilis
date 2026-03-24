/// A node that contains child nodes and manages their layout.
public class UIContainer: UINode, @unchecked Sendable {
    public private(set) var children: [UINode] = []

    /// The layout strategy for arranging children.
    public var layout: UILayout = .vertical()

    /// Padding inside the container edges.
    public var padding: Float = 0

    /// Add a child node.
    @discardableResult
    public func add(_ child: UINode) -> Self {
        child.parent = self
        children.append(child)
        return self
    }

    /// Remove a specific child node.
    public func remove(_ child: UINode) {
        children.removeAll(where: { $0 === child })
        child.parent = nil
    }

    /// Remove all children.
    public func removeAll() {
        for child in children { child.parent = nil }
        children.removeAll()
    }

    override public func update(context: UIContext, deltaTime: Double) {
        guard isVisible else { return }
        for child in children where child.isVisible {
            child.update(context: context, deltaTime: deltaTime)
        }
    }

    override public func render(renderer: any RenderBackend, theme: UITheme) {
        guard isVisible else { return }
        for child in children where child.isVisible {
            child.render(renderer: renderer, theme: theme)
        }
    }

    override public func renderOverlay(renderer: any RenderBackend, theme: UITheme, screenSize: Size) {
        guard isVisible else { return }
        for child in children where child.isVisible {
            child.renderOverlay(renderer: renderer, theme: theme, screenSize: screenSize)
        }
    }

    override public func sizeThatFits(_ available: Size) -> Size {
        let inner = Size(width: available.width - padding * 2,
                         height: available.height - padding * 2)

        switch layout {
        case .vertical(let spacing, _):
            var totalHeight: Float = 0
            var maxWidth: Float = 0
            for (i, child) in children.enumerated() where child.isVisible {
                let childSize = child.sizeThatFits(inner)
                maxWidth = max(maxWidth, childSize.width)
                totalHeight += childSize.height
                if i > 0 { totalHeight += spacing }
            }
            return Size(width: maxWidth + padding * 2,
                        height: totalHeight + padding * 2)

        case .horizontal(let spacing, _):
            var totalWidth: Float = 0
            var maxHeight: Float = 0
            for (i, child) in children.enumerated() where child.isVisible {
                let childSize = child.sizeThatFits(inner)
                maxHeight = max(maxHeight, childSize.height)
                totalWidth += childSize.width
                if i > 0 { totalWidth += spacing }
            }
            return Size(width: totalWidth + padding * 2,
                        height: maxHeight + padding * 2)

        case .manual:
            return available
        }
    }
}
