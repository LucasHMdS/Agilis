import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - Game Scene

final class GameScene: Scene {
    private var fpsFont: FontHandle = .invalid

    // Entity handles
    private var leftPaddle: Entity = .null
    private var rightPaddle: Entity = .null
    private var ball: Entity = .null
    private var topWall: Entity = .null
    private var bottomWall: Entity = .null

    // System references (for cleanup)
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var aiSystem: PongAISystem!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var physicsWorld: PhysicsWorld2D!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var pongPhysics: PongPhysicsSystem!

    // Score
    private var leftScore = 0
    private var rightScore = 0

    // Serve
    private var serving = true
    private var serveTimer: Double = Pong.serveDelay
    private var serveDirection: Float = 1

    // Rally tracking (driven by event bus)
    private var rallyCount = 0

    // Touch input (iOS)
    private var lastTouchY: Float?

    // Audio
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var sounds: PongSounds.SoundSet!

    // Debug
    private var showPhysicsDebug = false

    func didEnter(app: Application) {
        Pong.configure(screenSize: app.renderer.screenSize)
        app.renderer.setBackgroundColor(.black)
        fpsFont = app.renderer.loadDefaultFont()
        sounds = PongSounds.generate(audio: app.audio)
        serveDirection = Float.random(in: 0...1) < 0.5 ? 1 : -1

        let world = app.world
        let centerY = Pong.screenHeight / 2
        let wallThickness: Float = 20

        // --- Create left paddle (player) ---
        leftPaddle = world.createEntity()
        world.setName("leftPaddle", for: leftPaddle)
        world.addComponent(Transform2D(position: Vector2(x: Pong.paddleMargin, y: centerY)), to: leftPaddle)
        world.addComponent(PreviousTransform2D(position: Vector2(x: Pong.paddleMargin, y: centerY)), to: leftPaddle)
        world.addComponent(Velocity2D(), to: leftPaddle)
        world.addComponent(RigidBody2D(restitution: 1.0, friction: 0, bodyType: .kinematic), to: leftPaddle)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Pong.paddleWidth / 2, y: Pong.paddleHeight / 2)),
            layer: PongLayers.paddle,
            mask: PongLayers.ball
        ), to: leftPaddle)
        world.addComponent(Paddle(
            halfWidth: Pong.paddleWidth / 2,
            halfHeight: Pong.paddleHeight / 2,
            speed: Pong.paddleSpeed
        ), to: leftPaddle)

        // --- Create right paddle (AI) ---
        rightPaddle = world.createEntity()
        world.setName("rightPaddle", for: rightPaddle)
        world.addComponent(Transform2D(position: Vector2(x: Pong.screenWidth - Pong.paddleMargin, y: centerY)), to: rightPaddle)
        world.addComponent(PreviousTransform2D(position: Vector2(x: Pong.screenWidth - Pong.paddleMargin, y: centerY)), to: rightPaddle)
        world.addComponent(Velocity2D(), to: rightPaddle)
        world.addComponent(RigidBody2D(restitution: 1.0, friction: 0, bodyType: .kinematic), to: rightPaddle)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Pong.paddleWidth / 2, y: Pong.paddleHeight / 2)),
            layer: PongLayers.paddle,
            mask: PongLayers.ball
        ), to: rightPaddle)
        world.addComponent(Paddle(
            halfWidth: Pong.paddleWidth / 2,
            halfHeight: Pong.paddleHeight / 2,
            speed: Pong.aiSpeed
        ), to: rightPaddle)
        world.addComponent(AIControlled(targetY: centerY), to: rightPaddle)

        // --- Create ball ---
        ball = world.createEntity()
        world.setName("ball", for: ball)
        world.addComponent(Transform2D(position: Vector2(x: Pong.screenWidth / 2, y: centerY)), to: ball)
        world.addComponent(PreviousTransform2D(position: Vector2(x: Pong.screenWidth / 2, y: centerY)), to: ball)
        world.addComponent(Velocity2D(), to: ball)
        world.addComponent(RigidBody2D(restitution: 1.0, friction: 0, gravityScale: 0, bodyType: .dynamic), to: ball)
        world.addComponent(Collider2D(
            shape: .circle(radius: Pong.ballRadius),
            layer: PongLayers.ball,
            mask: PongLayers.paddle | PongLayers.wall
        ), to: ball)
        world.addComponent(Ball(radius: Pong.ballRadius, speed: Pong.ballInitialSpeed), to: ball)

        // --- Create wall entities for physics-based ball bouncing ---
        // Top wall: bottom edge sits at y=0
        topWall = world.createEntity()
        world.setName("topWall", for: topWall)
        world.addComponent(Transform2D(position: Vector2(x: Pong.screenWidth / 2, y: -wallThickness)), to: topWall)
        world.addComponent(RigidBody2D(restitution: 1.0, friction: 0, bodyType: .static), to: topWall)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Pong.screenWidth / 2, y: wallThickness)),
            layer: PongLayers.wall,
            mask: PongLayers.ball
        ), to: topWall)

        // Bottom wall: top edge sits at y=screenHeight
        bottomWall = world.createEntity()
        world.setName("bottomWall", for: bottomWall)
        world.addComponent(Transform2D(position: Vector2(x: Pong.screenWidth / 2, y: Pong.screenHeight + wallThickness)), to: bottomWall)
        world.addComponent(RigidBody2D(restitution: 1.0, friction: 0, bodyType: .static), to: bottomWall)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Pong.screenWidth / 2, y: wallThickness)),
            layer: PongLayers.wall,
            mask: PongLayers.ball
        ), to: bottomWall)

        // --- Register systems ---
        aiSystem = PongAISystem()
        physicsWorld = PhysicsWorld2D(gravity: .zero, cellSize: 128, priority: 100)
        pongPhysics = PongPhysicsSystem(physics: physicsWorld)
        world.addSystem(aiSystem)
        world.addSystem(physicsWorld)
        world.addSystem(pongPhysics)

        // --- Subscribe to game events (event bus) ---
        world.on(PaddleHitEvent.self) { [weak self] event in
            guard let self else { return }
            rallyCount += 1
            // Pitch rises with ball speed for satisfying feedback
            let pitch = clamp(event.ballSpeed / Pong.ballInitialSpeed, min: 0.8, max: 1.5)
            app.audio.playSound(sounds.paddleHit, volume: 0.5, pitch: pitch, looping: false)
        }

        world.on(WallBounceEvent.self) { [weak self] _ in
            guard let self else { return }
            app.audio.playSound(sounds.wallBounce, volume: 0.3, pitch: 1.0, looping: false)
        }

        world.on(GoalScoredEvent.self) { [weak self] _ in
            guard let self else { return }
            rallyCount = 0
            app.audio.playSound(sounds.goalScored, volume: 0.5, pitch: 1.0, looping: false)
        }
    }

    func update(app: Application, deltaTime: Double) {
        let world = app.world

        // --- Player input (left paddle) ---
        var paddleVelY: Float = 0

        #if os(iOS)
        // Touch: drag paddle using mouse emulation (platform maps first touch to mouse)
        if app.input.isMouseButtonDown(.left) {
            let mouseY = app.input.mousePosition.y
            if let lastY = lastTouchY {
                let delta = mouseY - lastY
                world.updateComponent(Transform2D.self, on: leftPaddle) { t in
                    t.position.y += delta
                    t.position.y = clamp(t.position.y, min: Pong.paddleHeight / 2, max: Pong.screenHeight - Pong.paddleHeight / 2)
                }
            }
            lastTouchY = mouseY
        } else {
            lastTouchY = nil
        }
        #else
        // Keyboard: W/S or Up/Down
        if app.input.isKeyDown(.w) || app.input.isKeyDown(.up) {
            paddleVelY -= Pong.paddleSpeed
        }
        if app.input.isKeyDown(.s) || app.input.isKeyDown(.down) {
            paddleVelY += Pong.paddleSpeed
        }
        #endif

        // Gamepad: left stick (analog) or D-pad (digital)
        if app.input.isGamepadConnected(0) {
            let stickY = app.input.gamepadAxis(0, .leftY)
            paddleVelY += Pong.paddleSpeed * stickY
            if app.input.isGamepadButtonDown(0, .dpadUp) {
                paddleVelY -= Pong.paddleSpeed
            }
            if app.input.isGamepadButtonDown(0, .dpadDown) {
                paddleVelY += Pong.paddleSpeed
            }
        }
        paddleVelY = max(-Pong.paddleSpeed, min(Pong.paddleSpeed, paddleVelY))

        world.updateComponent(Velocity2D.self, on: leftPaddle) { vel in
            vel.linear = Vector2(x: 0, y: paddleVelY)
        }

        // --- Serve ---
        if serving {
            serveTimer -= deltaTime
            if serveTimer <= 0 {
                serving = false
                launchBall(app: app, world: world)
            }
            // Keep ball at center during serve (velocity is zero from startServe)
            world.updateComponent(Transform2D.self, on: ball) { t in
                t.position = Vector2(x: Pong.screenWidth / 2, y: Pong.screenHeight / 2)
            }
            world.updateComponent(PreviousTransform2D.self, on: ball) { prev in
                prev.position = Vector2(x: Pong.screenWidth / 2, y: Pong.screenHeight / 2)
            }
            #if !os(iOS)
            if app.input.isKeyPressed(.escape)
                || app.input.isGamepadButtonPressed(0, .start) {
                app.sceneManager.replace(with: MenuScene(), app: app)
            }
            #else
            if app.input.isGamepadButtonPressed(0, .start) {
                app.sceneManager.replace(with: MenuScene(), app: app)
            }
            #endif
            return
        }

        // --- Scoring (check ball position from previous tick's movement) ---
        if let ballPos = world.getComponent(Transform2D.self, from: ball) {
            let radius = world.getComponent(Ball.self, from: ball)?.radius ?? Pong.ballRadius

            if ballPos.position.x < -radius * 2 {
                rightScore += 1
                world.emit(GoalScoredEvent(scorer: .right))
                if checkWin(app: app) { return }
                startServe(world: world, direction: -1)
            }
            if ballPos.position.x > Pong.screenWidth + radius * 2 {
                leftScore += 1
                world.emit(GoalScoredEvent(scorer: .left))
                if checkWin(app: app) { return }
                startServe(world: world, direction: 1)
            }
        }

        // --- Debug toggle ---
        #if !os(iOS)
        if app.input.isKeyPressed(.d)
            || app.input.isGamepadButtonPressed(0, .faceUp) {
            showPhysicsDebug.toggle()
        }
        #else
        if app.input.isGamepadButtonPressed(0, .faceUp) {
            showPhysicsDebug.toggle()
        }
        #endif

        // --- Escape / Start ---
        #if !os(iOS)
        if app.input.isKeyPressed(.escape)
            || app.input.isGamepadButtonPressed(0, .start) {
            app.sceneManager.replace(with: MenuScene(), app: app)
        }
        #else
        if app.input.isGamepadButtonPressed(0, .start) {
            app.sceneManager.replace(with: MenuScene(), app: app)
        }
        #endif
    }

    func render(app: Application, interpolation: Double) {
        let t = Float(interpolation)
        let world = app.world
        let screen = app.renderer.screenSize

        // Read current and previous transforms from ECS
        guard let leftPos = world.getComponent(Transform2D.self, from: leftPaddle),
              let leftPrev = world.getComponent(PreviousTransform2D.self, from: leftPaddle),
              let leftPaddleComp = world.getComponent(Paddle.self, from: leftPaddle),
              let rightPos = world.getComponent(Transform2D.self, from: rightPaddle),
              let rightPrev = world.getComponent(PreviousTransform2D.self, from: rightPaddle),
              let rightPaddleComp = world.getComponent(Paddle.self, from: rightPaddle),
              let ballPos = world.getComponent(Transform2D.self, from: ball),
              let ballPrev = world.getComponent(PreviousTransform2D.self, from: ball),
              let ballComp = world.getComponent(Ball.self, from: ball) else { return }

        // Interpolated positions for smooth rendering
        let drawLeftY = Agilis.lerp(leftPrev.position.y, leftPos.position.y, t: t)
        let drawRightY = Agilis.lerp(rightPrev.position.y, rightPos.position.y, t: t)
        let drawBall = ballPrev.position.lerp(to: ballPos.position, t: t)

        // Court
        drawCourtDashes(renderer: app.renderer, screenHeight: screen.height, centerX: screen.width / 2)
        // Top/bottom borders
        app.renderer.drawRect(
            Rect(x: 0, y: 0, width: screen.width, height: Pong.lineThickness),
            color: .white
        )
        app.renderer.drawRect(
            Rect(x: 0, y: screen.height - Pong.lineThickness, width: screen.width, height: Pong.lineThickness),
            color: .white
        )

        // Scores
        let scoreScale: Float = 1.5 * Pong.uiScale
        drawScore(leftScore, centerX: screen.width / 4, y: 30 * Pong.uiScale, scale: scoreScale, color: .white, renderer: app.renderer)
        drawScore(rightScore, centerX: screen.width * 3 / 4, y: 30 * Pong.uiScale, scale: scoreScale, color: .white, renderer: app.renderer)

        // Paddles
        app.renderer.drawRect(
            Rect(
                x: leftPos.position.x - leftPaddleComp.halfWidth,
                y: drawLeftY - leftPaddleComp.halfHeight,
                width: leftPaddleComp.halfWidth * 2,
                height: leftPaddleComp.halfHeight * 2
            ),
            color: .white
        )
        app.renderer.drawRect(
            Rect(
                x: rightPos.position.x - rightPaddleComp.halfWidth,
                y: drawRightY - rightPaddleComp.halfHeight,
                width: rightPaddleComp.halfWidth * 2,
                height: rightPaddleComp.halfHeight * 2
            ),
            color: .white
        )

        // Ball
        if serving {
            let blink = Int(serveTimer * 4) % 2 == 0
            if blink {
                app.renderer.drawCircle(center: drawBall, radius: ballComp.radius, color: .white)
            }
        } else {
            app.renderer.drawCircle(center: drawBall, radius: ballComp.radius, color: .white)
        }

        // Rally counter (driven by event bus)
        if rallyCount > 0 {
            let rallyColor = Color(r: 120, g: 120, b: 120)
            app.renderer.drawText(
                "Rally: \(rallyCount)",
                position: Vector2(x: screen.width / 2 - 30, y: screen.height - 18),
                font: fpsFont,
                size: Pong.fontSize(14),
                color: rallyColor
            )
        }

        // FPS counter
        let fpsColor = Color(r: 80, g: 80, b: 80)
        app.renderer.drawText(
            "\(app.fps) FPS",
            position: Vector2(x: 4, y: screen.height - 18),
            font: fpsFont,
            size: 14,
            color: fpsColor
        )

        // Physics debug overlay (toggle with D key or gamepad Y)
        if showPhysicsDebug {
            var debugOptions = PhysicsDebugRendererOptions()
            debugOptions.drawVelocities = true
            debugOptions.velocityScale = 0.2
            app.renderer.drawPhysicsDebug(
                world: world,
                events: physicsWorld.events,
                options: debugOptions
            )
            app.renderer.drawText(
                "[D] Debug ON",
                position: Vector2(x: screen.width - 120, y: screen.height - 18),
                font: fpsFont,
                size: Pong.fontSize(14),
                color: .cyan
            )
        }
    }

    func willExit(app: Application) {
        let world = app.world
        world.removeAllEventHandlers()
        if sounds != nil {
            sounds.unloadAll(audio: app.audio)
        }
        world.removeSystem(aiSystem)
        world.removeSystem(physicsWorld)
        world.removeSystem(pongPhysics)
        world.destroyEntity(leftPaddle)
        world.destroyEntity(rightPaddle)
        world.destroyEntity(ball)
        world.destroyEntity(topWall)
        world.destroyEntity(bottomWall)
        if fpsFont != .invalid {
            app.renderer.destroyFont(fpsFont)
        }
    }

    // MARK: - Private

    private func startServe(world: World, direction: Float) {
        serving = true
        serveTimer = Pong.serveDelay
        serveDirection = direction

        world.updateComponent(Ball.self, on: ball) { b in
            b.speed = Pong.ballInitialSpeed
        }
        world.updateComponent(Transform2D.self, on: ball) { t in
            t.position = Vector2(x: Pong.screenWidth / 2, y: Pong.screenHeight / 2)
        }
        world.updateComponent(PreviousTransform2D.self, on: ball) { prev in
            prev.position = Vector2(x: Pong.screenWidth / 2, y: Pong.screenHeight / 2)
        }
        world.updateComponent(Velocity2D.self, on: ball) { vel in
            vel.linear = .zero
        }
    }

    private func launchBall(app: Application, world: World) {
        app.audio.playSound(sounds.serve, volume: 0.4, pitch: 1.0, looping: false)
        let angle = Float.random(in: -30...30) * .pi / 180
        let speed = world.getComponent(Ball.self, from: ball)?.speed ?? Pong.ballInitialSpeed
        world.updateComponent(Velocity2D.self, on: ball) { vel in
            vel.linear = Vector2(
                x: serveDirection * speed * cosf(angle),
                y: speed * sinf(angle)
            )
        }
    }

    @discardableResult
    private func checkWin(app: Application) -> Bool {
        if leftScore >= Pong.winningScore || rightScore >= Pong.winningScore {
            app.sceneManager.replace(
                with: GameOverScene(
                    leftScore: leftScore,
                    rightScore: rightScore,
                    leftWon: leftScore >= Pong.winningScore
                ),
                app: app
            )
            return true
        }
        return false
    }
}
