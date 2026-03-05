import Agilis

final class MenuScene: Scene {
    private var ui: UIContext!
    private var tweens: TweenSystem!
    private var titleEntity: Entity = .null
    private var font: FontHandle = .invalid

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()
        var theme = UITheme.dark(font: font)
        theme.buttonColor = Color(r: 50, g: 50, b: 70, a: 220)
        theme.buttonHoverColor = Color(r: 80, g: 80, b: 110)
        theme.buttonPressColor = Color(r: 35, g: 35, b: 50)
        ui = UIContext(font: font, theme: theme)

        // Setup tween system for animated title
        tweens = TweenSystem()
        app.world.addSystem(tweens)

        // Title entity for tween animation
        titleEntity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: Vector2(x: Showcase.screenWidth / 2, y: -60)), to: titleEntity)
        app.world.addComponent(Sprite(texture: .invalid), to: titleEntity)

        // Animate title sliding in from top
        tweens.moveTo(titleEntity,
                      target: Vector2(x: Showcase.screenWidth / 2, y: 100),
                      duration: 0.8, easing: .backOut, in: app.world)

        // Pulsing title scale (yoyo + infinite repeat)
        let pulse = tweens.scaleTo(titleEntity,
                                   target: Vector2(x: 1.08, y: 1.08),
                                   duration: 1.2, easing: .sineInOut, in: app.world)
        tweens.setYoyo(pulse)
        tweens.setRepeat(pulse, count: -1)

        // Build UI
        let menu = UIContainer(id: "menu")
        menu.layout = .vertical(spacing: 18, alignment: .center)

        let subtitle = UILabel("Animation & Easing Demo", fontSize: 16)
        subtitle.color = Showcase.textDim
        menu.add(subtitle)

        let spacer = UILabel("", fontSize: 32)
        menu.add(spacer)

        let easingButton = UIButton("Easing Visualizer", fontSize: 22) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(
                with: EasingScene(),
                transition: .fade(duration: 0.6, color: .black, easing: .cubicInOut),
                app: app
            )
        }
        menu.add(easingButton)

        let sequenceButton = UIButton("Tween Sequences", fontSize: 22) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(
                with: SequenceScene(),
                transition: .flash(duration: 0.5),
                app: app
            )
        }
        menu.add(sequenceButton)

        let quitButton = UIButton("Quit", fontSize: 22) { [weak app] in
            app?.quit()
        }
        menu.add(quitButton)

        ui.add(menu)
        let screen = app.renderer.screenSize
        menu.frame = Rect(x: 0, y: screen.height * 0.35,
                          width: screen.width, height: screen.height * 0.6)
    }

    func update(app: Application, deltaTime: Double) {
        ui.update(app: app, deltaTime: deltaTime)

        if app.input.isKeyPressed(.escape) {
            app.quit()
        }

        // Gamepad: A to start easing scene
        if app.input.isGamepadButtonPressed(0, .faceDown) {
            app.sceneManager.replace(
                with: EasingScene(),
                transition: .fade(duration: 0.6),
                app: app
            )
        }
    }

    func render(app: Application, interpolation: Double) {
        let screen = app.renderer.screenSize

        // Draw title text at tweened position
        if let pos = app.world.getComponent(Transform2D.self, from: titleEntity),
           let scale = app.world.getComponent(Transform2D.self, from: titleEntity) {
            let s = scale.scale.x
            let fontSize: Float = 48 * s
            let text = "TWEEN SHOWCASE"
            let textWidth = Float(text.count) * fontSize * 0.52
            app.renderer.drawText(text,
                                  position: Vector2(x: pos.position.x - textWidth / 2, y: pos.position.y),
                                  font: font, size: fontSize, color: Showcase.accentColor)
        }

        // Decorative lines
        let lineY: Float = 160
        app.renderer.drawLine(
            from: Vector2(x: 100, y: lineY),
            to: Vector2(x: screen.width - 100, y: lineY),
            color: Showcase.trackColor, thickness: 1
        )

        ui.render(renderer: app.renderer)

        // FPS
        let fpsColor = Color(r: 80, g: 80, b: 80)
        app.renderer.drawText("\(app.fps) FPS",
                              position: Vector2(x: 4, y: screen.height - 18),
                              font: font, size: 14, color: fpsColor)
    }

    func willExit(app: Application) {
        app.world.removeAllEventHandlers()
        tweens.removeAll()
        app.world.removeSystem(tweens)
        if titleEntity != .null {
            app.world.destroyEntity(titleEntity)
        }
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }
}
