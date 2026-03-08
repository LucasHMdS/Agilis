@testable import Agilis
import Testing

// MARK: - UIInputConfig Tests

@Suite("UIInputConfig Tests")
struct UIInputConfigTests {

    @Test func defaultHasKeyboardNoGamepad() {
        let config = UIInputConfig.default
        #expect(config.keyboard != nil)
        #expect(config.gamepad == nil)
    }

    @Test func keyboardAndGamepadPreset() {
        let config = UIInputConfig.keyboardAndGamepad
        #expect(config.keyboard != nil)
        #expect(config.gamepad != nil)
        #expect(config.gamepad?.gamepadIndex == 0)
    }

    @Test func keyboardDefaults() {
        let kb = UIInputConfig.KeyboardConfig.default
        #expect(kb.confirm.contains(.enter))
        #expect(kb.confirm.contains(.space))
        #expect(kb.cancel.contains(.escape))
        #expect(kb.up.contains(.up))
        #expect(kb.down.contains(.down))
        #expect(kb.left.contains(.left))
        #expect(kb.right.contains(.right))
        #expect(kb.nextFocus.contains(.tab))
        #expect(kb.shiftForPrevFocus == true)
    }

    @Test func gamepadDefaults() {
        let gp = UIInputConfig.GamepadConfig.default
        #expect(gp.gamepadIndex == 0)
        #expect(gp.confirm.contains(.faceDown))
        #expect(gp.cancel.contains(.faceRight))
        #expect(gp.up.contains(.dpadUp))
        #expect(gp.down.contains(.dpadDown))
        #expect(gp.nextFocus.contains(.rightBumper))
        #expect(gp.prevFocus.contains(.leftBumper))
    }

    @Test func isConfirmPressedKeyboard() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        let config = UIInputConfig.default

        // No keys pressed
        input.update()
        #expect(config.isConfirmPressed(input: input) == false)

        // Press enter
        backend.keysDown = [.enter]
        input.update()
        #expect(config.isConfirmPressed(input: input) == true)
    }

    @Test func isCancelPressedKeyboard() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        let config = UIInputConfig.default

        backend.keysDown = [.escape]
        input.update()
        #expect(config.isCancelPressed(input: input) == true)
    }

    @Test func isUpDownPressed() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        let config = UIInputConfig.default

        backend.keysDown = [.up]
        input.update()
        #expect(config.isUpPressed(input: input) == true)
        #expect(config.isDownPressed(input: input) == false)

        backend.keysDown = []
        input.update()
        backend.keysDown = [.down]
        input.update()
        #expect(config.isDownPressed(input: input) == true)
    }

    @Test func isNextFocusPressedWithShift() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        let config = UIInputConfig.default

        // Tab without shift = next focus
        backend.keysDown = [.tab]
        input.update()
        #expect(config.isNextFocusPressed(input: input) == true)
        #expect(config.isPrevFocusPressed(input: input) == false)

        // Shift+Tab = prev focus
        backend.keysDown = []
        input.update()
        backend.keysDown = [.tab, .leftShift]
        input.update()
        #expect(config.isNextFocusPressed(input: input) == false)
        #expect(config.isPrevFocusPressed(input: input) == true)
    }

    @Test func disabledKeyboard() {
        let config = UIInputConfig(keyboard: nil, gamepad: nil)
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.keysDown = [.enter]
        input.update()
        #expect(config.isConfirmPressed(input: input) == false)
    }

    @Test func customKeyBindings() {
        var kb = UIInputConfig.KeyboardConfig.default
        kb.confirm = [.z]
        let config = UIInputConfig(keyboard: kb)

        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        // Enter should NOT confirm with custom binding
        backend.keysDown = [.enter]
        input.update()
        #expect(config.isConfirmPressed(input: input) == false)

        // Z should confirm
        backend.keysDown = []
        input.update()
        backend.keysDown = [.z]
        input.update()
        #expect(config.isConfirmPressed(input: input) == true)
    }

    @Test func contextUsesInputConfig() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let button1 = UIButton("A")
        button1.frame = Rect(x: 10, y: 10, width: 80, height: 30)
        let button2 = UIButton("B")
        button2.frame = Rect(x: 10, y: 50, width: 80, height: 30)
        ui.root.add(button1)
        ui.root.add(button2)

        // Layout pass
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Tab navigates focus (uses inputConfig)
        inputBackend.keysDown = [.tab]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(ui.focusedNode === button1)
    }
}

// MARK: - NinePatchSprite Tests

@Suite("NinePatchSprite Tests")
struct NinePatchSpriteTests {

    @Test func uniformBorderInit() {
        let patch = NinePatchSprite(
            texture: TextureHandle(id: 1),
            sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
            border: 12
        )
        #expect(patch.borderTop == 12)
        #expect(patch.borderRight == 12)
        #expect(patch.borderBottom == 12)
        #expect(patch.borderLeft == 12)
        #expect(patch.tint == .white)
    }

    @Test func perSideBorderInit() {
        let patch = NinePatchSprite(
            texture: TextureHandle(id: 1),
            sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
            borderTop: 8,
            borderRight: 10,
            borderBottom: 12,
            borderLeft: 6,
            tint: .red
        )
        #expect(patch.borderTop == 8)
        #expect(patch.borderRight == 10)
        #expect(patch.borderBottom == 12)
        #expect(patch.borderLeft == 6)
        #expect(patch.tint == .red)
    }

    @Test func drawNinePatchDraws9Sprites() {
        let renderer = MockRenderer()
        let patch = NinePatchSprite(
            texture: TextureHandle(id: 1),
            sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
            border: 12
        )
        renderer.drawCalls = []
        renderer.drawNinePatch(patch, destination: Rect(x: 10, y: 10, width: 200, height: 100))
        let spriteCount = renderer.drawCalls.filter { $0 == "sprite" }.count
        #expect(spriteCount == 9)
    }

    @Test func drawNinePatchTinyDestFallback() {
        let renderer = MockRenderer()
        let patch = NinePatchSprite(
            texture: TextureHandle(id: 1),
            sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
            border: 20
        )
        renderer.drawCalls = []
        // Destination smaller than borders → single sprite fallback
        renderer.drawNinePatch(patch, destination: Rect(x: 0, y: 0, width: 30, height: 30))
        let spriteCount = renderer.drawCalls.filter { $0 == "sprite" }.count
        #expect(spriteCount == 1)
    }
}

// MARK: - UIDropdown Tests

@Suite("UIDropdown Tests")
struct UIDropdownTests {

    @Test func defaultProperties() {
        let dropdown = UIDropdown(options: ["A", "B", "C"], selectedIndex: 1)
        #expect(dropdown.options.count == 3)
        #expect(dropdown.selectedIndex == 1)
        #expect(dropdown.isOpen == false)
        #expect(dropdown.isFocusable == true)
        #expect(dropdown.maxVisibleOptions == 6)
    }

    @Test func selectedIndexClampedOnInit() {
        let dropdown = UIDropdown(options: ["A", "B"], selectedIndex: 10)
        #expect(dropdown.selectedIndex == 1) // clamped to last
    }

    @Test func emptyOptionsDoesNotCrash() {
        let dropdown = UIDropdown(options: [])
        #expect(dropdown.selectedIndex == 0)
        dropdown.open()
        #expect(dropdown.isOpen == false) // can't open with no options
    }

    @Test func openAndClose() {
        let dropdown = UIDropdown(options: ["X", "Y", "Z"])
        dropdown.open()
        #expect(dropdown.isOpen == true)
        dropdown.close()
        #expect(dropdown.isOpen == false)
    }

    @Test func toggleOpen() {
        let dropdown = UIDropdown(options: ["A", "B"])
        dropdown.toggleOpen()
        #expect(dropdown.isOpen == true)
        dropdown.toggleOpen()
        #expect(dropdown.isOpen == false)
    }

    @Test func moveHighlight() {
        let dropdown = UIDropdown(options: ["A", "B", "C"], selectedIndex: 0)
        dropdown.open()
        // Highlighted starts at selectedIndex (0)
        dropdown.moveHighlight(1)
        dropdown.selectHighlighted()
        #expect(dropdown.selectedIndex == 1)
    }

    @Test func moveHighlightClampsToRange() {
        let dropdown = UIDropdown(options: ["A", "B", "C"], selectedIndex: 0)
        dropdown.open()
        dropdown.moveHighlight(-10) // clamp to 0
        dropdown.selectHighlighted()
        #expect(dropdown.selectedIndex == 0)

        dropdown.open()
        dropdown.moveHighlight(100) // clamp to last
        dropdown.selectHighlighted()
        #expect(dropdown.selectedIndex == 2)
    }

    @Test func onChangeCallback() {
        var received: Int?
        let dropdown = UIDropdown(options: ["A", "B", "C"], selectedIndex: 0)
        dropdown.onChange = { received = $0 }

        dropdown.open()
        dropdown.moveHighlight(2) // to "C"
        dropdown.selectHighlighted()

        #expect(received == 2)
    }

    @Test func onChangeNotCalledWhenSameIndex() {
        var callCount = 0
        let dropdown = UIDropdown(options: ["A", "B"], selectedIndex: 0)
        dropdown.onChange = { _ in callCount += 1 }

        dropdown.open()
        // Highlighted starts at 0, select without moving
        dropdown.selectHighlighted()

        #expect(callCount == 0)
    }

    @Test func sizeThatFitsUsesWidestOption() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let dropdown = UIDropdown(options: ["A", "Longer Option", "B"], fontSize: 20)

        // Simulate layout engine measurement
        var maxSize = Size(width: 0, height: 0)
        for option in dropdown.options {
            let size = renderer.measureText(option, font: font, size: dropdown.fontSize)
            if size.width > maxSize.width { maxSize.width = size.width }
            if size.height > maxSize.height { maxSize.height = size.height }
        }
        dropdown.cachedTextSize = maxSize

        let size = dropdown.sizeThatFits(Size(width: 800, height: 600))
        // Width should include padding + arrow
        #expect(size.width > maxSize.width)
        #expect(size.height > maxSize.height)
    }

    @Test func renderDrawsButtonAndText() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let dropdown = UIDropdown(options: ["Hello", "World"], selectedIndex: 0)
        dropdown.frame = Rect(x: 10, y: 10, width: 150, height: 36)

        renderer.drawCalls = []
        dropdown.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("rect")) // background
        #expect(renderer.drawCalls.contains("text:Hello")) // selected text
        #expect(renderer.drawCalls.contains("line")) // arrow
    }

    @Test func renderOverlayDrawsPopupWhenOpen() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let dropdown = UIDropdown(options: ["A", "B", "C"], selectedIndex: 0)
        dropdown.frame = Rect(x: 10, y: 10, width: 150, height: 36)

        // Not open → overlay draws nothing
        renderer.drawCalls = []
        dropdown.renderOverlay(renderer: renderer, theme: theme, screenSize: Size(width: 800, height: 600))
        #expect(renderer.drawCalls.isEmpty)

        // Open → overlay draws popup
        dropdown.open()
        renderer.drawCalls = []
        dropdown.renderOverlay(renderer: renderer, theme: theme, screenSize: Size(width: 800, height: 600))
        #expect(renderer.drawCalls.contains("beginClip"))
        #expect(renderer.drawCalls.contains("endClip"))
    }

    @Test func mouseClickOpensAndSelects() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let dropdown = UIDropdown(options: ["A", "B", "C"], selectedIndex: 0)
        dropdown.frame = Rect(x: 100, y: 100, width: 150, height: 36)
        ui.root.add(dropdown)
        ui.needsLayout = false

        // Click on dropdown button to open
        inputBackend.currentMousePosition = Vector2(x: 150, y: 115)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(dropdown.isOpen == true)
    }

    @Test func updatingOptionsClampSelection() {
        let dropdown = UIDropdown(options: ["A", "B", "C"], selectedIndex: 2)
        #expect(dropdown.selectedIndex == 2)
        dropdown.options = ["A"]
        #expect(dropdown.selectedIndex == 0) // clamped
    }
}

// MARK: - UIListView Tests

@Suite("UIListView Tests")
struct UIListViewTests {

    @Test func defaultProperties() {
        let list = UIListView(items: ["A", "B", "C"])
        #expect(list.items.count == 3)
        #expect(list.selectedIndex == -1)
        #expect(list.scrollOffset == 0)
        #expect(list.isFocusable == true)
        #expect(list.showScrollBar == true)
    }

    @Test func selectItem() {
        var received: Int?
        let list = UIListView(items: ["A", "B", "C"])
        list.onChange = { received = $0 }

        list.select(1)
        #expect(list.selectedIndex == 1)
        #expect(received == 1)
    }

    @Test func selectSameIndexNotifiesOnChange() {
        var callCount = 0
        let list = UIListView(items: ["A", "B"], selectedIndex: 0)
        list.onChange = { _ in callCount += 1 }

        list.select(0)
        // Same index → no callback (different behavior: -1 → 0 does fire)
        #expect(callCount == 0)
    }

    @Test func moveSelectionDown() {
        let list = UIListView(items: ["A", "B", "C"], selectedIndex: 0)
        list.moveSelection(1)
        #expect(list.selectedIndex == 1)
        list.moveSelection(1)
        #expect(list.selectedIndex == 2)
    }

    @Test func moveSelectionClamps() {
        let list = UIListView(items: ["A", "B", "C"], selectedIndex: 0)
        list.moveSelection(-1) // already at 0
        #expect(list.selectedIndex == 0)

        list.moveSelection(100) // clamp to last
        #expect(list.selectedIndex == 2)
    }

    @Test func moveSelectionFromNone() {
        let list = UIListView(items: ["A", "B", "C"])
        #expect(list.selectedIndex == -1)

        list.moveSelection(1) // forward from none → first
        #expect(list.selectedIndex == 0)
    }

    @Test func renderDrawsItems() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let list = UIListView(items: ["Alpha", "Beta"], selectedIndex: 0)
        list.frame = Rect(x: 10, y: 10, width: 200, height: 100)

        renderer.drawCalls = []
        list.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("beginClip"))
        #expect(renderer.drawCalls.contains("endClip"))
        #expect(renderer.drawCalls.contains("text:Alpha"))
        #expect(renderer.drawCalls.contains("text:Beta"))
    }

    @Test func renderDrawsSelectionHighlight() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let list = UIListView(items: ["A", "B"], selectedIndex: 0)
        list.frame = Rect(x: 0, y: 0, width: 200, height: 100)

        renderer.drawCalls = []
        list.render(renderer: renderer, theme: theme)

        // Should have rects for: panel bg, selection highlight, border, and potentially scrollbar
        let rectCount = renderer.drawCalls.filter { $0 == "rect" }.count
        #expect(rectCount >= 2) // at least bg + selection
    }

    @Test func mouseClickSelects() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let list = UIListView(items: ["A", "B", "C"])
        list.frame = Rect(x: 100, y: 100, width: 200, height: 200)
        list.rowHeight = 28
        ui.root.add(list)
        ui.needsLayout = false

        // Click on second row (y=100 + 28 = within row 1)
        inputBackend.currentMousePosition = Vector2(x: 150, y: 130)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(list.selectedIndex == 1)
    }

    @Test func updatingItemsClampSelection() {
        let list = UIListView(items: ["A", "B", "C"], selectedIndex: 2)
        #expect(list.selectedIndex == 2)
        list.items = ["A"]
        #expect(list.selectedIndex == 0)
    }

    @Test func emptyListRenders() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let list = UIListView(items: [])
        list.frame = Rect(x: 0, y: 0, width: 200, height: 100)

        renderer.drawCalls = []
        list.render(renderer: renderer, theme: theme)

        // Should still draw bg and border without crashing
        #expect(renderer.drawCalls.contains("rect"))
    }
}

// MARK: - UIModalDialog Tests

@Suite("UIModalDialog Tests")
struct UIModalDialogTests {

    @Test func defaultProperties() {
        let modal = UIModalDialog(title: "Test")
        #expect(modal.title == "Test")
        #expect(modal.dismissOnCancel == true)
        #expect(modal.dialogWidth == 400)
    }

    @Test func addContentBuilder() {
        let modal = UIModalDialog(title: "Test")
        let result = modal.addContent(UILabel("Hello"))
        #expect(result === modal) // returns self
        #expect(modal.contentContainer.children.count == 1)
    }

    @Test func addButtonBuilder() {
        let modal = UIModalDialog(title: "Test")
        modal.addButton("OK") {}
        #expect(modal.buttonContainer.children.count == 1)
        #expect((modal.buttonContainer.children[0] as? UIButton)?.text == "OK")
    }

    @Test func addOKCancelBuilder() {
        let modal = UIModalDialog(title: "Confirm")
        modal.addOKCancel(onOK: {}, onCancel: {})
        #expect(modal.buttonContainer.children.count == 2)
        #expect((modal.buttonContainer.children[0] as? UIButton)?.text == "OK")
        #expect((modal.buttonContainer.children[1] as? UIButton)?.text == "Cancel")
    }

    @Test func presentAndDismissModal() {
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        #expect(ui.activeModal == nil)

        let modal = UIModalDialog(title: "Test")
        ui.presentModal(modal)
        #expect(ui.activeModal === modal)

        ui.dismissModal()
        #expect(ui.activeModal == nil)
    }

    @Test func modalBlocksNormalInput() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        var buttonClicked = false
        let button = UIButton("Background") { buttonClicked = true }
        button.frame = Rect(x: 100, y: 100, width: 120, height: 40)
        ui.root.add(button)
        ui.needsLayout = false

        // Present modal
        let modal = UIModalDialog(title: "Blocking")
        modal.addButton("OK") {}
        ui.presentModal(modal)

        // Click on background button — should NOT trigger
        inputBackend.currentMousePosition = Vector2(x: 150, y: 120)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        #expect(!buttonClicked)
    }

    @Test func modalRenders() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let modal = UIModalDialog(title: "Hello")
        modal.addContent(UILabel("Content"))
        modal.addButton("OK") {}

        modal.layoutModal(
            renderer: renderer,
            font: font,
            screenSize: Size(width: 800, height: 600),
            theme: theme
        )

        renderer.drawCalls = []
        modal.renderModal(
            renderer: renderer,
            theme: theme,
            screenSize: Size(width: 800, height: 600)
        )

        // Should draw overlay, dialog bg, title bar, title text, content, button, border
        #expect(renderer.drawCalls.contains("rect"))
        #expect(renderer.drawCalls.contains("text:Hello"))
        #expect(renderer.drawCalls.contains("rectOutline"))
    }

    @Test func onDismissCallback() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        var dismissed = false
        let modal = UIModalDialog(title: "Test")
        modal.onDismiss = { dismissed = true }
        ui.presentModal(modal)

        // Press Escape (cancel) to dismiss
        inputBackend.keysDown = [.escape]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        #expect(dismissed)
        #expect(ui.activeModal == nil)
    }

    @Test func dismissOnCancelDisabled() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let modal = UIModalDialog(title: "Sticky")
        modal.dismissOnCancel = false
        ui.presentModal(modal)

        // Press Escape — should NOT dismiss
        inputBackend.keysDown = [.escape]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        #expect(ui.activeModal != nil)
    }

    @Test func dialogCentered() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let modal = UIModalDialog(title: "Center Test")
        modal.dialogWidth = 300

        modal.layoutModal(
            renderer: renderer,
            font: font,
            screenSize: Size(width: 800, height: 600),
            theme: theme
        )

        // Should be horizontally centered
        let expectedX = (800 - 300) / Float(2)
        #expect(abs(modal.dialogRect.x - expectedX) < 1)
    }
}

// MARK: - UITheme New Properties Tests

@Suite("UITheme Widget Properties Tests")
struct UIThemeWidgetPropertiesTests {

    @Test func darkThemeHasDropdownColors() {
        let font = FontHandle(id: 1)
        let theme = UITheme.dark(font: font)
        #expect(theme.dropdownColor.r == 60)
        #expect(theme.dropdownHighlightColor.r == 0) // blue highlight
        #expect(theme.dropdownOptionColor.r == 45)
    }

    @Test func darkThemeHasListColors() {
        let font = FontHandle(id: 1)
        let theme = UITheme.dark(font: font)
        #expect(theme.listSelectionColor.a == 160)
    }

    @Test func darkThemeHasModalColors() {
        let font = FontHandle(id: 1)
        let theme = UITheme.dark(font: font)
        #expect(theme.modalOverlayColor.a == 150)
        #expect(theme.modalTitleColor == .white)
        #expect(theme.modalTitleBarColor.r == 50)
    }

    @Test func lightThemeHasWidgetColors() {
        let font = FontHandle(id: 1)
        let theme = UITheme.light(font: font)
        #expect(theme.dropdownColor.r == 210)
        #expect(theme.dropdownOptionColor.r == 245)
        #expect(theme.modalTitleColor == Color(r: 20, g: 20, b: 20))
    }
}

// MARK: - renderOverlay Tests

@Suite("renderOverlay Tests")
struct RenderOverlayTests {

    @Test func nodeRenderOverlayIsNoOp() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let node = UINode()
        renderer.drawCalls = []
        node.renderOverlay(renderer: renderer, theme: theme, screenSize: Size(width: 800, height: 600))
        #expect(renderer.drawCalls.isEmpty)
    }

    @Test func containerRecursesRenderOverlay() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let container = UIContainer()
        let dropdown = UIDropdown(options: ["A", "B"], selectedIndex: 0)
        dropdown.frame = Rect(x: 10, y: 10, width: 150, height: 36)
        dropdown.open()
        container.add(dropdown)

        renderer.drawCalls = []
        container.renderOverlay(renderer: renderer, theme: theme, screenSize: Size(width: 800, height: 600))

        // Should have drawn popup (beginClip from dropdown overlay)
        #expect(renderer.drawCalls.contains("beginClip"))
    }

    @Test func hiddenContainerSkipsOverlay() {
        let renderer = MockRenderer()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let container = UIContainer()
        container.isVisible = false
        let dropdown = UIDropdown(options: ["A", "B"])
        dropdown.open()
        container.add(dropdown)

        renderer.drawCalls = []
        container.renderOverlay(renderer: renderer, theme: theme, screenSize: Size(width: 800, height: 600))
        #expect(renderer.drawCalls.isEmpty)
    }
}

// MARK: - UIDemo Dropdown Crash Reproduction

@Suite("UIDemo Dropdown Reproduction")
struct UIDemoDropdownReproduction {

    // Helper: create the UIDemo-like widget tree
    private static func makeUIDemoWidgets(app _: Application, renderer: MockRenderer) -> (UIContext, UIDropdown, UILabel, UIListView) {
        let font = renderer.loadDefaultFont()
        let ui = UIContext(font: font)
        ui.inputConfig = .keyboardAndGamepad

        let panel = UIContainer(id: "main")
        panel.layout = .vertical(spacing: 12, alignment: .center)

        panel.add(UILabel("Agilis UI Demo", fontSize: 32))
        panel.add(UILabel("Cross-platform", fontSize: 16))
        panel.add(UILabel("Clicks: 0", fontSize: 20))
        panel.add(UIButton("Click Me!", fontSize: 22) {})
        panel.add(UIProgressBar(value: 0))
        panel.add(UISlider("Volume", value: 0.75, range: 0...1))
        panel.add(UILabel("Dark Mode: OFF", fontSize: 16))
        panel.add(UIToggle("Dark Mode", isOn: false) { _ in })

        let difficultyLabel = UILabel("Difficulty: Normal", fontSize: 16)
        panel.add(difficultyLabel)

        let dropdown = UIDropdown(
            options: ["Easy", "Normal", "Hard", "Nightmare"],
            selectedIndex: 1,
            fontSize: 20
        )
        dropdown.onChange = { index in
            let names = ["Easy", "Normal", "Hard", "Nightmare"]
            difficultyLabel.text = "Difficulty: \(names[index])"
            ui.invalidateLayout()
        }
        panel.add(dropdown)

        panel.add(UILabel("Weapon: (none)", fontSize: 16))

        let listView = UIListView(
            items: ["Sword", "Bow", "Staff", "Dagger", "Axe", "Spear"],
            fontSize: 18
        )
        listView.rowHeight = 26
        panel.add(listView)

        panel.add(UIButton("Show Dialog", fontSize: 20) {})

        ui.add(panel)
        panel.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        return (ui, dropdown, difficultyLabel, listView)
    }

    @Test func step1_initialLayout() {
        let (app, renderer, _) = makeTestApp()
        let (ui, _, _, _) = Self.makeUIDemoWidgets(app: app, renderer: renderer)
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
    }

    @Test func step2_openDropdown() {
        let (app, renderer, inputBackend) = makeTestApp()
        let (ui, dropdown, _, _) = Self.makeUIDemoWidgets(app: app, renderer: renderer)

        // Initial layout
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Click to open
        let f = dropdown.frame
        inputBackend.currentMousePosition = Vector2(x: f.x + f.width / 2, y: f.y + f.height / 2)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(dropdown.isOpen == true)
    }

    @Test func step3a_openAndRelease() {
        let (app, renderer, inputBackend) = makeTestApp()
        let (ui, dropdown, _, _) = Self.makeUIDemoWidgets(app: app, renderer: renderer)

        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Open dropdown
        let f = dropdown.frame
        inputBackend.currentMousePosition = Vector2(x: f.x + f.width / 2, y: f.y + f.height / 2)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(dropdown.isOpen == true)

        // Release
        inputBackend.mouseButtonsDown = []
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(dropdown.isOpen == true) // should still be open after release
    }

    @Test func step3b_clickOption() {
        let (app, renderer, inputBackend) = makeTestApp()
        let (ui, dropdown, difficultyLabel, _) = Self.makeUIDemoWidgets(app: app, renderer: renderer)

        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        app.input.consumeTransitions()

        // Open via mouse click on the button
        let f = dropdown.frame
        inputBackend.currentMousePosition = Vector2(x: f.x + f.width / 2, y: f.y + f.height / 2)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(dropdown.isOpen == true)
        app.input.consumeTransitions()

        // Release mouse, then click 3rd option in next frame
        inputBackend.mouseButtonsDown = []
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        app.input.consumeTransitions()

        let rh = dropdown.fontSize + dropdown.verticalPadding * 2
        let optY = f.y + f.height + rh * 2.5
        inputBackend.currentMousePosition = Vector2(x: f.x + f.width / 2, y: optY)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        #expect(dropdown.selectedIndex == 2)
        #expect(difficultyLabel.text == "Difficulty: Hard")
    }

    @Test func step3c1a_justOpen() {
        let (app, renderer, _) = makeTestApp()
        let font = renderer.loadDefaultFont()
        let ui = UIContext(font: font)
        let panel = UIContainer(id: "main")
        panel.layout = .vertical(spacing: 12, alignment: .center)

        let dropdown = UIDropdown(options: ["A", "B", "C", "D"], selectedIndex: 1, fontSize: 20)
        panel.add(dropdown)
        ui.add(panel)
        panel.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        dropdown.open()
        #expect(dropdown.isOpen == true)
    }

    @Test func step3c1b_openAndSelect() {
        let dropdown = UIDropdown(options: ["A", "B", "C", "D"], selectedIndex: 1, fontSize: 20)
        dropdown.open()
        dropdown.moveHighlight(1)
        dropdown.selectHighlighted()
        #expect(dropdown.selectedIndex == 2)
    }

    @Test func step3c1b2_minimal() {
        let dropdown = UIDropdown(options: ["A", "B"], selectedIndex: 0, fontSize: 20)
        dropdown.selectedIndex = 1
        #expect(dropdown.selectedIndex == 1)
    }

    @Test func step3c1b3_setSelectedIndex() {
        let dropdown = UIDropdown(options: ["A", "B", "C", "D"], selectedIndex: 1, fontSize: 20)
        dropdown.selectedIndex = 2
        #expect(dropdown.selectedIndex == 2)
    }

    @Test func step3c1c_openSelectWithUI() {
        let (app, renderer, _) = makeTestApp()
        let font = renderer.loadDefaultFont()
        let ui = UIContext(font: font)
        let panel = UIContainer(id: "main")
        panel.layout = .vertical(spacing: 12, alignment: .center)

        let dropdown = UIDropdown(options: ["A", "B", "C", "D"], selectedIndex: 1, fontSize: 20)
        panel.add(dropdown)
        ui.add(panel)
        panel.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        dropdown.open()
        dropdown.moveHighlight(1)
        dropdown.selectHighlighted()

        #expect(dropdown.selectedIndex == 2)
    }

    @Test func step3c2_withOnChange() {
        let (app, renderer, _) = makeTestApp()
        let font = renderer.loadDefaultFont()
        let ui = UIContext(font: font)
        let panel = UIContainer(id: "main")
        panel.layout = .vertical(spacing: 12, alignment: .center)

        let label = UILabel("Test", fontSize: 16)
        panel.add(label)

        let dropdown = UIDropdown(options: ["A", "B", "C", "D"], selectedIndex: 1, fontSize: 20)
        dropdown.onChange = { index in
            label.text = "Selected: \(index)"
            ui.invalidateLayout()
        }
        panel.add(dropdown)
        ui.add(panel)
        panel.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        dropdown.open()
        dropdown.moveHighlight(1)
        dropdown.selectHighlighted()

        #expect(dropdown.selectedIndex == 2)
        #expect(label.text == "Selected: 2")
    }

    @Test func step3c3_fullWidgetTree() {
        let (app, renderer, _) = makeTestApp()
        let (ui, dropdown, difficultyLabel, _) = Self.makeUIDemoWidgets(app: app, renderer: renderer)

        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Select directly via API (no update after)
        dropdown.open()
        dropdown.moveHighlight(1) // highlight index 2 (was 1 from open)
        dropdown.selectHighlighted()

        #expect(dropdown.selectedIndex == 2)
        #expect(difficultyLabel.text == "Difficulty: Hard")
    }

    @Test func step3d_updateAfterAPISelect() {
        let (app, renderer, _) = makeTestApp()
        let (ui, dropdown, _, _) = Self.makeUIDemoWidgets(app: app, renderer: renderer)

        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Select directly
        dropdown.open()
        dropdown.moveHighlight(1)
        dropdown.selectHighlighted()

        // Now update (triggers layout rebuild due to invalidateLayout in onChange)
        ui.update(app: app, deltaTime: 1.0 / 60.0)
    }

    @Test func step4_updateAfterSelect() {
        let (app, renderer, inputBackend) = makeTestApp()
        let (ui, dropdown, _, _) = Self.makeUIDemoWidgets(app: app, renderer: renderer)

        // Initial layout
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Open
        let f = dropdown.frame
        inputBackend.currentMousePosition = Vector2(x: f.x + f.width / 2, y: f.y + f.height / 2)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Release
        inputBackend.mouseButtonsDown = []
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Click option
        let rh = dropdown.fontSize + dropdown.verticalPadding * 2
        let optY = f.y + f.height + rh * 2.5
        inputBackend.currentMousePosition = Vector2(x: f.x + f.width / 2, y: optY)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)

        // Second tick (same frame - tests multi-tick)
        ui.update(app: app, deltaTime: 1.0 / 60.0)
    }

    /// Reproduces the exact UIDemo widget tree and simulates clicking a dropdown option.
    @Test func clickDropdownOptionDoesNotCrash() {
        let (app, renderer, inputBackend) = makeTestApp()
        let font = renderer.loadDefaultFont()
        let ui = UIContext(font: font)
        ui.inputConfig = .keyboardAndGamepad

        // Build the same widget tree as UIDemo
        let panel = UIContainer(id: "main")
        panel.layout = .vertical(spacing: 12, alignment: .center)

        let title = UILabel("Agilis UI Demo", fontSize: 32)
        panel.add(title)

        let subtitle = UILabel("Cross-platform 2D game framework", fontSize: 16)
        panel.add(subtitle)

        let counterLabel = UILabel("Clicks: 0", fontSize: 20)
        panel.add(counterLabel)

        let button = UIButton("Click Me!", fontSize: 22) {}
        panel.add(button)

        let progressBar = UIProgressBar(value: 0)
        panel.add(progressBar)

        let slider = UISlider("Volume", value: 0.75, range: 0...1)
        panel.add(slider)

        let toggleLabel = UILabel("Dark Mode: OFF", fontSize: 16)
        panel.add(toggleLabel)

        let toggle = UIToggle("Dark Mode", isOn: false) { _ in }
        panel.add(toggle)

        let difficultyLabel = UILabel("Difficulty: Normal", fontSize: 16)
        panel.add(difficultyLabel)

        let dropdown = UIDropdown(
            options: ["Easy", "Normal", "Hard", "Nightmare"],
            selectedIndex: 1,
            fontSize: 20
        )
        dropdown.onChange = { index in
            let names = ["Easy", "Normal", "Hard", "Nightmare"]
            difficultyLabel.text = "Difficulty: \(names[index])"
            ui.invalidateLayout()
        }
        panel.add(dropdown)

        let listSelectionLabel = UILabel("Weapon: (none)", fontSize: 16)
        panel.add(listSelectionLabel)

        let listView = UIListView(
            items: ["Sword", "Bow", "Staff", "Dagger", "Axe", "Spear"],
            fontSize: 18
        )
        listView.rowHeight = 26
        listView.onChange = { index in
            let items = ["Sword", "Bow", "Staff", "Dagger", "Axe", "Spear"]
            listSelectionLabel.text = "Weapon: \(items[index])"
            ui.invalidateLayout()
        }
        panel.add(listView)

        let modalButton = UIButton("Show Dialog", fontSize: 20) {}
        panel.add(modalButton)

        ui.add(panel)
        let screen = renderer.screenSize
        panel.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)

        // Step 1: Initial layout
        print("STEP 1: Initial layout")
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        app.input.consumeTransitions()
        print("STEP 1 done. Dropdown frame: \(dropdown.frame)")

        // Step 2: Move mouse over dropdown button and click to open
        print("STEP 2: Click to open dropdown")
        let dropdownFrame = dropdown.frame
        let clickX = dropdownFrame.x + dropdownFrame.width / 2
        let clickY = dropdownFrame.y + dropdownFrame.height / 2
        print("  Click at: \(clickX), \(clickY)")
        inputBackend.currentMousePosition = Vector2(x: clickX, y: clickY)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        print("  isOpen: \(dropdown.isOpen)")
        #expect(dropdown.isOpen == true)
        app.input.consumeTransitions()

        // Step 3: Release mouse
        print("STEP 3: Release mouse")
        inputBackend.mouseButtonsDown = []
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        app.input.consumeTransitions()
        print("  isOpen after release: \(dropdown.isOpen)")

        // Step 4: Click on the 3rd option ("Hard", index 2)
        print("STEP 4: Click option")
        let rowHeight = dropdown.fontSize + dropdown.verticalPadding * 2
        let optionY = dropdownFrame.y + dropdownFrame.height + rowHeight * 2.5
        print("  Option click at: \(clickX), \(optionY)")
        inputBackend.currentMousePosition = Vector2(x: clickX, y: optionY)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()

        print("  Update tick 1...")
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        print("  Update tick 1 done. isOpen=\(dropdown.isOpen) selectedIndex=\(dropdown.selectedIndex)")

        // Should have selected "Hard" (index 2)
        #expect(dropdown.selectedIndex == 2)
        #expect(dropdown.isOpen == false)
        #expect(difficultyLabel.text == "Difficulty: Hard")

        // Step 5: Release and do another update cycle
        print("STEP 5: Release")
        inputBackend.mouseButtonsDown = []
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        app.input.consumeTransitions()
        print("STEP 5 done")

        // Step 6: Render
        print("STEP 6: Render")
        renderer.drawCalls = []
        ui.render(renderer: renderer)
        print("STEP 6 done")

        #expect(!renderer.drawCalls.isEmpty)
    }

    /// Test changing dropdown selection multiple times rapidly.
    @Test func changeDropdownMultipleTimes() {
        let (app, renderer, inputBackend) = makeTestApp()
        let font = renderer.loadDefaultFont()
        let ui = UIContext(font: font)
        ui.inputConfig = .keyboardAndGamepad

        let panel = UIContainer(id: "main")
        panel.layout = .vertical(spacing: 12, alignment: .center)

        let difficultyLabel = UILabel("Difficulty: Normal", fontSize: 16)
        panel.add(difficultyLabel)

        let dropdown = UIDropdown(
            options: ["Easy", "Normal", "Hard", "Nightmare"],
            selectedIndex: 1,
            fontSize: 20
        )
        dropdown.onChange = { index in
            let names = ["Easy", "Normal", "Hard", "Nightmare"]
            difficultyLabel.text = "Difficulty: \(names[index])"
            ui.invalidateLayout()
        }
        panel.add(dropdown)

        let listView = UIListView(
            items: ["Sword", "Bow", "Staff", "Dagger", "Axe", "Spear"],
            fontSize: 18
        )
        listView.rowHeight = 26
        panel.add(listView)

        ui.add(panel)
        panel.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        // Initial layout
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        app.input.consumeTransitions()

        // Select each option in sequence
        for targetIndex in [0, 2, 3, 1] {
            // Open dropdown by clicking
            let df = dropdown.frame
            inputBackend.currentMousePosition = Vector2(x: df.x + df.width / 2, y: df.y + df.height / 2)
            inputBackend.mouseButtonsDown = [.left]
            app.input.update()
            ui.update(app: app, deltaTime: 1.0 / 60.0)
            app.input.consumeTransitions()

            // Release
            inputBackend.mouseButtonsDown = []
            app.input.update()
            ui.update(app: app, deltaTime: 1.0 / 60.0)
            app.input.consumeTransitions()

            // Click on option
            let rh = dropdown.fontSize + dropdown.verticalPadding * 2
            let optY = df.y + df.height + rh * Float(targetIndex) + rh / 2
            inputBackend.currentMousePosition = Vector2(x: df.x + df.width / 2, y: optY)
            inputBackend.mouseButtonsDown = [.left]
            app.input.update()
            ui.update(app: app, deltaTime: 1.0 / 60.0)

            #expect(dropdown.selectedIndex == targetIndex)
            app.input.consumeTransitions()

            // Release
            inputBackend.mouseButtonsDown = []
            app.input.update()
            ui.update(app: app, deltaTime: 1.0 / 60.0)
            app.input.consumeTransitions()

            // Render
            ui.render(renderer: renderer)
        }
    }
}
