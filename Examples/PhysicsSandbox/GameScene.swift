import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

final class GameScene: Scene {
    deinit {}
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var physics: PhysicsWorld2D!
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var sounds: SandboxSounds.SoundSet!
    private var currentTab: Int = 0
    private var demoEntities: [Entity] = []
    private var wallEntities: [Entity] = []
    private var projectileEntities: [Entity] = []

    // Mouse interaction state
    private var draggedEntity: Entity = .null
    private var dragOffset: Vector2 = .zero

    // Debug options
    private var debugOptions = PhysicsDebugRendererOptions(
        drawColliders: true,
        drawContacts: true,
        drawVelocities: false,
        drawNormals: false,
        drawJoints: true,
        drawCCDPaths: true
    )
    private var showDebug: Bool = true

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()
        sounds = SandboxSounds.generate(audio: app.audio)

        // Setup physics
        physics = PhysicsWorld2D(gravity: Sandbox.gravity)
        app.world.addSystem(physics)

        physics.onJointBroken = { [weak self] _ in
            if let self = self {
                app.audio.playSound(sounds.jointBreak, volume: 0.5, pitch: 1.0, looping: false)
            }
        }

        // Build arena walls
        buildWalls(app: app)

        // Load first tab
        loadTab(0, app: app)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func update(app: Application, deltaTime: Double) {
        let dt = Float(deltaTime)

        // Tab switching (keys 1-6)
        for i in 0..<6 {
            let keys: [Key] = [.one, .two, .three, .four, .five, .six]
            if app.input.isKeyPressed(keys[i]) && i != currentTab {
                loadTab(i, app: app)
            }
        }

        // Time scale controls: P=pause, F1=slow, F2=normal, F3=fast
        if app.input.isKeyPressed(.p) { app.timeScale = 0 }
        if app.input.isKeyPressed(.f1) { app.timeScale = 0.25 }
        if app.input.isKeyPressed(.f2) { app.timeScale = 1.0 }
        if app.input.isKeyPressed(.f3) { app.timeScale = 4.0 }

        // Toggle debug rendering
        if app.input.isKeyPressed(.d) { showDebug.toggle() }

        // Toggle velocity/normal debug
        if app.input.isKeyPressed(.v) { debugOptions.drawVelocities.toggle() }
        if app.input.isKeyPressed(.n) { debugOptions.drawNormals.toggle() }

        // Mouse picking via pointQuery
        let mousePos = app.input.mousePosition
        if app.input.isMouseButtonPressed(.left) {
            let hits = physics.pointQuery(world: app.world, point: mousePos)
            for hit in hits {
                if app.world.getComponent(Draggable.self, from: hit.entity) != nil,
                   let transform = app.world.getComponent(Transform2D.self, from: hit.entity) {
                    draggedEntity = hit.entity
                    dragOffset = Vector2(x: transform.position.x - mousePos.x, y: transform.position.y - mousePos.y)
                    break
                }
            }
        }

        // Drag
        if draggedEntity != .null && app.input.isMouseButtonDown(.left) {
            let targetPos = Vector2(x: mousePos.x + dragOffset.x, y: mousePos.y + dragOffset.y)
            app.world.updateComponent(Velocity2D.self, on: draggedEntity) { vel in
                if let pos = app.world.getComponent(Transform2D.self, from: draggedEntity) {
                    vel.linear = Vector2(
                        x: (targetPos.x - pos.position.x) / max(dt, 0.001),
                        y: (targetPos.y - pos.position.y) / max(dt, 0.001)
                    )
                }
            }
        }

        // Release / throw
        if app.input.isMouseButtonReleased(.left) && draggedEntity != .null {
            draggedEntity = .null
        }

        // Right-click explosion (area query)
        if app.input.isMouseButtonPressed(.right) {
            let radius: Float = 120
            let hits = physics.areaQuery(
                world: app.world,
                rect: Rect(x: mousePos.x - radius, y: mousePos.y - radius, width: radius * 2, height: radius * 2)
            )
            for hit in hits {
                guard let pos = app.world.getComponent(Transform2D.self, from: hit.entity) else { continue }
                let dx = pos.position.x - mousePos.x
                let dy = pos.position.y - mousePos.y
                let dist = sqrtf(dx * dx + dy * dy)
                guard dist < radius && dist > 0.1 else { continue }

                let strength: Float = (1.0 - dist / radius) * 800
                let nx = dx / dist
                let ny = dy / dist

                app.world.updateComponent(Velocity2D.self, on: hit.entity) { vel in
                    vel.linear.x += nx * strength
                    vel.linear.y += ny * strength
                }
            }
            app.audio.playSound(sounds.explosion, volume: 0.5, pitch: 1.0, looping: false)
        }

        // Space to fire projectile (tab 6 only)
        if currentTab == 5 && app.input.isKeyPressed(.space) {
            let proj = DemoBuilders.spawnProjectile(
                in: app.world,
                from: Vector2(x: 200, y: 380),
                toward: mousePos
            )
            projectileEntities.append(proj)
            app.audio.playSound(sounds.launch, volume: 0.5, pitch: 1.0, looping: false)
        }

        // Projectile lifetime cleanup
        var toRemove: [Int] = []
        for (idx, entity) in projectileEntities.enumerated() {
            var expired = false
            app.world.updateComponent(Projectile.self, on: entity) { proj in
                proj.lifetime -= dt
                if proj.lifetime <= 0 { expired = true }
            }
            if expired { toRemove.append(idx) }
        }
        for idx in toRemove.reversed() {
            app.world.destroyEntity(projectileEntities[idx])
            projectileEntities.remove(at: idx)
        }
    }

    func render(app: Application, interpolation _: Double) {
        let screen = app.renderer.screenSize

        // Draw wall entities as rects
        for entity in wallEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity),
               let collider = app.world.getComponent(Collider2D.self, from: entity) {
                if case .aabb(let he) = collider.shape {
                    app.renderer.drawRect(
                        Rect(x: pos.position.x - he.x, y: pos.position.y - he.y, width: he.x * 2, height: he.y * 2),
                        color: Sandbox.wallColor
                    )
                }
            }
        }

        // Draw demo entities
        for entity in demoEntities {
            guard let pos = app.world.getComponent(Transform2D.self, from: entity),
                  let collider = app.world.getComponent(Collider2D.self, from: entity) else { continue }
            let rb = app.world.getComponent(RigidBody2D.self, from: entity)
            let isStatic = rb?.bodyType == .static
            let color = isStatic ? Sandbox.staticColor : Sandbox.dynamicColor

            switch collider.shape {
            case .aabb(let he):
                app.renderer.drawRect(
                    Rect(x: pos.position.x - he.x, y: pos.position.y - he.y, width: he.x * 2, height: he.y * 2),
                    color: color
                )

            case .circle(let r):
                app.renderer.drawCircle(center: pos.position, radius: r, color: color)

            default:
                break
            }
        }

        // Draw projectiles
        for entity in projectileEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity) {
                app.renderer.drawCircle(center: pos.position, radius: 5, color: Sandbox.dangerColor)
            }
        }

        // Debug rendering
        if showDebug {
            app.renderer.drawPhysicsDebug(world: app.world, events: physics.events, options: debugOptions)
            app.renderer.drawJointsDebug(physics: physics, world: app.world, options: debugOptions)
        }

        // Tab bar
        let tabWidth: Float = 140
        let tabHeight: Float = 30
        let tabY: Float = 5
        for (i, name) in Sandbox.tabNames.enumerated() {
            let x: Float = 10 + Float(i) * (tabWidth + 5)
            let color = i == currentTab ? Sandbox.activeTab : Sandbox.inactiveTab
            app.renderer.drawRect(Rect(x: x, y: tabY, width: tabWidth, height: tabHeight), color: color)
            app.renderer.drawText(name,
                                  position: Vector2(x: x + 5, y: tabY + 7),
                                  font: font, size: 13, color: Sandbox.textBright)
        }

        // HUD info
        let infoY = screen.height - 80
        app.renderer.drawText("[1-6] Switch Demo  [D] Debug  [V] Velocities  [N] Normals",
                              position: Vector2(x: 10, y: infoY),
                              font: font, size: 12, color: Sandbox.textDim)
        app.renderer.drawText("[P] Pause  [F1] Slow  [F2] Normal  [F3] Fast  |  Time: \(String(format: "%.2f", app.timeScale))x",
                              position: Vector2(x: 10, y: infoY + 16),
                              font: font, size: 12, color: Sandbox.textDim)
        app.renderer.drawText("[Left-Click] Drag  [Right-Click] Explosion" + (currentTab == 5 ? "  [Space] Fire" : ""),
                              position: Vector2(x: 10, y: infoY + 32),
                              font: font, size: 12, color: Sandbox.textDim)
        app.renderer.drawText("Joints: \(physics.jointCount)  |  Debug: \(showDebug ? "ON" : "OFF")",
                              position: Vector2(x: 10, y: infoY + 48),
                              font: font, size: 12, color: Sandbox.textDim)

        // FPS
        app.renderer.drawText("\(app.fps) FPS",
                              position: Vector2(x: screen.width - 80, y: screen.height - 18),
                              font: font, size: 14, color: Color(r: 80, g: 80, b: 80))
    }

    func willExit(app: Application) {
        app.world.removeAllEventHandlers()
        cleanupDemo(app: app)
        cleanupProjectiles(app: app)

        for entity in wallEntities {
            app.world.destroyEntity(entity)
        }
        wallEntities.removeAll()

        physics.removeAllJoints()
        app.world.removeSystem(physics)
        sounds.unloadAll(audio: app.audio)
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }

    // MARK: - Private

    private func buildWalls(app: Application) {
        let w = Sandbox.screenWidth
        let h = Sandbox.screenHeight
        let thickness: Float = 20

        // Floor
        wallEntities.append(DemoBuilders.createStaticBox(in: app.world, pos: Vector2(x: w / 2, y: h - thickness / 2), hw: w / 2, hh: thickness / 2))
        // Ceiling
        wallEntities.append(DemoBuilders.createStaticBox(in: app.world, pos: Vector2(x: w / 2, y: thickness / 2 + 40), hw: w / 2, hh: thickness / 2))
        // Left wall
        wallEntities.append(DemoBuilders.createStaticBox(in: app.world, pos: Vector2(x: thickness / 2, y: h / 2), hw: thickness / 2, hh: h / 2))
        // Right wall
        wallEntities.append(DemoBuilders.createStaticBox(in: app.world, pos: Vector2(x: w - thickness / 2, y: h / 2), hw: thickness / 2, hh: h / 2))
    }

    private func loadTab(_ tab: Int, app: Application) {
        cleanupDemo(app: app)
        cleanupProjectiles(app: app)
        physics.removeAllJoints()
        currentTab = tab

        switch tab {
        case 0: demoEntities = DemoBuilders.buildRagdoll(in: app.world, physics: physics)
        case 1: demoEntities = DemoBuilders.buildBridge(in: app.world, physics: physics)
        case 2: demoEntities = DemoBuilders.buildCrane(in: app.world, physics: physics)
        case 3: demoEntities = DemoBuilders.buildElevator(in: app.world, physics: physics)
        case 4: demoEntities = DemoBuilders.buildMotorDemo(in: app.world, physics: physics)
        case 5: demoEntities = DemoBuilders.buildProjectileRange(in: app.world, physics: physics)
        default: break
        }
    }

    private func cleanupDemo(app: Application) {
        for entity in demoEntities {
            app.world.destroyEntity(entity)
        }
        demoEntities.removeAll()
    }

    private func cleanupProjectiles(app: Application) {
        for entity in projectileEntities {
            app.world.destroyEntity(entity)
        }
        projectileEntities.removeAll()
    }
}
