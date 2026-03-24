import Agilis

// MARK: - Game Over Scene

final class GameOverScene: Scene {
    deinit {}
    let leftScore: Int
    let rightScore: Int
    let leftWon: Bool
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var ui: UIContext!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var sounds: PongSounds.SoundSet!

    init(leftScore: Int, rightScore: Int, leftWon: Bool) {
        self.leftScore = leftScore
        self.rightScore = rightScore
        self.leftWon = leftWon
    }

    func didEnter(app: Application) {
        Pong.configure(screenSize: app.renderer.screenSize)
        sounds = PongSounds.generate(audio: app.audio)
        let endSound = leftWon ? sounds.winFanfare : sounds.gameOver
        app.audio.playSound(endSound, volume: 0.6, pitch: 1.0, looping: false)

        font = app.renderer.loadDefaultFont()
        var theme = UITheme.dark(font: font)
        theme.buttonColor = Color(r: 40, g: 40, b: 40, a: 200)
        theme.buttonHoverColor = Color(r: 80, g: 80, b: 80)
        theme.buttonPressColor = Color(r: 30, g: 30, b: 30)
        ui = UIContext(font: font, theme: theme)

        let menu = UIContainer(id: "gameOverMenu")
        menu.layout = .vertical(spacing: 12 * Pong.uiScale, alignment: .center)

        let winnerText = leftWon ? "Player Wins!" : "CPU Wins!"
        let winLabel = UILabel(winnerText, fontSize: Pong.fontSize(36))
        winLabel.color = .yellow
        menu.add(winLabel)

        let scoreLabel = UILabel("\(leftScore) - \(rightScore)", fontSize: Pong.fontSize(28))
        scoreLabel.color = .white
        menu.add(scoreLabel)

        let rematchButton = UIButton("Rematch", fontSize: Pong.fontSize(24)) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: GameScene(), app: app)
        }
        menu.add(rematchButton)

        let menuButton = UIButton("Menu", fontSize: Pong.fontSize(24)) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: MenuScene(), app: app)
        }
        menu.add(menuButton)

        ui.add(menu)
        let screen = app.renderer.screenSize
        menu.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)

        // Gamepad: A or Start for rematch, B for menu
        if app.input.isGamepadButtonPressed(0, .faceDown)
            || app.input.isGamepadButtonPressed(0, .start) {
            app.sceneManager.replace(with: GameScene(), app: app)
        }
        if app.input.isGamepadButtonPressed(0, .faceRight) {
            app.sceneManager.replace(with: MenuScene(), app: app)
        }

        if app.input.isKeyPressed(.escape) {
            app.sceneManager.replace(with: MenuScene(), app: app)
        }
    }

    func willExit(app: Application) {
        if sounds != nil {
            sounds.unloadAll(audio: app.audio)
        }
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }

    func render(app: Application, interpolation _: Double) {
        let screen = app.renderer.screenSize
        let cx = screen.width / 2

        drawCourtDashes(renderer: app.renderer, screenHeight: screen.height, centerX: cx)
        ui.render(renderer: app.renderer)

        // FPS counter
        let fpsColor = Color(r: 80, g: 80, b: 80)
        app.renderer.drawText(
            "\(app.fps) FPS",
            position: Vector2(x: 4, y: screen.height - 18),
            font: ui.font,
            size: Pong.fontSize(14),
            color: fpsColor
        )
    }
}
