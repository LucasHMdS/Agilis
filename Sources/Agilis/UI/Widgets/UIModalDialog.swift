

/// A modal dialog that overlays the entire screen with a dimmed background.
///
/// When presented via `UIContext.presentModal()`, the dialog blocks input to the
/// normal UI tree and traps focus within its own button container.
///
/// ## Usage
/// ```swift
/// let modal = UIModalDialog(title: "Confirm")
/// modal.addContent(UILabel("Are you sure?"))
/// modal.addOKCancel(
///     onOK: { print("Confirmed") },
///     onCancel: { print("Cancelled") }
/// )
/// uiContext.presentModal(modal)
/// ```
public class UIModalDialog: UINode, @unchecked Sendable {
    /// The dialog title text.
    public var title: String

    /// Container for the dialog body content.
    public let contentContainer: UIContainer

    /// Container for action buttons at the bottom.
    public let buttonContainer: UIContainer

    /// Called when the dialog is dismissed.
    public var onDismiss: (() -> Void)?

    /// Whether the cancel input binding (from UIInputConfig) dismisses the dialog.
    public var dismissOnCancel: Bool = true

    /// The semi-transparent overlay color behind the dialog.
    public var overlayColor: Color

    /// The width of the dialog box.
    public var dialogWidth: Float = 400

    /// Font size for the title.
    public var titleFontSize: Float = 24

    /// Padding inside the dialog.
    public var dialogPadding: Float = 16

    /// Spacing between title, content, and buttons.
    public var sectionSpacing: Float = 12

    /// The computed dialog rect (set during layout).
    internal var dialogRect: Rect = Rect(x: 0, y: 0, width: 0, height: 0)

    /// Cached title text size.
    internal var cachedTitleSize: Size?

    /// Focus order within the modal.
    private var modalFocusOrder: [UINode] = []
    private var modalFocusIndex: Int = -1

    public init(title: String, overlayColor: Color? = nil) {
        self.title = title
        self.overlayColor = overlayColor ?? Color(r: 0, g: 0, b: 0, a: 150)
        self.contentContainer = UIContainer(id: "modal-content")
        self.contentContainer.layout = .vertical(spacing: 8)
        self.buttonContainer = UIContainer(id: "modal-buttons")
        self.buttonContainer.layout = .horizontal(spacing: 12)
        super.init(id: "modal-dialog")
    }

    // MARK: - Builder API

    /// Add a node to the content area.
    @discardableResult
    public func addContent(_ node: UINode) -> Self {
        contentContainer.add(node)
        return self
    }

    /// Add a button to the button bar.
    @discardableResult
    public func addButton(_ text: String, fontSize: Float = 20, action: @escaping () -> Void) -> Self {
        let button = UIButton(text, fontSize: fontSize, action: action)
        buttonContainer.add(button)
        return self
    }

    /// Add OK and Cancel buttons.
    @discardableResult
    public func addOKCancel(
        okText: String = "OK",
        cancelText: String = "Cancel",
        fontSize: Float = 20,
        onOK: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) -> Self {
        addButton(okText, fontSize: fontSize, action: onOK)
        addButton(cancelText, fontSize: fontSize, action: onCancel)
        return self
    }

    // MARK: - Modal Input Handling

    /// Called by UIContext during modal update.
    internal func updateModal(context: UIContext, deltaTime: Double) {
        guard let app = context.app else { return }
        let input = app.input
        let cfg = context.inputConfig

        // Cancel dismisses the dialog
        if dismissOnCancel && cfg.isCancelPressed(input: input) {
            context.dismissModal()
            onDismiss?()
            return
        }

        // Focus navigation within modal buttons
        if cfg.isNextFocusPressed(input: input) || cfg.isDownPressed(input: input)
            || cfg.isRightDown(input: input) {
            advanceModalFocus(forward: true)
        }
        if cfg.isPrevFocusPressed(input: input) || cfg.isUpPressed(input: input)
            || cfg.isLeftDown(input: input) {
            advanceModalFocus(forward: false)
        }

        // Confirm activates focused button
        if cfg.isConfirmPressed(input: input) {
            if let button = currentModalFocusedNode() as? UIButton {
                button.activate()
            }
        }

        // Update content and button containers normally (for mouse interaction)
        contentContainer.update(context: context, deltaTime: deltaTime)
        buttonContainer.update(context: context, deltaTime: deltaTime)
    }

    // MARK: - Modal Layout

    /// Called by UIContext to layout the modal centered on screen.
    internal func layoutModal(renderer: Renderer, font: FontHandle, screenSize: Size, theme: UITheme) {
        // Measure title
        cachedTitleSize = renderer.measureText(title, font: font, size: titleFontSize)

        let titleHeight = (cachedTitleSize?.height ?? titleFontSize) + dialogPadding * 2

        // Layout content container to measure its size
        let contentWidth = dialogWidth - dialogPadding * 2
        let contentAvailable = Size(width: contentWidth, height: screenSize.height * 0.5)
        measureAllText(in: contentContainer, renderer: renderer, font: font)
        measureAllText(in: buttonContainer, renderer: renderer, font: font)
        let contentSize = contentContainer.sizeThatFits(contentAvailable)
        let buttonSize = buttonContainer.sizeThatFits(contentAvailable)

        // Compute dialog height
        let dialogHeight = min(
            titleHeight + contentSize.height + sectionSpacing + buttonSize.height + sectionSpacing + dialogPadding,
            screenSize.height - 40
        )

        // Center on screen
        let x = (screenSize.width - dialogWidth) / 2
        let y = (screenSize.height - dialogHeight) / 2
        dialogRect = Rect(x: x, y: y, width: dialogWidth, height: dialogHeight)

        // Layout content area
        let contentY = y + titleHeight + sectionSpacing
        let contentBounds = Rect(x: x + dialogPadding, y: contentY,
                                 width: contentWidth, height: contentSize.height)
        UILayoutEngine.performLayout(on: contentContainer, in: contentBounds,
                                     renderer: renderer, font: font)

        // Layout button area (centered at bottom)
        let buttonY = y + dialogHeight - dialogPadding - buttonSize.height
        let buttonBounds = Rect(x: x + dialogPadding, y: buttonY,
                                width: contentWidth, height: buttonSize.height)
        UILayoutEngine.performLayout(on: buttonContainer, in: buttonBounds,
                                     renderer: renderer, font: font)

        // Rebuild modal focus order
        rebuildModalFocusOrder()
    }

    // MARK: - Modal Rendering

    /// Called by UIContext to render the modal on top of everything.
    internal func renderModal(renderer: Renderer, theme: UITheme, screenSize: Size) {
        // Dim overlay
        let overlayRect = Rect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
        renderer.drawRect(overlayRect, color: overlayColor)

        // Dialog background
        renderer.drawRect(dialogRect, color: theme.panelColor)

        // Title bar
        let titleBarHeight = (cachedTitleSize?.height ?? titleFontSize) + dialogPadding * 2
        let titleBarRect = Rect(x: dialogRect.x, y: dialogRect.y,
                                width: dialogRect.width, height: titleBarHeight)
        renderer.drawRect(titleBarRect, color: theme.modalTitleBarColor)

        // Title text centered in title bar
        let titleSize = cachedTitleSize ?? Size(width: 0, height: titleFontSize)
        let titleX = dialogRect.x + (dialogRect.width - titleSize.width) / 2
        let titleY = dialogRect.y + (titleBarHeight - titleSize.height) / 2
        renderer.drawText(title,
                          position: Vector2(x: titleX, y: titleY),
                          font: theme.font, size: titleFontSize, color: theme.modalTitleColor)

        // Content
        contentContainer.render(renderer: renderer, theme: theme)

        // Buttons
        buttonContainer.render(renderer: renderer, theme: theme)

        // Dialog border
        renderer.drawRectOutline(dialogRect, color: theme.borderColor, thickness: 1)
    }

    // MARK: - Private Focus Management

    private func rebuildModalFocusOrder() {
        modalFocusOrder = []
        collectFocusable(from: contentContainer)
        collectFocusable(from: buttonContainer)
        // Auto-focus first button if available
        if !modalFocusOrder.isEmpty && modalFocusIndex < 0 {
            modalFocusIndex = 0
            setModalFocus(modalFocusOrder[0])
        }
    }

    private func collectFocusable(from node: UINode) {
        if node.isFocusable && node.isVisible {
            modalFocusOrder.append(node)
        }
        if let container = node as? UIContainer {
            for child in container.children {
                collectFocusable(from: child)
            }
        }
    }

    private func advanceModalFocus(forward: Bool) {
        guard !modalFocusOrder.isEmpty else { return }
        if modalFocusIndex >= modalFocusOrder.count { modalFocusIndex = modalFocusOrder.count - 1 }
        // Clear old focus
        currentModalFocusedNode()?.isFocused = false

        if forward {
            modalFocusIndex = (modalFocusIndex + 1) % modalFocusOrder.count
        } else {
            modalFocusIndex = modalFocusIndex <= 0 ? modalFocusOrder.count - 1 : modalFocusIndex - 1
        }
        setModalFocus(modalFocusOrder[modalFocusIndex])
    }

    private func setModalFocus(_ node: UINode) {
        for n in modalFocusOrder { n.isFocused = false }
        node.isFocused = true
    }

    private func currentModalFocusedNode() -> UINode? {
        guard modalFocusIndex >= 0, modalFocusIndex < modalFocusOrder.count else { return nil }
        return modalFocusOrder[modalFocusIndex]
    }

    private func measureAllText(in node: UINode, renderer: Renderer, font: FontHandle) {
        if let label = node as? UILabel {
            label.cachedTextSize = renderer.measureText(label.text, font: font, size: label.fontSize)
        } else if let button = node as? UIButton {
            button.cachedTextSize = renderer.measureText(button.text, font: font, size: button.fontSize)
        }
        if let container = node as? UIContainer {
            for child in container.children {
                measureAllText(in: child, renderer: renderer, font: font)
            }
        }
    }
}
