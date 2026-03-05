import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

final class GameScene: Scene {
    private var font: FontHandle = .invalid
    private var sounds: DungeonSounds.SoundSet!

    // Systems
    private var physics: PhysicsWorld2D!
    private var lighting: LightingSystem!
    private var particleSystem: ParticleSystem!

    // Dungeon data
    private var dungeonData: DungeonBuilder.DungeonData!
    private var camera = Camera2D()

    // Entities
    private var playerEntity: Entity = .null
    private var enemyEntities: [Entity] = []
    private var sconceEntities: [Entity] = []
    private var torchParticleEntity: Entity = .null
    private var allEntities: [Entity] = []

    // State
    private var footstepTimer: Float = 0

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()
        sounds = DungeonSounds.generate(audio: app.audio)

        // Physics (top-down)
        physics = PhysicsWorld2D(gravity: .zero)
        app.world.addSystem(physics)

        // Particles
        particleSystem = ParticleSystem()
        app.world.addSystem(particleSystem)

        // Lighting
        lighting = LightingSystem(options: LightingOptions(
            ambientColor: Dungeon.ambientColor
        ))
        lighting.initialize(renderer: app.renderer)
        app.world.addSystem(lighting)

        // Generate dungeon
        dungeonData = DungeonBuilder.generate(renderer: app.renderer, world: app.world)
        allEntities.append(contentsOf: dungeonData.wallEntities)

        // Player
        spawnPlayer(app: app)

        // Room lights (wall sconces)
        for (i, center) in dungeonData.roomCenters.enumerated() {
            let sconce = app.world.createEntity()
            app.world.addComponent(Transform2D(position: center), to: sconce)
            app.world.addComponent(Light2D(
                color: Dungeon.sconceColor,
                intensity: 0.8,
                radius: Dungeon.sconceRadius,
                castsShadows: true,
                falloff: 1.5
            ), to: sconce)
            app.world.addComponent(WallSconce(roomIndex: i), to: sconce)
            sconceEntities.append(sconce)
            allEntities.append(sconce)
        }

        // Enemies with patrol paths
        if dungeonData.roomCenters.count >= 3 {
            spawnEnemy(app: app, roomCenter: dungeonData.roomCenters[1], patrolRadius: 60)
            if dungeonData.roomCenters.count >= 5 {
                spawnEnemy(app: app, roomCenter: dungeonData.roomCenters[3], patrolRadius: 50)
            }
        }

        // Camera setup
        camera.zoom = 2.0
        camera.offset = Vector2(x: Dungeon.screenWidth / 2, y: Dungeon.screenHeight / 2)
    }

    func update(app: Application, deltaTime: Double) {
        let dt = Float(deltaTime)

        // Escape to menu
        if app.input.isKeyPressed(.escape) {
            app.sceneManager.replace(
                with: MenuScene(),
                transition: .fade(duration: 0.5),
                app: app
            )
            return
        }

        // Toggle shadow debug (F1 to avoid conflict with D movement key)
        if app.input.isKeyPressed(.f1) {
            lighting.debugShadowVolumes.toggle()
        }

        // Player movement
        var moveX: Float = 0
        var moveY: Float = 0
        if app.input.isKeyDown(.w) { moveY -= 1 }
        if app.input.isKeyDown(.s) { moveY += 1 }
        if app.input.isKeyDown(.a) { moveX -= 1 }
        if app.input.isKeyDown(.d) { moveX += 1 }

        let len = sqrtf(moveX * moveX + moveY * moveY)
        if len > 0 {
            moveX /= len
            moveY /= len
        }
        let speed = len * Dungeon.playerSpeed

        app.world.updateComponent(Velocity2D.self, on: playerEntity) { vel in
            vel.linear = Vector2(x: moveX * Dungeon.playerSpeed, y: moveY * Dungeon.playerSpeed)
        }
        app.world.updateComponent(PlayerComp.self, on: playerEntity) { player in
            player.speed = speed
            if speed > 0.1 {
                player.facingAngle = atan2f(moveY, moveX)
            }
        }

        // Footstep sounds
        if speed > 10 {
            footstepTimer -= dt
            if footstepTimer <= 0 {
                app.audio.playSound(sounds.footstep, volume: 0.2, pitch: 0.9 + Float(dt * 10).truncatingRemainder(dividingBy: 0.2), looping: false)
                footstepTimer = 0.3
            }
        } else {
            footstepTimer = 0
        }

        // Torch flicker
        app.world.updateComponent(Torch.self, on: playerEntity) { torch in
            torch.flickerPhase += dt * 5
        }
        if let torch = app.world.getComponent(Torch.self, from: playerEntity) {
            let flicker = 1.0 + sinf(torch.flickerPhase) * 0.1 + sinf(torch.flickerPhase * 2.7) * 0.05
            app.world.updateComponent(Light2D.self, on: playerEntity) { light in
                light.intensity = 1.3 * flicker
            }
        }

        // Enemy patrol
        for entity in enemyEntities {
            app.world.updateComponent(EnemyComp.self, on: entity) { enemy in
                guard !enemy.patrolPath.isEmpty else { return }
                let target = enemy.patrolPath[enemy.currentWaypoint]
                if let pos = app.world.getComponent(Transform2D.self, from: entity) {
                    let dx = target.x - pos.position.x
                    let dy = target.y - pos.position.y
                    let dist = sqrtf(dx * dx + dy * dy)
                    if dist < 5 {
                        enemy.currentWaypoint = (enemy.currentWaypoint + 1) % enemy.patrolPath.count
                    } else {
                        let nx = dx / dist
                        let ny = dy / dist
                        enemy.facingAngle = atan2f(ny, nx)
                        app.world.updateComponent(Velocity2D.self, on: entity) { vel in
                            vel.linear = Vector2(x: nx * Dungeon.enemySpeed, y: ny * Dungeon.enemySpeed)
                        }
                    }
                }
            }

            // Line of sight check (raycast toward player)
            if let enemyPos = app.world.getComponent(Transform2D.self, from: entity),
               let playerPos = app.world.getComponent(Transform2D.self, from: playerEntity) {
                let dx = playerPos.position.x - enemyPos.position.x
                let dy = playerPos.position.y - enemyPos.position.y
                let dist = sqrtf(dx * dx + dy * dy)
                if dist < 200 && dist > 0.1 {
                    let dir = Vector2(x: dx / dist, y: dy / dist)
                    let hit = physics.raycast(world: app.world, origin: enemyPos.position,
                                              direction: dir, maxDistance: dist,
                                              layerMask: Dungeon.layerWall)
                    if hit == nil {
                        // Can see player — increase alert
                        app.world.updateComponent(EnemyComp.self, on: entity) { enemy in
                            let prev = enemy.alertLevel
                            enemy.alertLevel = min(1.0, enemy.alertLevel + dt * 0.5)
                            if prev < 0.5 && enemy.alertLevel >= 0.5 {
                                app.audio.playSound(sounds.enemyAlert, volume: 0.4, pitch: 1.0, looping: false)
                            }
                        }
                    } else {
                        // Wall blocks line of sight — decay alert
                        app.world.updateComponent(EnemyComp.self, on: entity) { enemy in
                            enemy.alertLevel = max(0, enemy.alertLevel - dt * 0.3)
                        }
                    }
                } else {
                    app.world.updateComponent(EnemyComp.self, on: entity) { enemy in
                        enemy.alertLevel = max(0, enemy.alertLevel - dt * 0.3)
                    }
                }
            }

            // Update enemy spot light direction
            if let enemy = app.world.getComponent(EnemyComp.self, from: entity) {
                app.world.updateComponent(Light2D.self, on: entity) { light in
                    light.lightType = .spot(direction: enemy.facingAngle, coneAngle: 0.6)
                    light.intensity = 0.6 + enemy.alertLevel * 0.6
                    light.color = Color(
                        r: UInt8(200 + Int(enemy.alertLevel * 55)),
                        g: UInt8(max(0, 180 - Int(enemy.alertLevel * 150))),
                        b: UInt8(max(0, 100 - Int(enemy.alertLevel * 100)))
                    )
                }
            }
        }

        // Sync torch particle position to player
        if let playerPos = app.world.getComponent(Transform2D.self, from: playerEntity) {
            app.world.updateComponent(Transform2D.self, on: torchParticleEntity) { t in
                t.position = playerPos.position
            }
        }

        // Camera follow player
        if let playerPos = app.world.getComponent(Transform2D.self, from: playerEntity) {
            let lerpSpeed: Float = 5
            camera.target.x += (playerPos.position.x - camera.target.x) * lerpSpeed * dt
            camera.target.y += (playerPos.position.y - camera.target.y) * lerpSpeed * dt
        }
    }

    func render(app: Application, interpolation: Double) {
        let screen = app.renderer.screenSize

        // Begin camera
        app.renderer.beginCamera(camera)

        // Draw tilemap
        app.renderer.drawTileMap(dungeonData.tileMap, position: .zero, camera: camera)

        // Draw enemies
        for entity in enemyEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity),
               let enemy = app.world.getComponent(EnemyComp.self, from: entity) {
                let r = UInt8(220)
                let g = UInt8(max(0, 60 - Int(enemy.alertLevel * 60)))
                let b = UInt8(max(0, 60 - Int(enemy.alertLevel * 60)))
                app.renderer.drawCircle(center: pos.position, radius: 10, color: Color(r: r, g: g, b: b))

                // Direction indicator
                let dirX = pos.position.x + cosf(enemy.facingAngle) * 14
                let dirY = pos.position.y + sinf(enemy.facingAngle) * 14
                app.renderer.drawCircle(center: Vector2(x: dirX, y: dirY), radius: 3,
                                       color: Color(r: 255, g: 100, b: 100))
            }
        }

        // Draw player
        if let pos = app.world.getComponent(Transform2D.self, from: playerEntity) {
            app.renderer.drawCircle(center: pos.position, radius: 10, color: Dungeon.playerColor)
        }

        // Draw particles (torch flame) with additive blend
        app.renderer.beginBlendMode(.additive)
        if torchParticleEntity != .null,
           let emitter = app.world.getComponent(ParticleEmitter.self, from: torchParticleEntity),
           let pos = app.world.getComponent(Transform2D.self, from: torchParticleEntity) {
            app.renderer.drawParticles(emitter, at: pos.position)
        }
        app.renderer.endBlendMode()

        app.renderer.endCamera()

        // Render lighting
        lighting.renderLightMap(renderer: app.renderer, camera: camera)
        lighting.compositeLightMap(renderer: app.renderer)

        // Shadow debug overlay (world-space, needs camera)
        app.renderer.beginCamera(camera)
        lighting.drawShadowDebug(renderer: app.renderer)
        app.renderer.endCamera()

        // HUD
        let debugInfo = "Lights: \(lighting.debugLightCount)  Occluders: \(lighting.debugOccluderCount)  \(lighting.debugShadowInfo)"
        app.renderer.drawText(debugInfo,
                              position: Vector2(x: 5, y: 5),
                              font: font, size: 12, color: Dungeon.textBright)
        app.renderer.drawText("[ESC] Menu  [WASD] Move  [F1] Toggle Debug",
                              position: Vector2(x: 5, y: screen.height - 18),
                              font: font, size: 11, color: Dungeon.textDim)

        // Minimap
        drawMinimap(app: app)
    }

    func willExit(app: Application) {
        app.world.removeAllEventHandlers()

        for entity in allEntities {
            app.world.destroyEntity(entity)
        }
        for entity in enemyEntities {
            app.world.destroyEntity(entity)
        }
        if playerEntity != .null { app.world.destroyEntity(playerEntity) }
        if torchParticleEntity != .null { app.world.destroyEntity(torchParticleEntity) }

        lighting.shutdown(renderer: app.renderer)
        app.world.removeSystem(lighting)
        app.world.removeSystem(particleSystem)
        app.world.removeSystem(physics)

        if dungeonData.tileTexture != .invalid {
            app.renderer.destroyTexture(dungeonData.tileTexture)
        }
        sounds.unloadAll(audio: app.audio)
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }

    // MARK: - Spawn Helpers

    private func spawnPlayer(app: Application) {
        guard let firstRoom = dungeonData.roomCenters.first else { return }
        playerEntity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: firstRoom), to: playerEntity)
        app.world.addComponent(Velocity2D(), to: playerEntity)
        app.world.addComponent(RigidBody2D(
            mass: 1, gravityScale: 0, bodyType: .dynamic, linearDamping: 10
        ), to: playerEntity)
        app.world.addComponent(Collider2D(
            shape: .circle(radius: 10),
            layer: Dungeon.layerPlayer,
            mask: Dungeon.layerWall | Dungeon.layerEnemy
        ), to: playerEntity)
        app.world.addComponent(PlayerComp(), to: playerEntity)
        app.world.addComponent(Torch(), to: playerEntity)
        app.world.addComponent(Sprite(texture: .invalid), to: playerEntity)

        // Player torch light
        app.world.addComponent(Light2D(
            color: Dungeon.torchColor,
            intensity: 1.3,
            radius: Dungeon.torchRadius,
            castsShadows: true,
            falloff: 1.5,
            softShadowRadius: 6
        ), to: playerEntity)

        // Torch flame particle emitter
        torchParticleEntity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: firstRoom), to: torchParticleEntity)
        app.world.addComponent(ParticleEmitter(
            emissionRate: 30,
            maxParticles: 60,
            lifetime: 0.3...0.7,
            speed: 10...30,
            angle: (Float.pi * 1.3)...(Float.pi * 1.7), // upward
            startColor: Color(r: 255, g: 200, b: 80, a: 200),
            endColor: Color(r: 255, g: 80, b: 0, a: 0),
            startScale: 0.8...1.2,
            endScale: 0.2,
            renderShape: .circle(radius: 2),
            worldSpace: false
        ), to: torchParticleEntity)

        // Parent particle to player
        app.world.setParent(playerEntity, for: torchParticleEntity)
        allEntities.append(playerEntity)
    }

    private func spawnEnemy(app: Application, roomCenter: Vector2, patrolRadius: Float) {
        let entity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: roomCenter), to: entity)
        app.world.addComponent(Velocity2D(), to: entity)
        app.world.addComponent(RigidBody2D(
            mass: 1, gravityScale: 0, bodyType: .dynamic, linearDamping: 8
        ), to: entity)
        app.world.addComponent(Collider2D(
            shape: .circle(radius: 10),
            layer: Dungeon.layerEnemy,
            mask: Dungeon.layerWall | Dungeon.layerPlayer
        ), to: entity)
        app.world.addComponent(Sprite(texture: .invalid), to: entity)

        // Patrol path (square around room center)
        let path = [
            Vector2(x: roomCenter.x - patrolRadius, y: roomCenter.y - patrolRadius),
            Vector2(x: roomCenter.x + patrolRadius, y: roomCenter.y - patrolRadius),
            Vector2(x: roomCenter.x + patrolRadius, y: roomCenter.y + patrolRadius),
            Vector2(x: roomCenter.x - patrolRadius, y: roomCenter.y + patrolRadius),
        ]
        app.world.addComponent(EnemyComp(patrolPath: path), to: entity)

        // Spot light on enemy
        app.world.addComponent(Light2D(
            lightType: .spot(direction: 0, coneAngle: 0.6),
            color: Color(r: 200, g: 180, b: 100),
            intensity: 0.6,
            radius: 120,
            castsShadows: true,
            falloff: 2.0
        ), to: entity)

        enemyEntities.append(entity)
    }

    // MARK: - Helpers

    private func worldToScreen(_ worldPos: Vector2) -> Vector2 {
        let zoom = camera.zoom
        return Vector2(
            x: (worldPos.x - camera.target.x) * zoom + camera.offset.x,
            y: (worldPos.y - camera.target.y) * zoom + camera.offset.y
        )
    }

    // MARK: - Minimap

    private func drawMinimap(app: Application) {
        let renderer = app.renderer
        let mmX: Float = Dungeon.screenWidth - 110
        let mmY: Float = 10
        let mmScale: Float = 2.5

        // Background
        renderer.drawRect(Rect(x: mmX - 2, y: mmY - 2,
                                width: Float(Dungeon.mapCols) * mmScale + 4,
                                height: Float(Dungeon.mapRows) * mmScale + 4),
                          color: Color(r: 0, g: 0, b: 0, a: 180))

        // Tiles (simplified — just floor/wall indicators)
        let layer = dungeonData.tileMap.layers[0]
        for row in 0..<Dungeon.mapRows {
            for col in 0..<Dungeon.mapCols {
                if let tile = layer.tile(atColumn: col, row: row), tile.id == 2 {
                    renderer.drawRect(
                        Rect(x: mmX + Float(col) * mmScale, y: mmY + Float(row) * mmScale,
                             width: mmScale, height: mmScale),
                        color: Color(r: 60, g: 60, b: 80, a: 160)
                    )
                }
            }
        }

        // Player dot
        if let pos = app.world.getComponent(Transform2D.self, from: playerEntity) {
            let px = mmX + pos.position.x / Float(Dungeon.tileSize) * mmScale
            let py = mmY + pos.position.y / Float(Dungeon.tileSize) * mmScale
            renderer.drawCircle(center: Vector2(x: px, y: py), radius: 2, color: Dungeon.playerColor)
        }

        // Enemy dots
        for entity in enemyEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity) {
                let ex = mmX + pos.position.x / Float(Dungeon.tileSize) * mmScale
                let ey = mmY + pos.position.y / Float(Dungeon.tileSize) * mmScale
                renderer.drawCircle(center: Vector2(x: ex, y: ey), radius: 1.5, color: Dungeon.enemyColor)
            }
        }
    }
}
