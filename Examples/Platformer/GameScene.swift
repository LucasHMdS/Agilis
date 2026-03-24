import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

final class GameScene: Scene {
    // Entity handles
    private var playerEntity: Entity = .null
    private var allEntities: [Entity] = []
    private var particleEntities: [Entity] = []

    // Systems
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var physicsWorld: PhysicsWorld2D!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var enemyAI: EnemyAISystem!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var gameplay: GameplaySystem!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var postPhysics: PostPhysicsSystem!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var particleSystem: ParticleSystem!

    // Camera
    private var camera = Camera2D(
        target: .zero,
        offset: Vector2(x: Mario.screenWidth / 2, y: Mario.screenHeight / 2),
        zoom: 1.0
    )

    // Game state
    private var score: Int
    private var lives: Int
    private var coins: Int = 0
    private var levelComplete: Bool = false
    private var sceneChangePending: Bool = false
    private var levelCompleteTimer: Float = 0
    private var gameTime: Float = 0

    // UI
    private var font: FontHandle = .invalid

    // Sprites
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var spriteAtlas: MarioSprites.Atlas!

    // Audio
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var sounds: MarioSounds.SoundSet!

    // Debug
    private var showPhysicsDebug = false

    init(lives: Int = Mario.startLives, score: Int = 0) {
        self.lives = lives
        self.score = score
    }

    // MARK: - Scene Lifecycle

    func didEnter(app: Application) {
        app.renderer.setBackgroundColor(Mario.skyColor)
        font = app.renderer.loadDefaultFont()
        spriteAtlas = MarioSprites.buildAtlas(renderer: app.renderer)
        sounds = MarioSounds.generate(audio: app.audio)

        let world = app.world

        // Build level
        let levelData = LevelBuilder.buildLevel(in: world)
        playerEntity = levelData.player
        allEntities = levelData.allEntities

        // Initialize camera to player position
        if let pos = world.getComponent(Transform2D.self, from: playerEntity) {
            camera.target = pos.position
        }

        // Create systems
        physicsWorld = PhysicsWorld2D(
            gravity: Vector2(x: 0, y: Mario.gravity),
            cellSize: Mario.physicsGridCell,
            priority: 100
        )
        enemyAI = EnemyAISystem()
        gameplay = GameplaySystem()
        postPhysics = PostPhysicsSystem(physics: physicsWorld)
        particleSystem = ParticleSystem()

        world.addSystem(enemyAI)
        world.addSystem(gameplay)
        world.addSystem(physicsWorld)
        world.addSystem(postPhysics)
        world.addSystem(particleSystem)

        // Subscribe to events
        world.on(CoinCollectedEvent.self) { [weak self] event in
            guard let self else { return }
            score += Mario.coinScore
            coins += 1
            app.audio.playSound(sounds.coin, volume: 0.5, pitch: 1.0, looping: false)
            if let coinPos = world.getComponent(Transform2D.self, from: event.coinEntity) {
                spawnCoinSparkle(at: coinPos.position, in: world)
            }
            world.destroyEntity(event.coinEntity)
        }

        world.on(EnemyStompedEvent.self) { [weak self] event in
            guard let self else { return }
            score += 200
            app.audio.playSound(sounds.stomp, volume: 0.5, pitch: 1.0, looping: false)
            world.updateComponent(Enemy.self, on: event.enemyEntity) { e in
                e.isDead = true
                e.deathTimer = Mario.goombaSquishedTime
            }
            world.updateComponent(Velocity2D.self, on: event.enemyEntity) { v in
                v.linear = .zero
            }
            // Bounce player up
            world.updateComponent(Velocity2D.self, on: event.playerEntity) { v in
                v.linear.y = Mario.stompBounceVelocity
            }
            if let enemyPos = world.getComponent(Transform2D.self, from: event.enemyEntity) {
                spawnStompPoof(at: enemyPos.position, in: world)
            }
        }

        world.on(BlockHitEvent.self) { [weak self] event in
            guard let self else { return }
            app.audio.playSound(sounds.blockHit, volume: 0.5, pitch: 1.0, looping: false)
            world.updateComponent(QuestionBlock.self, on: event.blockEntity) { block in
                guard block.state == .active else { return }
                block.coinsRemaining -= 1
                block.state = .bouncing
                block.bounceTimer = Mario.blockBounceTime
                self.score += Mario.coinScore
                self.coins += 1
            }
            if let blockPos = world.getComponent(Transform2D.self, from: event.blockEntity) {
                spawnCoinSparkle(
                    at: Vector2(
                        x: blockPos.position.x,
                        y: blockPos.position.y - Mario.tileSize
                    ),
                    in: world
                )
            }
        }

        world.on(PlayerHurtEvent.self) { [weak self] event in
            guard let self else { return }
            if let player = world.getComponent(Player.self, from: event.playerEntity),
               player.isInvincible || player.isDead {
                return
            }
            app.audio.playSound(sounds.hurt, volume: 0.6, pitch: 1.0, looping: false)
            killPlayer(in: world)
        }

        world.on(LevelCompleteEvent.self) { [weak self] event in
            guard let self, !levelComplete else { return }
            levelComplete = true
            app.audio.playSound(sounds.levelComplete, volume: 0.6, pitch: 1.0, looping: false)
            levelCompleteTimer = 2.5
            // Stop player movement
            world.updateComponent(Velocity2D.self, on: event.playerEntity) { v in
                v.linear = .zero
            }
        }
    }

    func update(app: Application, deltaTime: Double) {
        let dt = Float(deltaTime)
        gameTime += dt

        if levelComplete {
            levelCompleteTimer -= dt
            if levelCompleteTimer <= 0 && !sceneChangePending {
                sceneChangePending = true
                app.sceneManager.replace(
                    with: VictoryScene(score: score, coins: coins),
                    transition: .fade(),
                    app: app
                )
            }
            return
        }

        updatePlayer(app: app, deltaTime: deltaTime)
        updateCamera(app: app, dt: dt)
        cleanupParticles(world: app.world)

        // Escape to menu
        if app.input.isKeyPressed(.escape)
            || app.input.isGamepadButtonPressed(0, .start) {
            app.sceneManager.replace(with: MenuScene(), app: app)
        }

        // Debug toggle
        if app.input.isKeyPressed(.f1) {
            showPhysicsDebug.toggle()
        }
    }

    func render(app: Application, interpolation: Double) {
        let renderer = app.renderer
        let world = app.world
        let t = Float(interpolation)
        let screen = renderer.screenSize

        // Background (screen space, before camera)
        drawBackground(
            cameraTargetX: camera.target.x,
            screenSize: screen,
            atlas: spriteAtlas,
            renderer: renderer
        )
        // Begin camera
        renderer.beginCamera(camera)

        // Tiles
        world.forEach { (_: Entity, pos: inout Transform2D, tile: inout Tile) in
            drawTile(
                pos: pos.position,
                tile: tile,
                atlas: self.spriteAtlas,
                renderer: renderer
            )
        }
        // Question blocks
        world.forEach { (_: Entity, pos: inout Transform2D, block: inout QuestionBlock) in
            drawQuestionBlock(
                pos: pos.position,
                block: block,
                atlas: self.spriteAtlas,
                renderer: renderer
            )
        }
        // Coins
        world.forEach { (_: Entity, pos: inout Transform2D, _: inout Coin) in
            drawCoin(
                pos: pos.position,
                time: self.gameTime,
                atlas: self.spriteAtlas,
                renderer: renderer
            )
        }
        // Enemies (with interpolation)
        world.forEach { (_: Entity, pos: inout Transform2D, prev: inout PreviousTransform2D, enemy: inout Enemy) in
            let drawPos = prev.position.lerp(to: pos.position, t: t)
            drawGoomba(
                pos: drawPos,
                enemy: enemy,
                gameTime: self.gameTime,
                atlas: self.spriteAtlas,
                renderer: renderer
            )
        }
        // Player (with interpolation)
        if let pos = world.getComponent(Transform2D.self, from: playerEntity),
           let prev = world.getComponent(PreviousTransform2D.self, from: playerEntity),
           let player = world.getComponent(Player.self, from: playerEntity) {
            let drawPos = prev.position.lerp(to: pos.position, t: t)
            drawPlayer(
                pos: drawPos,
                player: player,
                gameTime: gameTime,
                atlas: spriteAtlas,
                renderer: renderer
            )
        }
        // Flagpole
        if let flagEntity = world.entity(named: "flagpole"),
           let flagPos = world.getComponent(Transform2D.self, from: flagEntity) {
            drawFlagpole(
                pos: flagPos.position,
                atlas: spriteAtlas,
                renderer: renderer
            )
        }
        // Particles
        world.forEach { (_: Entity, emitter: inout ParticleEmitter, pos: inout Transform2D) in
            renderer.drawParticles(emitter, at: pos.position)
        }

        // Debug overlay
        if showPhysicsDebug {
            var debugOptions = PhysicsDebugRendererOptions()
            debugOptions.drawVelocities = true
            debugOptions.velocityScale = 0.2
            renderer.drawPhysicsDebug(
                world: world,
                events: physicsWorld.events,
                options: debugOptions
            )
        }

        renderer.endCamera()

        // HUD (screen space)
        drawHUD(
            score: score,
            lives: lives,
            coins: coins,
            font: font,
            renderer: renderer
        )

        // FPS
        let fpsColor = Color(r: 80, g: 80, b: 80)
        renderer.drawText(
            "\(app.fps) FPS",
            position: Vector2(x: 4, y: screen.height - 18),
            font: font,
            size: 14,
            color: fpsColor
        )

        // Level complete overlay
        if levelComplete {
            renderer.drawRect(
                Rect(x: 0, y: 0, width: screen.width, height: screen.height),
                color: Color(r: 0, g: 0, b: 0, a: 120)
            )
            renderer.drawText(
                "LEVEL COMPLETE!",
                position: Vector2(x: screen.width / 2 - 140, y: 200),
                font: font,
                size: 36,
                color: .yellow
            )
            renderer.drawText(
                "Score: \(score)",
                position: Vector2(x: screen.width / 2 - 60, y: 260),
                font: font,
                size: 24,
                color: .white
            )
        }
    }

    func willExit(app: Application) {
        let world = app.world
        world.removeAllEventHandlers()

        if sounds != nil {
            sounds.unloadAll(audio: app.audio)
        }
        if spriteAtlas != nil {
            app.renderer.destroyTexture(spriteAtlas.texture)
        }
        world.removeSystem(enemyAI)
        world.removeSystem(gameplay)
        world.removeSystem(physicsWorld)
        world.removeSystem(postPhysics)
        world.removeSystem(particleSystem)

        for entity in allEntities {
            world.destroyEntity(entity)
        }
        for entity in particleEntities {
            world.destroyEntity(entity)
        }
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }

    // MARK: - Player Input & Control

    private func updatePlayer(app: Application, deltaTime: Double) {
        let world = app.world
        let dt = Float(deltaTime)

        guard var player = world.getComponent(Player.self, from: playerEntity),
              var vel = world.getComponent(Velocity2D.self, from: playerEntity),
              let pos = world.getComponent(Transform2D.self, from: playerEntity) else { return }

        // Death handling
        if player.isDead {
            player.deathTimer -= dt
            if player.deathTimer <= 0 && !sceneChangePending {
                sceneChangePending = true
                lives -= 1
                if lives <= 0 {
                    app.sceneManager.replace(
                        with: GameOverScene(score: score),
                        transition: .fade(),
                        app: app
                    )
                } else {
                    app.sceneManager.replace(
                        with: GameScene(lives: lives, score: score),
                        transition: .fade(),
                        app: app
                    )
                }
            }
            world.updateComponent(Player.self, on: playerEntity) { p in p = player }
            return
        }

        // Death by falling
        if pos.position.y > Mario.deathY {
            app.audio.playSound(sounds.hurt, volume: 0.6, pitch: 1.0, looping: false)
            killPlayer(in: world)
            return
        }

        // Horizontal input
        var moveInput: Float = 0
        if app.input.isKeyDown(.right) || app.input.isKeyDown(.d) { moveInput += 1 }
        if app.input.isKeyDown(.left) || app.input.isKeyDown(.a) { moveInput -= 1 }

        if app.input.isGamepadConnected(0) {
            let stickX = app.input.gamepadAxis(0, .leftX)
            moveInput += stickX
            if app.input.isGamepadButtonDown(0, .dpadRight) { moveInput += 1 }
            if app.input.isGamepadButtonDown(0, .dpadLeft) { moveInput -= 1 }
        }
        moveInput = clamp(moveInput, min: -1, max: 1)

        vel.linear.x = moveInput * Mario.playerMoveSpeed

        // Face direction
        if moveInput > 0.1 { player.facingRight = true } else if moveInput < -0.1 { player.facingRight = false }

        // Walk animation
        if abs(moveInput) > 0.1 && player.isGrounded {
            player.walkAnimTimer += dt
        } else {
            player.walkAnimTimer = 0
        }

        // Coyote time
        if !player.isGrounded {
            player.coyoteTimer -= dt
        }

        // Jump input
        let jumpPressed = app.input.isKeyPressed(.space) || app.input.isKeyPressed(.up)
            || app.input.isKeyPressed(.w)
            || app.input.isGamepadButtonPressed(0, .faceDown)
        let jumpHeld = app.input.isKeyDown(.space) || app.input.isKeyDown(.up)
            || app.input.isKeyDown(.w)
            || app.input.isGamepadButtonDown(0, .faceDown)

        if jumpPressed {
            player.jumpBufferTimer = Mario.jumpBufferTime
        } else {
            player.jumpBufferTimer -= dt
        }

        // Jump execution
        let canJump = player.isGrounded || player.coyoteTimer > 0
        if player.jumpBufferTimer > 0 && canJump && !player.isJumping {
            vel.linear.y = Mario.playerJumpVelocity
            player.isJumping = true
            player.jumpHeld = true
            player.jumpBufferTimer = 0
            player.coyoteTimer = 0
            app.audio.playSound(sounds.jump, volume: 0.4, pitch: 1.0, looping: false)
            spawnJumpDust(at: pos.position, in: world)
        }

        // Variable jump height
        if player.isJumping && player.jumpHeld {
            if !jumpHeld {
                if vel.linear.y < 0 {
                    vel.linear.y *= Mario.playerJumpCutMultiplier
                }
                player.jumpHeld = false
            }
        }

        // Landing
        if player.isGrounded && vel.linear.y >= 0 {
            player.isJumping = false
        }

        // Write back
        world.updateComponent(Player.self, on: playerEntity) { p in p = player }
        world.updateComponent(Velocity2D.self, on: playerEntity) { v in v = vel }
    }

    // MARK: - Camera

    private func updateCamera(app: Application, dt: Float) {
        guard let pos = app.world.getComponent(Transform2D.self, from: playerEntity),
              let player = app.world.getComponent(Player.self, from: playerEntity) else { return }

        let lookAheadX: Float = player.facingRight
            ? Mario.cameraLookAheadX : -Mario.cameraLookAheadX
        let targetX = pos.position.x + lookAheadX

        var targetY = camera.target.y
        let vertDiff = pos.position.y - camera.target.y
        if abs(vertDiff) > Mario.cameraVerticalDeadzone {
            targetY = pos.position.y - (vertDiff > 0
                ? Mario.cameraVerticalDeadzone : -Mario.cameraVerticalDeadzone)
        }

        let t = clamp(Mario.cameraSmoothSpeed * dt, min: 0, max: 1)
        camera.target.x = Agilis.lerp(camera.target.x, targetX, t: t)
        camera.target.y = Agilis.lerp(camera.target.y, targetY, t: t)

        // Clamp to level bounds
        let halfScreenW = Mario.screenWidth / 2
        let halfScreenH = Mario.screenHeight / 2
        let levelWidth = Float(Mario.levelWidthTiles) * Mario.tileSize
        let levelHeight = Float(Mario.levelHeightTiles) * Mario.tileSize
        camera.target.x = clamp(
            camera.target.x,
            min: halfScreenW,
            max: levelWidth - halfScreenW
        )
        camera.target.y = clamp(
            camera.target.y,
            min: halfScreenH,
            max: levelHeight - halfScreenH
        )
    }

    // MARK: - Player Death

    private func killPlayer(in world: World) {
        world.updateComponent(Player.self, on: playerEntity) { p in
            p.isDead = true
            p.deathTimer = Mario.deathDuration
        }
        world.updateComponent(Velocity2D.self, on: playerEntity) { v in
            v.linear = Vector2(x: 0, y: Mario.deathBounceVelocity)
        }
        // Disable collision so player falls through
        world.updateComponent(Collider2D.self, on: playerEntity) { c in
            c.mask = 0
        }
    }

    // MARK: - Particle Effects

    private func spawnJumpDust(at position: Vector2, in world: World) {
        let entity = world.createEntity()
        let spawnPos = Vector2(x: position.x, y: position.y + Mario.playerHeight / 2)
        world.addComponent(Transform2D(position: spawnPos), to: entity)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 10,
            lifetime: 0.15...0.3,
            speed: 20...60,
            angle: Float.pi...(2 * Float.pi),
            startColor: Color(r: 180, g: 160, b: 140),
            endColor: Color(r: 180, g: 160, b: 140, a: 0),
            startScale: 0.8...1.2,
            endScale: 0.2,
            emissionShape: .rect(width: 16, height: 4),
            renderShape: .circle(radius: 3),
            isEmitting: false
        )
        emitter.burst(count: 6)
        world.addComponent(emitter, to: entity)
        particleEntities.append(entity)
    }

    private func spawnCoinSparkle(at position: Vector2, in world: World) {
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: position), to: entity)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 12,
            lifetime: 0.2...0.5,
            speed: 40...100,
            angle: 0...(2 * Float.pi),
            startColor: Mario.coinColor,
            endColor: Color(r: 255, g: 255, b: 200, a: 0),
            startScale: 0.5...1.0,
            endScale: 0.1,
            renderShape: .rect(width: 4, height: 4),
            isEmitting: false
        )
        emitter.burst(count: 8)
        world.addComponent(emitter, to: entity)
        particleEntities.append(entity)
    }

    private func spawnStompPoof(at position: Vector2, in world: World) {
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: position), to: entity)
        var emitter = ParticleEmitter(
            emissionRate: 0,
            maxParticles: 8,
            lifetime: 0.15...0.35,
            speed: 30...80,
            angle: (Float.pi * 0.25)...(Float.pi * 0.75),
            gravity: Vector2(x: 0, y: 100),
            startColor: .white,
            endColor: Color(r: 200, g: 200, b: 200, a: 0),
            startScale: 0.8...1.5,
            endScale: 2.0,
            renderShape: .circle(radius: 4),
            isEmitting: false
        )
        emitter.burst(count: 6)
        world.addComponent(emitter, to: entity)
        particleEntities.append(entity)
    }

    private func cleanupParticles(world: World) {
        particleEntities.removeAll { entity in
            guard let emitter = world.getComponent(ParticleEmitter.self, from: entity) else {
                return true
            }
            if !emitter.isEmitting && emitter.activeParticleCount == 0 {
                world.destroyEntity(entity)
                return true
            }
            return false
        }
    }
}
