import Agilis

final class UIDemoScene: Scene {
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var ui: UIContext!
    private var clickCount = 0
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var counterLabel: UILabel!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var progressBar: UIProgressBar!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var toggleLabel: UILabel!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var difficultyLabel: UILabel!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var listSelectionLabel: UILabel!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var nameLabel: UILabel!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var uiImage: UIImage!

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()
        ui = UIContext(font: font)

        // Enable keyboard + gamepad navigation
        ui.inputConfig = .keyboardAndGamepad

        // --- Scroll Container wraps everything so the demo is scrollable ---
        let scrollContainer = UIScrollContainer(id: "scroll")
        scrollContainer.layout = .vertical(spacing: 16, alignment: .center)
        scrollContainer.padding = 16
        scrollContainer.maxHeight = 600

        // --- Header ---
        let title = UILabel("Agilis UI Demo", fontSize: 32)
        title.color = .white
        scrollContainer.add(title)

        let subtitle = UILabel("A cross-platform 2D game framework", fontSize: 16)
        subtitle.color = Color(r: 200, g: 200, b: 200)
        scrollContainer.add(subtitle)

        // --- Image (texture loaded after renderer is initialized) ---
        uiImage = UIImage(texture: .invalid, fixedSize: Size(width: 48, height: 48))
        scrollContainer.add(uiImage)

        // --- Text Input ---
        nameLabel = UILabel("Player: (unnamed)", fontSize: 16)
        nameLabel.color = Color(r: 180, g: 180, b: 180)
        scrollContainer.add(nameLabel)

        let textInput = UITextInput("Enter player name...", fontSize: 18) { [weak self] text in
            self?.nameLabel.text = text.isEmpty ? "Player: (unnamed)" : "Player: \(text)"
            self?.ui.invalidateLayout()
        }
        scrollContainer.add(textInput)

        // --- Button + Progress ---
        counterLabel = UILabel("Clicks: 0", fontSize: 20)
        scrollContainer.add(counterLabel)

        let button = UIButton("Click Me!", fontSize: 22) { [weak self] in
            guard let self else { return }
            clickCount += 1
            counterLabel.text = "Clicks: \(clickCount)"
            progressBar.value = min(Float(clickCount) / 10.0, 1.0)
            ui.invalidateLayout()
        }
        scrollContainer.add(button)

        progressBar = UIProgressBar(value: 0)
        scrollContainer.add(progressBar)

        // --- Settings Panel (groups slider, toggle, dropdown) ---
        let settingsPanel = UIPanel(layout: .vertical(spacing: 10, alignment: .center), padding: 12)
        settingsPanel.borderThickness = 1

        let settingsTitle = UILabel("Settings", fontSize: 20)
        settingsTitle.color = .white
        settingsPanel.add(settingsTitle)

        let slider = UISlider("Volume", value: 0.75, range: 0...1)
        settingsPanel.add(slider)

        toggleLabel = UILabel("Dark Mode: OFF", fontSize: 16)
        toggleLabel.color = Color(r: 180, g: 180, b: 180)
        settingsPanel.add(toggleLabel)

        let toggle = UIToggle("Dark Mode", isOn: false) { [weak self] isOn in
            self?.toggleLabel.text = "Dark Mode: \(isOn ? "ON" : "OFF")"
            self?.ui.invalidateLayout()
        }
        settingsPanel.add(toggle)

        difficultyLabel = UILabel("Difficulty: Normal", fontSize: 16)
        difficultyLabel.color = Color(r: 180, g: 180, b: 180)
        settingsPanel.add(difficultyLabel)

        let dropdown = UIDropdown(
            options: ["Easy", "Normal", "Hard", "Nightmare"],
            selectedIndex: 1,
            fontSize: 20
        )
        dropdown.onChange = { [weak self] index in
            let names = ["Easy", "Normal", "Hard", "Nightmare"]
            self?.difficultyLabel.text = "Difficulty: \(names[index])"
            self?.ui.invalidateLayout()
        }
        settingsPanel.add(dropdown)

        scrollContainer.add(settingsPanel)

        // --- List View ---
        listSelectionLabel = UILabel("Weapon: (none)", fontSize: 16)
        listSelectionLabel.color = Color(r: 180, g: 180, b: 180)
        scrollContainer.add(listSelectionLabel)

        let listView = UIListView(
            items: ["Sword", "Bow", "Staff", "Dagger", "Axe", "Spear"],
            fontSize: 18
        )
        listView.rowHeight = 26
        listView.onChange = { [weak self] index in
            let items = ["Sword", "Bow", "Staff", "Dagger", "Axe", "Spear"]
            self?.listSelectionLabel.text = "Weapon: \(items[index])"
            self?.ui.invalidateLayout()
        }
        scrollContainer.add(listView)

        // --- Modal Dialog Button ---
        let modalButton = UIButton("Show Dialog", fontSize: 20) { [weak self] in
            guard let self else { return }
            let modal = UIModalDialog(title: "Hello!")
            modal.addContent(UILabel("This is a modal dialog.", fontSize: 18))
            modal.addContent(UILabel("Press OK or Escape to close.", fontSize: 14))
            modal.addOKCancel(
                onOK: { [weak self] in self?.ui.dismissModal() },
                onCancel: { [weak self] in self?.ui.dismissModal() }
            )
            ui.presentModal(modal)
        }
        scrollContainer.add(modalButton)

        ui.add(scrollContainer)
        let screen = app.renderer.screenSize
        scrollContainer.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)

        uiImage.texture = createIconTexture(renderer: app.renderer)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)

        if app.input.isKeyPressed(.escape) && ui.activeModal == nil {
            app.quit()
        }
    }

    func render(app: Application, interpolation _: Double) {
        // Draw some background shapes
        app.renderer.drawRect(
            Rect(x: 50, y: 50, width: 120, height: 80),
            color: Color(r: 60, g: 60, b: 100, a: 100)
        )
        app.renderer.drawCircle(
            center: Vector2(x: 700, y: 500),
            radius: 40,
            color: Color(r: 100, g: 60, b: 60, a: 100)
        )

        ui.render(renderer: app.renderer)
    }

    func willExit(app: Application) {
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }
}

/// Creates a small procedural texture (a colored diamond icon).
private func createIconTexture(renderer: any RenderBackend) -> TextureHandle {
    let size = 32
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    for y in 0..<size {
        for x in 0..<size {
            let cx = abs(x - size / 2)
            let cy = abs(y - size / 2)
            let dist = cx + cy
            if dist < size / 2 {
                let i = (y * size + x) * 4
                let t = Float(dist) / Float(size / 2)
                pixels[i + 0] = UInt8(clamping: Int(100 + 155 * (1 - t)))
                pixels[i + 1] = UInt8(clamping: Int(180 * (1 - t)))
                pixels[i + 2] = 255
                pixels[i + 3] = 255
            }
        }
    }
    let image = ImageData(width: size, height: size, pixels: pixels)
    return renderer.loadTextureFromImage(image)
}

let config = WindowConfig(
    title: "Agilis - UI Demo",
    width: 800,
    height: 600,
    targetFPS: 60
)

let app = Application(config: config)
app.renderer.setBackgroundColor(.cornflowerBlue)
app.sceneManager.push(UIDemoScene(), app: app)

try app.run()
