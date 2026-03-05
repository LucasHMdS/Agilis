import Agilis

final class MenuScene: Scene {
    private var font: FontHandle = .invalid
    private var ui: UIContext!

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()

        ui = UIContext(font: font)
        let menu = UIContainer(id: "menu")
        menu.layout = .vertical(spacing: 16, alignment: .center)
        menu.frame = Rect(x: 0, y: 0, width: Shooter.screenWidth, height: Shooter.screenHeight)

        let title = UILabel("Top-Down Shooter", fontSize: 32, color: Shooter.playerColor)
        menu.add(title)

        let subtitle = UILabel("Raycasting, CCD, SpriteBatch & Particles", fontSize: 13, color: Shooter.textDim)
        menu.add(subtitle)

        let playButton = UIButton("Start Game", fontSize: 22) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: GameScene(), transition: .fade(duration: 0.5), app: app)
        }
        menu.add(playButton)

        let quitButton = UIButton("Quit", fontSize: 22) { [weak app] in
            app?.quit()
        }
        menu.add(quitButton)

        ui.add(menu)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)
        if app.input.isKeyPressed(.escape) { app.quit() }
    }

    func render(app: Application, interpolation: Double) {
        ui.render(renderer: app.renderer)
    }

    func willExit(app: Application) {
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }
}
