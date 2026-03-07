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
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var sounds: ShooterSounds.SoundSet!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var physics: PhysicsWorld2D!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var particleSystem: ParticleSystem!
    private var batch = SpriteBatch(sortMode: .byTexture)

    // Entities
    private var playerEntity: Entity = .null
    private var wallEntities: [Entity] = []
    private var bulletEntities: [Entity] = []
    private var enemyEntities: [Entity] = []
    private var waveEntity: Entity = .null
    private var scoreEntity: Entity = .null
    private var particleEntities: [Entity] = []

    // Camera shake
    private var shakeTimer: Float = 0
    private var shakeIntensity: Float = 0
    private var camera = Camera2D()

    // Laser rendering state
    private var laserStart: Vector2 = .zero
    private var laserEnd: Vector2 = .zero
    private var laserActive: Bool = false
    private var laserTimer: Float = 0

    // Seed for spawning
    private var spawnSeed: UInt32 = 12_345

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()
        sounds = ShooterSounds.generate(audio: app.audio)

        // Physics
        physics = PhysicsWorld2D(gravity: .zero)
        app.world.addSystem(physics)

        // Particles
        particleSystem = ParticleSystem()
        app.world.addSystem(particleSystem)

        // Arena walls
        buildArena(app: app)

        // Player
        spawnPlayer(app: app)

        // Wave manager
        waveEntity = app.world.createEntity()
        app.world.addComponent(WaveManager(spawnTimer: 2.0), to: waveEntity)

        // Score tracker
        scoreEntity = app.world.createEntity()
        app.world.addComponent(ScoreTracker(), to: scoreEntity)

        // Camera centered on arena
        camera.target = Vector2(x: Shooter.screenWidth / 2, y: Shooter.screenHeight / 2)
        camera.offset = Vector2(x: Shooter.screenWidth / 2, y: Shooter.screenHeight / 2)

        // Events
        app.world.on(EnemyKilledEvent.self) { [weak self] event in
            guard let self = self else { return }
            app.world.updateComponent(ScoreTracker.self, on: scoreEntity) { score in
                score.score += 100
                score.kills += 1
            }
            shakeTimer = Shooter.shakeDuration
            shakeIntensity = Shooter.shakeIntensity
            spawnDeathParticles(at: event.position, app: app)
            app.audio.playSound(sounds.enemyDie, volume: 0.4, pitch: 1.0, looping: false)
        }

        app.world.on(WaveStartedEvent.self) { [weak self] _ in
            guard let self = self else { return }
            app.audio.playSound(sounds.waveStart, volume: 0.5, pitch: 1.0, looping: false)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func update(app: Application, deltaTime: Double) {
        let dt = Float(deltaTime)

        // Escape to menu
        if app.input.isKeyPressed(.escape) {
            app.sceneManager.replace(with: MenuScene(), transition: .fade(duration: 0.3), app: app)
            return
        }

        guard playerEntity != .null else { return }

        // Player movement (WASD)
        var moveX: Float = 0
        var moveY: Float = 0
        if app.input.isKeyDown(.w) { moveY -= 1 }
        if app.input.isKeyDown(.s) { moveY += 1 }
        if app.input.isKeyDown(.a) { moveX -= 1 }
        if app.input.isKeyDown(.d) { moveX += 1 }

        let mLen = sqrtf(moveX * moveX + moveY * moveY)
        if mLen > 0 { moveX /= mLen; moveY /= mLen }

        app.world.updateComponent(Velocity2D.self, on: playerEntity) { vel in
            vel.linear = Vector2(x: moveX * Shooter.playerSpeed, y: moveY * Shooter.playerSpeed)
        }

        // Aiming with mouse
        let mousePos = app.input.mousePosition
        if let playerPos = app.world.getComponent(Transform2D.self, from: playerEntity) {
            let dx = mousePos.x - playerPos.position.x
            let dy = mousePos.y - playerPos.position.y
            let angle = atan2f(dy, dx)
            app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in
                p.aimAngle = angle
            }
        }

        // Weapon switching (Tab or 1/2/3)
        if app.input.isKeyPressed(.tab) {
            app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in
                p.currentWeapon = WeaponType(rawValue: (p.currentWeapon.rawValue + 1) % 3) ?? .pistol
            }
        }
        if app.input.isKeyPressed(.one) {
            app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in p.currentWeapon = .pistol }
        }
        if app.input.isKeyPressed(.two) {
            app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in p.currentWeapon = .shotgun }
        }
        if app.input.isKeyPressed(.three) {
            app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in p.currentWeapon = .laser }
        }

        // Shooting
        app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in
            p.shootCooldown -= dt
        }
        if app.input.isMouseButtonPressed(.left) {
            if let player = app.world.getComponent(PlayerShooter.self, from: playerEntity),
               let playerPos = app.world.getComponent(Transform2D.self, from: playerEntity),
               player.shootCooldown <= 0 {
                fireWeapon(player: player, pos: playerPos.position, app: app)
                app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in
                    switch p.currentWeapon {
                    case .pistol: p.shootCooldown = 0.2
                    case .shotgun: p.shootCooldown = 0.6
                    case .laser: p.shootCooldown = 0.1
                    }
                }
            }
        }

        // Laser fade
        if laserTimer > 0 { laserTimer -= dt }
        if laserTimer <= 0 { laserActive = false }

        // Bullet lifetime
        var bulletsToRemove: [Int] = []
        for (idx, entity) in bulletEntities.enumerated() {
            var expired = false
            app.world.updateComponent(BulletComp.self, on: entity) { b in
                b.lifetime -= dt
                if b.lifetime <= 0 { expired = true }
            }
            if expired { bulletsToRemove.append(idx) }
        }
        for idx in bulletsToRemove.reversed() {
            app.world.destroyEntity(bulletEntities[idx])
            bulletEntities.remove(at: idx)
        }

        // Collision handling (single pass over physics events)
        for event in physics.events {
            guard event.type == .began else { continue }

            // Bullet-enemy collision
            handleBulletCollision(event, app: app)

            // Enemy-player collision (damage)
            let isPlayerA = event.entityA == playerEntity
            let isPlayerB = event.entityB == playerEntity
            if isPlayerA || isPlayerB {
                let other = isPlayerA ? event.entityB : event.entityA
                if app.world.getComponent(EnemyAI.self, from: other) != nil {
                    app.world.updateComponent(PlayerShooter.self, on: playerEntity) { p in
                        p.health -= 10
                    }
                    app.audio.playSound(sounds.playerHurt, volume: 0.4, pitch: 1.0, looping: false)
                }
            }
        }

        // Enemy AI — move toward player
        if let playerPos = app.world.getComponent(Transform2D.self, from: playerEntity) {
            for entity in enemyEntities {
                guard let enemyAI = app.world.getComponent(EnemyAI.self, from: entity), !enemyAI.isDead else { continue }
                if let pos = app.world.getComponent(Transform2D.self, from: entity) {
                    let dx = playerPos.position.x - pos.position.x
                    let dy = playerPos.position.y - pos.position.y
                    let dist = sqrtf(dx * dx + dy * dy)
                    if dist > 20 {
                        let speed: Float
                        switch enemyAI.type {
                        case .basic: speed = Shooter.enemySpeedBasic
                        case .fast: speed = Shooter.enemySpeedFast
                        case .tank: speed = Shooter.enemySpeedTank
                        }
                        app.world.updateComponent(Velocity2D.self, on: entity) { vel in
                            vel.linear = Vector2(x: (dx / dist) * speed, y: (dy / dist) * speed)
                        }
                    }
                }
            }
        }

        // Check player death
        if let player = app.world.getComponent(PlayerShooter.self, from: playerEntity), player.health <= 0 {
            let score = app.world.getComponent(ScoreTracker.self, from: scoreEntity)
            let wave = app.world.getComponent(WaveManager.self, from: waveEntity)
            app.sceneManager.replace(
                with: GameOverScene(
                    score: score?.score ?? 0,
                    wave: wave?.currentWave ?? 0,
                    kills: score?.kills ?? 0
                ),
                transition: .fade(duration: 0.5),
                app: app
            )
            return
        }

        // Dead enemy cleanup
        var enemiesToRemove: [Int] = []
        for (idx, entity) in enemyEntities.enumerated() {
            if let ai = app.world.getComponent(EnemyAI.self, from: entity), ai.isDead {
                enemiesToRemove.append(idx)
            }
        }
        for idx in enemiesToRemove.reversed() {
            app.world.destroyEntity(enemyEntities[idx])
            enemyEntities.remove(at: idx)
        }

        // Wave management
        app.world.updateComponent(WaveManager.self, on: waveEntity) { wave in
            wave.spawnTimer -= dt
            if wave.spawnTimer <= 0 && enemyEntities.isEmpty {
                wave.currentWave += 1
                let count = wave.currentWave * 3 + 2
                wave.enemiesRemaining = count
                wave.spawnTimer = Shooter.waveInterval
                wave.waveActive = true
                spawnWave(count: count, wave: wave.currentWave, app: app)
                app.world.emit(WaveStartedEvent(wave: wave.currentWave, enemyCount: count))
            }
        }

        // Camera shake
        if shakeTimer > 0 {
            shakeTimer -= dt
            let ox = (Float(nextRand() % 100) / 50 - 1) * shakeIntensity
            let oy = (Float(nextRand() % 100) / 50 - 1) * shakeIntensity
            camera.offset = Vector2(
                x: Shooter.screenWidth / 2 + ox,
                y: Shooter.screenHeight / 2 + oy
            )
        } else {
            camera.offset = Vector2(x: Shooter.screenWidth / 2, y: Shooter.screenHeight / 2)
        }

        // Particle entity cleanup
        var particlesToRemove: [Int] = []
        for (idx, entity) in particleEntities.enumerated() {
            if let emitter = app.world.getComponent(ParticleEmitter.self, from: entity) {
                if !emitter.isEmitting && emitter.activeParticleCount == 0 {
                    particlesToRemove.append(idx)
                }
            }
        }
        for idx in particlesToRemove.reversed() {
            app.world.destroyEntity(particleEntities[idx])
            particleEntities.remove(at: idx)
        }
    }

    func render(app: Application, interpolation _: Double) {
        let screen = app.renderer.screenSize

        app.renderer.beginCamera(camera)

        // Arena floor
        let ax = (Shooter.screenWidth - Shooter.arenaWidth) / 2
        let ay = (Shooter.screenHeight - Shooter.arenaHeight) / 2
        app.renderer.drawRect(
            Rect(x: ax, y: ay, width: Shooter.arenaWidth, height: Shooter.arenaHeight),
            color: Shooter.arenaColor
        )

        // Walls
        for entity in wallEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity),
               let col = app.world.getComponent(Collider2D.self, from: entity) {
                if case .aabb(let he) = col.shape {
                    app.renderer.drawRect(
                        Rect(x: pos.position.x - he.x, y: pos.position.y - he.y,
                             width: he.x * 2, height: he.y * 2),
                        color: Shooter.wallColor
                    )
                }
            }
        }

        // Enemies
        for entity in enemyEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity),
               let ai = app.world.getComponent(EnemyAI.self, from: entity) {
                let color: Color
                switch ai.type {
                case .basic: color = Shooter.enemyBasicColor
                case .fast: color = Shooter.enemyFastColor
                case .tank: color = Shooter.enemyTankColor
                }
                app.renderer.drawCircle(center: pos.position, radius: Shooter.enemyRadius, color: color)

                // Health bar for tanks
                if ai.type == .tank {
                    let maxHP: Float = 60
                    let ratio = Float(ai.health) / maxHP
                    let barW: Float = 20
                    app.renderer.drawRect(
                        Rect(x: pos.position.x - barW / 2, y: pos.position.y - 18, width: barW * ratio, height: 3),
                        color: Color(r: 100, g: 220, b: 100)
                    )
                }
            }
        }

        // Bullets with additive blend
        app.renderer.beginBlendMode(.additive)
        for entity in bulletEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity) {
                app.renderer.drawCircle(center: pos.position, radius: Shooter.bulletRadius, color: Shooter.bulletColor)
            }
        }

        // Laser beam
        if laserActive && laserTimer > 0 {
            let alpha = UInt8(min(255, laserTimer / 0.05 * 255))
            app.renderer.drawLine(from: laserStart, to: laserEnd,
                                  color: Color(r: 255, g: 50, b: 50, a: alpha), thickness: 3)
            app.renderer.drawLine(from: laserStart, to: laserEnd,
                                  color: Color(r: 255, g: 200, b: 200, a: alpha / 2), thickness: 6)
        }
        app.renderer.endBlendMode()

        // Particles
        for entity in particleEntities {
            if let emitter = app.world.getComponent(ParticleEmitter.self, from: entity),
               let pos = app.world.getComponent(Transform2D.self, from: entity) {
                app.renderer.drawParticles(emitter, at: pos.position)
            }
        }

        // Player
        if let pos = app.world.getComponent(Transform2D.self, from: playerEntity),
           let player = app.world.getComponent(PlayerShooter.self, from: playerEntity) {
            app.renderer.drawCircle(center: pos.position, radius: Shooter.playerRadius, color: Shooter.playerColor)
            // Aim direction
            let aimX = pos.position.x + cosf(player.aimAngle) * 18
            let aimY = pos.position.y + sinf(player.aimAngle) * 18
            app.renderer.drawCircle(center: Vector2(x: aimX, y: aimY), radius: 3, color: .white)
        }

        app.renderer.endCamera()

        // HUD
        if let player = app.world.getComponent(PlayerShooter.self, from: playerEntity) {
            // Health bar
            let hpRatio = Float(max(0, player.health)) / Float(Shooter.playerMaxHealth)
            app.renderer.drawRect(Rect(x: 10, y: 10, width: 150, height: 12), color: Color(r: 40, g: 40, b: 40))
            app.renderer.drawRect(Rect(x: 10, y: 10, width: 150 * hpRatio, height: 12),
                                  color: Color(r: UInt8(200 * (1 - hpRatio)), g: UInt8(200 * hpRatio), b: 50))
            app.renderer.drawText("HP: \(player.health)",
                                  position: Vector2(x: 12, y: 9),
                                  font: font, size: 11, color: .white)

            // Weapon indicator
            let weaponName: String
            switch player.currentWeapon {
            case .pistol: weaponName = "Pistol"
            case .shotgun: weaponName = "Shotgun"
            case .laser: weaponName = "Laser"
            }
            app.renderer.drawText("[TAB/1-3] \(weaponName)",
                                  position: Vector2(x: 10, y: 28),
                                  font: font, size: 12, color: Shooter.textBright)
        }

        // Score and wave
        if let score = app.world.getComponent(ScoreTracker.self, from: scoreEntity),
           let wave = app.world.getComponent(WaveManager.self, from: waveEntity) {
            app.renderer.drawText("Score: \(score.score)  Wave: \(wave.currentWave)  Kills: \(score.kills)",
                                  position: Vector2(x: 10, y: 45),
                                  font: font, size: 12, color: Shooter.textDim)
        }

        // SpriteBatch stats
        app.renderer.drawText("Enemies: \(enemyEntities.count)  Bullets: \(bulletEntities.count)  Particles: \(particleEntities.count)",
                              position: Vector2(x: 10, y: screen.height - 32),
                              font: font, size: 11, color: Shooter.textDim)

        // Controls + FPS
        app.renderer.drawText("[WASD] Move  [Mouse] Aim  [Click] Fire  [ESC] Menu",
                              position: Vector2(x: 10, y: screen.height - 18),
                              font: font, size: 11, color: Shooter.textDim)
        app.renderer.drawText("\(app.fps) FPS",
                              position: Vector2(x: screen.width - 70, y: screen.height - 18),
                              font: font, size: 12, color: Color(r: 60, g: 60, b: 60))
    }

    func willExit(app: Application) {
        app.world.removeAllEventHandlers()

        for e in wallEntities { app.world.destroyEntity(e) }
        for e in bulletEntities { app.world.destroyEntity(e) }
        for e in enemyEntities { app.world.destroyEntity(e) }
        for e in particleEntities { app.world.destroyEntity(e) }
        if playerEntity != .null { app.world.destroyEntity(playerEntity) }
        if waveEntity != .null { app.world.destroyEntity(waveEntity) }
        if scoreEntity != .null { app.world.destroyEntity(scoreEntity) }

        app.world.removeSystem(particleSystem)
        app.world.removeSystem(physics)
        sounds.unloadAll(audio: app.audio)
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }

    // MARK: - Arena

    private func buildArena(app: Application) {
        let ax = (Shooter.screenWidth - Shooter.arenaWidth) / 2
        let ay = (Shooter.screenHeight - Shooter.arenaHeight) / 2
        let t: Float = 15

        // Top
        wallEntities.append(makeWall(app: app, pos: Vector2(x: Shooter.screenWidth / 2, y: ay - t / 2),
                                     hw: Shooter.arenaWidth / 2 + t, hh: t / 2))
        // Bottom
        wallEntities.append(makeWall(app: app, pos: Vector2(x: Shooter.screenWidth / 2, y: ay + Shooter.arenaHeight + t / 2),
                                     hw: Shooter.arenaWidth / 2 + t, hh: t / 2))
        // Left
        wallEntities.append(makeWall(app: app, pos: Vector2(x: ax - t / 2, y: Shooter.screenHeight / 2),
                                     hw: t / 2, hh: Shooter.arenaHeight / 2 + t))
        // Right
        wallEntities.append(makeWall(app: app, pos: Vector2(x: ax + Shooter.arenaWidth + t / 2, y: Shooter.screenHeight / 2),
                                     hw: t / 2, hh: Shooter.arenaHeight / 2 + t))
    }

    private func makeWall(app: Application, pos: Vector2, hw: Float, hh: Float) -> Entity {
        let entity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: pos), to: entity)
        app.world.addComponent(RigidBody2D(mass: 0, bodyType: .static), to: entity)
        app.world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: hw, y: hh)),
            layer: Shooter.layerWall,
            mask: Shooter.layerPlayer | Shooter.layerEnemy | Shooter.layerBullet
        ), to: entity)
        return entity
    }

    // MARK: - Player

    private func spawnPlayer(app: Application) {
        playerEntity = app.world.createEntity()
        let center = Vector2(x: Shooter.screenWidth / 2, y: Shooter.screenHeight / 2)
        app.world.addComponent(Transform2D(position: center), to: playerEntity)
        app.world.addComponent(Velocity2D(), to: playerEntity)
        app.world.addComponent(RigidBody2D(
            mass: 1, gravityScale: 0, bodyType: .dynamic, linearDamping: 10
        ), to: playerEntity)
        app.world.addComponent(Collider2D(
            shape: .circle(radius: Shooter.playerRadius),
            layer: Shooter.layerPlayer,
            mask: Shooter.layerWall | Shooter.layerEnemy
        ), to: playerEntity)
        app.world.addComponent(PlayerShooter(health: Shooter.playerMaxHealth), to: playerEntity)
        app.world.addComponent(Sprite(texture: .invalid), to: playerEntity)
    }

    // MARK: - Weapons

    private func fireWeapon(player: PlayerShooter, pos: Vector2, app: Application) {
        switch player.currentWeapon {
        case .pistol:
            spawnBullet(from: pos, angle: player.aimAngle, damage: 20, app: app, useCCD: false)
            app.audio.playSound(sounds.pistolFire, volume: 0.4, pitch: 1.0, looping: false)

        case .shotgun:
            for i in 0..<Shooter.shotgunPellets {
                let spread = Shooter.shotgunSpread
                let offset = -spread / 2 + spread * Float(i) / Float(Shooter.shotgunPellets - 1)
                spawnBullet(from: pos, angle: player.aimAngle + offset, damage: 10, app: app, useCCD: true)
            }
            app.audio.playSound(sounds.shotgunFire, volume: 0.5, pitch: 1.0, looping: false)

        case .laser:
            fireLaser(from: pos, angle: player.aimAngle, app: app)
            app.audio.playSound(sounds.laserFire, volume: 0.3, pitch: 1.0, looping: false)
        }
    }

    private func spawnBullet(from pos: Vector2, angle: Float, damage: Int, app: Application, useCCD: Bool) {
        let entity = app.world.createEntity()
        let dir = Vector2(x: cosf(angle), y: sinf(angle))
        let startPos = Vector2(x: pos.x + dir.x * 20, y: pos.y + dir.y * 20)

        app.world.addComponent(Transform2D(position: startPos), to: entity)
        app.world.addComponent(Velocity2D(linear: Vector2(
            x: dir.x * Shooter.bulletSpeed, y: dir.y * Shooter.bulletSpeed
        )), to: entity)
        app.world.addComponent(RigidBody2D(
            mass: 0.1, gravityScale: 0, bodyType: .dynamic, useCCD: useCCD
        ), to: entity)
        app.world.addComponent(Collider2D(
            shape: .circle(radius: Shooter.bulletRadius),
            layer: Shooter.layerBullet,
            mask: Shooter.layerEnemy | Shooter.layerWall
        ), to: entity)
        app.world.addComponent(BulletComp(damage: damage, lifetime: 2.0), to: entity)
        app.world.addComponent(Sprite(texture: .invalid), to: entity)

        bulletEntities.append(entity)
    }

    private func fireLaser(from pos: Vector2, angle: Float, app: Application) {
        let dir = Vector2(x: cosf(angle), y: sinf(angle))
        let origin = Vector2(x: pos.x + dir.x * 20, y: pos.y + dir.y * 20)

        // Raycast all to hit multiple enemies
        let hits = physics.raycastAll(
            world: app.world, origin: origin, direction: dir,
            maxDistance: Shooter.laserRange, layerMask: Shooter.layerEnemy | Shooter.layerWall
        )

        laserStart = origin
        laserEnd = Vector2(x: origin.x + dir.x * Shooter.laserRange, y: origin.y + dir.y * Shooter.laserRange)
        laserActive = true
        laserTimer = 0.08

        for hit in hits {
            if app.world.getComponent(EnemyAI.self, from: hit.entity) != nil {
                // Damage enemy
                var killed = false
                app.world.updateComponent(EnemyAI.self, on: hit.entity) { ai in
                    ai.health -= 15
                    if ai.health <= 0 && !ai.isDead {
                        ai.isDead = true
                        killed = true
                    }
                }
                if killed {
                    app.world.emit(EnemyKilledEvent(entity: hit.entity, position: hit.point))
                }
                app.audio.playSound(sounds.enemyHit, volume: 0.3, pitch: 1.2, looping: false)
            } else {
                // Hit wall — stop laser here
                laserEnd = hit.point
                break
            }
        }
    }

    // MARK: - Collision Handling

    private func handleBulletCollision(_ event: CollisionEvent, app: Application) {
        let bulletA = app.world.getComponent(BulletComp.self, from: event.entityA)
        let bulletB = app.world.getComponent(BulletComp.self, from: event.entityB)

        if let bullet = bulletA {
            processBulletHit(bullet: event.entityA, damage: bullet.damage, other: event.entityB, app: app)
        } else if let bullet = bulletB {
            processBulletHit(bullet: event.entityB, damage: bullet.damage, other: event.entityA, app: app)
        }
    }

    private func processBulletHit(bullet: Entity, damage: Int, other: Entity, app: Application) {
        // Destroy bullet
        if let idx = bulletEntities.firstIndex(of: bullet) {
            bulletEntities.remove(at: idx)
            app.world.destroyEntity(bullet)
        }

        // Damage enemy
        if app.world.getComponent(EnemyAI.self, from: other) != nil {
            var killed = false
            var deathPos: Vector2 = .zero
            app.world.updateComponent(EnemyAI.self, on: other) { ai in
                ai.health -= damage
                if ai.health <= 0 && !ai.isDead {
                    ai.isDead = true
                    killed = true
                }
            }
            if killed, let pos = app.world.getComponent(Transform2D.self, from: other) {
                deathPos = pos.position
                app.world.emit(EnemyKilledEvent(entity: other, position: deathPos))
            } else {
                app.audio.playSound(sounds.enemyHit, volume: 0.3, pitch: 1.0, looping: false)
            }
        }
    }

    // MARK: - Enemies

    private func spawnWave(count: Int, wave: Int, app: Application) {
        let ax = (Shooter.screenWidth - Shooter.arenaWidth) / 2
        let ay = (Shooter.screenHeight - Shooter.arenaHeight) / 2

        for i in 0..<count {
            // Spawn at arena edges
            let side = nextRand() % 4
            var spawnPos: Vector2
            switch side {
            case 0: spawnPos = Vector2(x: ax + 20, y: ay + Float(nextRand() % UInt32(Shooter.arenaHeight - 40)) + 20)
            case 1: spawnPos = Vector2(x: ax + Shooter.arenaWidth - 20, y: ay + Float(nextRand() % UInt32(Shooter.arenaHeight - 40)) + 20)
            case 2: spawnPos = Vector2(x: ax + Float(nextRand() % UInt32(Shooter.arenaWidth - 40)) + 20, y: ay + 20)
            default: spawnPos = Vector2(x: ax + Float(nextRand() % UInt32(Shooter.arenaWidth - 40)) + 20, y: ay + Shooter.arenaHeight - 20)
            }

            let type: EnemyAI.EnemyType
            let health: Int
            if wave >= 3 && i % 5 == 0 {
                type = .tank; health = 60
            } else if wave >= 2 && i % 3 == 0 {
                type = .fast; health = 15
            } else {
                type = .basic; health = 25
            }

            let entity = app.world.createEntity()
            app.world.addComponent(Transform2D(position: spawnPos), to: entity)
            app.world.addComponent(Velocity2D(), to: entity)
            let radius: Float = type == .tank ? 14 : Shooter.enemyRadius
            app.world.addComponent(RigidBody2D(
                mass: type == .tank ? 3 : 1, gravityScale: 0, bodyType: .dynamic, linearDamping: 5
            ), to: entity)
            app.world.addComponent(Collider2D(
                shape: .circle(radius: radius),
                layer: Shooter.layerEnemy,
                mask: Shooter.layerPlayer | Shooter.layerBullet | Shooter.layerWall | Shooter.layerEnemy
            ), to: entity)
            app.world.addComponent(EnemyAI(type: type, health: health), to: entity)
            app.world.addComponent(Sprite(texture: .invalid), to: entity)

            enemyEntities.append(entity)
        }
    }

    // MARK: - Particles

    private func spawnDeathParticles(at pos: Vector2, app: Application) {
        let entity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: pos), to: entity)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 30,
            lifetime: 0.3...0.8,
            speed: 80...200,
            startColor: Color(r: 255, g: 200, b: 80, a: 255),
            endColor: Color(r: 255, g: 60, b: 0, a: 0),
            startScale: 0.8...1.5,
            endScale: 0.1,
            renderShape: .circle(radius: 3),
            isEmitting: false
        )
        emitter.burst(count: 20)
        app.world.addComponent(emitter, to: entity)
        particleEntities.append(entity)
    }

    // MARK: - RNG

    private func nextRand() -> UInt32 {
        spawnSeed = spawnSeed &* 1_664_525 &+ 1_013_904_223
        return spawnSeed >> 16
    }
}
