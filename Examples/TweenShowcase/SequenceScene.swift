import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

final class SequenceScene: Scene, @unchecked Sendable {
    private var tweens: TweenSystem!
    private var font: FontHandle = .invalid
    private var entities: [Entity] = []
    private var ninePatchTex: TextureHandle = .invalid
    private var ninePatchSourceRect = Rect()
    private var completionCount: Int = 0

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()

        tweens = TweenSystem()
        app.world.addSystem(tweens)

        let (tex, srcRect) = generateNinePatchTexture(renderer: app.renderer)
        ninePatchTex = tex
        ninePatchSourceRect = srcRect

        setupDemos(app: app)
    }

    func update(app: Application, deltaTime: Double) {
        if app.input.isKeyPressed(.escape) {
            app.sceneManager.replace(
                with: MenuScene(),
                transition: .fade(duration: 0.5),
                app: app
            )
        }

        if app.input.isKeyPressed(.tab) {
            app.sceneManager.replace(
                with: EasingScene(),
                transition: .fade(duration: 0.4),
                app: app
            )
        }

        // Number keys to test scene transitions
        if app.input.isKeyPressed(.one) {
            app.sceneManager.replace(
                with: SequenceScene(),
                transition: .fade(duration: 0.8, color: .black, easing: .cubicInOut) {
                    // onMidpoint callback
                },
                app: app
            )
        }
        if app.input.isKeyPressed(.two) {
            app.sceneManager.replace(
                with: SequenceScene(),
                transition: .flash(duration: 0.4),
                app: app
            )
        }
        if app.input.isKeyPressed(.three) {
            app.sceneManager.replace(with: SequenceScene(), transition: .instant, app: app)
        }
    }

    func render(app: Application, interpolation: Double) {
        let screen = app.renderer.screenSize
        let ninePatch = NinePatchSprite(texture: ninePatchTex, sourceRect: ninePatchSourceRect, border: 12)

        // Title
        app.renderer.drawText("Tween Sequences & Transitions",
                              position: Vector2(x: 10, y: 8),
                              font: font, size: 24, color: Showcase.textBright)
        app.renderer.drawText("[ESC] Menu  [TAB] Easings  [1] Fade  [2] Flash  [3] Instant",
                              position: Vector2(x: 10, y: 34),
                              font: font, size: 12, color: Showcase.textDim)

        // Demo 1: Patrol Path (square loop)
        let d1x: Float = 40
        let d1y: Float = 70
        app.renderer.drawNinePatch(ninePatch, destination: Rect(x: d1x, y: d1y, width: 280, height: 240))
        app.renderer.drawText("Patrol Path (sequence)",
                              position: Vector2(x: d1x + 8, y: d1y + 5),
                              font: font, size: 13, color: Showcase.textDim)
        // Draw path outline
        let pathPoints: [Vector2] = [
            Vector2(x: d1x + 40, y: d1y + 40),
            Vector2(x: d1x + 240, y: d1y + 40),
            Vector2(x: d1x + 240, y: d1y + 200),
            Vector2(x: d1x + 40, y: d1y + 200),
        ]
        for i in 0..<4 {
            app.renderer.drawLine(
                from: pathPoints[i],
                to: pathPoints[(i + 1) % 4],
                color: Showcase.trackColor, thickness: 1
            )
        }
        // Ball at entity 0
        if entities.count > 0,
           let pos = app.world.getComponent(Transform2D.self, from: entities[0]) {
            app.renderer.drawCircle(center: pos.position, radius: 10, color: Showcase.accentColor)
        }

        // Demo 2: Fade Chain
        let d2x: Float = 340
        let d2y: Float = 70
        app.renderer.drawNinePatch(ninePatch, destination: Rect(x: d2x, y: d2y, width: 280, height: 240))
        app.renderer.drawText("Fade Chain (fadeOut/fadeIn)",
                              position: Vector2(x: d2x + 8, y: d2y + 5),
                              font: font, size: 13, color: Showcase.textDim)
        if entities.count > 1,
           let sprite = app.world.getComponent(Sprite.self, from: entities[1]) {
            let alpha = sprite.tint.a
            let c = Color(r: 100, g: 180, b: 255, a: alpha)
            app.renderer.drawRect(
                Rect(x: d2x + 60, y: d2y + 60, width: 160, height: 120),
                color: c
            )
            app.renderer.drawText("alpha: \(alpha)",
                                  position: Vector2(x: d2x + 100, y: d2y + 190),
                                  font: font, size: 12, color: Showcase.textDim)
        }

        // Demo 3: Scale Pulse
        let d3x: Float = 640
        let d3y: Float = 70
        app.renderer.drawNinePatch(ninePatch, destination: Rect(x: d3x, y: d3y, width: 280, height: 110))
        app.renderer.drawText("Scale Pulse (yoyo + repeat)",
                              position: Vector2(x: d3x + 8, y: d3y + 5),
                              font: font, size: 13, color: Showcase.textDim)
        if entities.count > 2,
           let transform = app.world.getComponent(Transform2D.self, from: entities[2]) {
            let s = transform.scale.x
            let size = 30 * s
            let cx = d3x + 140
            let cy = d3y + 65
            app.renderer.drawRect(
                Rect(x: cx - size / 2, y: cy - size / 2, width: size, height: size),
                color: Showcase.highlightColor
            )
            app.renderer.drawText(String(format: "%.2fx", s),
                                  position: Vector2(x: d3x + 200, y: d3y + 58),
                                  font: font, size: 12, color: Showcase.textDim)
        }

        // Demo 4: Rotation
        let d4x: Float = 640
        let d4y: Float = 195
        app.renderer.drawNinePatch(ninePatch, destination: Rect(x: d4x, y: d4y, width: 280, height: 115))
        app.renderer.drawText("Rotation (backOut easing)",
                              position: Vector2(x: d4x + 8, y: d4y + 5),
                              font: font, size: 13, color: Showcase.textDim)
        if entities.count > 3,
           let transform = app.world.getComponent(Transform2D.self, from: entities[3]) {
            let cx = d4x + 140
            let cy = d4y + 65
            let r = transform.rotation
            let len: Float = 30
            let endX = cx + cosf(r) * len
            let endY = cy + sinf(r) * len
            app.renderer.drawCircle(center: Vector2(x: cx, y: cy), radius: 6,
                                   color: Showcase.sequenceColor)
            app.renderer.drawLine(from: Vector2(x: cx, y: cy),
                                  to: Vector2(x: endX, y: endY),
                                  color: Showcase.sequenceColor, thickness: 3)
            app.renderer.drawText(String(format: "%.1f rad", r),
                                  position: Vector2(x: d4x + 200, y: d4y + 58),
                                  font: font, size: 12, color: Showcase.textDim)
        }

        // Completion counter
        app.renderer.drawText("Sequence completions: \(completionCount)",
                              position: Vector2(x: 10, y: screen.height - 40),
                              font: font, size: 13, color: Showcase.textDim)

        // Active tweens
        app.renderer.drawText("Active tweens: \(tweens.tweenCount)",
                              position: Vector2(x: 10, y: screen.height - 22),
                              font: font, size: 13, color: Showcase.textDim)

        // FPS
        app.renderer.drawText("\(app.fps) FPS",
                              position: Vector2(x: screen.width - 80, y: screen.height - 18),
                              font: font, size: 14, color: Color(r: 80, g: 80, b: 80))
    }

    func willExit(app: Application) {
        app.world.removeAllEventHandlers()
        tweens.removeAll()
        app.world.removeSystem(tweens)

        for entity in entities {
            app.world.destroyEntity(entity)
        }
        entities.removeAll()

        if ninePatchTex != .invalid { app.renderer.destroyTexture(ninePatchTex) }
        if font != .invalid { app.renderer.destroyFont(font) }
    }

    // MARK: - Setup

    private func setupDemos(app: Application) {
        let world = app.world

        // Demo 1: Patrol path (square loop sequence)
        let patrol = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 80, y: 110)), to: patrol)
        world.addComponent(Sprite(texture: .invalid), to: patrol)
        entities.append(patrol)

        let patrolHandle = tweens.sequence(patrol, steps: [
            .moveTo(target: Vector2(x: 280, y: 110), duration: 0.6, easing: .cubicInOut),
            .wait(duration: 0.1),
            .moveTo(target: Vector2(x: 280, y: 270), duration: 0.6, easing: .cubicInOut),
            .wait(duration: 0.1),
            .moveTo(target: Vector2(x: 80, y: 270), duration: 0.6, easing: .cubicInOut),
            .wait(duration: 0.1),
            .moveTo(target: Vector2(x: 80, y: 110), duration: 0.6, easing: .cubicInOut),
            .wait(duration: 0.1),
            .callback { [weak self] in
                self?.completionCount += 1
            }
        ], repeatCount: -1, in: world)
        _ = patrolHandle

        // Demo 2: Fade chain
        let fade = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 400, y: 130)), to: fade)
        world.addComponent(Sprite(texture: .invalid, tint: Color(r: 100, g: 180, b: 255, a: 255)), to: fade)
        entities.append(fade)

        let fadeHandle = tweens.sequence(fade, steps: [
            .fadeOut(duration: 0.8, easing: .quadIn),
            .wait(duration: 0.4),
            .fadeIn(duration: 0.8, easing: .quadOut),
            .wait(duration: 0.4),
        ], repeatCount: -1, in: world)
        _ = fadeHandle

        // Demo 3: Scale pulse (yoyo)
        let pulse = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 780, y: 135)), to: pulse)
        world.addComponent(Sprite(texture: .invalid), to: pulse)
        entities.append(pulse)

        let pulseHandle = tweens.scaleTo(pulse,
                                         target: Vector2(x: 1.6, y: 1.6),
                                         duration: 0.6, easing: .elasticOut, in: world)
        tweens.setYoyo(pulseHandle)
        tweens.setRepeat(pulseHandle, count: -1)

        // Demo 4: Rotation
        let rotator = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 780, y: 260)), to: rotator)
        world.addComponent(Sprite(texture: .invalid), to: rotator)
        entities.append(rotator)

        let rotHandle = tweens.rotateTo(rotator,
                                         target: Float.pi * 2,
                                         duration: 1.5, easing: .backOut, in: world)
        tweens.setRepeat(rotHandle, count: -1)
    }
}
