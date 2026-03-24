/// A dropdown/select widget that shows a list of options when activated.
///
/// The dropdown button shows the currently selected option. When opened, a popup
/// list appears with all options. The popup automatically positions itself to stay
/// within screen bounds (opens downward by default, upward if insufficient space below).
///
/// ## Usage
/// ```swift
/// let dropdown = UIDropdown(options: ["Easy", "Normal", "Hard"], selectedIndex: 1)
/// dropdown.onChange = { index in print("Selected: \(dropdown.options[index])") }
/// ```
public class UIDropdown: UINode, @unchecked Sendable {
    /// The available options to choose from.
    public var options: [String] {
        didSet { cachedTextSize = nil; clampSelection() }
    }

    /// The index of the currently selected option.
    public var selectedIndex: Int {
        didSet { clampSelection() }
    }

    /// Called when the selection changes.
    public var onChange: ((Int) -> Void)?

    /// Font size for option text.
    public var fontSize: Float { didSet { if fontSize != oldValue { cachedTextSize = nil } } }

    /// Whether the popup list is currently visible.
    public private(set) var isOpen = false

    /// Maximum number of visible options before scrolling is enabled.
    public var maxVisibleOptions = 6

    /// Horizontal padding inside the button and each option row.
    public var horizontalPadding: Float = 12

    /// Vertical padding inside the button and each option row.
    public var verticalPadding: Float = 8

    /// Cached text measurement for the widest option, set by layout engine.
    internal var cachedTextSize: Size?

    /// Currently highlighted option index in the popup (mouse hover or keyboard).
    private var highlightedIndex = -1

    /// Scroll offset for the popup list when options exceed maxVisibleOptions.
    private var scrollOffset = 0

    /// Whether the popup opens upward (computed when opened).
    private var opensUpward = false

    /// Guards against multi-tick processing of the same press event.
    private var inputGuard = false

    /// The computed popup rect (set when opened, used for rendering).
    private var popupRect: Rect = .init(x: 0, y: 0, width: 0, height: 0)

    public init(options: [String] = [], selectedIndex: Int = 0, fontSize: Float = 20) {
        self.options = options
        self.selectedIndex = max(0, min(selectedIndex, max(0, options.count - 1)))
        self.fontSize = fontSize
        super.init()
        self.isFocusable = true
    }

    // MARK: - Public API

    /// Open the popup list.
    public func open() {
        guard !options.isEmpty else { return }
        isOpen = true
        highlightedIndex = selectedIndex
        scrollOffset = 0
        ensureHighlightedVisible()
    }

    /// Close the popup list.
    public func close() {
        isOpen = false
        highlightedIndex = -1
    }

    /// Toggle the popup open/closed.
    public func toggleOpen() {
        if isOpen { close() } else { open() }
    }

    /// Select the currently highlighted option and close.
    public func selectHighlighted() {
        guard isOpen, highlightedIndex >= 0, highlightedIndex < options.count else { return }
        let oldIndex = selectedIndex
        selectedIndex = highlightedIndex
        close()
        if selectedIndex != oldIndex {
            onChange?(selectedIndex)
        }
    }

    /// Move the highlight up or down by delta rows.
    public func moveHighlight(_ delta: Int) {
        guard isOpen, !options.isEmpty else { return }
        highlightedIndex = max(0, min(options.count - 1, highlightedIndex + delta))
        ensureHighlightedVisible()
    }

    // MARK: - Layout

    override public func sizeThatFits(_: Size) -> Size {
        let textSize = cachedTextSize ?? Size(width: 100, height: fontSize + 4)
        let arrowWidth: Float = 20
        return Size(width: textSize.width + horizontalPadding * 2 + arrowWidth,
                    height: textSize.height + verticalPadding * 2)
    }

    // MARK: - Update

    override public func update(context: UIContext, deltaTime _: Double) {
        guard isVisible, let app = context.app else { return }
        let input = app.input
        let mousePos = input.mousePosition

        // Prevent the same press event from being processed across multiple
        // fixed-timestep ticks within a single frame.
        if inputGuard {
            if !input.isMouseButtonPressed(.left) && !context.inputConfig.isConfirmPressed(input: input) {
                inputGuard = false
            }
            return
        }

        if isOpen {
            updateOpenState(input: input, mousePos: mousePos, context: context)
        } else {
            updateClosedState(input: input, mousePos: mousePos, context: context)
        }
    }

    private func updateClosedState(input: InputManager, mousePos: Vector2, context: UIContext) {
        // Mouse click on button opens the dropdown
        if frame.contains(mousePos) && input.isMouseButtonPressed(.left) {
            open()
            inputGuard = true
            computePopupRect(screenSize: context.app?.renderer.screenSize ?? Size(width: 800, height: 600))
            return
        }

        // Keyboard/gamepad confirm opens when focused
        if isFocused && context.inputConfig.isConfirmPressed(input: input) {
            open()
            inputGuard = true
            computePopupRect(screenSize: context.app?.renderer.screenSize ?? Size(width: 800, height: 600))
        }
    }

    private func updateOpenState(input: InputManager, mousePos: Vector2, context: UIContext) {
        let cfg = context.inputConfig
        let rowHeight = self.rowHeight

        // Keyboard/gamepad navigation
        if cfg.isUpPressed(input: input) {
            moveHighlight(-1)
            return
        }
        if cfg.isDownPressed(input: input) {
            moveHighlight(1)
            return
        }
        if cfg.isConfirmPressed(input: input) {
            selectHighlighted()
            inputGuard = true
            return
        }
        if cfg.isCancelPressed(input: input) {
            close()
            inputGuard = true
            return
        }

        // Mouse wheel scrolling
        let scrollDelta = input.mouseScrollDelta
        if scrollDelta != 0 && popupRect.contains(mousePos) {
            let visibleCount = min(options.count, maxVisibleOptions)
            let maxOffset = max(0, options.count - visibleCount)
            scrollOffset = max(0, min(maxOffset, scrollOffset - Int(scrollDelta)))
        }

        // Mouse hover highlights options
        if popupRect.contains(mousePos) {
            let relativeY = mousePos.y - popupRect.y
            let hoveredRow = Int(relativeY / rowHeight) + scrollOffset
            if hoveredRow >= 0 && hoveredRow < options.count {
                highlightedIndex = hoveredRow
            }
        }

        // Mouse click on option selects it
        if input.isMouseButtonPressed(.left) {
            if popupRect.contains(mousePos) {
                selectHighlighted()
                inputGuard = true
            } else if !frame.contains(mousePos) {
                // Click outside closes
                close()
                inputGuard = true
            } else {
                // Click on button toggles closed
                close()
                inputGuard = true
            }
        }
    }

    // MARK: - Render

    override public func render(renderer: any RenderBackend, theme: UITheme) {
        guard isVisible else { return }

        // Draw button background
        let bgColor = isOpen || isFocused ? theme.dropdownHoverColor : theme.dropdownColor
        renderer.drawRect(frame, color: bgColor)

        // Draw selected text
        let selectedText = options.indices.contains(selectedIndex) ? options[selectedIndex] : ""
        let textY = frame.y + (frame.height - fontSize) / 2
        renderer.drawText(selectedText,
                          position: Vector2(x: frame.x + horizontalPadding, y: textY),
                          font: theme.font,
                          size: fontSize,
                          color: theme.textColor)

        // Draw dropdown arrow
        let arrowSize: Float = 8
        let arrowX = frame.x + frame.width - horizontalPadding - arrowSize
        let arrowY = frame.y + frame.height / 2
        drawArrow(renderer: renderer,
                  x: arrowX,
                  y: arrowY,
                  size: arrowSize,
                  pointsDown: !isOpen,
                  color: theme.textColor)

        // Focus outline
        if isFocused {
            renderer.drawRectOutline(frame, color: theme.focusColor, thickness: 2)
        }
    }

    /// Draw the dropdown popup on top of everything else.
    override public func renderOverlay(renderer: any RenderBackend, theme: UITheme, screenSize _: Size) {
        guard isVisible, isOpen, !options.isEmpty else { return }

        let rowHeight = self.rowHeight
        let visibleCount = min(options.count, maxVisibleOptions)

        // Background
        renderer.drawRect(popupRect, color: theme.dropdownOptionColor)

        // Clip to popup bounds
        renderer.beginClip(popupRect)

        // Draw visible option rows
        for i in 0..<visibleCount {
            let optionIndex = i + scrollOffset
            guard optionIndex < options.count else { break }

            let rowY = popupRect.y + Float(i) * rowHeight
            let rowRect = Rect(x: popupRect.x, y: rowY, width: popupRect.width, height: rowHeight)

            // Highlight bar
            if optionIndex == highlightedIndex {
                renderer.drawRect(rowRect, color: theme.dropdownHighlightColor)
            }

            // Option text
            let textColor = optionIndex == highlightedIndex ? Color.white : theme.textColor
            let textY = rowY + (rowHeight - fontSize) / 2
            renderer.drawText(options[optionIndex],
                              position: Vector2(x: popupRect.x + horizontalPadding, y: textY),
                              font: theme.font,
                              size: fontSize,
                              color: textColor)
        }

        renderer.endClip()

        // Border
        renderer.drawRectOutline(popupRect, color: theme.borderColor, thickness: 1)

        // Scroll indicators if needed
        if options.count > maxVisibleOptions {
            let indicatorColor = Color(r: 160, g: 160, b: 160)
            if scrollOffset > 0 {
                // Up arrow indicator at top
                let cx = popupRect.x + popupRect.width - 10
                let cy = popupRect.y + 6
                drawArrow(renderer: renderer,
                          x: cx - 4,
                          y: cy,
                          size: 4,
                          pointsDown: false,
                          color: indicatorColor)
            }
            let visibleCount = min(options.count, maxVisibleOptions)
            if scrollOffset + visibleCount < options.count {
                // Down arrow indicator at bottom
                let cx = popupRect.x + popupRect.width - 10
                let cy = popupRect.y + popupRect.height - 6
                drawArrow(renderer: renderer,
                          x: cx - 4,
                          y: cy,
                          size: 4,
                          pointsDown: true,
                          color: indicatorColor)
            }
        }
    }

    // MARK: - Private Helpers

    private var rowHeight: Float {
        fontSize + verticalPadding * 2
    }

    private func clampSelection() {
        let clamped: Int
        if options.isEmpty {
            clamped = 0
        } else {
            clamped = max(0, min(selectedIndex, options.count - 1))
        }
        if selectedIndex != clamped {
            selectedIndex = clamped
        }
    }

    private func ensureHighlightedVisible() {
        let visibleCount = min(options.count, maxVisibleOptions)
        if highlightedIndex < scrollOffset {
            scrollOffset = highlightedIndex
        } else if highlightedIndex >= scrollOffset + visibleCount {
            scrollOffset = highlightedIndex - visibleCount + 1
        }
    }

    private func computePopupRect(screenSize: Size) {
        let rowHeight = self.rowHeight
        let visibleCount = min(options.count, maxVisibleOptions)
        let popupHeight = rowHeight * Float(visibleCount)
        let popupWidth = frame.width

        let spaceBelow = screenSize.height - (frame.y + frame.height)
        let spaceAbove = frame.y

        if popupHeight <= spaceBelow {
            // Opens downward (default)
            opensUpward = false
            popupRect = Rect(x: frame.x,
                             y: frame.y + frame.height,
                             width: popupWidth,
                             height: popupHeight)
        } else if popupHeight <= spaceAbove {
            // Opens upward
            opensUpward = true
            popupRect = Rect(x: frame.x,
                             y: frame.y - popupHeight,
                             width: popupWidth,
                             height: popupHeight)
        } else {
            // Open in direction with more space, clamp height
            if spaceBelow >= spaceAbove {
                opensUpward = false
                let clampedHeight = min(popupHeight, spaceBelow)
                popupRect = Rect(x: frame.x,
                                 y: frame.y + frame.height,
                                 width: popupWidth,
                                 height: clampedHeight)
            } else {
                opensUpward = true
                let clampedHeight = min(popupHeight, spaceAbove)
                popupRect = Rect(x: frame.x,
                                 y: frame.y - clampedHeight,
                                 width: popupWidth,
                                 height: clampedHeight)
            }
        }

        // Clamp horizontal to screen bounds
        if popupRect.x + popupRect.width > screenSize.width {
            popupRect = Rect(x: screenSize.width - popupRect.width,
                             y: popupRect.y,
                             width: popupRect.width,
                             height: popupRect.height)
        }
        if popupRect.x < 0 {
            popupRect = Rect(x: 0,
                             y: popupRect.y,
                             width: popupRect.width,
                             height: popupRect.height)
        }
    }

    private func drawArrow(renderer: any RenderBackend,
                           x: Float,
                           y: Float,
                           size: Float,
                           pointsDown: Bool,
                           color: Color) {
        if pointsDown {
            renderer.drawLine(
                from: Vector2(x: x, y: y - size / 2),
                to: Vector2(x: x + size, y: y + size / 2),
                color: color,
                thickness: 2
            )
            renderer.drawLine(
                from: Vector2(x: x + size, y: y + size / 2),
                to: Vector2(x: x + size * 2, y: y - size / 2),
                color: color,
                thickness: 2
            )
        } else {
            renderer.drawLine(
                from: Vector2(x: x, y: y + size / 2),
                to: Vector2(x: x + size, y: y - size / 2),
                color: color,
                thickness: 2
            )
            renderer.drawLine(
                from: Vector2(x: x + size, y: y - size / 2),
                to: Vector2(x: x + size * 2, y: y + size / 2),
                color: color,
                thickness: 2
            )
        }
    }
}
