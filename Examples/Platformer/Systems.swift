import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - Enemy AI System (priority 0)

final class EnemyAISystem: System {
    var priority: Int { 0 }

    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [Enemy.self], writes: [Velocity2D.self, Enemy.self])
    }

    func update(context: SystemContext) {
        let world = context.world

        world.forEach { (_: Entity, vel: inout Velocity2D, enemy: inout Enemy) in
            if enemy.isDead {
                vel.linear = .zero
                return
            }
            vel.linear.x = enemy.moveDirection * Mario.goombaMoveSpeed
        }
    }
}

// MARK: - Gameplay System (priority 10)

final class GameplaySystem: System {
    var priority: Int { 10 }

    var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [QuestionBlock.self, Enemy.self, Player.self],
            writes: [Transform2D.self, QuestionBlock.self, Enemy.self, Player.self],
            mutatesEntities: true
        )
    }

    func update(context: SystemContext) {
        let world = context.world
        let dt = Float(context.deltaTime)

        // Question block bounce animation
        world.forEach { (_: Entity, pos: inout Transform2D, block: inout QuestionBlock) in
            if block.state == .bouncing {
                block.bounceTimer -= dt
                if block.bounceTimer <= 0 {
                    block.state = .used
                    pos.position.y = block.originalY
                } else {
                    let t = block.bounceTimer / Mario.blockBounceTime
                    let offset = sinf(t * .pi) * Mario.blockBounceDistance
                    pos.position.y = block.originalY - offset
                }
            }
        }

        // Dead enemy cleanup
        var toDestroy: [Entity] = []
        world.forEach { (entity: Entity, enemy: inout Enemy) in
            if enemy.isDead {
                enemy.deathTimer -= dt
                if enemy.deathTimer <= 0 {
                    toDestroy.append(entity)
                }
            }
        }
        for entity in toDestroy {
            world.destroyEntity(entity)
        }

        // Player invincibility countdown
        world.forEach { (_: Entity, player: inout Player) in
            if player.isInvincible {
                player.invincibleTimer -= dt
                if player.invincibleTimer <= 0 {
                    player.isInvincible = false
                }
            }
        }
    }
}

// MARK: - Post-Physics System (priority 110)

final class PostPhysicsSystem: System {
    var priority: Int { 110 }

    var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [
                Tile.self, Coin.self, QuestionBlock.self, Flagpole.self,
                Collider2D.self, Transform2D.self
            ],
            writes: [Player.self, Enemy.self, Velocity2D.self],
            emitsEvents: true
        )
    }

    let physics: PhysicsWorld2D

    init(physics: PhysicsWorld2D) {
        self.physics = physics
    }

    // swiftlint:disable:next cyclomatic_complexity
    func update(context: SystemContext) {
        let world = context.world

        // Reset grounded state before collision checks
        world.forEach { (_: Entity, player: inout Player) in
            player.isGrounded = false
        }

        for event in physics.events {
            guard event.type == .began || event.type == .ongoing else { continue }
            guard let contact = event.contact else { continue }

            let entityA = event.entityA
            let entityB = event.entityB

            // Determine if either entity is the player
            let playerEntity: Entity
            let otherEntity: Entity
            let normalFromPlayer: Vector2

            if world.getComponent(Player.self, from: entityA) != nil {
                playerEntity = entityA
                otherEntity = entityB
                normalFromPlayer = contact.normal
            } else if world.getComponent(Player.self, from: entityB) != nil {
                playerEntity = entityB
                otherEntity = entityA
                normalFromPlayer = Vector2(x: -contact.normal.x, y: -contact.normal.y)
            } else {
                // Neither is player — check enemy-wall collision
                handleEnemyWallCollision(
                    entityA: entityA,
                    entityB: entityB,
                    contact: contact,
                    eventType: event.type,
                    world: world
                )
                continue
            }

            // Skip if player is dead
            if let player = world.getComponent(Player.self, from: playerEntity), player.isDead {
                continue
            }

            // Ground detection: normalFromPlayer points downward (player on top of something)
            if normalFromPlayer.y > 0.5 {
                let isSolid = world.getComponent(Tile.self, from: otherEntity) != nil
                    || world.getComponent(QuestionBlock.self, from: otherEntity) != nil
                if isSolid {
                    world.updateComponent(Player.self, on: playerEntity) { p in
                        p.isGrounded = true
                        p.coyoteTimer = Mario.coyoteTime
                    }
                }
            }

            // Enemy interaction
            if let enemy = world.getComponent(Enemy.self, from: otherEntity), !enemy.isDead {
                if normalFromPlayer.y > 0.3 {
                    // Stomp: player above enemy
                    world.emit(EnemyStompedEvent(enemyEntity: otherEntity,
                                                 playerEntity: playerEntity))
                } else if event.type == .began {
                    // Hurt: side or below contact
                    world.emit(PlayerHurtEvent(playerEntity: playerEntity,
                                               enemyEntity: otherEntity))
                }
            }

            // Coin collection (trigger)
            if world.getComponent(Coin.self, from: otherEntity) != nil {
                if event.type == .began {
                    world.emit(CoinCollectedEvent(coinEntity: otherEntity,
                                                  playerEntity: playerEntity))
                }
            }

            // Question block from below: normalFromPlayer.y < -0.5 means player hit above
            if normalFromPlayer.y < -0.5 {
                if world.getComponent(QuestionBlock.self, from: otherEntity) != nil {
                    if event.type == .began {
                        world.emit(BlockHitEvent(blockEntity: otherEntity,
                                                 playerEntity: playerEntity))
                    }
                }
            }

            // Flagpole
            if world.getComponent(Flagpole.self, from: otherEntity) != nil {
                if event.type == .began {
                    world.emit(LevelCompleteEvent(playerEntity: playerEntity))
                }
            }
        }

        // Enemy ledge detection and bounds clamping
        // Collect enemy data first (read phase) to avoid exclusivity violation
        // with pointQuery during forEach
        let levelLeft: Float = Mario.tileSize / 2
        let levelRight = Float(Mario.levelWidthTiles) * Mario.tileSize - Mario.tileSize / 2
        let groundCheckY = LevelBuilder.groundY() + Mario.tileSize / 2 + 4

        var enemyUpdates: [(entity: Entity, newDirection: Float)] = []

        world.forEach { (entity: Entity, pos: inout Transform2D, enemy: inout Enemy) in
            if enemy.isDead { return }

            var dir = enemy.moveDirection

            // Reverse at map bounds
            if pos.position.x <= levelLeft && dir < 0 {
                dir = 1
            } else if pos.position.x >= levelRight && dir > 0 {
                dir = -1
            }

            if dir != enemy.moveDirection {
                enemyUpdates.append((entity: entity, newDirection: dir))
                return
            }

            // Store data for ledge check (done outside forEach)
            enemyUpdates.append((entity: entity, newDirection: 0))
        }

        // Ledge detection (outside forEach to avoid exclusivity issues)
        for i in 0..<enemyUpdates.count {
            // Skip if already updated by bounds check (newDirection != 0)
            if enemyUpdates[i].newDirection != 0 {
                world.updateComponent(Enemy.self, on: enemyUpdates[i].entity) { e in
                    e.moveDirection = enemyUpdates[i].newDirection
                }
                continue
            }

            let entity = enemyUpdates[i].entity
            guard let pos = world.getComponent(Transform2D.self, from: entity),
                  let enemy = world.getComponent(Enemy.self, from: entity) else { continue }

            let aheadX = pos.position.x + enemy.moveDirection * (Mario.goombaWidth / 2 + 4)
            let groundAhead = physics.pointQuery(
                world: world,
                point: Vector2(x: aheadX, y: groundCheckY),
                layerMask: PlatformerLayers.ground
            )
            if groundAhead.isEmpty {
                world.updateComponent(Enemy.self, on: entity) { e in
                    e.moveDirection = -e.moveDirection
                }
            }
        }
    }

    private func handleEnemyWallCollision(
        entityA: Entity,
        entityB: Entity,
        contact: Contact,
        eventType: CollisionEventType,
        world: World
    ) {
        guard eventType == .began else { return }

        let enemyEntity: Entity
        let otherEntity: Entity
        let normalFromEnemy: Vector2

        if world.getComponent(Enemy.self, from: entityA) != nil {
            enemyEntity = entityA
            otherEntity = entityB
            normalFromEnemy = contact.normal
        } else if world.getComponent(Enemy.self, from: entityB) != nil {
            enemyEntity = entityB
            otherEntity = entityA
            normalFromEnemy = Vector2(x: -contact.normal.x, y: -contact.normal.y)
        } else {
            return
        }

        if let enemy = world.getComponent(Enemy.self, from: enemyEntity), enemy.isDead {
            return
        }

        // Only reverse when hitting pipes — ground tile edges produce false
        // horizontal normals at tile boundaries (ghost collision problem)
        guard let otherCollider = world.getComponent(Collider2D.self, from: otherEntity),
              otherCollider.layer & PlatformerLayers.pipe != 0 else { return }

        if abs(normalFromEnemy.x) > 0.5 {
            world.updateComponent(Enemy.self, on: enemyEntity) { e in
                e.moveDirection = normalFromEnemy.x > 0 ? -1 : 1
            }
        }
    }
}
