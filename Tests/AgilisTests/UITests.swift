import Testing
@testable import Agilis

// MARK: - Mock Render Backend

/// A minimal render backend for testing UI layout and text measurement.
final class MockRenderBackend: @unchecked Sendable, RenderBackend {
    var _screenSize = Size(width: 800, height: 600)
    var drawCalls: [String] = []
    var fonts: [UInt32: Bool] = [:]
    private var nextFontId: UInt32 = 1

    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}

    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}

    func drawSprite(_ sprite: Sprite) { drawCalls.append("sprite") }
    func drawRect(_ rect: Rect, color: Color) { drawCalls.append("rect") }
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) { drawCalls.append("rectOutline") }
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) { drawCalls.append("line") }
    func drawCircle(center: Vector2, radius: Float, color: Color) { drawCalls.append("circle") }
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) { drawCalls.append("circleOutline") }

    func loadDefaultFont() -> FontHandle {
        let handle = FontHandle(id: nextFontId)
        fonts[nextFontId] = true
        nextFontId += 1
        return handle
    }
    func loadFont(from path: String, size: Int) -> FontHandle {
        let handle = FontHandle(id: nextFontId)
        fonts[nextFontId] = true
        nextFontId += 1
        return handle
    }
    func destroyFont(_ handle: FontHandle) { fonts.removeValue(forKey: handle.id) }
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {
        drawCalls.append("text:\(text)")
    }
    /// Returns a predictable size: 10px per character width, fontSize height.
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size {
        Size(width: Float(text.count) * size * 0.5, height: size)
    }

    func beginClip(_ rect: Rect) { drawCalls.append("beginClip") }
    func endClip() { drawCalls.append("endClip") }

    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}

    var screenSize: Size { _screenSize }
}

/// A minimal audio backend for creating test Applications.
final class MockAudioBackend: @unchecked Sendable, AudioBackend {
    func initialize() throws {}
    func shutdown() {}
    func loadSound(from path: String) -> SoundHandle { .invalid }
    func playSound(_ handle: SoundHandle, volume: Float, pitch: Float, looping: Bool) {}
    func stopSound(_ handle: SoundHandle) {}
    func unloadSound(_ handle: SoundHandle) {}
    func loadMusic(from path: String) -> MusicHandle { .invalid }
    func playMusic(_ handle: MusicHandle, volume: Float, looping: Bool) {}
    func pauseMusic(_ handle: MusicHandle) {}
    func resumeMusic(_ handle: MusicHandle) {}
    func stopMusic(_ handle: MusicHandle) {}
    func updateMusicStream(_ handle: MusicHandle) {}
    func unloadMusic(_ handle: MusicHandle) {}
    func setMasterVolume(_ volume: Float) {}
}

// MARK: - Helpers

func makeTestApp(screenWidth: Float = 800, screenHeight: Float = 600) -> (Application, MockRenderBackend, MockInputBackend) {
    let renderer = MockRenderBackend()
    renderer._screenSize = Size(width: screenWidth, height: screenHeight)
    let inputBackend = MockInputBackend()
    let audio = MockAudioBackend()
    let config = WindowConfig(title: "Test", width: Int(screenWidth), height: Int(screenHeight))
    let app = Application(config: config, renderer: renderer, audio: audio, inputBackend: inputBackend)
    return (app, renderer, inputBackend)
}

// MARK: - UINode Tests

@Suite("UINode Tests")
struct UINodeTests {

    @Test func defaultProperties() {
        let node = UINode()
        #expect(node.isVisible == true)
        #expect(node.isFocusable == false)
        #expect(node.isFocused == false)
        #expect(node.frame.width == 0)
        #expect(node.frame.height == 0)
    }

    @Test func customId() {
        let node = UINode(id: "myNode")
        #expect(node.id == "myNode")
    }

    @Test func autoId() {
        let a = UINode()
        let b = UINode()
        #expect(a.id != b.id)
    }

    @Test func sizeThatFitsDefault() {
        let node = UINode()
        let size = node.sizeThatFits(Size(width: 100, height: 50))
        #expect(size.width == 100)
        #expect(size.height == 50)
    }
}

// MARK: - UIContainer Tests

@Suite("UIContainer Tests")
struct UIContainerTests {

    @Test func addAndRemoveChildren() {
        let container = UIContainer()
        let child1 = UINode()
        let child2 = UINode()

        container.add(child1)
        container.add(child2)
        #expect(container.children.count == 2)
        #expect(child1.parent === container)

        container.remove(child1)
        #expect(container.children.count == 1)
        #expect(child1.parent == nil)

        container.removeAll()
        #expect(container.children.count == 0)
    }

    @Test func addReturnsSelf() {
        let container = UIContainer()
        let result = container.add(UINode())
        #expect(result === container)
    }

    @Test func sizeThatFitsVertical() {
        let container = UIContainer()
        container.layout = .vertical(spacing: 10, alignment: .center)
        container.padding = 5

        let label1 = UILabel("Hello", fontSize: 20)
        label1.cachedTextSize = Size(width: 50, height: 20)
        let label2 = UILabel("World", fontSize: 20)
        label2.cachedTextSize = Size(width: 60, height: 20)

        container.add(label1)
        container.add(label2)

        let size = container.sizeThatFits(Size(width: 800, height: 600))
        // Max width = 60 + padding*2 = 70
        #expect(size.width == 70)
        // Total height = 20 + 10 + 20 + padding*2 = 60
        #expect(size.height == 60)
    }

    @Test func sizeThatFitsHorizontal() {
        let container = UIContainer()
        container.layout = .horizontal(spacing: 5, alignment: .center)

        let label1 = UILabel("A", fontSize: 20)
        label1.cachedTextSize = Size(width: 30, height: 20)
        let label2 = UILabel("B", fontSize: 20)
        label2.cachedTextSize = Size(width: 40, height: 20)

        container.add(label1)
        container.add(label2)

        let size = container.sizeThatFits(Size(width: 800, height: 600))
        #expect(size.width == 75) // 30 + 5 + 40
        #expect(size.height == 20)
    }
}

// MARK: - UILabel Tests

@Suite("UILabel Tests")
struct UILabelTests {

    @Test func defaultProperties() {
        let label = UILabel("Test")
        #expect(label.text == "Test")
        #expect(label.fontSize == 20)
        #expect(label.color == nil)
        #expect(label.alignment == .left)
        #expect(label.isFocusable == false)
    }

    @Test func sizeThatFitsUsesCache() {
        let label = UILabel("Hello")
        label.cachedTextSize = Size(width: 75, height: 22)
        let size = label.sizeThatFits(Size(width: 800, height: 600))
        #expect(size.width == 75)
        #expect(size.height == 22)
    }

    @Test func renderDrawsText() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let label = UILabel("Hello")
        label.frame = Rect(x: 10, y: 20, width: 100, height: 30)
        label.cachedTextSize = Size(width: 50, height: 20)

        renderer.drawCalls = []
        label.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("text:Hello"))
    }

    @Test func hiddenLabelDoesNotRender() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let label = UILabel("Hidden")
        label.isVisible = false
        label.frame = Rect(x: 0, y: 0, width: 100, height: 30)

        renderer.drawCalls = []
        label.render(renderer: renderer, theme: theme)
        #expect(renderer.drawCalls.isEmpty)
    }
}

// MARK: - UIButton Tests

@Suite("UIButton Tests")
struct UIButtonTests {

    @Test func defaultProperties() {
        let button = UIButton("Click")
        #expect(button.text == "Click")
        #expect(button.fontSize == 20)
        #expect(button.isFocusable == true)
        #expect(button.state == .normal)
    }

    @Test func sizeThatFitsIncludesPadding() {
        let button = UIButton("OK")
        button.cachedTextSize = Size(width: 30, height: 20)
        button.horizontalPadding = 24
        button.verticalPadding = 12
        let size = button.sizeThatFits(Size(width: 800, height: 600))
        #expect(size.width == 78) // 30 + 48
        #expect(size.height == 44) // 20 + 24
    }

    @Test func clickTriggersAction() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        var clicked = false
        let button = UIButton("Go") { clicked = true }
        button.frame = Rect(x: 100, y: 100, width: 120, height: 40)
        ui.root.add(button)
        ui.needsLayout = false

        // Mouse press over button
        inputBackend.currentMousePosition = Vector2(x: 150, y: 120)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(button.state == .pressed)
        #expect(!clicked)

        // Mouse release over button
        inputBackend.mouseButtonsDown = []
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(clicked)
    }

    @Test func hoverState() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let button = UIButton("Hover")
        button.frame = Rect(x: 100, y: 100, width: 120, height: 40)
        ui.root.add(button)
        ui.needsLayout = false

        // Mouse over button (no click)
        inputBackend.currentMousePosition = Vector2(x: 150, y: 120)
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(button.state == .hovered)

        // Mouse off button
        inputBackend.currentMousePosition = Vector2(x: 0, y: 0)
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(button.state == .normal)
    }

    @Test func renderDrawsRectAndText() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let button = UIButton("OK")
        button.frame = Rect(x: 10, y: 10, width: 100, height: 40)
        button.cachedTextSize = Size(width: 30, height: 20)

        renderer.drawCalls = []
        button.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("rect"))
        #expect(renderer.drawCalls.contains("text:OK"))
    }

    @Test func focusedButtonShowsOutline() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let button = UIButton("Focused")
        button.frame = Rect(x: 10, y: 10, width: 100, height: 40)
        button.isFocused = true

        renderer.drawCalls = []
        button.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("rectOutline"))
    }

    @Test func activateCallsAction() {
        var called = false
        let button = UIButton("Test") { called = true }
        button.activate()
        #expect(called)
    }
}

// MARK: - UIPanel Tests

@Suite("UIPanel Tests")
struct UIPanelTests {

    @Test func renderDrawsBackground() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let panel = UIPanel()
        panel.frame = Rect(x: 0, y: 0, width: 200, height: 100)

        renderer.drawCalls = []
        panel.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("rect"))
    }

    @Test func renderDrawsBorder() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let panel = UIPanel()
        panel.borderThickness = 2
        panel.frame = Rect(x: 0, y: 0, width: 200, height: 100)

        renderer.drawCalls = []
        panel.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("rect"))
        #expect(renderer.drawCalls.contains("rectOutline"))
    }

    @Test func panelRendersChildren() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let panel = UIPanel()
        panel.frame = Rect(x: 0, y: 0, width: 200, height: 100)

        let label = UILabel("Child")
        label.frame = Rect(x: 10, y: 10, width: 80, height: 20)
        label.cachedTextSize = Size(width: 50, height: 20)
        panel.add(label)

        renderer.drawCalls = []
        panel.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("text:Child"))
    }
}

// MARK: - UISlider Tests

@Suite("UISlider Tests")
struct UISliderTests {

    @Test func defaultProperties() {
        let slider = UISlider("Volume")
        #expect(slider.label == "Volume")
        #expect(slider.value == 0.5)
        #expect(slider.isFocusable == true)
    }

    @Test func adjustByStep() {
        let slider = UISlider("Vol", value: 0.5, range: 0...1)
        slider.stepFraction = 0.1

        slider.adjustByStep(1) // +10%
        #expect(slider.value > 0.59 && slider.value < 0.61)

        slider.adjustByStep(-1) // -10%
        #expect(slider.value > 0.49 && slider.value < 0.51)
    }

    @Test func adjustClampsToRange() {
        let slider = UISlider("Vol", value: 0.95, range: 0...1)
        slider.stepFraction = 0.1

        slider.adjustByStep(1) // would be 1.05, clamped to 1.0
        #expect(slider.value == 1.0)

        slider.value = 0.05
        slider.adjustByStep(-1) // would be -0.05, clamped to 0.0
        #expect(slider.value == 0.0)
    }

    @Test func onChangeCallback() {
        var received: Float?
        let slider = UISlider("Vol", value: 0.5) { received = $0 }
        slider.adjustByStep(1)
        #expect(received != nil)
    }
}

// MARK: - UIToggle Tests

@Suite("UIToggle Tests")
struct UIToggleTests {

    @Test func defaultProperties() {
        let toggle = UIToggle("Music")
        #expect(toggle.label == "Music")
        #expect(toggle.isOn == false)
        #expect(toggle.isFocusable == true)
    }

    @Test func toggleFlipsState() {
        let toggle = UIToggle("Sound", isOn: false)
        toggle.toggle()
        #expect(toggle.isOn == true)
        toggle.toggle()
        #expect(toggle.isOn == false)
    }

    @Test func onChangeCallback() {
        var received: Bool?
        let toggle = UIToggle("Music", onChange: { received = $0 })
        toggle.toggle()
        #expect(received == true)
        toggle.toggle()
        #expect(received == false)
    }

    @Test func clickToggles() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let toggle = UIToggle("Test", isOn: false)
        toggle.frame = Rect(x: 50, y: 50, width: 150, height: 28)
        ui.root.add(toggle)
        ui.needsLayout = false

        // Click over toggle
        inputBackend.currentMousePosition = Vector2(x: 80, y: 60)
        inputBackend.mouseButtonsDown = [.left]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(toggle.isOn == true)
    }
}

// MARK: - UITextInput Tests

@Suite("UITextInput Tests")
struct UITextInputTests {

    @Test func defaultProperties() {
        let input = UITextInput("Name")
        #expect(input.placeholder == "Name")
        #expect(input.text == "")
        #expect(input.cursorIndex == 0)
        #expect(input.isFocusable == true)
    }

    @Test func initWithText() {
        let input = UITextInput("", text: "Hello")
        #expect(input.text == "Hello")
        #expect(input.cursorIndex == 5)
    }
}

// MARK: - UIProgressBar Tests

@Suite("UIProgressBar Tests")
struct UIProgressBarTests {

    @Test func defaultProperties() {
        let bar = UIProgressBar()
        #expect(bar.value == 0)
        #expect(bar.isFocusable == false)
    }

    @Test func renderDrawsTrackAndFill() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let bar = UIProgressBar(value: 0.5)
        bar.frame = Rect(x: 10, y: 10, width: 200, height: 16)

        renderer.drawCalls = []
        bar.render(renderer: renderer, theme: theme)

        // Should draw: track rect, fill rect, border outline
        let rectCount = renderer.drawCalls.filter { $0 == "rect" }.count
        #expect(rectCount == 2)
        #expect(renderer.drawCalls.contains("rectOutline"))
    }
}

// MARK: - UILayout Engine Tests

@Suite("UILayout Engine Tests")
struct UILayoutEngineTests {

    @Test func verticalLayoutCentersChildren() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()

        let container = UIContainer()
        container.layout = .vertical(spacing: 10, alignment: .center)

        let label1 = UILabel("A", fontSize: 20)
        let label2 = UILabel("B", fontSize: 20)
        container.add(label1)
        container.add(label2)

        let bounds = Rect(x: 0, y: 0, width: 400, height: 300)
        UILayoutEngine.performLayout(on: container, in: bounds, renderer: renderer, font: font)

        // Children should be centered horizontally
        let midX = bounds.width / 2
        #expect(abs(label1.frame.x + label1.frame.width / 2 - midX) < 1)
        #expect(abs(label2.frame.x + label2.frame.width / 2 - midX) < 1)

        // label2 should be below label1
        #expect(label2.frame.y > label1.frame.y)
        // Gap between them should be the spacing
        let gap = label2.frame.y - (label1.frame.y + label1.frame.height)
        #expect(abs(gap - 10) < 0.01)
    }

    @Test func horizontalLayout() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()

        let container = UIContainer()
        container.layout = .horizontal(spacing: 5, alignment: .center)

        let label1 = UILabel("X", fontSize: 20)
        let label2 = UILabel("YZ", fontSize: 20)
        container.add(label1)
        container.add(label2)

        let bounds = Rect(x: 0, y: 0, width: 400, height: 300)
        UILayoutEngine.performLayout(on: container, in: bounds, renderer: renderer, font: font)

        // label2 should be to the right of label1
        #expect(label2.frame.x > label1.frame.x + label1.frame.width)
    }

    @Test func paddingInsets() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()

        let container = UIContainer()
        container.layout = .vertical(spacing: 0, alignment: .leading)
        container.padding = 20

        let label = UILabel("Test", fontSize: 20)
        container.add(label)

        let bounds = Rect(x: 0, y: 0, width: 400, height: 300)
        UILayoutEngine.performLayout(on: container, in: bounds, renderer: renderer, font: font)

        // The label's x should be at least at the padding offset
        #expect(label.frame.x >= 20)
    }

    @Test func hiddenChildrenSkipped() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()

        let container = UIContainer()
        container.layout = .vertical(spacing: 10, alignment: .center)

        let label1 = UILabel("A", fontSize: 20)
        let hidden = UILabel("HIDDEN", fontSize: 20)
        hidden.isVisible = false
        let label2 = UILabel("B", fontSize: 20)
        container.add(label1)
        container.add(hidden)
        container.add(label2)

        let bounds = Rect(x: 0, y: 0, width: 400, height: 300)
        UILayoutEngine.performLayout(on: container, in: bounds, renderer: renderer, font: font)

        // Only 10px gap between label1 and label2, hidden is skipped
        let gap = label2.frame.y - (label1.frame.y + label1.frame.height)
        #expect(abs(gap - 10) < 0.01)
    }
}

// MARK: - UIContext Tests

@Suite("UIContext Tests")
struct UIContextTests {

    @Test func addSetsNeedsLayout() {
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)
        ui.needsLayout = false
        ui.add(UILabel("Test"))
        #expect(ui.needsLayout == true)
    }

    @Test func focusManagement() {
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let button1 = UIButton("A")
        let button2 = UIButton("B")
        ui.root.add(button1)
        ui.root.add(button2)

        ui.setFocus(button1)
        #expect(ui.focusedNode === button1)
        #expect(button1.isFocused == true)
        #expect(button2.isFocused == false)

        ui.setFocus(button2)
        #expect(ui.focusedNode === button2)
        #expect(button1.isFocused == false)
        #expect(button2.isFocused == true)

        ui.setFocus(nil)
        #expect(ui.focusedNode == nil)
        #expect(button2.isFocused == false)
    }

    @Test func tabCyclesFocus() {
        let (app, _, inputBackend) = makeTestApp()
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)

        let button1 = UIButton("A")
        button1.frame = Rect(x: 100, y: 100, width: 80, height: 30)
        let button2 = UIButton("B")
        button2.frame = Rect(x: 100, y: 150, width: 80, height: 30)
        let label = UILabel("Not focusable")
        label.frame = Rect(x: 100, y: 50, width: 100, height: 20)

        ui.root.add(label)
        ui.root.add(button1)
        ui.root.add(button2)

        // Initial layout pass
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(ui.focusedNode == nil)

        // Tab → focus button1
        inputBackend.keysDown = [.tab]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(ui.focusedNode === button1)

        // Tab again → focus button2
        inputBackend.keysDown = []
        app.input.update() // release tab
        inputBackend.keysDown = [.tab]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(ui.focusedNode === button2)

        // Tab wraps around to button1
        inputBackend.keysDown = []
        app.input.update()
        inputBackend.keysDown = [.tab]
        app.input.update()
        ui.update(app: app, deltaTime: 1.0 / 60.0)
        #expect(ui.focusedNode === button1)
    }

    @Test func invalidateLayoutTriggersRelayout() {
        let font = FontHandle(id: 1)
        let ui = UIContext(font: font)
        ui.needsLayout = false
        ui.invalidateLayout()
        #expect(ui.needsLayout == true)
    }
}

// MARK: - UITheme Tests

@Suite("UITheme Tests")
struct UIThemeTests {

    @Test func darkThemeDefaults() {
        let font = FontHandle(id: 1)
        let theme = UITheme.dark(font: font)
        #expect(theme.font == font)
        #expect(theme.textColor == .white)
        #expect(theme.defaultPadding == 8)
        #expect(theme.defaultSpacing == 8)
    }

    @Test func lightThemeDefaults() {
        let font = FontHandle(id: 1)
        let theme = UITheme.light(font: font)
        #expect(theme.font == font)
        #expect(theme.textColor == Color(r: 20, g: 20, b: 20))
    }

    @Test func customTheme() {
        let font = FontHandle(id: 1)
        let theme = UITheme(font: font, textColor: .red, defaultPadding: 16)
        #expect(theme.textColor == .red)
        #expect(theme.defaultPadding == 16)
    }
}

// MARK: - UIScrollContainer Tests

@Suite("UIScrollContainer Tests")
struct UIScrollContainerTests {

    @Test func renderClips() {
        let renderer = MockRenderBackend()
        let font = renderer.loadDefaultFont()
        let theme = UITheme.dark(font: font)

        let scroll = UIScrollContainer()
        scroll.frame = Rect(x: 0, y: 0, width: 200, height: 100)
        scroll.showScrollBar = false

        let label = UILabel("Inside")
        label.frame = Rect(x: 10, y: 10, width: 80, height: 20)
        label.cachedTextSize = Size(width: 50, height: 20)
        scroll.add(label)

        renderer.drawCalls = []
        scroll.render(renderer: renderer, theme: theme)

        #expect(renderer.drawCalls.contains("beginClip"))
        #expect(renderer.drawCalls.contains("endClip"))
        #expect(renderer.drawCalls.contains("text:Inside"))
    }
}

// MARK: - UIImage Tests

@Suite("UIImage Tests")
struct UIImageTests {

    @Test func defaultProperties() {
        let img = UIImage(texture: TextureHandle(id: 5))
        #expect(img.texture.id == 5)
        #expect(img.tint == .white)
        #expect(img.fixedSize == nil)
        #expect(img.isFocusable == false)
    }

    @Test func fixedSizeThatFits() {
        let img = UIImage(texture: .invalid, fixedSize: Size(width: 32, height: 32))
        let size = img.sizeThatFits(Size(width: 800, height: 600))
        #expect(size.width == 32)
        #expect(size.height == 32)
    }
}

// MARK: - FontHandle Tests

@Suite("FontHandle Tests")
struct FontHandleTests {

    @Test func invalidHandle() {
        #expect(FontHandle.invalid.id == 0)
    }

    @Test func equality() {
        let a = FontHandle(id: 5)
        let b = FontHandle(id: 5)
        let c = FontHandle(id: 6)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func hashable() {
        let a = FontHandle(id: 1)
        let b = FontHandle(id: 2)
        var set: Set<FontHandle> = [a, b]
        #expect(set.count == 2)
        set.insert(FontHandle(id: 1))
        #expect(set.count == 2) // duplicate
    }
}

// MARK: - TextAlignment Tests

@Suite("TextAlignment Tests")
struct TextAlignmentTests {

    @Test func allCases() {
        let left = TextAlignment.left
        let center = TextAlignment.center
        let right = TextAlignment.right
        #expect(left != center)
        #expect(center != right)
        #expect(left != right)
    }
}

// MARK: - Application FPS Tests

@Suite("Application FPS Tests")
struct ApplicationFPSTests {

    @Test func initialFPSIsZero() {
        let (app, _, _) = makeTestApp()
        #expect(app.fps == 0)
        #expect(app.frameTime == 0)
    }
}
