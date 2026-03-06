import Testing
@testable import Agilis

// MARK: - Ray Intersection Tests

@Suite("Ray Intersection Tests")
struct RayIntersectionTests {

    @Test("Ray hits AABB front face")
    func rayHitsAABBFrontFace() {
        // Ray from left, hitting right-facing side of AABB at (50, 50) with half (10, 10)
        let hit = SpatialQuery.rayVsAABB(
            origin: Vector2(x: 0, y: 50),
            direction: Vector2(x: 1, y: 0),
            tMax: 100,
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )

        #expect(hit != nil)
        #expect(abs(hit!.distance - 40) < 0.01) // hits at x=40 (50-10)
        #expect(abs(hit!.point.x - 40) < 0.01)
        #expect(abs(hit!.point.y - 50) < 0.01)
        #expect(hit!.normal.x < 0) // normal points left (toward ray origin)
    }

    @Test("Ray misses AABB")
    func rayMissesAABB() {
        // Ray passes above the AABB
        let hit = SpatialQuery.rayVsAABB(
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0),
            tMax: 200,
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(hit == nil)
    }

    @Test("Ray origin inside AABB returns distance 0")
    func rayOriginInsideAABB() {
        let hit = SpatialQuery.rayVsAABB(
            origin: Vector2(x: 50, y: 50),
            direction: Vector2(x: 1, y: 0),
            tMax: 100,
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )

        #expect(hit != nil)
        #expect(hit!.distance == 0)
        #expect(hit!.point == Vector2(x: 50, y: 50))
    }

    @Test("Ray hits circle")
    func rayHitsCircle() {
        let hit = SpatialQuery.rayVsCircle(
            origin: Vector2(x: 0, y: 50),
            direction: Vector2(x: 1, y: 0),
            tMax: 200,
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )

        #expect(hit != nil)
        #expect(abs(hit!.distance - 40) < 0.01) // hits at x=40 (50-10)
        #expect(abs(hit!.point.x - 40) < 0.01)
        // Normal should point toward ray origin (left)
        #expect(hit!.normal.x < 0)
        #expect(abs(hit!.normal.y) < 0.01)
    }

    @Test("Ray misses circle")
    func rayMissesCircle() {
        // Ray passes above the circle
        let hit = SpatialQuery.rayVsCircle(
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0),
            tMax: 200,
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )
        #expect(hit == nil)
    }

    @Test("Ray origin inside circle returns distance 0")
    func rayOriginInsideCircle() {
        let hit = SpatialQuery.rayVsCircle(
            origin: Vector2(x: 50, y: 50),
            direction: Vector2(x: 1, y: 0),
            tMax: 100,
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )

        #expect(hit != nil)
        #expect(hit!.distance == 0)
    }

    @Test("Ray hits convex polygon")
    func rayHitsPolygon() {
        // Triangle at (50, 50) pointing right
        let vertices: [Vector2] = [
            Vector2(x: 40, y: 40),
            Vector2(x: 40, y: 60),
            Vector2(x: 60, y: 50)
        ]

        let hit = SpatialQuery.rayVsPolygon(
            origin: Vector2(x: 0, y: 50),
            direction: Vector2(x: 1, y: 0),
            tMax: 200,
            vertices: vertices
        )

        #expect(hit != nil)
        #expect(abs(hit!.point.x - 40) < 0.01) // hits left edge at x=40
        #expect(hit!.distance > 0)
    }

    @Test("Ray maxDistance cuts short")
    func rayMaxDistanceCutsShort() {
        // Ray would hit AABB at distance 40, but maxDistance is 30
        let hit = SpatialQuery.rayVsAABB(
            origin: Vector2(x: 0, y: 50),
            direction: Vector2(x: 1, y: 0),
            tMax: 30,
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(hit == nil)
    }
}

// MARK: - Point Query Tests

@Suite("Point Query Tests")
struct PointQueryTests {

    @Test("Point inside AABB")
    func pointInsideAABB() {
        let inside = SpatialQuery.pointInAABB(
            point: Vector2(x: 52, y: 48),
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(inside == true)
    }

    @Test("Point outside AABB")
    func pointOutsideAABB() {
        let inside = SpatialQuery.pointInAABB(
            point: Vector2(x: 100, y: 50),
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(inside == false)
    }

    @Test("Point inside circle")
    func pointInsideCircle() {
        let inside = SpatialQuery.pointInCircle(
            point: Vector2(x: 52, y: 50),
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )
        #expect(inside == true)
    }

    @Test("Point outside circle")
    func pointOutsideCircle() {
        let inside = SpatialQuery.pointInCircle(
            point: Vector2(x: 100, y: 50),
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )
        #expect(inside == false)
    }

    @Test("Point inside and outside convex polygon")
    func pointInPolygon() {
        // Square polygon centered at (50, 50) with side length 20
        let vertices: [Vector2] = [
            Vector2(x: 40, y: 40),
            Vector2(x: 40, y: 60),
            Vector2(x: 60, y: 60),
            Vector2(x: 60, y: 40)
        ]

        let inside = SpatialQuery.pointInPolygon(
            point: Vector2(x: 50, y: 50),
            vertices: vertices
        )
        #expect(inside == true)

        let outside = SpatialQuery.pointInPolygon(
            point: Vector2(x: 100, y: 100),
            vertices: vertices
        )
        #expect(outside == false)
    }
}

// MARK: - Area Query Tests

@Suite("Area Query Tests")
struct AreaQueryTests {

    @Test("Rect overlaps AABB")
    func rectOverlapsAABB() {
        let overlaps = SpatialQuery.rectOverlapsAABB(
            rect: Rect(x: 45, y: 45, width: 20, height: 20),
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(overlaps == true)
    }

    @Test("Rect does not overlap AABB")
    func rectDoesNotOverlapAABB() {
        let overlaps = SpatialQuery.rectOverlapsAABB(
            rect: Rect(x: 100, y: 100, width: 20, height: 20),
            aabbPos: Vector2(x: 50, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(overlaps == false)
    }

    @Test("Rect overlaps circle")
    func rectOverlapsCircle() {
        let overlaps = SpatialQuery.rectOverlapsCircle(
            rect: Rect(x: 55, y: 45, width: 20, height: 20),
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )
        #expect(overlaps == true)
    }

    @Test("Rect does not overlap circle")
    func rectDoesNotOverlapCircle() {
        let overlaps = SpatialQuery.rectOverlapsCircle(
            rect: Rect(x: 100, y: 100, width: 10, height: 10),
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )
        #expect(overlaps == false)
    }

    @Test("Rect overlaps convex polygon")
    func rectOverlapsPolygon() {
        // Triangle
        let vertices: [Vector2] = [
            Vector2(x: 40, y: 40),
            Vector2(x: 40, y: 60),
            Vector2(x: 60, y: 50)
        ]
        var normals: [Vector2] = []
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let edge = vertices[j] - vertices[i]
            normals.append(Vector2(x: edge.y, y: -edge.x).normalized)
        }

        let overlaps = SpatialQuery.rectOverlapsPolygon(
            rect: Rect(x: 35, y: 45, width: 20, height: 10),
            vertices: vertices, normals: normals
        )
        #expect(overlaps == true)

        // Far away rect
        let noOverlap = SpatialQuery.rectOverlapsPolygon(
            rect: Rect(x: 200, y: 200, width: 10, height: 10),
            vertices: vertices, normals: normals
        )
        #expect(noOverlap == false)
    }
}

// MARK: - PhysicsWorld2D Query Integration Tests

@Suite("PhysicsWorld2D Query Tests")
struct PhysicsWorldQueryTests {

    // MARK: - Helpers

    private func makeWorld(
        entities: [(pos: Vector2, shape: CollisionShape, layer: UInt32, offset: Vector2, rotation: Float)]
    ) -> (World, PhysicsWorld2D) {
        let world = World()
        let physics = PhysicsWorld2D(gravity: .zero, cellSize: 128)
        world.addSystem(physics)

        for config in entities {
            let e = world.createEntity()
            world.addComponent(Transform2D(position: config.pos, rotation: config.rotation), to: e)
            world.addComponent(Collider2D(
                shape: config.shape,
                offset: config.offset,
                layer: config.layer,
                mask: 0xFFFF_FFFF
            ), to: e)
        }

        return (world, physics)
    }

    private func makeSimpleWorld(
        entities: [(pos: Vector2, shape: CollisionShape)]
    ) -> (World, PhysicsWorld2D) {
        makeWorld(entities: entities.map { ($0.pos, $0.shape, 0xFFFF_FFFF, .zero, 0) })
    }

    // MARK: - Raycast Tests

    @Test("Raycast hits closest entity")
    func raycastHitsClosest() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5))),
            (pos: Vector2(x: 100, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)))
        ])

        let hit = physics.raycast(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0)
        )

        #expect(hit != nil)
        #expect(abs(hit!.distance - 45) < 0.01) // 50 - 5 = 45
        #expect(abs(hit!.point.x - 45) < 0.01)
    }

    @Test("Raycast returns nil when no hit")
    func raycastReturnsNil() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)))
        ])

        let hit = physics.raycast(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0) // misses - entity at y=50
        )

        #expect(hit == nil)
    }

    @Test("Raycast respects layerMask")
    func raycastRespectsLayerMask() {
        let (world, physics) = makeWorld(entities: [
            (pos: Vector2(x: 50, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
             layer: 0x0002, offset: .zero, rotation: 0),
            (pos: Vector2(x: 100, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
             layer: 0x0001, offset: .zero, rotation: 0)
        ])

        // Only query layer 0x0001 — should skip the first entity at x=50
        let hit = physics.raycast(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0),
            layerMask: 0x0001
        )

        #expect(hit != nil)
        #expect(abs(hit!.distance - 95) < 0.01) // 100 - 5 = 95
    }

    @Test("RaycastAll returns multiple hits sorted by distance")
    func raycastAllSorted() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 100, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5))),
            (pos: Vector2(x: 50, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)))
        ])

        let hits = physics.raycastAll(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0)
        )

        #expect(hits.count == 2)
        #expect(hits[0].distance < hits[1].distance)
        #expect(abs(hits[0].distance - 45) < 0.01)
        #expect(abs(hits[1].distance - 95) < 0.01)
    }

    @Test("Raycast handles collider offset")
    func raycastHandlesOffset() {
        let (world, physics) = makeWorld(entities: [
            (pos: Vector2(x: 50, y: 0),
             shape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
             layer: 0xFFFF_FFFF,
             offset: Vector2(x: 10, y: 0), // effective position = (60, 0)
             rotation: 0)
        ])

        let hit = physics.raycast(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0)
        )

        #expect(hit != nil)
        #expect(abs(hit!.distance - 55) < 0.01) // 60 - 5 = 55
    }

    @Test("Raycast handles rotated entity")
    func raycastHandlesRotation() {
        // A thin AABB (20x2) rotated 90 degrees becomes 2x20
        let (world, physics) = makeWorld(entities: [
            (pos: Vector2(x: 50, y: 0),
             shape: .aabb(halfExtents: Vector2(x: 10, y: 1)),
             layer: 0xFFFF_FFFF,
             offset: .zero,
             rotation: Float.pi / 2) // 90 degrees
        ])

        // Ray along y=0 should hit the rotated shape
        let hit = physics.raycast(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0)
        )

        #expect(hit != nil)
        // After 90° rotation, halfExtents (10,1) becomes effectively (1,10)
        #expect(abs(hit!.point.x - 49) < 0.5)
    }

    @Test("Raycast with circle collider")
    func raycastWithCircle() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 0), shape: .circle(radius: 10))
        ])

        let hit = physics.raycast(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0)
        )

        #expect(hit != nil)
        #expect(abs(hit!.distance - 40) < 0.01) // 50 - 10 = 40
    }

    @Test("Raycast maxDistance filters far entities")
    func raycastMaxDistance() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 100, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)))
        ])

        let hit = physics.raycast(
            world: world,
            origin: Vector2(x: 0, y: 0),
            direction: Vector2(x: 1, y: 0),
            maxDistance: 50 // entity starts at 95, too far
        )

        #expect(hit == nil)
    }

    // MARK: - Point Query Tests

    @Test("Point query finds overlapping entities")
    func pointQueryFindsEntities() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 20, y: 20))),
            (pos: Vector2(x: 55, y: 50), shape: .circle(radius: 15))
        ])

        let results = physics.pointQuery(
            world: world,
            point: Vector2(x: 50, y: 50)
        )

        #expect(results.count == 2)
    }

    @Test("Point query returns empty when no match")
    func pointQueryEmpty() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)))
        ])

        let results = physics.pointQuery(
            world: world,
            point: Vector2(x: 200, y: 200)
        )

        #expect(results.isEmpty)
    }

    @Test("Point query respects layerMask")
    func pointQueryLayerMask() {
        let (world, physics) = makeWorld(entities: [
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 20, y: 20)),
             layer: 0x0001, offset: .zero, rotation: 0),
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 20, y: 20)),
             layer: 0x0002, offset: .zero, rotation: 0)
        ])

        let results = physics.pointQuery(
            world: world,
            point: Vector2(x: 50, y: 50),
            layerMask: 0x0001
        )

        #expect(results.count == 1)
    }

    // MARK: - Area Query Tests

    @Test("Area query finds overlapping entities")
    func areaQueryFindsEntities() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 10, y: 10))),
            (pos: Vector2(x: 200, y: 200), shape: .aabb(halfExtents: Vector2(x: 10, y: 10)))
        ])

        let results = physics.areaQuery(
            world: world,
            rect: Rect(x: 40, y: 40, width: 30, height: 30)
        )

        #expect(results.count == 1)
    }

    @Test("Area query returns empty when no overlap")
    func areaQueryEmpty() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)))
        ])

        let results = physics.areaQuery(
            world: world,
            rect: Rect(x: 200, y: 200, width: 10, height: 10)
        )

        #expect(results.isEmpty)
    }

    @Test("Area query respects layerMask")
    func areaQueryLayerMask() {
        let (world, physics) = makeWorld(entities: [
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
             layer: 0x0001, offset: .zero, rotation: 0),
            (pos: Vector2(x: 50, y: 50), shape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
             layer: 0x0002, offset: .zero, rotation: 0)
        ])

        let results = physics.areaQuery(
            world: world,
            rect: Rect(x: 40, y: 40, width: 30, height: 30),
            layerMask: 0x0002
        )

        #expect(results.count == 1)
    }

    // MARK: - Edge Cases

    @Test("Query on empty world returns nil/empty")
    func queryEmptyWorld() {
        let world = World()
        let physics = PhysicsWorld2D(gravity: .zero, cellSize: 128)
        world.addSystem(physics)

        let rayHit = physics.raycast(
            world: world,
            origin: .zero,
            direction: Vector2(x: 1, y: 0)
        )
        #expect(rayHit == nil)

        let points = physics.pointQuery(world: world, point: .zero)
        #expect(points.isEmpty)

        let areas = physics.areaQuery(world: world, rect: Rect(x: 0, y: 0, width: 100, height: 100))
        #expect(areas.isEmpty)
    }

    @Test("Raycast with zero direction returns nil")
    func raycastZeroDirection() {
        let (world, physics) = makeSimpleWorld(entities: [
            (pos: Vector2(x: 50, y: 0), shape: .aabb(halfExtents: Vector2(x: 5, y: 5)))
        ])

        let hit = physics.raycast(
            world: world,
            origin: .zero,
            direction: .zero
        )

        #expect(hit == nil)
    }
}
