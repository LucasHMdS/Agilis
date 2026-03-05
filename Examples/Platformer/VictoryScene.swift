import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

final class VictoryScene: Scene {
    let finalScore: Int
    let totalCoins: Int
    private var font: FontHandle = .invalid
    private var ui: UIContext!
    private var sounds: MarioSounds.SoundSet!
    private var gameTime: Float = 0

    // Animated star positions (decorative sparkles)
    private struct Star {
        var x: Float
        var y: Float
        var speed: Float
        var size: Float
        var phase: Float
    }
    private var stars: [Star] = []

    init(score: Int, coins: Int) {
        self.finalScore = score
        self.totalCoins = coins
    }

    func didEnter(app: Application) {
        let bgColor = Color(r: 25, g: 20, b: 60)
        app.renderer.setBackgroundColor(bgColor)

        sounds = MarioSounds.generate(audio: app.audio)
        app.audio.playSound(sounds.levelComplete, volume: 0.6, pitch: 1.0, looping: false)

        font = app.renderer.loadDefaultFont()
        var theme = UITheme.dark(font: font)
        theme.buttonColor = Color(r: 100, g: 80, b: 10, a: 220)
        theme.buttonHoverColor = Color(r: 160, g: 130, b: 20)
        theme.buttonPressColor = Color(r: 80, g: 60, b: 5)
        ui = UIContext(font: font, theme: theme)

        let menu = UIContainer(id: "victoryMenu")
        menu.layout = .vertical(spacing: 12, alignment: .center)

        let title = UILabel("YOU WIN!", fontSize: 52)
        title.color = Mario.coinColor
        menu.add(title)

        let scoreLabel = UILabel("Score: \(finalScore)", fontSize: 28)
        scoreLabel.color = .white
        menu.add(scoreLabel)

        let coinLabel = UILabel("Coins: \(totalCoins)", fontSize: 22)
        coinLabel.color = Mario.coinColor
        menu.add(coinLabel)

        let playAgainButton = UIButton("Play Again", fontSize: 24) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: GameScene(), app: app)
        }
        menu.add(playAgainButton)

        let menuButton = UIButton("Menu", fontSize: 24) { [weak app] in
            guard let app else { return }
            app.sceneManager.replace(with: MenuScene(), app: app)
        }
        menu.add(menuButton)

        ui.add(menu)
        let screen = app.renderer.screenSize
        menu.frame = Rect(x: 0, y: 0, width: screen.width, height: screen.height)

        // Generate decorative stars
        let screenW = app.renderer.screenSize.width
        let screenH = app.renderer.screenSize.height
        for _ in 0..<30 {
            stars.append(Star(
                x: Float.random(in: 0...screenW),
                y: Float.random(in: 0...screenH),
                speed: Float.random(in: 20...80),
                size: Float.random(in: 2...5),
                phase: Float.random(in: 0...(2 * .pi))
            ))
        }
    }

    func update(app: Application, deltaTime: Double) {
        let dt = Float(deltaTime)
        gameTime += dt

        ui.update(app: app, deltaTime: deltaTime)

        // Animate stars falling
        let screenH = app.renderer.screenSize.height
        for i in 0..<stars.count {
            stars[i].y += stars[i].speed * dt
            if stars[i].y > screenH + 10 {
                stars[i].y = -10
                stars[i].x = Float.random(in: 0...app.renderer.screenSize.width)
            }
        }

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
        let renderer = app.renderer
        let screen = renderer.screenSize

        // Draw animated sparkle stars
        for star in stars {
            let pulse = (sinf(gameTime * 3.0 + star.phase) + 1.0) / 2.0
            let alpha = UInt8(120 + Int(pulse * 135))
            let r = UInt8(min(255, 200 + Int(pulse * 55)))
            let color = Color(r: r, g: 200, b: 50, a: alpha)
            renderer.drawCircle(
                center: Vector2(x: star.x, y: star.y),
                radius: star.size * (0.6 + pulse * 0.4),
                color: color
            )
        }

        // Draw a decorative trophy/flag
        let flagX = screen.width / 2
        let flagBaseY = screen.height - 80

        // Flagpole
        renderer.drawRect(
            Rect(x: flagX - 2, y: flagBaseY - 120, width: 4, height: 120),
            color: Mario.flagpoleColor
        )
        // Flag
        renderer.drawRect(
            Rect(x: flagX + 2, y: flagBaseY - 120, width: 30, height: 20),
            color: Mario.flagColor
        )
        // Base
        renderer.drawRect(
            Rect(x: flagX - 10, y: flagBaseY, width: 20, height: 6),
            color: Mario.flagpoleColor
        )

        // Ground strip
        renderer.drawRect(
            Rect(x: 0, y: screen.height - 40, width: screen.width, height: 4),
            color: Mario.groundTopColor
        )
        renderer.drawRect(
            Rect(x: 0, y: screen.height - 36, width: screen.width, height: 36),
            color: Mario.groundColor
        )

        ui.render(renderer: renderer)

        let fpsColor = Color(r: 80, g: 80, b: 80)
        renderer.drawText("\(app.fps) FPS",
                          position: Vector2(x: 4, y: screen.height - 18),
                          font: ui.font, size: 14, color: fpsColor)
    }
}
