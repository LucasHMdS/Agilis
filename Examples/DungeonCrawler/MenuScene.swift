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
        menu.frame = Rect(x: 0, y: 0, width: Dungeon.screenWidth, height: Dungeon.screenHeight)

        let title = UILabel("Dungeon Crawler", fontSize: 32, color: Dungeon.torchColor)
        menu.add(title)

        let subtitle = UILabel("Lighting, Shadows & TileMap Demo", fontSize: 14, color: Dungeon.textDim)
        menu.add(subtitle)

        let playButton = UIButton("Enter Dungeon", fontSize: 22) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(
                with: GameScene(),
                transition: .fade(duration: 1.0, color: .black),
                app: app
            )
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

    func render(app: Application, interpolation _: Double) {
        ui.render(renderer: app.renderer)
    }

    func willExit(app: Application) {
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }
}
