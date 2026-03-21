import Agilis

final class MenuScene: Scene {
    deinit {}
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var ui: UIContext!

    func didEnter(app: Application) {
        app.renderer.setBackgroundColor(Mario.skyColor)

        font = app.renderer.loadDefaultFont()
        var theme = UITheme.dark(font: font)
        theme.buttonColor = Color(r: 40, g: 100, b: 40, a: 220)
        theme.buttonHoverColor = Color(r: 60, g: 140, b: 60)
        theme.buttonPressColor = Color(r: 30, g: 80, b: 30)
        ui = UIContext(font: font, theme: theme)

        let menu = UIContainer(id: "menu")
        menu.layout = .vertical(spacing: 16, alignment: .center)

        let title = UILabel("SUPER MARIO", fontSize: 48)
        title.color = Mario.playerBodyColor
        menu.add(title)

        let subtitle = UILabel("A Platformer Demo", fontSize: 16)
        subtitle.color = Color(r: 200, g: 200, b: 200)
        menu.add(subtitle)

        let playButton = UIButton("Play", fontSize: 24) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: GameScene(), app: app)
        }
        menu.add(playButton)

        let quitButton = UIButton("Quit", fontSize: 24) { [weak app] in
            app?.quit()
        }
        menu.add(quitButton)

        ui.add(menu)
        let screen = app.renderer.screenSize
        menu.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)

        if app.input.isGamepadButtonPressed(0, .faceDown)
            || app.input.isGamepadButtonPressed(0, .start) {
            app.sceneManager.replace(with: GameScene(), app: app)
        }

        if app.input.isKeyPressed(.escape) {
            app.quit()
        }
    }

    func render(app: Application, interpolation _: Double) {
        let screen = app.renderer.screenSize

        // Decorative ground
        let groundY = screen.height - 64
        app.renderer.drawRect(
            Rect(x: 0, y: groundY, width: screen.width, height: 8),
            color: Mario.groundTopColor
        )
        app.renderer.drawRect(
            Rect(x: 0, y: groundY + 8, width: screen.width, height: 56),
            color: Mario.groundColor
        )

        // Decorative clouds
        let cloudColor = Color(r: 255, g: 255, b: 255, a: 160)
        app.renderer.drawCircle(center: Vector2(x: 150, y: 80), radius: 30, color: cloudColor)
        app.renderer.drawCircle(center: Vector2(x: 175, y: 70), radius: 22, color: cloudColor)
        app.renderer.drawCircle(center: Vector2(x: 130, y: 75), radius: 25, color: cloudColor)

        app.renderer.drawCircle(center: Vector2(x: 700, y: 100), radius: 28, color: cloudColor)
        app.renderer.drawCircle(center: Vector2(x: 725, y: 90), radius: 20, color: cloudColor)
        app.renderer.drawCircle(center: Vector2(x: 680, y: 95), radius: 24, color: cloudColor)

        // Decorative pipe
        app.renderer.drawRect(
            Rect(x: 700, y: groundY - 64, width: 64, height: 64),
            color: Mario.pipeGreen
        )
        app.renderer.drawRectOutline(
            Rect(x: 696, y: groundY - 64, width: 72, height: 32),
            color: Mario.pipeDarkGreen,
            thickness: 2
        )
        app.renderer.drawRect(
            Rect(x: 696, y: groundY - 64, width: 72, height: 32),
            color: Mario.pipeGreen
        )

        ui.render(renderer: app.renderer)

        let fpsColor = Color(r: 80, g: 80, b: 80)
        app.renderer.drawText(
            "\(app.fps) FPS",
            position: Vector2(x: 4, y: screen.height - 18),
            font: ui.font,
            size: 14,
            color: fpsColor
        )
    }

    func willExit(app: Application) {
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }
}
