import Agilis

enum LevelBuilder {

    struct LevelData {
        let player: Entity
        var allEntities: [Entity]
    }

    static func buildLevel(in world: World) -> LevelData {
        var entities: [Entity] = []

        // Ground segments with gaps (pits)
        let groundSegments: [(start: Int, end: Int)] = [
            (0, 40), (42, 70), (72, 110), (112, 145), (147, 200)
        ]
        for segment in groundSegments {
            for col in segment.start..<segment.end {
                entities.append(contentsOf: createGroundColumn(col: col, in: world))
            }
        }

        // Floating brick platforms
        entities.append(contentsOf: createPlatform(startCol: 16, row: 10, width: 4, in: world))
        entities.append(contentsOf: createPlatform(startCol: 22, row: 7, width: 3, in: world))
        entities.append(contentsOf: createPlatform(startCol: 50, row: 10, width: 5, in: world))
        entities.append(contentsOf: createPlatform(startCol: 80, row: 9, width: 6, in: world))
        entities.append(contentsOf: createPlatform(startCol: 100, row: 11, width: 3, in: world))
        entities.append(contentsOf: createPlatform(startCol: 120, row: 8, width: 4, in: world))
        entities.append(contentsOf: createPlatform(startCol: 135, row: 10, width: 5, in: world))
        entities.append(contentsOf: createPlatform(startCol: 160, row: 9, width: 4, in: world))

        // Question blocks
        entities.append(createQuestionBlock(col: 12, row: 10, in: world))
        entities.append(createQuestionBlock(col: 21, row: 10, in: world))
        entities.append(createQuestionBlock(col: 19, row: 6, in: world))
        entities.append(createQuestionBlock(col: 55, row: 10, in: world))
        entities.append(createQuestionBlock(col: 87, row: 9, in: world))
        entities.append(createQuestionBlock(col: 125, row: 8, in: world))
        entities.append(createQuestionBlock(col: 140, row: 10, in: world))
        entities.append(createQuestionBlock(col: 165, row: 9, in: world))

        // Pipes
        entities.append(contentsOf: createPipe(col: 28, height: 2, in: world))
        entities.append(contentsOf: createPipe(col: 38, height: 3, in: world))
        entities.append(contentsOf: createPipe(col: 65, height: 2, in: world))
        entities.append(contentsOf: createPipe(col: 95, height: 2, in: world))
        entities.append(contentsOf: createPipe(col: 130, height: 3, in: world))
        entities.append(contentsOf: createPipe(col: 155, height: 2, in: world))

        // Coin rows
        entities.append(contentsOf: createCoinRow(startCol: 16, row: 8, count: 4, in: world))
        entities.append(contentsOf: createCoinRow(startCol: 50, row: 8, count: 5, in: world))
        entities.append(contentsOf: createCoinRow(startCol: 80, row: 7, count: 3, in: world))
        entities.append(contentsOf: createCoinRow(startCol: 110, row: 9, count: 4, in: world))
        entities.append(contentsOf: createCoinRow(startCol: 135, row: 8, count: 5, in: world))
        entities.append(contentsOf: createCoinRow(startCol: 170, row: 8, count: 3, in: world))

        // Goombas
        let gY = groundY() - Mario.goombaHeight / 2
        entities.append(createGoomba(at: Vector2(x: 400, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 700, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 1_100, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 1_600, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 2_200, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 2_600, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 3_200, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 3_800, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 4_400, y: gY), in: world))
        entities.append(createGoomba(at: Vector2(x: 5_200, y: gY), in: world))

        // Flagpole
        entities.append(createFlagpole(col: 193, in: world))

        // Left boundary wall
        entities.append(createBoundaryWall(x: -16, in: world))

        // Player (created last so it's on top)
        let startPos = Vector2(x: 80, y: groundY() - Mario.playerHeight / 2)
        let player = createPlayer(at: startPos, in: world)
        entities.append(player)

        return LevelData(player: player, allEntities: entities)
    }

    // MARK: - Helpers

    static func groundY() -> Float {
        Float(Mario.groundRow) * Mario.tileSize
    }

    static func createPlayer(at position: Vector2, in world: World) -> Entity {
        let entity = world.createEntity()
        world.setName("player", for: entity)
        world.addComponent(Transform2D(position: position), to: entity)
        world.addComponent(PreviousTransform2D(position: position), to: entity)
        world.addComponent(Velocity2D(), to: entity)
        world.addComponent(RigidBody2D(
            mass: 1.0,
            restitution: 0,
            friction: 0,
            gravityScale: 1.0,
            bodyType: .dynamic
        ), to: entity)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Mario.playerWidth / 2,
                                              y: Mario.playerHeight / 2)),
            layer: PlatformerLayers.player,
            mask: PlatformerLayers.solid | PlatformerLayers.enemy
                | PlatformerLayers.coin | PlatformerLayers.flagpole
        ), to: entity)
        world.addComponent(Player(), to: entity)
        return entity
    }

    static func createGroundColumn(col: Int, in world: World) -> [Entity] {
        var entities: [Entity] = []
        let x = Float(col) * Mario.tileSize + Mario.tileSize / 2

        // Top ground tile (grass)
        let topY = Float(Mario.groundRow) * Mario.tileSize + Mario.tileSize / 2
        entities.append(createStaticTile(
            position: Vector2(x: x, y: topY),
            type: .groundTop,
            in: world
        ))

        // Fill below with ground
        let bottomY = Float(Mario.groundRow + 1) * Mario.tileSize + Mario.tileSize / 2
        entities.append(createStaticTile(
            position: Vector2(x: x, y: bottomY),
            type: .ground,
            in: world
        ))
        return entities
    }

    static func createStaticTile(position: Vector2, type: TileType, in world: World) -> Entity {
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: position), to: entity)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Mario.tileSize / 2, y: Mario.tileSize / 2)),
            layer: PlatformerLayers.ground,
            mask: PlatformerLayers.player | PlatformerLayers.enemy
        ), to: entity)
        world.addComponent(RigidBody2D(bodyType: .static), to: entity)
        world.addComponent(Tile(tileType: type), to: entity)
        return entity
    }

    static func createPlatform(startCol: Int, row: Int, width: Int, in world: World) -> [Entity] {
        var entities: [Entity] = []
        for i in 0..<width {
            let x = Float(startCol + i) * Mario.tileSize + Mario.tileSize / 2
            let y = Float(row) * Mario.tileSize + Mario.tileSize / 2
            entities.append(createStaticTile(
                position: Vector2(x: x, y: y),
                type: .brick,
                in: world
            ))
        }
        return entities
    }

    static func createQuestionBlock(col: Int, row: Int, in world: World) -> Entity {
        let x = Float(col) * Mario.tileSize + Mario.tileSize / 2
        let y = Float(row) * Mario.tileSize + Mario.tileSize / 2
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: x, y: y)), to: entity)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Mario.tileSize / 2, y: Mario.tileSize / 2)),
            layer: PlatformerLayers.block,
            mask: PlatformerLayers.player | PlatformerLayers.enemy
        ), to: entity)
        world.addComponent(RigidBody2D(bodyType: .static), to: entity)
        world.addComponent(QuestionBlock(originalY: y), to: entity)
        return entity
    }

    static func createPipe(col: Int, height: Int, in world: World) -> [Entity] {
        var entities: [Entity] = []
        let x = Float(col) * Mario.tileSize + Mario.tileSize
        for row in 0..<height {
            let tileRow = Mario.groundRow - height + row
            let y = Float(tileRow) * Mario.tileSize + Mario.tileSize / 2
            let isTop = row == 0
            let entity = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: x, y: y)), to: entity)
            world.addComponent(Collider2D(
                shape: .aabb(halfExtents: Vector2(x: Mario.tileSize, y: Mario.tileSize / 2)),
                layer: PlatformerLayers.pipe,
                mask: PlatformerLayers.player | PlatformerLayers.enemy
            ), to: entity)
            world.addComponent(RigidBody2D(bodyType: .static), to: entity)
            world.addComponent(Tile(tileType: isTop ? .pipeTop : .pipeBody), to: entity)
            entities.append(entity)
        }
        return entities
    }

    static func createCoinRow(startCol: Int, row: Int, count: Int, in world: World) -> [Entity] {
        var entities: [Entity] = []
        for i in 0..<count {
            let x = Float(startCol + i) * Mario.tileSize + Mario.tileSize / 2
            let y = Float(row) * Mario.tileSize + Mario.tileSize / 2
            let entity = world.createEntity()
            world.addComponent(Transform2D(position: Vector2(x: x, y: y)), to: entity)
            world.addComponent(Collider2D(
                shape: .circle(radius: Mario.coinRadius),
                isTrigger: true,
                layer: PlatformerLayers.coin,
                mask: PlatformerLayers.player
            ), to: entity)
            world.addComponent(Coin(), to: entity)
            entities.append(entity)
        }
        return entities
    }

    static func createGoomba(at position: Vector2, in world: World) -> Entity {
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: position), to: entity)
        world.addComponent(PreviousTransform2D(position: position), to: entity)
        world.addComponent(Velocity2D(), to: entity)
        world.addComponent(RigidBody2D(
            mass: 0.5,
            restitution: 0,
            friction: 0,
            gravityScale: 1,
            bodyType: .dynamic
        ), to: entity)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: Mario.goombaWidth / 2,
                                              y: Mario.goombaHeight / 2)),
            layer: PlatformerLayers.enemy,
            mask: PlatformerLayers.player | PlatformerLayers.ground | PlatformerLayers.pipe
        ), to: entity)
        world.addComponent(Enemy(type: .goomba), to: entity)
        return entity
    }

    static func createFlagpole(col: Int, in world: World) -> Entity {
        let x = Float(col) * Mario.tileSize + Mario.tileSize / 2
        let baseY = Float(Mario.groundRow) * Mario.tileSize
        let topY = Float(Mario.groundRow - 8) * Mario.tileSize
        let midY = (baseY + topY) / 2
        let halfH = (baseY - topY) / 2

        let entity = world.createEntity()
        world.setName("flagpole", for: entity)
        world.addComponent(Transform2D(position: Vector2(x: x, y: midY)), to: entity)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: 4, y: halfH)),
            isTrigger: true,
            layer: PlatformerLayers.flagpole,
            mask: PlatformerLayers.player
        ), to: entity)
        world.addComponent(Flagpole(), to: entity)
        return entity
    }

    static func createBoundaryWall(x: Float, in world: World) -> Entity {
        let levelHeight = Mario.tileSize * Float(Mario.levelHeightTiles)
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: x, y: levelHeight / 2)), to: entity)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: 16, y: levelHeight / 2)),
            layer: PlatformerLayers.ground,
            mask: PlatformerLayers.player
        ), to: entity)
        world.addComponent(RigidBody2D(bodyType: .static), to: entity)
        return entity
    }
}
