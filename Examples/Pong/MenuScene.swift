import Agilis

// MARK: - Menu Scene

final class MenuScene: Scene {
    deinit {}
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var ui: UIContext!

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()
        var theme = UITheme.dark(font: font)
        theme.buttonColor = Color(r: 40, g: 40, b: 40, a: 200)
        theme.buttonHoverColor = Color(r: 80, g: 80, b: 80)
        theme.buttonPressColor = Color(r: 30, g: 30, b: 30)
        ui = UIContext(font: font, theme: theme)

        let menu = UIContainer(id: "menu")
        menu.layout = .vertical(spacing: 16, alignment: .center)

        let title = UILabel("PONG", fontSize: 48)
        title.color = .white
        menu.add(title)

        let subtitle = UILabel("A Classic Arcade Game", fontSize: 16)
        subtitle.color = Color(r: 150, g: 150, b: 150)
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

        // Gamepad: A or Start to play
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
        let cx = screen.width / 2
        let cy = screen.height / 2

        // Draw court dashes behind UI
        drawCourtDashes(renderer: app.renderer, screenHeight: screen.height, centerX: cx)

        // Paddle silhouettes
        let dim = Color(r: 60, g: 60, b: 60)
        app.renderer.drawRect(
            Rect(
                x: Pong.paddleMargin - Pong.paddleWidth / 2,
                y: cy - Pong.paddleHeight / 2,
                width: Pong.paddleWidth,
                height: Pong.paddleHeight
            ),
            color: dim
        )
        app.renderer.drawRect(
            Rect(
                x: screen.width - Pong.paddleMargin - Pong.paddleWidth / 2,
                y: cy - Pong.paddleHeight / 2,
                width: Pong.paddleWidth,
                height: Pong.paddleHeight
            ),
            color: dim
        )

        ui.render(renderer: app.renderer)

        // FPS counter
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
