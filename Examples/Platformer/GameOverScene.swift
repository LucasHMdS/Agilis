import Agilis

final class GameOverScene: Scene {
    let finalScore: Int
    private var font: FontHandle = .invalid
    private var ui: UIContext!
    private var sounds: MarioSounds.SoundSet!

    init(score: Int) {
        self.finalScore = score
    }

    func didEnter(app: Application) {
        app.renderer.setBackgroundColor(.black)
        sounds = MarioSounds.generate(audio: app.audio)
        app.audio.playSound(sounds.gameOver, volume: 0.6, pitch: 1.0, looping: false)

        font = app.renderer.loadDefaultFont()
        var theme = UITheme.dark(font: font)
        theme.buttonColor = Color(r: 60, g: 30, b: 30, a: 220)
        theme.buttonHoverColor = Color(r: 100, g: 50, b: 50)
        theme.buttonPressColor = Color(r: 40, g: 20, b: 20)
        ui = UIContext(font: font, theme: theme)

        let menu = UIContainer(id: "gameOverMenu")
        menu.layout = .vertical(spacing: 12, alignment: .center)

        let gameOverLabel = UILabel("GAME OVER", fontSize: 48)
        gameOverLabel.color = .red
        menu.add(gameOverLabel)

        let scoreLabel = UILabel("Score: \(finalScore)", fontSize: 28)
        scoreLabel.color = .white
        menu.add(scoreLabel)

        let retryButton = UIButton("Retry", fontSize: 24) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: GameScene(), app: app)
        }
        menu.add(retryButton)

        let menuButton = UIButton("Menu", fontSize: 24) { [weak app] in
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

    func render(app: Application, interpolation: Double) {
        ui.render(renderer: app.renderer)

        let screen = app.renderer.screenSize
        let fpsColor = Color(r: 80, g: 80, b: 80)
        app.renderer.drawText("\(app.fps) FPS",
                              position: Vector2(x: 4, y: screen.height - 18),
                              font: ui.font, size: 14, color: fpsColor)
    }
}
