import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

final class EasingScene: Scene {
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var tweens: TweenSystem!
    private var font: FontHandle = .invalid
    private var ballEntities: [Entity] = []
    private var ninePatchTex: TextureHandle = .invalid
    private var ninePatchSourceRect = Rect()
    private var renderTarget: RenderTargetHandle = .invalid
    private var rtEntity: Entity = .null
    private var customEntity: Entity = .null

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()

        // Tween system
        tweens = TweenSystem()
        app.world.addSystem(tweens)

        // Generate nine-patch texture
        let (tex, srcRect) = generateNinePatchTexture(renderer: app.renderer)
        ninePatchTex = tex
        ninePatchSourceRect = srcRect

        // Create ball entities for each easing function
        let easings = Showcase.allEasings
        for (i, entry) in easings.enumerated() {
            let col = i % Showcase.gridCols
            let row = i / Showcase.gridCols

            let cellX = Showcase.gridOffsetX + Float(col) * (Showcase.cellWidth + Showcase.cellPadding)
            let cellY = Showcase.gridOffsetY + Float(row) * (Showcase.cellHeight + Showcase.cellPadding)
            let trackStartX = cellX + 60
            let trackEndX = trackStartX + Showcase.trackLength

            let entity = app.world.createEntity()
            app.world.addComponent(
                Transform2D(position: Vector2(x: trackStartX, y: cellY + 55)),
                to: entity
            )
            app.world.addComponent(Sprite(texture: .invalid), to: entity)

            // Tween: move ball along the horizontal track using this easing
            let handle = tweens.moveTo(
                entity,
                target: Vector2(x: trackEndX, y: cellY + 55),
                duration: 1.5,
                easing: entry.easing,
                in: app.world
            )
            tweens.setYoyo(handle)
            tweens.setRepeat(handle, count: -1)

            ballEntities.append(entity)
        }

        // Custom tween demo: entity that color-shifts (shown as a separate panel)
        customEntity = app.world.createEntity()
        app.world.addComponent(
            Transform2D(position: Vector2(x: Showcase.screenWidth - 180, y: Showcase.screenHeight - 80)),
            to: customEntity
        )
        app.world.addComponent(Sprite(texture: .invalid, tint: Showcase.accentColor), to: customEntity)
        let customHandle = tweens.custom(
            customEntity,
            duration: 2.0,
            easing: .sineInOut
        ) { world, entity, t in
            world.updateComponent(Sprite.self, on: entity) { sprite in
                let r = UInt8(100 + t * 155)
                let g = UInt8(180 - t * 130)
                let b = UInt8(255 - t * 200)
                sprite.tint = Color(r: r, g: g, b: b)
            }
        }
        tweens.setYoyo(customHandle)
        tweens.setRepeat(customHandle, count: -1)

        // Render target demo: a small scene drawn offscreen and tweened
        renderTarget = app.renderer.createRenderTarget(width: 120, height: 80)
        if renderTarget != .invalid {
            // Draw a pattern into the render target
            app.renderer.beginRenderTarget(renderTarget)
            app.renderer.drawRect(Rect(x: 0, y: 0, width: 120, height: 80), color: Color(r: 30, g: 50, b: 80))
            app.renderer.drawRect(Rect(x: 10, y: 10, width: 40, height: 60), color: Showcase.highlightColor)
            app.renderer.drawCircle(center: Vector2(x: 80, y: 40), radius: 25, color: Showcase.accentColor)
            app.renderer.drawText("RT", position: Vector2(x: 40, y: 30), font: font, size: 16, color: .white)
            app.renderer.endRenderTarget()

            // Create an entity to tween the RT position
            rtEntity = app.world.createEntity()
            app.world.addComponent(
                Transform2D(position: Vector2(x: Showcase.screenWidth - 180, y: Showcase.screenHeight - 170)),
                to: rtEntity
            )
            let rtHandle = tweens.moveTo(
                rtEntity,
                target: Vector2(x: Showcase.screenWidth - 50, y: Showcase.screenHeight - 170),
                duration: 2.0,
                easing: .bounceOut,
                in: app.world
            )
            tweens.setYoyo(rtHandle)
            tweens.setRepeat(rtHandle, count: -1)
        }
    }

    func update(app: Application, deltaTime _: Double) {
        // Escape returns to menu
        if app.input.isKeyPressed(.escape) {
            app.sceneManager.replace(
                with: MenuScene(),
                transition: .fade(duration: 0.5),
                app: app
            )
        }

        // Space to restart all tweens
        if app.input.isKeyPressed(.space) {
            restartTweens(app: app)
        }

        // Tab to go to sequence scene
        if app.input.isKeyPressed(.tab) {
            app.sceneManager.replace(
                with: SequenceScene(),
                transition: .flash(duration: 0.4),
                app: app
            )
        }
    }

    func render(app: Application, interpolation _: Double) {
        let screen = app.renderer.screenSize
        let easings = Showcase.allEasings

        // Title
        app.renderer.drawText(
            "Easing Functions (19)",
            position: Vector2(x: 10, y: 8),
            font: font,
            size: 24,
            color: Showcase.textBright
        )
        app.renderer.drawText(
            "[ESC] Menu  [SPACE] Restart  [TAB] Sequences",
            position: Vector2(x: 10, y: 34),
            font: font,
            size: 12,
            color: Showcase.textDim
        )

        // Draw grid cells
        let ninePatch = NinePatchSprite(texture: ninePatchTex, sourceRect: ninePatchSourceRect, border: 12)

        for (i, entry) in easings.enumerated() {
            let col = i % Showcase.gridCols
            let row = i / Showcase.gridCols

            let cellX = Showcase.gridOffsetX + Float(col) * (Showcase.cellWidth + Showcase.cellPadding)
            let cellY = Showcase.gridOffsetY + Float(row) * (Showcase.cellHeight + Showcase.cellPadding)

            // Nine-patch panel background
            app.renderer.drawNinePatch(
                ninePatch,
                destination: Rect(
                    x: cellX,
                    y: cellY,
                    width: Showcase.cellWidth,
                    height: Showcase.cellHeight
                )
            )

            // Label
            app.renderer.drawText(
                entry.name,
                position: Vector2(x: cellX + 5, y: cellY + 5),
                font: font,
                size: 12,
                color: Showcase.textDim
            )

            // Easing curve (small, in upper right of cell)
            let curveRect = Rect(x: cellX + 5, y: cellY + 20, width: 48, height: 30)
            drawEasingCurve(
                easing: entry.easing,
                rect: curveRect,
                resolution: 30,
                color: Color(r: 80, g: 80, b: 100),
                renderer: app.renderer
            )

            // Track line
            let trackStartX = cellX + 60
            let trackEndX = trackStartX + Showcase.trackLength
            let trackY = cellY + 55
            drawTrack(
                startX: trackStartX,
                endX: trackEndX,
                y: trackY,
                color: Showcase.trackColor,
                renderer: app.renderer
            )

            // Draw the ball at its tweened position
            if i < ballEntities.count,
               let pos = app.world.getComponent(Transform2D.self, from: ballEntities[i]) {
                app.renderer.drawCircle(
                    center: pos.position,
                    radius: Showcase.ballRadius,
                    color: Showcase.accentColor
                )
            }
        }

        // Custom tween demo panel
        let customPanelX = Showcase.screenWidth - 200
        let customPanelY = Showcase.screenHeight - 100
        app.renderer.drawNinePatch(
            ninePatch,
            destination: Rect(
                x: customPanelX,
                y: customPanelY,
                width: 190,
                height: 35
            )
        )
        app.renderer.drawText(
            "Custom Color Tween",
            position: Vector2(x: customPanelX + 5, y: customPanelY + 3),
            font: font,
            size: 11,
            color: Showcase.textDim
        )
        // Draw color swatch
        if let sprite = app.world.getComponent(Sprite.self, from: customEntity) {
            app.renderer.drawRect(
                Rect(x: customPanelX + 130, y: customPanelY + 5, width: 50, height: 25),
                color: sprite.tint
            )
        }

        // Render target demo
        if renderTarget != .invalid, let pos = app.world.getComponent(Transform2D.self, from: rtEntity) {
            app.renderer.drawNinePatch(
                ninePatch,
                destination: Rect(
                    x: customPanelX,
                    y: customPanelY - 85,
                    width: 190,
                    height: 80
                )
            )
            app.renderer.drawText(
                "Render Target + Tween",
                position: Vector2(x: customPanelX + 5, y: customPanelY - 82),
                font: font,
                size: 11,
                color: Showcase.textDim
            )
            app.renderer.drawRenderTarget(
                renderTarget,
                position: Vector2(x: pos.position.x - 60, y: pos.position.y - 20)
            )
        }

        // Tween count
        app.renderer.drawText(
            "Active tweens: \(tweens.tweenCount)",
            position: Vector2(x: customPanelX, y: Showcase.screenHeight - 22),
            font: font,
            size: 12,
            color: Showcase.textDim
        )

        // FPS
        app.renderer.drawText(
            "\(app.fps) FPS",
            position: Vector2(x: 4, y: screen.height - 18),
            font: font,
            size: 14,
            color: Color(r: 80, g: 80, b: 80)
        )
    }

    func willExit(app: Application) {
        app.world.removeAllEventHandlers()
        tweens.removeAll()
        app.world.removeSystem(tweens)

        for entity in ballEntities {
            app.world.destroyEntity(entity)
        }
        ballEntities.removeAll()

        if customEntity != .null { app.world.destroyEntity(customEntity) }
        if rtEntity != .null { app.world.destroyEntity(rtEntity) }
        if renderTarget != .invalid { app.renderer.destroyRenderTarget(renderTarget) }
        if ninePatchTex != .invalid { app.renderer.destroyTexture(ninePatchTex) }
        if font != .invalid { app.renderer.destroyFont(font) }
    }

    // MARK: - Private

    private func restartTweens(app: Application) {
        tweens.removeAll()

        let easings = Showcase.allEasings
        for (i, entry) in easings.enumerated() {
            guard i < ballEntities.count else { break }
            let col = i % Showcase.gridCols
            let row = i / Showcase.gridCols
            let cellX = Showcase.gridOffsetX + Float(col) * (Showcase.cellWidth + Showcase.cellPadding)
            let cellY = Showcase.gridOffsetY + Float(row) * (Showcase.cellHeight + Showcase.cellPadding)
            let trackStartX = cellX + 60
            let trackEndX = trackStartX + Showcase.trackLength

            // Reset position
            app.world.updateComponent(Transform2D.self, on: ballEntities[i]) { t in
                t.position = Vector2(x: trackStartX, y: cellY + 55)
            }

            let handle = tweens.moveTo(
                ballEntities[i],
                target: Vector2(x: trackEndX, y: cellY + 55),
                duration: 1.5,
                easing: entry.easing,
                in: app.world
            )
            tweens.setYoyo(handle)
            tweens.setRepeat(handle, count: -1)
        }
    }
}
