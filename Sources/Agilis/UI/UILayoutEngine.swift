/// Performs layout on a UI tree, measuring text and positioning children.
public enum UILayoutEngine {

    /// Lay out a container and all its descendants within the given bounds.
    public static func performLayout(
        on container: UIContainer,
        in bounds: Rect,
        renderer: any RenderBackend,
        font: FontHandle
    ) {
        container.frame = bounds
        let padding = container.padding
        let innerBounds = Rect(
            x: bounds.x + padding,
            y: bounds.y + padding,
            width: bounds.width - padding * 2,
            height: bounds.height - padding * 2
        )

        // Measure text in all descendants
        measureText(in: container, renderer: renderer, font: font)

        // Apply layout strategy
        switch container.layout {
        case .vertical(let spacing, let alignment):
            layoutVertical(container, in: innerBounds, spacing: spacing, alignment: alignment)

        case .horizontal(let spacing, let alignment):
            layoutHorizontal(container, in: innerBounds, spacing: spacing, alignment: alignment)

        case .manual:
            break
        }

        // Recurse into child containers
        for child in container.children {
            if let childContainer = child as? UIContainer {
                performLayout(
                    on: childContainer,
                    in: child.frame,
                    renderer: renderer,
                    font: font
                )
            }
        }
    }

    // MARK: - Text Measurement

    private static func measureText(
        in node: UINode,
        renderer: any RenderBackend,
        font: FontHandle
    ) {
        if let label = node as? UILabel {
            label.cachedTextSize = renderer.measureText(label.text, font: font, size: label.fontSize)
        } else if let button = node as? UIButton {
            button.cachedTextSize = renderer.measureText(button.text, font: font, size: button.fontSize)
        } else if let slider = node as? UISlider {
            slider.cachedLabelSize = renderer.measureText(slider.label, font: font, size: slider.fontSize)
        } else if let toggle = node as? UIToggle {
            toggle.cachedLabelSize = renderer.measureText(toggle.label, font: font, size: toggle.fontSize)
        } else if let textInput = node as? UITextInput {
            let displayText = textInput.text.isEmpty ? textInput.placeholder : textInput.text
            textInput.cachedTextSize = renderer.measureText(displayText, font: font, size: textInput.fontSize)
        } else if let dropdown = node as? UIDropdown {
            var maxSize = Size(width: 0, height: 0)
            for option in dropdown.options {
                let size = renderer.measureText(option, font: font, size: dropdown.fontSize)
                if size.width > maxSize.width { maxSize.width = size.width }
                if size.height > maxSize.height { maxSize.height = size.height }
            }
            dropdown.cachedTextSize = maxSize
        }

        if let container = node as? UIContainer {
            for child in container.children {
                measureText(in: child, renderer: renderer, font: font)
            }
        }
    }

    // MARK: - Vertical Layout

    private static func layoutVertical(
        _ container: UIContainer,
        in bounds: Rect,
        spacing: Float,
        alignment: UILayout.HorizontalAlignment
    ) {
        let visibleChildren = container.children.filter(\.isVisible)
        guard !visibleChildren.isEmpty else { return }

        // Measure all children
        let sizes = visibleChildren.map { $0.sizeThatFits(bounds.size) }
        let totalHeight = sizes.reduce(Float(0)) { $0 + $1.height }
            + spacing * Float(visibleChildren.count - 1)

        // Center the stack vertically within bounds (clamp to top when content overflows)
        var y = bounds.y + max(0, (bounds.height - totalHeight) / 2)

        for (i, child) in visibleChildren.enumerated() {
            let size = sizes[i]
            let x: Float
            switch alignment {
            case .leading:
                x = bounds.x

            case .center:
                x = bounds.x + (bounds.width - size.width) / 2

            case .trailing:
                x = bounds.x + bounds.width - size.width
            }

            child.frame = Rect(x: x, y: y, width: size.width, height: size.height)
            y += size.height + spacing
        }
    }

    // MARK: - Horizontal Layout

    private static func layoutHorizontal(
        _ container: UIContainer,
        in bounds: Rect,
        spacing: Float,
        alignment: UILayout.VerticalAlignment
    ) {
        let visibleChildren = container.children.filter(\.isVisible)
        guard !visibleChildren.isEmpty else { return }

        let sizes = visibleChildren.map { $0.sizeThatFits(bounds.size) }
        let totalWidth = sizes.reduce(Float(0)) { $0 + $1.width }
            + spacing * Float(visibleChildren.count - 1)

        // Center the stack horizontally within bounds (clamp to left when content overflows)
        var x = bounds.x + max(0, (bounds.width - totalWidth) / 2)

        for (i, child) in visibleChildren.enumerated() {
            let size = sizes[i]
            let y: Float
            switch alignment {
            case .top:
                y = bounds.y

            case .center:
                y = bounds.y + (bounds.height - size.height) / 2

            case .bottom:
                y = bounds.y + bounds.height - size.height
            }

            child.frame = Rect(x: x, y: y, width: size.width, height: size.height)
            x += size.width + spacing
        }
    }
}
