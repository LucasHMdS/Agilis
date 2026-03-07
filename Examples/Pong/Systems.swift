import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - ECS Systems

/// Updates AI paddle targeting based on ball trajectory prediction.
final class PongAISystem: System {
    deinit {}
    var priority: Int { -10 }

    var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [Transform2D.self, Paddle.self],
            writes: [Velocity2D.self, AIControlled.self]
        )
    }

    func update(context: SystemContext) {
        let world = context.world

        // Read ball state
        guard let ballEntity = world.entity(named: "ball"),
              let ballPos = world.getComponent(Transform2D.self, from: ballEntity),
              let ballVel = world.getComponent(Velocity2D.self, from: ballEntity) else { return }

        // Update AI-controlled paddles
        world.forEach { (_: Entity, pos: inout Transform2D, paddle: inout Paddle, vel: inout Velocity2D, ai: inout AIControlled) in
            if ballVel.linear.x > 0 {
                // Ball heading toward AI — predict landing Y
                let paddleX = Pong.screenWidth - Pong.paddleMargin
                let timeToReach = (paddleX - ballPos.position.x) / max(ballVel.linear.x, 1)
                var predictedY = ballPos.position.y + ballVel.linear.y * timeToReach

                // Simulate wall bounces for accurate prediction
                while predictedY < 0 || predictedY > Pong.screenHeight {
                    if predictedY < 0 { predictedY = -predictedY }
                    if predictedY > Pong.screenHeight { predictedY = 2 * Pong.screenHeight - predictedY }
                }
                ai.targetY = predictedY
            } else {
                // Drift back to center when ball moves away
                ai.targetY = Pong.screenHeight / 2
            }

            // Move toward target
            let diff = ai.targetY - pos.position.y
            if abs(diff) > 2 {
                vel.linear.y = diff > 0 ? paddle.speed : -paddle.speed
            } else {
                vel.linear.y = 0
            }
        }
    }
}

/// Post-physics system: clamps paddles and applies custom paddle-ball reflection.
///
/// Runs after `PhysicsWorld2D` (priority 100) to override the impulse-based
/// collision response with Pong's angle-based paddle reflection and speed increase.
/// Wall bounces are handled entirely by the physics system (restitution = 1).
final class PongPhysicsSystem: System {
    deinit {}
    var priority: Int { 110 }

    var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [Transform2D.self, Paddle.self],
            writes: [Velocity2D.self, Ball.self],
            emitsEvents: true
        )
    }

    let physics: PhysicsWorld2D

    init(physics: PhysicsWorld2D) {
        self.physics = physics
    }

    func update(context: SystemContext) {
        let world = context.world

        // Clamp paddles to screen bounds (after physics integration)
        world.forEach { (_: Entity, pos: inout Transform2D, paddle: inout Paddle) in
            pos.position.y = clamp(pos.position.y, min: paddle.halfHeight,
                          max: Pong.screenHeight - paddle.halfHeight)
        }

        // Override ball velocity for paddle collisions with angle-based reflection
        guard let ballEntity = world.entity(named: "ball") else { return }

        for event in physics.events where event.type == .began {
            // Determine which entity is the ball and which is the other
            let otherEntity: Entity
            if event.entityA == ballEntity {
                otherEntity = event.entityB
            } else if event.entityB == ballEntity {
                otherEntity = event.entityA
            } else {
                continue
            }

            // Only override for paddle collisions (wall bounces handled by physics)
            guard let paddleComp = world.getComponent(Paddle.self, from: otherEntity),
                  let paddlePos = world.getComponent(Transform2D.self, from: otherEntity)
            else { continue }

            guard let ballPos = world.getComponent(Transform2D.self, from: ballEntity),
                  var ballVel = world.getComponent(Velocity2D.self, from: ballEntity),
                  var ballComp = world.getComponent(Ball.self, from: ballEntity)
            else { continue }

            // Angle based on where ball hit the paddle face
            let hitOffset = (ballPos.position.y - paddlePos.position.y) / paddleComp.halfHeight
            let maxAngle: Float = 60 * .pi / 180
            let angle = clamp(hitOffset, min: -1, max: 1) * maxAngle

            // Speed increases on each paddle hit
            ballComp.speed = min(ballComp.speed + Pong.ballSpeedIncrease, Pong.ballMaxSpeed)

            // Direction depends on which side the paddle is on
            let isLeftPaddle = paddlePos.position.x < Pong.screenWidth / 2
            if isLeftPaddle {
                ballVel.linear.x = ballComp.speed * cosf(angle)
                ballVel.linear.y = ballComp.speed * sinf(angle)
            } else {
                ballVel.linear.x = -ballComp.speed * cosf(angle)
                ballVel.linear.y = ballComp.speed * sinf(angle)
            }

            world.updateComponent(Velocity2D.self, on: ballEntity) { v in v.linear = ballVel.linear }
            world.updateComponent(Ball.self, on: ballEntity) { b in b.speed = ballComp.speed }

            // Notify listeners via event bus (decoupled from scoring/audio/effects)
            world.emit(PaddleHitEvent(paddle: otherEntity, ballSpeed: ballComp.speed))
        }

        // Detect wall bounces (ball collides with non-paddle entity)
        for event in physics.events where event.type == .began {
            let isBallA = event.entityA == ballEntity
            let isBallB = event.entityB == ballEntity
            guard isBallA || isBallB else { continue }
            let other = isBallA ? event.entityB : event.entityA
            if world.getComponent(Paddle.self, from: other) == nil {
                world.emit(WallBounceEvent())
            }
        }
    }
}
