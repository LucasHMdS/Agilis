import Agilis

final class GameOverScene: Scene {
    let finalScore: Int
    let finalWave: Int
    let finalKills: Int

    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var ui: UIContext!

    init(score: Int, wave: Int, kills: Int) {
        self.finalScore = score
        self.finalWave = wave
        self.finalKills = kills
    }

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()

        ui = UIContext(font: font)
        let menu = UIContainer(id: "menu")
        menu.layout = .vertical(spacing: 12, alignment: .center)
        menu.frame = Rect(x: 0, y: 0, width: Shooter.screenWidth, height: Shooter.screenHeight)

        let title = UILabel("GAME OVER", fontSize: 36, color: Color(r: 220, g: 60, b: 60))
        menu.add(title)

        let scoreLabel = UILabel("Score: \(finalScore)", fontSize: 20, color: Shooter.textBright)
        menu.add(scoreLabel)

        let waveLabel = UILabel("Wave: \(finalWave)  |  Kills: \(finalKills)", fontSize: 16, color: Shooter.textDim)
        menu.add(waveLabel)

        let retryButton = UIButton("Retry", fontSize: 22) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: GameScene(), transition: .fade(duration: 0.4), app: app)
        }
        menu.add(retryButton)

        let menuButton = UIButton("Menu", fontSize: 22) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: MenuScene(), transition: .fade(duration: 0.4), app: app)
        }
        menu.add(menuButton)

        ui.add(menu)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)
    }

    func render(app: Application, interpolation _: Double) {
        ui.render(renderer: app.renderer)
    }

    func willExit(app: Application) {
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }
}
