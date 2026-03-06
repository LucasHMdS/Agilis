import Testing
import Foundation
@testable import Agilis
@testable import Agilis

// MARK: - Codable Conformance Tests

@Suite("Codable Conformance Tests")
struct CodableConformanceTests {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    @Test("Vector2 round-trip")
    func vector2RoundTrip() throws {
        let v = Vector2(x: 3.14, y: -42.5)
        let decoded = try roundTrip(v)
        #expect(decoded == v)
    }

    @Test("Size round-trip")
    func sizeRoundTrip() throws {
        let s = Size(width: 800, height: 600)
        let decoded = try roundTrip(s)
        #expect(decoded == s)
    }

    @Test("Rect round-trip")
    func rectRoundTrip() throws {
        let r = Rect(x: 10, y: 20, width: 100, height: 50)
        let decoded = try roundTrip(r)
        #expect(decoded == r)
    }

    @Test("Color round-trip")
    func colorRoundTrip() throws {
        let c = Color(r: 128, g: 64, b: 200, a: 180)
        let decoded = try roundTrip(c)
        #expect(decoded == c)
    }

    @Test("TextureHandle round-trip")
    func textureHandleRoundTrip() throws {
        let h = TextureHandle(id: 42)
        let decoded = try roundTrip(h)
        #expect(decoded == h)
    }

    @Test("CollisionShape AABB round-trip")
    func collisionShapeAABBRoundTrip() throws {
        let shape = CollisionShape.aabb(halfExtents: Vector2(x: 16, y: 24))
        let decoded = try roundTrip(shape)
        #expect(decoded == shape)
    }

    @Test("CollisionShape circle round-trip")
    func collisionShapeCircleRoundTrip() throws {
        let shape = CollisionShape.circle(radius: 32)
        let decoded = try roundTrip(shape)
        #expect(decoded == shape)
    }

    @Test("CollisionShape polygon round-trip")
    func collisionShapePolygonRoundTrip() throws {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: 0, y: 0),
            Vector2(x: 10, y: 0),
            Vector2(x: 5, y: 10)
        ])
        let shape = CollisionShape.polygon(poly)
        let decoded = try roundTrip(shape)
        #expect(decoded == shape)
    }

    @Test("ConvexPolygon serializes vertices only, recomputes normals on decode")
    func convexPolygonVerticesOnly() throws {
        let original = ConvexPolygon(vertices: [
            Vector2(x: 0, y: 0),
            Vector2(x: 20, y: 0),
            Vector2(x: 20, y: 20),
            Vector2(x: 0, y: 20)
        ])
        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // Only "vertices" key should be present
        #expect(json.keys.count == 1)
        #expect(json["vertices"] != nil)

        let decoded = try JSONDecoder().decode(ConvexPolygon.self, from: data)
        #expect(decoded.vertices == original.vertices)
        #expect(decoded.normals.count == original.normals.count)
        #expect(decoded.localBounds == original.localBounds)
    }

    @Test("RigidBody2D inverseMass recomputed on decode")
    func rigidBody2DInverseMassRecomputed() throws {
        let body = RigidBody2D(mass: 4.0, restitution: 0.5, friction: 0.8,
                                gravityScale: 2.0, bodyType: .dynamic, linearDamping: 0.1)
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(RigidBody2D.self, from: data)

        #expect(decoded.mass == 4.0)
        #expect(decoded.inverseMass == 0.25) // 1/4
        #expect(decoded.restitution == 0.5)
        #expect(decoded.friction == 0.8)
        #expect(decoded.bodyType == .dynamic)
    }

    @Test("RigidBody2D static body has zero inverseMass on decode")
    func rigidBody2DStaticInverseMass() throws {
        let body = RigidBody2D(mass: 10.0, bodyType: .`static`)
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(RigidBody2D.self, from: data)
        #expect(decoded.inverseMass == 0)
        #expect(decoded.bodyType == .`static`)
    }

    @Test("ParticleEmitter serializes config only, not pool state")
    func particleEmitterConfigOnly() throws {
        var emitter = ParticleEmitter(
            emissionRate: 50, maxParticles: 200,
            lifetime: 0.5...1.5, speed: 50...100,
            startColor: .yellow, endColor: .red,
            emissionShape: .circle(radius: 10),
            renderShape: .rect(width: 4, height: 4),
            worldSpace: false
        )
        // Simulate some internal state
        emitter.burst(count: 5)

        let data = try JSONEncoder().encode(emitter)
        let decoded = try JSONDecoder().decode(ParticleEmitter.self, from: data)

        // Config preserved
        #expect(decoded.emissionRate == 50)
        #expect(decoded.maxParticles == 200)
        #expect(decoded.lifetime == 0.5...1.5)
        #expect(decoded.startColor == .yellow)
        #expect(decoded.worldSpace == false)

        // Internal state reset (not serialized)
        #expect(decoded.activeParticleCount == 0)
    }

    @Test("SpriteAnimator round-trip without lastEvent")
    func spriteAnimatorRoundTrip() throws {
        let clip = AnimationClip(
            name: "walk",
            frames: [
                AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1),
                AnimationFrame(sourceRect: Rect(x: 32, y: 0, width: 32, height: 32), duration: 0.1),
            ],
            mode: .forward
        )
        var animator = SpriteAnimator(clip: clip, speed: 1.5)
        animator.currentFrameIndex = 1
        animator.frameTime = 0.05
        animator.lastEvent = .looped  // Should NOT be serialized

        let data = try JSONEncoder().encode(animator)
        let decoded = try JSONDecoder().decode(SpriteAnimator.self, from: data)

        #expect(decoded.clip == clip)
        #expect(decoded.currentFrameIndex == 1)
        #expect(decoded.frameTime == 0.05)
        #expect(decoded.isPlaying == true)
        #expect(decoded.speed == 1.5)
        #expect(decoded.lastEvent == nil)  // Transient, not serialized
    }

    @Test("EmissionShape enum round-trips")
    func emissionShapeRoundTrip() throws {
        let shapes: [EmissionShape] = [
            .point,
            .circle(radius: 25),
            .ring(radius: 50),
            .rect(width: 100, height: 60)
        ]
        for shape in shapes {
            let decoded = try roundTrip(shape)
            #expect(decoded == shape)
        }
    }

    @Test("BodyType enum round-trips")
    func bodyTypeRoundTrip() throws {
        let types: [BodyType] = [.dynamic, .kinematic, .static]
        for bt in types {
            let decoded = try roundTrip(bt)
            #expect(decoded == bt)
        }
    }

    @Test("PlaybackMode enum round-trips")
    func playbackModeRoundTrip() throws {
        let modes: [PlaybackMode] = [.forward, .reverse, .pingPong, .oneShot]
        for mode in modes {
            let decoded = try roundTrip(mode)
            #expect(decoded == mode)
        }
    }
}

// MARK: - SerializableComponent Tests

@Suite("SerializableComponent Protocol Tests")
struct SerializableComponentTests {

    @Test("Built-in component names are unique")
    func builtinComponentNamesUnique() {
        let names = [
            Transform2D.componentName,
            PreviousTransform2D.componentName,
            Velocity2D.componentName,
            RigidBody2D.componentName,
            Collider2D.componentName,
            Sprite.componentName,
            SpriteAnimator.componentName,
            ParticleEmitter.componentName,
        ]
        let unique = Set(names)
        #expect(unique.count == names.count)
    }

    @Test("WorldSerializer registers component types")
    func registerComponentTypes() {
        let serializer = WorldSerializer()
        #expect(serializer.registeredComponentNames.isEmpty)

        serializer.register(Transform2D.self)
        #expect(serializer.registeredComponentNames == ["Transform2D"])

        serializer.register(Velocity2D.self)
        #expect(serializer.registeredComponentNames.count == 2)
    }

    @Test("registerDefaults registers all built-in types")
    func registerDefaults() {
        let serializer = WorldSerializer()
        serializer.registerDefaults()
        #expect(serializer.registeredComponentNames.count == 12)
        #expect(serializer.registeredComponentNames.contains("Transform2D"))
        #expect(serializer.registeredComponentNames.contains("Sprite"))
        #expect(serializer.registeredComponentNames.contains("ParticleEmitter"))
        #expect(serializer.registeredComponentNames.contains("Light2D"))
        #expect(serializer.registeredComponentNames.contains("ShadowCaster2D"))
        #expect(serializer.registeredComponentNames.contains("NormalMapData"))
    }
}

// MARK: - WorldSerializer Tests

@Suite("WorldSerializer Tests")
struct WorldSerializerTests {

    @Test("Empty world encodes and decodes")
    func emptyWorldRoundTrip() throws {
        let world = World()
        let serializer = WorldSerializer()
        serializer.registerDefaults()

        let data = try serializer.encode(world: world)
        let newWorld = World()
        let remap = try serializer.decode(from: data, into: newWorld)

        #expect(remap.isEmpty)
        #expect(newWorld.entityCount == 0)
    }

    @Test("Single entity with one component")
    func singleEntityOneComponent() throws {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 200)), to: entity)

        let serializer = WorldSerializer()
        serializer.register(Transform2D.self)

        let data = try serializer.encode(world: world)
        let newWorld = World()
        let remap = try serializer.decode(from: data, into: newWorld)

        #expect(remap.count == 1)
        #expect(newWorld.entityCount == 1)

        let newEntity = remap[entity.index]!
        let transform = newWorld.getComponent(Transform2D.self, from: newEntity)!
        #expect(transform.position.x == 100)
        #expect(transform.position.y == 200)
    }

    @Test("Multiple entities with mixed components")
    func multipleEntitiesMixedComponents() throws {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 10, y: 20)), to: e1)
        world.addComponent(Velocity2D(linear: Vector2(x: 5, y: 0)), to: e1)
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 60)), to: e2)

        let serializer = WorldSerializer()
        serializer.register(Transform2D.self)
        serializer.register(Velocity2D.self)

        let data = try serializer.encode(world: world)
        let newWorld = World()
        let remap = try serializer.decode(from: data, into: newWorld)

        #expect(newWorld.entityCount == 2)

        // Entity 1: Transform2D + Velocity2D
        let n1 = remap[e1.index]!
        #expect(newWorld.getComponent(Transform2D.self, from: n1)!.position.x == 10)
        #expect(newWorld.getComponent(Velocity2D.self, from: n1)!.linear.x == 5)

        // Entity 2: Transform2D only
        let n2 = remap[e2.index]!
        #expect(newWorld.getComponent(Transform2D.self, from: n2)!.position.x == 50)
        #expect(newWorld.getComponent(Velocity2D.self, from: n2) == nil)
    }

    @Test("Entity index remapping")
    func entityIndexRemapping() throws {
        let world = World()
        // Create and destroy to advance indices
        let temp = world.createEntity()
        world.destroyEntity(temp)
        let entity = world.createEntity()  // May reuse slot 0 with gen 1
        world.addComponent(Transform2D(position: .zero), to: entity)

        let serializer = WorldSerializer()
        serializer.register(Transform2D.self)

        let data = try serializer.encode(world: world)

        // Decode into a world that already has entities
        let newWorld = World()
        _ = newWorld.createEntity()  // Occupies slot 0
        _ = newWorld.createEntity()  // Occupies slot 1
        let remap = try serializer.decode(from: data, into: newWorld)

        // The remapped entity should be a different slot than the original
        let newEntity = remap[entity.index]!
        #expect(newWorld.isAlive(newEntity))
        #expect(newWorld.getComponent(Transform2D.self, from: newEntity) != nil)
    }

    @Test("Hierarchy preservation (parent-child)")
    func hierarchyPreservation() throws {
        let world = World()
        let parent = world.createEntity()
        let child = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 1, y: 2)), to: parent)
        world.addComponent(Transform2D(position: Vector2(x: 3, y: 4)), to: child)
        world.setParent(parent, for: child)

        let serializer = WorldSerializer()
        serializer.register(Transform2D.self)

        let data = try serializer.encode(world: world)
        let newWorld = World()
        let remap = try serializer.decode(from: data, into: newWorld)

        let newParent = remap[parent.index]!
        let newChild = remap[child.index]!

        // Verify hierarchy restored
        let resolvedParent = newWorld.parent(of: newChild)
        #expect(resolvedParent == newParent)

        let children = newWorld.children(of: newParent)
        #expect(children.count == 1)
        #expect(children[0] == newChild)
    }

    @Test("Metadata preservation (name and tags)")
    func metadataPreservation() throws {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.setName("player", for: entity)
        world.addTag("hero", to: entity)
        world.addTag("controllable", to: entity)

        let serializer = WorldSerializer()
        serializer.register(Transform2D.self)

        let data = try serializer.encode(world: world)
        let newWorld = World()
        let remap = try serializer.decode(from: data, into: newWorld)

        let newEntity = remap[entity.index]!
        #expect(newWorld.name(of: newEntity) == "player")
        #expect(newWorld.hasTag("hero", on: newEntity))
        #expect(newWorld.hasTag("controllable", on: newEntity))

        // Lookup by name
        let found = newWorld.entity(named: "player")
        #expect(found == newEntity)
    }

    @Test("Selective registration — unregistered components skipped")
    func selectiveRegistration() throws {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 1, y: 2)), to: entity)
        world.addComponent(Velocity2D(linear: Vector2(x: 5, y: 0)), to: entity)

        // Only register Transform2D — Velocity2D should be skipped
        let serializer = WorldSerializer()
        serializer.register(Transform2D.self)

        let data = try serializer.encode(world: world)
        let newWorld = World()
        // Register both for decode, but Velocity2D won't be in the data
        serializer.register(Velocity2D.self)
        let remap = try serializer.decode(from: data, into: newWorld)

        let newEntity = remap[entity.index]!
        #expect(newWorld.getComponent(Transform2D.self, from: newEntity) != nil)
        #expect(newWorld.getComponent(Velocity2D.self, from: newEntity) == nil)
    }

    @Test("Unknown components in JSON gracefully skipped")
    func unknownComponentsSkipped() throws {
        // Manually create JSON with an unknown component type
        let json = """
        {
            "entities": [
                {
                    "index": 0,
                    "components": {
                        "Transform2D": {"position":{"x":1,"y":2},"rotation":0,"scale":{"x":1,"y":1}},
                        "UnknownComponent": {"foo": "bar"}
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let serializer = WorldSerializer()
        serializer.register(Transform2D.self)

        let world = World()
        let remap = try serializer.decode(from: json, into: world)

        #expect(world.entityCount == 1)
        let entity = remap[0]!
        #expect(world.getComponent(Transform2D.self, from: entity)!.position.x == 1)
    }

    @Test("Full round-trip with complex world state")
    func fullRoundTrip() throws {
        let world = World()

        // Create a scene with physics entities
        let player = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 200), rotation: 0.5), to: player)
        world.addComponent(Velocity2D(linear: Vector2(x: 10, y: -5), angular: 0.1), to: player)
        world.addComponent(RigidBody2D(mass: 2.0, restitution: 0.3, bodyType: .dynamic), to: player)
        world.addComponent(Collider2D(shape: .circle(radius: 16), isTrigger: false, layer: 1, mask: 0xFF), to: player)
        world.setName("player", for: player)
        world.addTag("controllable", to: player)

        let wall = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 0, y: 300)), to: wall)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 400, y: 10))), to: wall)
        world.addComponent(RigidBody2D(bodyType: .static), to: wall)
        world.setName("floor", for: wall)

        let child = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 5, y: 5)), to: child)
        world.setParent(player, for: child)

        let serializer = WorldSerializer()
        serializer.registerDefaults()

        // Encode
        let data = try serializer.encode(world: world)

        // Decode into fresh world
        let newWorld = World()
        let remap = try serializer.decode(from: data, into: newWorld)

        #expect(newWorld.entityCount == 3)

        // Verify player
        let newPlayer = remap[player.index]!
        let t = newWorld.getComponent(Transform2D.self, from: newPlayer)!
        #expect(t.position.x == 100)
        #expect(t.position.y == 200)
        #expect(t.rotation == 0.5)

        let v = newWorld.getComponent(Velocity2D.self, from: newPlayer)!
        #expect(v.linear.x == 10)

        let rb = newWorld.getComponent(RigidBody2D.self, from: newPlayer)!
        #expect(rb.mass == 2.0)
        #expect(rb.inverseMass == 0.5) // Recomputed
        #expect(rb.bodyType == .dynamic)

        let c = newWorld.getComponent(Collider2D.self, from: newPlayer)!
        #expect(c.shape == .circle(radius: 16))

        #expect(newWorld.name(of: newPlayer) == "player")
        #expect(newWorld.hasTag("controllable", on: newPlayer))

        // Verify wall
        let newWall = remap[wall.index]!
        let wallRB = newWorld.getComponent(RigidBody2D.self, from: newWall)!
        #expect(wallRB.bodyType == .static)
        #expect(wallRB.inverseMass == 0)
        #expect(newWorld.name(of: newWall) == "floor")

        // Verify hierarchy
        let newChild = remap[child.index]!
        #expect(newWorld.parent(of: newChild) == newPlayer)
        let children = newWorld.children(of: newPlayer)
        #expect(children.count == 1)
        #expect(children[0] == newChild)
    }

    @Test("Invalid JSON throws invalidFormat error")
    func invalidJsonThrows() throws {
        let serializer = WorldSerializer()
        serializer.registerDefaults()

        let badData = "not json".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try serializer.decode(from: badData, into: World())
        }
    }

    @Test("Entities without components serialize correctly")
    func entitiesWithoutComponents() throws {
        let world = World()
        let entity = world.createEntity()
        world.setName("empty", for: entity)

        let serializer = WorldSerializer()
        serializer.registerDefaults()

        let data = try serializer.encode(world: world)
        let newWorld = World()
        let remap = try serializer.decode(from: data, into: newWorld)

        #expect(newWorld.entityCount == 1)
        let newEntity = remap[entity.index]!
        #expect(newWorld.name(of: newEntity) == "empty")
    }
}
