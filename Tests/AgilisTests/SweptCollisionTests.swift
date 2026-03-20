@testable import Agilis
import Testing

// MARK: - Helper Tests

@Suite("SweptCollision Helper Tests")
struct SweptCollisionHelperTests {

    @Test("minimumExtent of circle returns radius")
    func minimumExtentCircle() {
        let extent = SweptCollision.minimumExtent(of: .circle(radius: 8))
        #expect(abs(extent - 8) < 0.001)
    }

    @Test("minimumExtent of AABB returns smaller half-extent")
    func minimumExtentAABB() {
        let extent = SweptCollision.minimumExtent(of: .aabb(halfExtents: Vector2(x: 20, y: 5)))
        #expect(abs(extent - 5) < 0.001)
    }

    @Test("minimumExtent of polygon uses local bounds")
    func minimumExtentPolygon() {
        // Square polygon: local bounds should be roughly equal in both dimensions
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -10, y: -10), Vector2(x: 10, y: -10),
            Vector2(x: 10, y: 10), Vector2(x: -10, y: 10)
        ])
        let extent = SweptCollision.minimumExtent(of: .polygon(poly))
        #expect(abs(extent - 10) < 0.1)
    }

    @Test("boundingRadius of circle returns radius")
    func boundingRadiusCircle() {
        let r = SweptCollision.boundingRadius(of: .circle(radius: 12))
        #expect(abs(r - 12) < 0.001)
    }

    @Test("boundingRadius of AABB returns diagonal half-length")
    func boundingRadiusAABB() {
        // half-extents (3, 4) -> radius = sqrt(9+16) = 5
        let r = SweptCollision.boundingRadius(of: .aabb(halfExtents: Vector2(x: 3, y: 4)))
        #expect(abs(r - 5) < 0.001)
    }

    @Test("boundingRadius of polygon returns max vertex distance")
    func boundingRadiusPolygon() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -5, y: 0), Vector2(x: 5, y: 0),
            Vector2(x: 0, y: 12)
        ])
        let r = SweptCollision.boundingRadius(of: .polygon(poly))
        #expect(abs(r - 12) < 0.001)
    }
}

// MARK: - Swept Circle vs Circle

@Suite("Swept Circle vs Circle Tests")
struct SweptCircleVsCircleTests {

    @Test("Head-on collision returns correct TOI")
    func headOnCollision() throws {
        // Circle radius 5 at (0, 50) sweeps to (100, 50) toward static circle radius 5 at (80, 50)
        // Contact when centers are 10 apart (5+5), so at x=70 -> TOI = 70/100 = 0.7
        let toi = try #require(SweptCollision.sweptCircleVsCircle(
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            radiusA: 5,
            circlePos: Vector2(x: 80, y: 50),
            radiusB: 5
        ))
        #expect(abs(toi - 0.7) < 0.01)
    }

    @Test("Miss returns nil")
    func missReturnsNil() {
        // Circle sweeps parallel to static circle, not close enough
        let toi = SweptCollision.sweptCircleVsCircle(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            radiusA: 5,
            circlePos: Vector2(x: 50, y: 20),
            radiusB: 5
        )
        #expect(toi == nil)
    }

    @Test("Already overlapping returns nil")
    func alreadyOverlapping() {
        // Start position overlaps the static circle
        let toi = SweptCollision.sweptCircleVsCircle(
            startPos: Vector2(x: 50, y: 50),
            endPos: Vector2(x: 100, y: 50),
            radiusA: 10,
            circlePos: Vector2(x: 55, y: 50),
            radiusB: 10
        )
        #expect(toi == nil)
    }

    @Test("Tangent/graze contact")
    func tangentGraze() throws {
        // Circle radius 5 at y=0 sweeps right, static circle radius 5 at y=10
        // Combined radius = 10, gap = 10 -> should just barely touch (tangent)
        let toi = try #require(SweptCollision.sweptCircleVsCircle(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 200, y: 0),
            radiusA: 5,
            circlePos: Vector2(x: 100, y: 10),
            radiusB: 5
        ))
        // Should hit (tangent or very close to it)
        #expect(toi > 0 && toi < 1)
    }

    @Test("Zero displacement returns nil")
    func zeroDisplacement() {
        let toi = SweptCollision.sweptCircleVsCircle(
            startPos: Vector2(x: 50, y: 50),
            endPos: Vector2(x: 50, y: 50),
            radiusA: 5,
            circlePos: Vector2(x: 80, y: 50),
            radiusB: 5
        )
        #expect(toi == nil)
    }
}

// MARK: - Swept Circle vs AABB

@Suite("Swept Circle vs AABB Tests")
struct SweptCircleVsAABBTests {

    @Test("Circle hits AABB face")
    func circleHitsAABBFace() throws {
        // Circle radius 5 sweeps from (0, 50) to (100, 50), AABB at (80, 50) half-extents (10, 20)
        // Expanded AABB left face = 80 - 10 - 5 = 65 -> TOI ~ 65/100
        let toi = try #require(SweptCollision.sweptCircleVsAABB(
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            radius: 5,
            aabbPos: Vector2(x: 80, y: 50),
            halfExtents: Vector2(x: 10, y: 20)
        ))
        #expect(abs(toi - 0.65) < 0.02)
    }

    @Test("Circle misses AABB")
    func circleMissesAABB() {
        // Circle sweeps far above AABB
        let toi = SweptCollision.sweptCircleVsAABB(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 200, y: 0),
            radius: 5,
            aabbPos: Vector2(x: 100, y: 100),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(toi == nil)
    }

    @Test("Circle hits AABB corner region")
    func circleHitsAABBCorner() throws {
        // Circle radius 5 sweeps diagonally toward a corner
        let toi = try #require(SweptCollision.sweptCircleVsAABB(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 100),
            radius: 5,
            aabbPos: Vector2(x: 70, y: 70),
            halfExtents: Vector2(x: 5, y: 5)
        ))
        #expect(toi > 0 && toi < 1)
    }

    @Test("Already overlapping returns nil")
    func alreadyOverlapping() {
        let toi = SweptCollision.sweptCircleVsAABB(
            startPos: Vector2(x: 80, y: 50),
            endPos: Vector2(x: 120, y: 50),
            radius: 15,
            aabbPos: Vector2(x: 80, y: 50),
            halfExtents: Vector2(x: 10, y: 10)
        )
        #expect(toi == nil)
    }
}

// MARK: - Swept Circle vs Polygon

@Suite("Swept Circle vs Polygon Tests")
struct SweptCircleVsPolygonTests {

    @Test("Circle hits polygon edge")
    func circleHitsPolygonEdge() throws {
        // Rectangle wall at x=80. Circle radius 5 sweeps from left to right.
        // Use a rectangle polygon (CW in screen coords = CCW in math coords)
        // so outward normals are correctly computed.
        let vertices = [
            Vector2(x: 75, y: -50), Vector2(x: 85, y: -50),
            Vector2(x: 85, y: 50), Vector2(x: 75, y: 50)
        ]
        let toi = try #require(SweptCollision.sweptCircleVsPolygon(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            radius: 5,
            vertices: vertices
        ))
        #expect(toi > 0 && toi < 1)
        // Circle should hit the left face or vertex circles at roughly x=70 (75-5) -> TOI ~ 0.70
        #expect(abs(toi - 0.70) < 0.1)
    }

    @Test("Circle hits polygon vertex")
    func circleHitsPolygonVertex() throws {
        // Circle sweeps toward a vertex
        let vertices = [
            Vector2(x: 50, y: 45), Vector2(x: 60, y: 50),
            Vector2(x: 50, y: 55)
        ]
        let toi = try #require(SweptCollision.sweptCircleVsPolygon(
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            radius: 3,
            vertices: vertices
        ))
        #expect(toi > 0 && toi < 1)
    }

    @Test("Circle misses polygon")
    func circleMissesPolygon() {
        let vertices = [
            Vector2(x: 50, y: 100), Vector2(x: 60, y: 100),
            Vector2(x: 55, y: 110)
        ]
        let toi = SweptCollision.sweptCircleVsPolygon(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            radius: 5,
            vertices: vertices
        )
        #expect(toi == nil)
    }
}

// MARK: - Swept AABB vs AABB

@Suite("Swept AABB vs AABB Tests")
struct SweptAABBvsAABBTests {

    @Test("AABB hits static AABB")
    func aabbHitsStaticAABB() throws {
        // Moving AABB half (5,5) sweeps from (0,50) to (100,50)
        // Static AABB half (10,20) at (80,50)
        // Minkowski expanded half = (15, 25)
        // Left face of expanded = 80 - 15 = 65 -> TOI = 65/100
        let toi = try #require(SweptCollision.sweptAABBvsAABB(
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            halfA: Vector2(x: 5, y: 5),
            aabbPos: Vector2(x: 80, y: 50),
            halfB: Vector2(x: 10, y: 20)
        ))
        #expect(abs(toi - 0.65) < 0.02)
    }

    @Test("AABB misses static AABB")
    func aabbMissesStaticAABB() {
        let toi = SweptCollision.sweptAABBvsAABB(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            halfA: Vector2(x: 5, y: 5),
            aabbPos: Vector2(x: 50, y: 100),
            halfB: Vector2(x: 10, y: 10)
        )
        #expect(toi == nil)
    }

    @Test("Already overlapping returns nil")
    func alreadyOverlapping() {
        let toi = SweptCollision.sweptAABBvsAABB(
            startPos: Vector2(x: 50, y: 50),
            endPos: Vector2(x: 100, y: 50),
            halfA: Vector2(x: 10, y: 10),
            aabbPos: Vector2(x: 55, y: 50),
            halfB: Vector2(x: 10, y: 10)
        )
        #expect(toi == nil)
    }

    @Test("TOI accuracy for known geometry")
    func toiAccuracy() throws {
        // Moving half (2,2) from x=0 to x=50, static half (3,3) at x=30
        // Expanded half-x = 2+3 = 5, left edge = 30-5 = 25 -> TOI = 25/50 = 0.5
        let toi = try #require(SweptCollision.sweptAABBvsAABB(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 50, y: 0),
            halfA: Vector2(x: 2, y: 2),
            aabbPos: Vector2(x: 30, y: 0),
            halfB: Vector2(x: 3, y: 3)
        ))
        #expect(abs(toi - 0.5) < 0.01)
    }
}

// MARK: - Swept AABB vs Circle

@Suite("Swept AABB vs Circle Tests")
struct SweptAABBvsCircleTests {

    @Test("AABB hits static circle")
    func aabbHitsCircle() throws {
        // AABB half (5,5) sweeps from (0,50) to (100,50), circle radius 10 at (80,50)
        // Expanded AABB half = (5+10, 5+10) = (15, 15) at circlePos
        // Left face = 80 - 15 = 65 -> TOI ~ 65/100
        let toi = try #require(SweptCollision.sweptAABBvsCircle(
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            halfExtents: Vector2(x: 5, y: 5),
            circlePos: Vector2(x: 80, y: 50),
            radius: 10
        ))
        #expect(abs(toi - 0.65) < 0.02)
    }

    @Test("AABB misses static circle")
    func aabbMissesCircle() {
        let toi = SweptCollision.sweptAABBvsCircle(
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            halfExtents: Vector2(x: 5, y: 5),
            circlePos: Vector2(x: 50, y: 50),
            radius: 10
        )
        #expect(toi == nil)
    }
}

// MARK: - Dispatcher Tests

@Suite("SweptCollision Dispatcher Tests")
struct SweptCollisionDispatcherTests {

    @Test("Dispatcher handles circle vs circle")
    func dispatcherCircleVsCircle() throws {
        let toi = try #require(SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            movingRot: 0,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 50),
            staticRot: 0
        ))
        #expect(abs(toi - 0.7) < 0.01)
    }

    @Test("Dispatcher handles circle vs AABB")
    func dispatcherCircleVsAABB() {
        let toi = SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            movingRot: 0,
            staticShape: .aabb(halfExtents: Vector2(x: 10, y: 20)),
            staticPos: Vector2(x: 80, y: 50),
            staticRot: 0
        )
        #expect(toi != nil)
    }

    @Test("Dispatcher handles circle vs polygon")
    func dispatcherCircleVsPolygon() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -10, y: -10), Vector2(x: 10, y: -10),
            Vector2(x: 10, y: 10), Vector2(x: -10, y: 10)
        ])
        let toi = SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            movingRot: 0,
            staticShape: .polygon(poly),
            staticPos: Vector2(x: 80, y: 0),
            staticRot: 0
        )
        #expect(toi != nil)
    }

    @Test("Dispatcher handles AABB vs AABB")
    func dispatcherAABBvsAABB() {
        let toi = SweptCollision.timeOfImpact(
            movingShape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            movingRot: 0,
            staticShape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            staticPos: Vector2(x: 80, y: 0),
            staticRot: 0
        )
        #expect(toi != nil)
    }

    @Test("Dispatcher handles AABB vs circle")
    func dispatcherAABBvsCircle() {
        let toi = SweptCollision.timeOfImpact(
            movingShape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            movingRot: 0,
            staticShape: .circle(radius: 10),
            staticPos: Vector2(x: 80, y: 50),
            staticRot: 0
        )
        #expect(toi != nil)
    }

    @Test("Dispatcher handles polygon vs AABB (conservative)")
    func dispatcherPolygonVsAABB() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -5, y: -5), Vector2(x: 5, y: -5),
            Vector2(x: 5, y: 5), Vector2(x: -5, y: 5)
        ])
        let toi = SweptCollision.timeOfImpact(
            movingShape: .polygon(poly),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            movingRot: 0,
            staticShape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            staticPos: Vector2(x: 80, y: 0),
            staticRot: 0
        )
        #expect(toi != nil)
        // Conservative: TOI may be slightly early but must not be nil for a clear hit
    }

    @Test("Dispatcher handles rotated AABB vs AABB (conservative)")
    func dispatcherRotatedAABBvsAABB() {
        let toi = SweptCollision.timeOfImpact(
            movingShape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            movingRot: 0.5, // rotated
            staticShape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            staticPos: Vector2(x: 80, y: 0),
            staticRot: 0
        )
        #expect(toi != nil)
    }

    @Test("Dispatcher returns nil for clear miss")
    func dispatcherMiss() {
        let toi = SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            movingRot: 0,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 50, y: 100),
            staticRot: 0
        )
        #expect(toi == nil)
    }
}

// MARK: - Angular Sweep Tests

@Suite("SweptCollision Angular Sweep Tests")
struct SweptCollisionAngularSweepTests {

    // MARK: - angularSweepExtent

    @Test("angularSweepExtent of circle is always zero")
    func angularExtentCircle() {
        let extent = SweptCollision.angularSweepExtent(
            of: .circle(radius: 10),
            angularDisplacement: 3.14
        )
        #expect(extent == 0)
    }

    @Test("angularSweepExtent of AABB is boundingRadius times angle")
    func angularExtentAABB() {
        // halfExtents (3,4) -> boundingRadius = 5
        let extent = SweptCollision.angularSweepExtent(
            of: .aabb(halfExtents: Vector2(x: 3, y: 4)),
            angularDisplacement: 1.0
        )
        #expect(abs(extent - 5.0) < 0.001)
    }

    @Test("angularSweepExtent of polygon uses bounding radius")
    func angularExtentPolygon() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -5, y: 0), Vector2(x: 5, y: 0), Vector2(x: 0, y: 12)
        ])
        // boundingRadius = 12 -> extent = 12 * 0.5 = 6
        let extent = SweptCollision.angularSweepExtent(
            of: .polygon(poly),
            angularDisplacement: 0.5
        )
        #expect(abs(extent - 6.0) < 0.001)
    }

    @Test("angularSweepExtent with zero angle returns zero")
    func angularExtentZeroAngle() {
        let extent = SweptCollision.angularSweepExtent(
            of: .aabb(halfExtents: Vector2(x: 50, y: 2)),
            angularDisplacement: 0
        )
        #expect(extent == 0)
    }

    @Test("angularSweepExtent with negative angle uses absolute value")
    func angularExtentNegativeAngle() {
        let positive = SweptCollision.angularSweepExtent(
            of: .aabb(halfExtents: Vector2(x: 3, y: 4)),
            angularDisplacement: 1.0
        )
        let negative = SweptCollision.angularSweepExtent(
            of: .aabb(halfExtents: Vector2(x: 3, y: 4)),
            angularDisplacement: -1.0
        )
        #expect(positive == negative)
    }

    // MARK: - timeOfImpact with start/end rotation

    @Test("New overload with zero angular displacement matches original")
    func zeroAngularDelegates() {
        let toiOld = SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            movingRot: 0,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 50),
            staticRot: 0
        )
        let toiNew = SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            startRot: 0,
            endRot: 0,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 50),
            staticRot: 0
        )
        #expect(toiOld == toiNew)
    }

    @Test("Rotating circle uses exact path (not bounding circle)")
    func rotatingCircleExact() {
        // Circle rotation should have no effect — same TOI with or without rotation
        let toiNoRot = SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            startRot: 0,
            endRot: 0,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 50),
            staticRot: 0
        )
        let toiWithRot = SweptCollision.timeOfImpact(
            movingShape: .circle(radius: 5),
            startPos: Vector2(x: 0, y: 50),
            endPos: Vector2(x: 100, y: 50),
            startRot: 0,
            endRot: 6.28,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 50),
            staticRot: 0
        )
        #expect(toiNoRot == toiWithRot)
    }

    @Test("Rotating AABB uses conservative bounding circle (detects wider area)")
    func rotatingAABBConservative() {
        // Thin rod (50,2) with rotation: bounding circle radius ~50
        // Should detect collision with wider radius than the thin dimension
        // Circle at y=40 is within bounding radius (50) but outside AABB height (2)
        let toi = SweptCollision.timeOfImpact(
            movingShape: .aabb(halfExtents: Vector2(x: 50, y: 2)),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            startRot: 0,
            endRot: 1.0,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 40),
            staticRot: 0
        )
        // With bounding circle ~50, should hit the circle at y=40
        #expect(toi != nil, "Rotating AABB should detect collision via bounding circle")
    }

    @Test("Non-rotating AABB uses exact path (narrower hit area)")
    func nonRotatingAABBExact() {
        // Same geometry but no rotation — should miss (AABB is only 4 units tall)
        let toi = SweptCollision.timeOfImpact(
            movingShape: .aabb(halfExtents: Vector2(x: 50, y: 2)),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            startRot: 0,
            endRot: 0,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 40),
            staticRot: 0
        )
        // Without rotation, AABB is only 4px tall at y=0, circle at y=40 is too far
        #expect(toi == nil, "Non-rotating AABB should miss distant circle")
    }

    @Test("Non-rotating AABB overload matches original dispatcher")
    func nonRotatingAABBMatchesOriginal() {
        // Ensure the new overload with zero rotation produces the same result
        let toiOld = SweptCollision.timeOfImpact(
            movingShape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            movingRot: 0,
            staticShape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            staticPos: Vector2(x: 80, y: 0),
            staticRot: 0
        )
        let toiNew = SweptCollision.timeOfImpact(
            movingShape: .aabb(halfExtents: Vector2(x: 5, y: 5)),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            startRot: 0,
            endRot: 0,
            staticShape: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            staticPos: Vector2(x: 80, y: 0),
            staticRot: 0
        )
        #expect(toiOld == toiNew)
    }

    @Test("Rotating polygon uses conservative bounding circle")
    func rotatingPolygonConservative() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -30, y: -2), Vector2(x: 30, y: -2),
            Vector2(x: 30, y: 2), Vector2(x: -30, y: 2)
        ])
        // Bounding radius ~30, so should hit a circle at y=20
        let toi = SweptCollision.timeOfImpact(
            movingShape: .polygon(poly),
            startPos: Vector2(x: 0, y: 0),
            endPos: Vector2(x: 100, y: 0),
            startRot: 0,
            endRot: 0.5,
            staticShape: .circle(radius: 5),
            staticPos: Vector2(x: 80, y: 20),
            staticRot: 0
        )
        #expect(toi != nil, "Rotating polygon should detect collision via bounding circle")
    }
}
