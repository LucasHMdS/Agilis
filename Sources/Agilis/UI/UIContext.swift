import AgilisCore

/// Manages the UI tree, focus state, and input dispatch for a scene.
public final class UIContext: @unchecked Sendable {
    /// The root container. All UI elements are children of this.
    public let root: UIContainer

    /// The currently focused node (for keyboard navigation).
    public private(set) var focusedNode: UINode?

    /// The font handle used for text rendering.
    public let font: FontHandle

    /// The theme used for rendering.
    public var theme: UITheme

    /// Configurable input bindings for UI navigation.
    public var inputConfig: UIInputConfig = .default

    /// The application reference, set during update().
    public private(set) weak var app: Application?

    /// Whether layout needs to be recalculated.
    public var needsLayout: Bool = true

    /// Cached screen size for detecting resize.
    private var lastScreenSize: Size = .zero

    /// All focusable nodes in tab order.
    private var focusOrder: [UINode] = []
    private var focusIndex: Int = -1

    /// Previous mouse position for detecting mouse movement.
    private var lastMousePosition: Vector2 = .zero

    /// The currently active modal dialog, if any. When set, blocks normal UI input.
    public private(set) var activeModal: UIModalDialog?

    public init(font: FontHandle, theme: UITheme? = nil) {
        self.font = font
        self.theme = theme ?? .dark(font: font)
        self.root = UIContainer(id: "root")
        self.root.layout = .manual
    }

    /// Convenience: add a node directly to the root.
    @discardableResult
    public func add(_ node: UINode) -> Self {
        root.add(node)
        needsLayout = true
        return self
    }

    /// Call in the scene's update() method.
    public func update(app: Application, deltaTime: Double) {
        self.app = app
        let screenSize = app.renderer.screenSize
        if screenSize.width != lastScreenSize.width || screenSize.height != lastScreenSize.height {
            lastScreenSize = screenSize
            needsLayout = true
        }

        if needsLayout {
            let bounds = Rect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
            UILayoutEngine.performLayout(on: root, in: bounds,
                                         renderer: app.renderer, font: font)
            rebuildFocusOrder()
            needsLayout = false
        }

        // When a modal is active, only update the modal (blocks normal input)
        if let modal = activeModal {
            modal.layoutModal(renderer: app.renderer, font: font,
                              screenSize: screenSize, theme: theme)
            modal.updateModal(context: self, deltaTime: deltaTime)
            return
        }

        handleFocusNavigation(input: app.input)
        root.update(context: self, deltaTime: deltaTime)

        // If a modal was presented during root.update() (e.g. from a button action),
        // lay it out now so it doesn't render at (0,0) for one frame.
        if let modal = activeModal {
            modal.layoutModal(renderer: app.renderer, font: font,
                              screenSize: screenSize, theme: theme)
        }
    }

    /// Call in the scene's render() method.
    public func render(renderer: RenderBackend) {
        root.render(renderer: renderer, theme: theme)
        let screenSize = lastScreenSize
        root.renderOverlay(renderer: renderer, theme: theme, screenSize: screenSize)

        // Render modal on top of everything
        if let modal = activeModal {
            modal.renderModal(renderer: renderer, theme: theme, screenSize: screenSize)
        }
    }

    /// Set focus to a specific node.
    public func setFocus(_ node: UINode?) {
        focusedNode?.isFocused = false
        focusedNode = node
        focusedNode?.isFocused = true
        if let node {
            focusIndex = focusOrder.firstIndex(where: { $0 === node }) ?? -1
        } else {
            focusIndex = -1
        }
    }

    /// Mark layout as needing recalculation.
    public func invalidateLayout() {
        needsLayout = true
    }

    // MARK: - Modal Management

    /// Present a modal dialog. Blocks input to the normal UI tree.
    public func presentModal(_ modal: UIModalDialog) {
        activeModal = modal
    }

    /// Dismiss the current modal dialog.
    public func dismissModal() {
        activeModal = nil
    }

    // MARK: - Focus Management

    private func rebuildFocusOrder() {
        focusOrder = []
        collectFocusable(from: root)
        // Sync focusIndex with the rebuilt array
        if let node = focusedNode {
            focusIndex = focusOrder.firstIndex(where: { $0 === node }) ?? -1
            if focusIndex == -1 {
                // Focused node is no longer in the focus order
                focusedNode?.isFocused = false
                focusedNode = nil
            }
        } else {
            focusIndex = -1
        }
    }

    private func collectFocusable(from node: UINode) {
        if node.isFocusable && node.isVisible {
            focusOrder.append(node)
        }
        if let container = node as? UIContainer {
            for child in container.children {
                collectFocusable(from: child)
            }
        }
    }

    private func handleFocusNavigation(input: InputManager) {
        guard !focusOrder.isEmpty else { return }
        let cfg = inputConfig

        // Mouse movement clears keyboard/gamepad focus
        let mousePos = input.mousePosition
        if mousePos.x != lastMousePosition.x || mousePos.y != lastMousePosition.y {
            if focusedNode != nil && (input.isMouseButtonPressed(.left) ||
                abs(mousePos.x - lastMousePosition.x) > 2 ||
                abs(mousePos.y - lastMousePosition.y) > 2) {
                setFocus(nil)
            }
            lastMousePosition = mousePos
        }

        // When a dropdown is open or a list view is focused, Up/Down/Confirm
        // are consumed by the widget — skip focus navigation for those inputs.
        let widgetConsumesInput = isWidgetConsumingDirectionalInput()

        // Next focus / Down
        if cfg.isNextFocusPressed(input: input) {
            advanceFocus(forward: true)
        } else if !widgetConsumesInput && cfg.isDownPressed(input: input) {
            advanceFocus(forward: true)
        }

        // Prev focus / Up
        if cfg.isPrevFocusPressed(input: input) {
            advanceFocus(forward: false)
        } else if !widgetConsumesInput && cfg.isUpPressed(input: input) {
            advanceFocus(forward: false)
        }

        // Confirm: activate focused node (skip if widget handles it)
        if !widgetConsumesInput && cfg.isConfirmPressed(input: input) {
            if let button = focusedNode as? UIButton {
                button.activate()
            } else if let toggle = focusedNode as? UIToggle {
                toggle.toggle()
            }
        }

        // Left/Right for slider adjustment
        if let slider = focusedNode as? UISlider {
            if cfg.isLeftDown(input: input) {
                slider.adjustByStep(-1)
            }
            if cfg.isRightDown(input: input) {
                slider.adjustByStep(1)
            }
        }
    }

    /// Returns true if a focused widget is consuming Up/Down/Confirm input.
    private func isWidgetConsumingDirectionalInput() -> Bool {
        if let dropdown = focusedNode as? UIDropdown, dropdown.isOpen {
            return true
        }
        if focusedNode is UIListView {
            return true
        }
        return false
    }

    private func advanceFocus(forward: Bool) {
        guard !focusOrder.isEmpty else { return }
        if focusIndex >= focusOrder.count { focusIndex = focusOrder.count - 1 }

        if forward {
            focusIndex = (focusIndex + 1) % focusOrder.count
        } else {
            focusIndex = focusIndex <= 0 ? focusOrder.count - 1 : focusIndex - 1
        }

        setFocus(focusOrder[focusIndex])
    }
}
