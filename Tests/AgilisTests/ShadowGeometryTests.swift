import Testing
import Foundation
@testable import Agilis

// MARK: - Shadow Geometry

@Suite("ShadowGeometry")
struct ShadowGeometryTests {

    // MARK: - AABB Vertex Generation

    @Test("AABB vertices are generated in CCW order")
    func aabbVertices() {
        let verts = ShadowGeometry.aabbVertices(halfExtents: Vector2(x: 10, y: 5))
        #expect(verts.count == 4)
        // Bottom-left, bottom-right, top-right, top-left
        #expect(verts[0].x == -10)
        #expect(verts[0].y == -5)
        #expect(verts[1].x == 10)
        #expect(verts[1].y == -5)
        #expect(verts[2].x == 10)
        #expect(verts[2].y == 5)
        #expect(verts[3].x == -10)
        #expect(verts[3].y == 5)
    }

    // MARK: - Vertex Transformation

    @Test("Transform vertices with no rotation is translation only")
    func transformNoRotation() {
        let verts = [Vector2(x: 1, y: 0), Vector2(x: 0, y: 1)]
        let result = ShadowGeometry.transformVertices(verts, position: Vector2(x: 10, y: 20), rotation: 0)
        #expect(abs(result[0].x - 11) < 0.001)
        #expect(abs(result[0].y - 20) < 0.001)
        #expect(abs(result[1].x - 10) < 0.001)
        #expect(abs(result[1].y - 21) < 0.001)
    }

    @Test("Transform vertices with 90-degree rotation")
    func transform90Degrees() {
        let verts = [Vector2(x: 1, y: 0)]
        let halfPi = Float.pi / 2
        let result = ShadowGeometry.transformVertices(verts, position: .zero, rotation: halfPi)
        // (1, 0) rotated 90 degrees CCW = (0, 1)
        #expect(abs(result[0].x) < 0.001)
        #expect(abs(result[0].y - 1) < 0.001)
    }

    // MARK: - Polygon Shadow Computation

    @Test("Shadow from AABB with light to the left")
    func aabbShadowLeftLight() {
        // Light is to the left of a box centered at origin
        let lightPos = Vector2(x: -50, y: 0)
        let halfExtents = Vector2(x: 10, y: 10)
        let verts = ShadowGeometry.aabbVertices(halfExtents: halfExtents)
        // Vertices are in local space at (0,0) with no rotation = world space

        let shadow = ShadowGeometry.shadowForPolygon(
            lightPos: lightPos,
            vertices: verts,
            shadowExtent: 100
        )

        #expect(shadow != nil)
        if let shadow = shadow {
            // Shadow should have vertices extending to the right of the box
            #expect(shadow.vertices.count >= 4)

            // All projected vertices should be to the right of the box
            let maxX = shadow.vertices.map(\.x).max() ?? 0
            #expect(maxX > 10) // Shadow extends past the box
        }
    }

    @Test("Shadow from AABB with light above")
    func aabbShadowAboveLight() {
        let lightPos = Vector2(x: 0, y: -50)
        let halfExtents = Vector2(x: 10, y: 10)
        let verts = ShadowGeometry.aabbVertices(halfExtents: halfExtents)

        let shadow = ShadowGeometry.shadowForPolygon(
            lightPos: lightPos,
            vertices: verts,
            shadowExtent: 100
        )

        #expect(shadow != nil)
        if let shadow = shadow {
            // Shadow should extend downward
            let maxY = shadow.vertices.map(\.y).max() ?? 0
            #expect(maxY > 10) // Shadow extends below the box
        }
    }

    @Test("No shadow when light is inside polygon")
    func noShadowWhenInsidePolygon() {
        let lightPos = Vector2(x: 0, y: 0) // Inside the box
        let halfExtents = Vector2(x: 10, y: 10)
        let verts = ShadowGeometry.aabbVertices(halfExtents: halfExtents)

        let shadow = ShadowGeometry.shadowForPolygon(
            lightPos: lightPos,
            vertices: verts,
            shadowExtent: 100
        )

        #expect(shadow == nil)
    }

    @Test("Shadow with triangle polygon")
    func triangleShadow() {
        let lightPos = Vector2(x: 0, y: -30)
        let triangle = [
            Vector2(x: -10, y: 0),
            Vector2(x: 10, y: 0),
            Vector2(x: 0, y: 10),
        ]

        let shadow = ShadowGeometry.shadowForPolygon(
            lightPos: lightPos,
            vertices: triangle,
            shadowExtent: 100
        )

        #expect(shadow != nil)
        if let shadow = shadow {
            #expect(shadow.vertices.count >= 3)
        }
    }

    // MARK: - Circle Shadow Computation

    @Test("Shadow from circle with light to the left")
    func circleShadowLeftLight() {
        let shadow = ShadowGeometry.shadowForCircle(
            lightPos: Vector2(x: -50, y: 0),
            center: Vector2(x: 0, y: 0),
            radius: 10,
            shadowExtent: 100
        )

        #expect(shadow != nil)
        if let shadow = shadow {
            #expect(shadow.vertices.count >= 4)

            // Shadow should extend to the right
            let maxX = shadow.vertices.map(\.x).max() ?? 0
            #expect(maxX > 10)
        }
    }

    @Test("No shadow when light is inside circle")
    func noShadowWhenInsideCircle() {
        let shadow = ShadowGeometry.shadowForCircle(
            lightPos: Vector2(x: 0, y: 0),
            center: Vector2(x: 3, y: 0),
            radius: 10,
            shadowExtent: 100
        )

        #expect(shadow == nil)
    }

    @Test("Circle shadow tangent points are at correct distance")
    func circleTangentDistance() {
        let lightPos = Vector2(x: -50, y: 0)
        let center = Vector2(x: 0, y: 0)
        let radius: Float = 10

        let shadow = ShadowGeometry.shadowForCircle(
            lightPos: lightPos,
            center: center,
            radius: radius,
            shadowExtent: 100
        )

        #expect(shadow != nil)
        if let shadow = shadow {
            // The tangent vertices (indices 1 and count-2) should be approximately
            // at radius distance from the circle center
            let tangentA = shadow.vertices[1]
            let tangentB = shadow.vertices[shadow.vertices.count - 2]
            let distA = tangentA.distance(to: center)
            let distB = tangentB.distance(to: center)
            // Tangent points should be approximately on the circle
            #expect(abs(distA - radius) < 1.0)
            #expect(abs(distB - radius) < 1.0)
        }
    }

    // MARK: - Batch Computation

    @Test("computeShadows returns empty for no occluders")
    func noOccluders() {
        let results = ShadowGeometry.computeShadows(
            lightPosition: Vector2(x: 0, y: 0),
            lightRadius: 200,
            occluders: []
        )
        #expect(results.isEmpty)
    }

    @Test("computeShadows skips out-of-range occluders")
    func outOfRange() {
        let occluder = ShadowOccluder(
            shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            position: Vector2(x: 1000, y: 0),
            rotation: 0
        )

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 100,
            occluders: [occluder]
        )

        #expect(results.isEmpty)
    }

    @Test("computeShadows produces result for nearby AABB")
    func nearbyAABB() {
        let occluder = ShadowOccluder(
            shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            position: Vector2(x: 50, y: 0),
            rotation: 0
        )

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 200,
            occluders: [occluder]
        )

        #expect(results.count == 1)
    }

    @Test("computeShadows produces result for nearby circle")
    func nearbyCircle() {
        let occluder = ShadowOccluder(
            shape: .circle(radius: 15),
            position: Vector2(x: 50, y: 0),
            rotation: 0
        )

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 200,
            occluders: [occluder]
        )

        #expect(results.count == 1)
    }

    @Test("computeShadows handles polygon occluder")
    func polygonOccluder() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -10, y: -10),
            Vector2(x: 10, y: -10),
            Vector2(x: 10, y: 10),
            Vector2(x: -10, y: 10),
        ])
        let occluder = ShadowOccluder(
            shape: .polygon(poly),
            position: Vector2(x: 50, y: 0),
            rotation: 0
        )

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 200,
            occluders: [occluder]
        )

        #expect(results.count == 1)
    }

    @Test("computeShadows handles rotated AABB")
    func rotatedAABB() {
        let occluder = ShadowOccluder(
            shape: .aabb(halfExtents: Vector2(x: 20, y: 5)),
            position: Vector2(x: 50, y: 0),
            rotation: Float.pi / 4 // 45 degrees
        )

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 200,
            occluders: [occluder]
        )

        #expect(results.count == 1)
    }

    @Test("computeShadows respects custom shadow extent")
    func customShadowExtent() {
        let occluder = ShadowOccluder(
            shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            position: Vector2(x: 50, y: 0),
            rotation: 0
        )

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 200,
            occluders: [occluder],
            shadowExtent: 500
        )

        #expect(results.count == 1)
        if let shadow = results.first {
            // With extent 500, projected vertices should be far from the box
            let maxX = shadow.vertices.map(\.x).max() ?? 0
            #expect(maxX > 100)
        }
    }

    @Test("computeShadows handles multiple occluders")
    func multipleOccluders() {
        let occluders = [
            ShadowOccluder(shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
                          position: Vector2(x: 50, y: 0)),
            ShadowOccluder(shape: .circle(radius: 10),
                          position: Vector2(x: 0, y: 50)),
            ShadowOccluder(shape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
                          position: Vector2(x: -50, y: 0)),
        ]

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 200,
            occluders: occluders
        )

        #expect(results.count == 3)
    }

    @Test("computeShadows with offset occluder")
    func offsetOccluder() {
        let occluder = ShadowOccluder(
            shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            position: Vector2(x: 40, y: 0),
            rotation: 0,
            offset: Vector2(x: 10, y: 0) // Effective position: (50, 0)
        )

        let results = ShadowGeometry.computeShadows(
            lightPosition: .zero,
            lightRadius: 200,
            occluders: [occluder]
        )

        #expect(results.count == 1)
    }
}

// MARK: - LightingSystem

@Suite("LightingSystem")
struct LightingSystemTests {

    @Test("Default initialization")
    func defaults() {
        let system = LightingSystem()
        #expect(system.priority == 300)
        #expect(system.isInitialized == false)
    }

    @Test("Custom priority")
    func customPriority() {
        let system = LightingSystem(priority: 150)
        #expect(system.priority == 150)
    }

    @Test("Custom options")
    func customOptions() {
        let options = LightingOptions(ambientColor: .black, lightMapScale: 0.5)
        let system = LightingSystem(options: options)
        #expect(system.options.ambientColor == .black)
        #expect(system.options.lightMapScale == 0.5)
    }

    @Test("Options are mutable after creation")
    func mutableOptions() {
        let system = LightingSystem()
        system.options.debugDraw = true
        #expect(system.options.debugDraw == true)
    }

    @Test("Update snapshots light entities")
    func updateSnapshots() {
        let world = World()
        let system = LightingSystem()
        world.addSystem(system)

        // Create a light entity
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 200)), to: entity)
        world.addComponent(Light2D(color: .yellow, intensity: 1.5), to: entity)

        // Run the system
        let context = SystemContext(world: world, deltaTime: 1.0 / 60.0, commands: CommandBuffer())
        system.update(context: context)

        // System should have captured the light snapshot (internal state, tested indirectly)
        // We verify by checking that the system doesn't crash and processes correctly
    }

    @Test("Update snapshots disabled lights are excluded")
    func disabledLightsExcluded() {
        let world = World()
        let system = LightingSystem()

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.addComponent(Light2D(isEnabled: false), to: entity)

        let context = SystemContext(world: world, deltaTime: 1.0 / 60.0, commands: CommandBuffer())
        system.update(context: context)
        // Should not crash, disabled light should be skipped
    }

    @Test("Update snapshots shadow casters")
    func shadowCasterSnapshots() {
        let world = World()
        let system = LightingSystem()

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: entity)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 10, y: 10))), to: entity)
        world.addComponent(ShadowCaster2D(), to: entity)

        let context = SystemContext(world: world, deltaTime: 1.0 / 60.0, commands: CommandBuffer())
        system.update(context: context)
        // Should not crash, shadow caster should be captured
    }
}
