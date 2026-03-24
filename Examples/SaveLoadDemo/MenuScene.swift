import Agilis

final class MenuScene: Scene {
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var ui: UIContext!

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()

        ui = UIContext(font: font)
        let menu = UIContainer(id: "menu")
        menu.layout = .vertical(spacing: 16, alignment: .center)
        menu.frame = Rect(x: 0, y: 0, width: RPG.screenWidth, height: RPG.screenHeight)

        let title = UILabel("Save & Load Demo", fontSize: 26, color: RPG.textBright)
        menu.add(title)

        let playButton = UIButton("New Game", fontSize: 20) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(
                with: GameScene(),
                transition: .fade(duration: 0.6),
                app: app
            )
        }
        menu.add(playButton)

        let quitButton = UIButton("Quit", fontSize: 20) { [weak app] in
            app?.quit()
        }
        menu.add(quitButton)

        ui.add(menu)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)

        if app.input.isKeyPressed(.escape) {
            app.quit()
        }
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
