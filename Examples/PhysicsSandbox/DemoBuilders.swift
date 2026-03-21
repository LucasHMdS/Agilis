import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Factory functions that build each joint/physics demo and return all created entities for cleanup.
enum DemoBuilders {

    // MARK: - Tab 1: Ragdoll (Revolute Joints with Angle Limits)

    static func buildRagdoll(in world: World, physics: PhysicsWorld2D) -> [Entity] {
        var entities: [Entity] = []

        let cx: Float = Sandbox.screenWidth / 2
        let startY: Float = 150

        // Head
        let head = createDynamicCircle(in: world, pos: Vector2(x: cx, y: startY), radius: 18, mass: 2)
        entities.append(head)

        // Torso
        let torso = createDynamicBox(in: world, pos: Vector2(x: cx, y: startY + 55), hw: 14, hh: 30, mass: 5)
        entities.append(torso)

        // Head-Torso joint (neck)
        physics.createJoint(.revolute(RevoluteJointDef(
            entityA: torso,
            entityB: head,
            anchor: Vector2(x: cx, y: startY + 22),
            enableLimit: true,
            lowerAngle: -0.4,
            upperAngle: 0.4
        )), in: world)

        // Upper arms
        let leftArm = createDynamicBox(in: world, pos: Vector2(x: cx - 35, y: startY + 40), hw: 18, hh: 6, mass: 1.5)
        let rightArm = createDynamicBox(in: world, pos: Vector2(x: cx + 35, y: startY + 40), hw: 18, hh: 6, mass: 1.5)
        entities.append(contentsOf: [leftArm, rightArm])

        physics.createJoint(.revolute(RevoluteJointDef(
            entityA: torso,
            entityB: leftArm,
            anchor: Vector2(x: cx - 16, y: startY + 30),
            enableLimit: true,
            lowerAngle: -1.5,
            upperAngle: 1.5
        )), in: world)
        physics.createJoint(.revolute(RevoluteJointDef(
            entityA: torso,
            entityB: rightArm,
            anchor: Vector2(x: cx + 16, y: startY + 30),
            enableLimit: true,
            lowerAngle: -1.5,
            upperAngle: 1.5
        )), in: world)

        // Legs
        let leftLeg = createDynamicBox(in: world, pos: Vector2(x: cx - 10, y: startY + 110), hw: 7, hh: 22, mass: 2)
        let rightLeg = createDynamicBox(in: world, pos: Vector2(x: cx + 10, y: startY + 110), hw: 7, hh: 22, mass: 2)
        entities.append(contentsOf: [leftLeg, rightLeg])

        physics.createJoint(.revolute(RevoluteJointDef(
            entityA: torso,
            entityB: leftLeg,
            anchor: Vector2(x: cx - 8, y: startY + 85),
            enableLimit: true,
            lowerAngle: -0.8,
            upperAngle: 0.8
        )), in: world)
        physics.createJoint(.revolute(RevoluteJointDef(
            entityA: torso,
            entityB: rightLeg,
            anchor: Vector2(x: cx + 8, y: startY + 85),
            enableLimit: true,
            lowerAngle: -0.8,
            upperAngle: 0.8
        )), in: world)

        return entities
    }

    // MARK: - Tab 2: Bridge (Distance Joints as Springs)

    static func buildBridge(in world: World, physics: PhysicsWorld2D) -> [Entity] {
        var entities: [Entity] = []

        let plankCount = 12
        let plankWidth: Float = 50
        let plankHeight: Float = 10
        let startX: Float = 150
        let bridgeY: Float = 350
        let spacing: Float = 55

        // Left anchor (static)
        let leftAnchor = createStaticBox(in: world, pos: Vector2(x: startX - 30, y: bridgeY), hw: 20, hh: 20)
        entities.append(leftAnchor)

        var prevEntity = leftAnchor
        var prevAnchorX = startX - 10

        for i in 0..<plankCount {
            let px = startX + Float(i) * spacing + spacing / 2
            let plank = createDynamicBox(in: world, pos: Vector2(x: px, y: bridgeY), hw: plankWidth / 2, hh: plankHeight / 2, mass: 2)
            entities.append(plank)

            let anchorX = px - plankWidth / 2
            physics.createJoint(.distance(DistanceJointDef(
                entityA: prevEntity,
                entityB: plank,
                anchorA: Vector2(x: prevAnchorX, y: bridgeY),
                anchorB: Vector2(x: anchorX, y: bridgeY),
                frequencyHz: 3.0,
                dampingRatio: 0.4
            )), in: world)

            prevEntity = plank
            prevAnchorX = px + plankWidth / 2
        }

        // Right anchor (static)
        let rightX = startX + Float(plankCount) * spacing + 30
        let rightAnchor = createStaticBox(in: world, pos: Vector2(x: rightX, y: bridgeY), hw: 20, hh: 20)
        entities.append(rightAnchor)

        physics.createJoint(.distance(DistanceJointDef(
            entityA: prevEntity,
            entityB: rightAnchor,
            anchorA: Vector2(x: prevAnchorX, y: bridgeY),
            anchorB: Vector2(x: rightX - 10, y: bridgeY),
            frequencyHz: 3.0,
            dampingRatio: 0.4
        )), in: world)

        // Heavy ball to drop on bridge
        let ball = createDynamicCircle(in: world, pos: Vector2(x: Sandbox.screenWidth / 2, y: 100), radius: 25, mass: 15)
        entities.append(ball)

        return entities
    }

    // MARK: - Tab 3: Crane (Rope + Weld)

    static func buildCrane(in world: World, physics: PhysicsWorld2D) -> [Entity] {
        var entities: [Entity] = []

        let anchorPos = Vector2(x: Sandbox.screenWidth / 2, y: 100)
        let payloadPos = Vector2(x: Sandbox.screenWidth / 2, y: 350)

        // Crane anchor (static)
        let anchor = createStaticBox(in: world, pos: anchorPos, hw: 30, hh: 15)
        entities.append(anchor)

        // Rope body (dynamic, light)
        let ropeBody = createDynamicCircle(in: world, pos: Vector2(x: anchorPos.x, y: 220), radius: 8, mass: 0.5)
        entities.append(ropeBody)

        // Rope joint — goes slack when close
        physics.createJoint(.rope(RopeJointDef(
            entityA: anchor,
            entityB: ropeBody,
            anchorA: anchorPos,
            anchorB: Vector2(x: anchorPos.x, y: 220),
            maxLength: 200
        )), in: world)

        // Payload (two welded boxes)
        let payloadA = createDynamicBox(in: world, pos: payloadPos, hw: 30, hh: 20, mass: 8)
        let payloadB = createDynamicBox(in: world, pos: Vector2(x: payloadPos.x, y: payloadPos.y + 35), hw: 20, hh: 12, mass: 4)
        entities.append(contentsOf: [payloadA, payloadB])

        // Weld payload pieces together
        physics.createJoint(.weld(WeldJointDef(
            entityA: payloadA,
            entityB: payloadB,
            anchor: Vector2(x: payloadPos.x, y: payloadPos.y + 20)
        )), in: world)

        // Rope body to payload
        physics.createJoint(.rope(RopeJointDef(
            entityA: ropeBody,
            entityB: payloadA,
            anchorA: Vector2(x: anchorPos.x, y: 220),
            anchorB: payloadPos,
            maxLength: 150
        )), in: world)

        return entities
    }

    // MARK: - Tab 4: Elevator (Prismatic Joint)

    static func buildElevator(in world: World, physics: PhysicsWorld2D) -> [Entity] {
        var entities: [Entity] = []

        let railX: Float = Sandbox.screenWidth / 2
        let railY: Float = 300

        // Rail (static)
        let rail = createStaticBox(in: world, pos: Vector2(x: railX, y: railY), hw: 10, hh: 200)
        entities.append(rail)

        // Platform (dynamic)
        let platform = createDynamicBox(in: world, pos: Vector2(x: railX, y: railY - 100), hw: 60, hh: 12, mass: 5)
        entities.append(platform)

        // Prismatic joint — vertical axis with motor
        physics.createJoint(.prismatic(PrismaticJointDef(
            entityA: rail,
            entityB: platform,
            anchor: Vector2(x: railX, y: railY),
            axis: Vector2(x: 0, y: 1),
            enableLimit: true,
            lowerTranslation: -180,
            upperTranslation: 180,
            enableMotor: true,
            motorSpeed: 80,
            maxMotorForce: 800
        )), in: world)

        // Boxes to ride on the platform
        for i in 0..<3 {
            let box = createDynamicBox(
                in: world,
                pos: Vector2(x: railX - 30 + Float(i) * 30, y: railY - 150),
                hw: 10,
                hh: 10,
                mass: 1
            )
            entities.append(box)
        }

        return entities
    }

    // MARK: - Tab 5: Motor Joint

    static func buildMotorDemo(in world: World, physics: PhysicsWorld2D) -> [Entity] {
        var entities: [Entity] = []

        let cx: Float = Sandbox.screenWidth / 2
        let cy: Float = 350

        // Reference body (static)
        let reference = createStaticBox(in: world, pos: Vector2(x: cx, y: cy), hw: 15, hh: 15)
        entities.append(reference)

        // Follower body (dynamic)
        let follower = createDynamicBox(in: world, pos: Vector2(x: cx + 100, y: cy), hw: 20, hh: 20, mass: 3)
        entities.append(follower)

        // Motor joint — drives follower toward an offset relative to reference
        physics.createJoint(.motor(MotorJointDef(
            entityA: reference,
            entityB: follower,
            linearOffset: Vector2(x: 100, y: 0),
            correctionFactor: 0.3,
            maxForce: 500,
            maxTorque: 200
        )), in: world)

        // Additional objects for the follower to push around
        for i in 0..<5 {
            let angle = Float(i) * Float.pi * 2 / 5
            let ox = cx + cosf(angle) * 180
            let oy = cy + sinf(angle) * 120
            let ball = createDynamicCircle(in: world, pos: Vector2(x: ox, y: oy), radius: 12, mass: 1)
            entities.append(ball)
        }

        return entities
    }

    // MARK: - Tab 6: Projectiles (CCD + Breakable Weld Joints)

    static func buildProjectileRange(in world: World, physics: PhysicsWorld2D) -> [Entity] {
        var entities: [Entity] = []

        // Build a wall of weld-joined boxes
        let wallX: Float = 650
        let wallStartY: Float = 250
        let boxSize: Float = 20

        var wallBoxes: [[Entity]] = []
        for row in 0..<6 {
            var rowBoxes: [Entity] = []
            for col in 0..<4 {
                let x = wallX + Float(col) * (boxSize + 2)
                let y = wallStartY + Float(row) * (boxSize + 2)
                let box = createDynamicBox(in: world, pos: Vector2(x: x, y: y), hw: boxSize / 2, hh: boxSize / 2, mass: 2)
                rowBoxes.append(box)
                entities.append(box)
            }
            wallBoxes.append(rowBoxes)
        }

        // Weld horizontal neighbors (breakable)
        for row in wallBoxes {
            for i in 0..<(row.count - 1) {
                let posA = Vector2(x: wallX + Float(i) * (boxSize + 2) + boxSize / 2 + 1, y: 0)
                let rowIdx = wallBoxes.firstIndex(where: { $0.contains(row[i]) }) ?? 0
                let ay = wallStartY + Float(rowIdx) * (boxSize + 2)
                physics.createJoint(.weld(WeldJointDef(
                    entityA: row[i],
                    entityB: row[i + 1],
                    anchor: Vector2(x: posA.x, y: ay),
                    maxForce: 200
                )), in: world)
            }
        }

        // Weld vertical neighbors (breakable)
        for rowIdx in 0..<(wallBoxes.count - 1) {
            for col in 0..<wallBoxes[rowIdx].count {
                let x = wallX + Float(col) * (boxSize + 2)
                let y = wallStartY + Float(rowIdx) * (boxSize + 2) + boxSize / 2 + 1
                physics.createJoint(.weld(WeldJointDef(
                    entityA: wallBoxes[rowIdx][col],
                    entityB: wallBoxes[rowIdx + 1][col],
                    anchor: Vector2(x: x, y: y),
                    maxForce: 200
                )), in: world)
            }
        }

        // Launcher platform (static)
        let launcher = createStaticBox(in: world, pos: Vector2(x: 200, y: 400), hw: 40, hh: 10)
        entities.append(launcher)

        return entities
    }

    // MARK: - Helpers

    static func createDynamicBox(in world: World, pos: Vector2, hw: Float, hh: Float, mass: Float) -> Entity {
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: pos), to: entity)
        world.addComponent(Velocity2D(), to: entity)
        let shape = CollisionShape.aabb(halfExtents: Vector2(x: hw, y: hh))
        world.addComponent(RigidBody2D(
            mass: mass,
            inertia: RigidBody2D.computeInertia(mass: mass, shape: shape),
            restitution: 0.3,
            friction: 0.5,
            bodyType: .dynamic
        ), to: entity)
        world.addComponent(Collider2D(
            shape: shape,
            layer: Sandbox.layerObject,
            mask: Sandbox.layerObject | Sandbox.layerWall | Sandbox.layerProjectile
        ), to: entity)
        world.addComponent(Draggable(), to: entity)
        return entity
    }

    static func createDynamicCircle(in world: World, pos: Vector2, radius: Float, mass: Float) -> Entity {
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: pos), to: entity)
        world.addComponent(Velocity2D(), to: entity)
        let shape = CollisionShape.circle(radius: radius)
        world.addComponent(RigidBody2D(
            mass: mass,
            inertia: RigidBody2D.computeInertia(mass: mass, shape: shape),
            restitution: 0.4,
            friction: 0.3,
            bodyType: .dynamic
        ), to: entity)
        world.addComponent(Collider2D(
            shape: shape,
            layer: Sandbox.layerObject,
            mask: Sandbox.layerObject | Sandbox.layerWall | Sandbox.layerProjectile
        ), to: entity)
        world.addComponent(Draggable(), to: entity)
        return entity
    }

    static func createStaticBox(in world: World, pos: Vector2, hw: Float, hh: Float) -> Entity {
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: pos), to: entity)
        world.addComponent(RigidBody2D(mass: 0, bodyType: .static), to: entity)
        world.addComponent(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: hw, y: hh)),
            layer: Sandbox.layerWall,
            mask: Sandbox.layerObject | Sandbox.layerProjectile
        ), to: entity)
        return entity
    }

    static func spawnProjectile(in world: World, from pos: Vector2, toward target: Vector2) -> Entity {
        let entity = world.createEntity()
        let dir = Vector2(x: target.x - pos.x, y: target.y - pos.y)
        let len = sqrtf(dir.x * dir.x + dir.y * dir.y)
        let norm = len > 0.001 ? Vector2(x: dir.x / len, y: dir.y / len) : Vector2(x: 1, y: 0)
        let speed: Float = 2_000

        world.addComponent(Transform2D(position: pos), to: entity)
        world.addComponent(Velocity2D(linear: Vector2(x: norm.x * speed, y: norm.y * speed)), to: entity)
        let shape = CollisionShape.circle(radius: 5)
        world.addComponent(RigidBody2D(
            mass: 0.5,
            gravityScale: 0,
            bodyType: .dynamic,
            useCCD: true
        ), to: entity)
        world.addComponent(Collider2D(
            shape: shape,
            layer: Sandbox.layerProjectile,
            mask: Sandbox.layerObject | Sandbox.layerWall
        ), to: entity)
        world.addComponent(Projectile(lifetime: 3.0), to: entity)
        return entity
    }
}
