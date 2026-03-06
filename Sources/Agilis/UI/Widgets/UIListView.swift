

/// A data-driven scrollable list with single-item selection.
///
/// Renders items directly (no child UINodes per row) for efficiency.
/// Supports mouse click, scroll wheel, and keyboard/gamepad navigation.
///
/// ## Usage
/// ```swift
/// let list = UIListView(items: ["Sword", "Shield", "Potion"], selectedIndex: 0)
/// list.onChange = { index in print("Selected: \(list.items[index])") }
/// ```
public class UIListView: UINode, @unchecked Sendable {
    /// The items to display.
    public var items: [String] {
        didSet { clampSelection() }
    }

    /// The index of the currently selected item. -1 means no selection.
    public var selectedIndex: Int {
        didSet { clampSelection() }
    }

    /// Called when the selection changes.
    public var onChange: ((Int) -> Void)?

    /// Font size for item text.
    public var fontSize: Float

    /// Height of each row in pixels.
    public var rowHeight: Float = 28

    /// Current scroll offset in pixels.
    public var scrollOffset: Float = 0

    /// Scroll speed for mouse wheel (pixels per tick).
    public var scrollSpeed: Float = 30

    /// Whether to show the vertical scroll bar.
    public var showScrollBar: Bool = true

    /// Horizontal padding for item text.
    public var horizontalPadding: Float = 8

    private let scrollBarWidth: Float = 6

    public init(items: [String] = [], selectedIndex: Int = -1, fontSize: Float = 20) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.fontSize = fontSize
        super.init()
        self.isFocusable = true
    }

    // MARK: - Public API

    /// Select an item by index.
    public func select(_ index: Int) {
        let oldIndex = selectedIndex
        selectedIndex = index
        clampSelection()
        ensureSelectedVisible()
        if selectedIndex != oldIndex {
            onChange?(selectedIndex)
        }
    }

    /// Move the selection up or down by delta rows.
    public func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        let newIndex: Int
        if selectedIndex < 0 {
            newIndex = delta > 0 ? 0 : items.count - 1
        } else {
            newIndex = max(0, min(items.count - 1, selectedIndex + delta))
        }
        select(newIndex)
    }

    // MARK: - Layout

    public override func sizeThatFits(_ available: Size) -> Size {
        let contentHeight = Float(items.count) * rowHeight
        return Size(width: available.width, height: min(contentHeight, available.height))
    }

    // MARK: - Update

    public override func update(context: UIContext, deltaTime: Double) {
        guard isVisible, let app = context.app else { return }
        let input = app.input
        let mousePos = input.mousePosition

        // Mouse wheel scrolling
        if frame.contains(mousePos) {
            let delta = input.mouseScrollDelta
            if delta != 0 {
                scrollOffset -= delta * scrollSpeed
                clampScroll()
            }
        }

        // Mouse click to select
        if frame.contains(mousePos) && input.isMouseButtonPressed(.left) {
            let relativeY = mousePos.y - frame.y + scrollOffset
            let clickedRow = Int(relativeY / rowHeight)
            if clickedRow >= 0 && clickedRow < items.count {
                select(clickedRow)
            }
        }

        // Keyboard/gamepad navigation when focused
        if isFocused {
            let cfg = context.inputConfig
            if cfg.isUpPressed(input: input) {
                moveSelection(-1)
            }
            if cfg.isDownPressed(input: input) {
                moveSelection(1)
            }
        }
    }

    // MARK: - Render

    public override func render(renderer: any RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        // Background
        renderer.drawRect(frame, color: theme.panelColor)

        // Clip to bounds
        renderer.beginClip(frame)

        // Determine visible row range
        let firstVisible = max(0, Int(scrollOffset / rowHeight))
        let visibleRows = Int(frame.height / rowHeight) + 2
        let lastVisible = min(items.count, firstVisible + visibleRows)

        for i in firstVisible..<lastVisible {
            let rowY = frame.y + Float(i) * rowHeight - scrollOffset
            let rowRect = Rect(x: frame.x, y: rowY, width: frame.width, height: rowHeight)

            // Selection highlight
            if i == selectedIndex {
                renderer.drawRect(rowRect, color: theme.listSelectionColor)
            }

            // Item text
            let textY = rowY + (rowHeight - fontSize) / 2
            renderer.drawText(items[i],
                              position: Vector2(x: frame.x + horizontalPadding, y: textY),
                              font: theme.font, size: fontSize, color: theme.textColor)
        }

        renderer.endClip()

        // Scroll bar
        if showScrollBar {
            let contentHeight = Float(items.count) * rowHeight
            if contentHeight > frame.height {
                let ratio = frame.height / contentHeight
                let barHeight = max(frame.height * ratio, 20)
                let maxScroll = contentHeight - frame.height
                let scrollRatio = maxScroll > 0 ? scrollOffset / maxScroll : 0
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

        // Focus outline
        if isFocused {
            renderer.drawRectOutline(frame, color: theme.focusColor, thickness: 2)
        }

        // Border
        renderer.drawRectOutline(frame, color: theme.borderColor, thickness: 1)
    }

    // MARK: - Private Helpers

    private func clampSelection() {
        let clamped: Int
        if items.isEmpty {
            clamped = -1
        } else if selectedIndex >= items.count {
            clamped = items.count - 1
        } else {
            return
        }
        if selectedIndex != clamped {
            selectedIndex = clamped
        }
    }

    private func ensureSelectedVisible() {
        guard selectedIndex >= 0 else { return }
        let rowTop = Float(selectedIndex) * rowHeight
        let rowBottom = rowTop + rowHeight

        if rowTop < scrollOffset {
            scrollOffset = rowTop
        } else if rowBottom > scrollOffset + frame.height {
            scrollOffset = rowBottom - frame.height
        }
        clampScroll()
    }

    private func clampScroll() {
        let contentHeight = Float(items.count) * rowHeight
        let maxScroll = max(0, contentHeight - frame.height)
        scrollOffset = clamp(scrollOffset, min: 0, max: maxScroll)
    }
}
