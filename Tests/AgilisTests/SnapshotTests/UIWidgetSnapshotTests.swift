@testable import Agilis
import Testing

@Suite("UI Widget Snapshots", .serialized)
struct UIWidgetSnapshotTests {

    /// Create a UITheme with the given font.
    private static func makeTheme(font: FontHandle) -> UITheme {
        UITheme.dark(font: font)
    }

    /// Layout a container and render it.
    private static func layoutAndRender(
        renderer: Renderer,
        root: UIContainer,
        font: FontHandle,
        theme: UITheme,
        bounds: Rect = Rect(x: 0, y: 0, width: 320, height: 240)
    ) {
        UILayoutEngine.performLayout(on: root, in: bounds, renderer: renderer, font: font)
        root.render(renderer: renderer, theme: theme)
    }

    @Test("Label widget")
    func label() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 20
        let label = UILabel("Hello, Agilis!", fontSize: 20)
        root.add(label)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "label")
    }

    @Test("Label center alignment")
    func labelCenter() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 20
        let label = UILabel("Centered Text", fontSize: 20, alignment: .center)
        root.add(label)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "label-center")
    }

    @Test("Label right alignment")
    func labelRight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 20
        let label = UILabel("Right Aligned", fontSize: 20, alignment: .right)
        root.add(label)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "label-right")
    }

    @Test("Button normal state")
    func buttonNormal() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let button = UIButton("Click Me", fontSize: 18)
        root.add(button)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "button-normal")
    }

    @Test("Panel with border")
    func panelBorder() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 20

        let panel = UIPanel(layout: .vertical(), padding: 16)
        panel.backgroundColor = Color(r: 50, g: 50, b: 70)
        panel.borderColor = Color(r: 100, g: 150, b: 255)
        panel.borderThickness = 2
        panel.add(UILabel("Inside Panel", fontSize: 16))
        root.add(panel)

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "panel-border")
    }

    @Test("Panel vertical layout with 3 labels")
    func panelVertical() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 10

        let panel = UIPanel(layout: .vertical(spacing: 8), padding: 12)
        panel.backgroundColor = Color(r: 40, g: 40, b: 60)
        panel.add(UILabel("Line 1", fontSize: 16))
        panel.add(UILabel("Line 2", fontSize: 16))
        panel.add(UILabel("Line 3", fontSize: 16))
        root.add(panel)

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "panel-vertical")
    }

    @Test("Panel horizontal layout with 3 labels")
    func panelHorizontal() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 10

        let panel = UIPanel(layout: .horizontal(spacing: 12), padding: 12)
        panel.backgroundColor = Color(r: 40, g: 40, b: 60)
        panel.add(UILabel("A", fontSize: 16))
        panel.add(UILabel("B", fontSize: 16))
        panel.add(UILabel("C", fontSize: 16))
        root.add(panel)

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "panel-horizontal")
    }

    @Test("Slider at half value")
    func sliderHalf() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let slider = UISlider("Volume", value: 0.5, fontSize: 16)
        root.add(slider)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "slider-half")
    }

    @Test("Slider at full value")
    func sliderFull() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let slider = UISlider("Brightness", value: 1.0, fontSize: 16)
        root.add(slider)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "slider-full")
    }

    @Test("Toggle on")
    func toggleOn() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let toggle = UIToggle("Enable Sound", isOn: true, fontSize: 16)
        root.add(toggle)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "toggle-on")
    }

    @Test("Toggle off")
    func toggleOff() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let toggle = UIToggle("Music", isOn: false, fontSize: 16)
        root.add(toggle)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "toggle-off")
    }

    @Test("Progress bar at half")
    func progressHalf() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let progress = UIProgressBar(value: 0.5)
        root.add(progress)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "progress-half")
    }

    @Test("Progress bar full")
    func progressFull() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let progress = UIProgressBar(value: 1.0)
        root.add(progress)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "progress-full")
    }

    @Test("Progress bar empty")
    func progressEmpty() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let progress = UIProgressBar(value: 0.0)
        root.add(progress)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "progress-empty")
    }

    @Test("Text input with placeholder")
    func textInputEmpty() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let input = UITextInput("Enter name...", fontSize: 16)
        root.add(input)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "text-input-empty")
    }

    @Test("Image widget")
    func imageWidget() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let theme = Self.makeTheme(font: font)

        let tex = SnapshotTestUtilities.createCheckerboardTexture(
            renderer: renderer, width: 48, height: 48, tileSize: 8
        )
        defer { renderer.destroyTexture(tex) }

        let root = UIContainer()
        root.layout = .vertical()
        root.padding = 30
        let img = UIImage(texture: tex, fixedSize: Size(width: 48, height: 48))
        root.add(img)

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // swiftlint:disable:next force_cast
            Self.layoutAndRender(renderer: r as! Renderer, root: root, font: font, theme: theme)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "UIWidgets", name: "image-widget")
    }
}
