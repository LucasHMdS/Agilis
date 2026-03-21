@testable import Agilis
import Testing

@Suite("Narrow Phase Tests")
struct NarrowPhaseTests {

    // MARK: - AABB vs AABB

    @Test("AABB vs AABB: overlapping boxes")
    func aabbOverlap() throws {
        let contact = try #require(NarrowPhase.testAABBvsAABB(
            posA: Vector2(x: 0, y: 0),
            halfA: Vector2(x: 10, y: 10),
            posB: Vector2(x: 15, y: 0),
            halfB: Vector2(x: 10, y: 10)
        ))
        #expect(abs(contact.penetration - 5) < 0.01)
        #expect(contact.normal.x > 0) // Points from A to B (rightward)
    }

    @Test("AABB vs AABB: separated boxes")
    func aabbSeparated() {
        let contact = NarrowPhase.testAABBvsAABB(
            posA: Vector2(x: 0, y: 0),
            halfA: Vector2(x: 10, y: 10),
            posB: Vector2(x: 25, y: 0),
            halfB: Vector2(x: 10, y: 10)
        )
        #expect(contact == nil)
    }

    @Test("AABB vs AABB: touching edge returns nil")
    func aabbTouching() {
        let contact = NarrowPhase.testAABBvsAABB(
            posA: Vector2(x: 0, y: 0),
            halfA: Vector2(x: 10, y: 10),
            posB: Vector2(x: 20, y: 0),
            halfB: Vector2(x: 10, y: 10)
        )
        #expect(contact == nil)
    }

    @Test("AABB vs AABB: nested (one inside the other)")
    func aabbNested() throws {
        let contact = try #require(NarrowPhase.testAABBvsAABB(
            posA: Vector2(x: 0, y: 0),
            halfA: Vector2(x: 20, y: 20),
            posB: Vector2(x: 5, y: 5),
            halfB: Vector2(x: 5, y: 5)
        ))
        // Should find the minimum penetration axis
        #expect(contact.penetration > 0)
    }

    @Test("AABB vs AABB: vertical overlap")
    func aabbVerticalOverlap() throws {
        let contact = try #require(NarrowPhase.testAABBvsAABB(
            posA: Vector2(x: 0, y: 0),
            halfA: Vector2(x: 10, y: 10),
            posB: Vector2(x: 0, y: 15),
            halfB: Vector2(x: 10, y: 10)
        ))
        #expect(abs(contact.penetration - 5) < 0.01)
        #expect(contact.normal.y > 0) // Points downward (from A to B)
    }

    // MARK: - Circle vs Circle

    @Test("Circle vs Circle: overlapping")
    func circleOverlap() throws {
        let contact = try #require(NarrowPhase.testCircleVsCircle(
            posA: Vector2(x: 0, y: 0),
            radiusA: 10,
            posB: Vector2(x: 15, y: 0),
            radiusB: 10
        ))
        #expect(abs(contact.penetration - 5) < 0.01)
        #expect(abs(contact.normal.x - 1) < 0.01) // Points right
        #expect(abs(contact.normal.y) < 0.01)
    }

    @Test("Circle vs Circle: separated")
    func circleSeparated() {
        let contact = NarrowPhase.testCircleVsCircle(
            posA: Vector2(x: 0, y: 0),
            radiusA: 5,
            posB: Vector2(x: 20, y: 0),
            radiusB: 5
        )
        #expect(contact == nil)
    }

    @Test("Circle vs Circle: concentric")
    func circleConcentric() throws {
        let contact = try #require(NarrowPhase.testCircleVsCircle(
            posA: Vector2(x: 0, y: 0),
            radiusA: 10,
            posB: Vector2(x: 0, y: 0),
            radiusB: 5
        ))
        #expect(abs(contact.penetration - 15) < 0.01)
    }

    @Test("Circle vs Circle: diagonal overlap")
    func circleDiagonal() throws {
        let contact = try #require(NarrowPhase.testCircleVsCircle(
            posA: Vector2(x: 0, y: 0),
            radiusA: 10,
            posB: Vector2(x: 10, y: 10),
            radiusB: 10
        ))
        // Distance = sqrt(200) ~ 14.14, sum of radii = 20, penetration ~ 5.86
        let expectedPen: Float = 20 - Float(200).squareRoot()
        #expect(abs(contact.penetration - expectedPen) < 0.1)
    }

    // MARK: - AABB vs Circle

    @Test("AABB vs Circle: circle overlaps face")
    func aabbCircleFaceOverlap() throws {
        let contact = try #require(NarrowPhase.testAABBvsCircle(
            aabbPos: Vector2(x: 0, y: 0),
            halfExtents: Vector2(x: 10, y: 10),
            circlePos: Vector2(x: 15, y: 0),
            radius: 8
        ))
        #expect(abs(contact.penetration - 3) < 0.1)
        #expect(contact.normal.x > 0) // Points toward circle
    }

    @Test("AABB vs Circle: no overlap")
    func aabbCircleSeparated() {
        let contact = NarrowPhase.testAABBvsCircle(
            aabbPos: Vector2(x: 0, y: 0),
            halfExtents: Vector2(x: 10, y: 10),
            circlePos: Vector2(x: 25, y: 0),
            radius: 5
        )
        #expect(contact == nil)
    }

    @Test("AABB vs Circle: circle at corner")
    func aabbCircleCorner() {
        // Circle near corner of AABB
        let contact = NarrowPhase.testAABBvsCircle(
            aabbPos: Vector2(x: 0, y: 0),
            halfExtents: Vector2(x: 10, y: 10),
            circlePos: Vector2(x: 14, y: 14),
            radius: 8
        )
        // Distance from corner (10,10) to circle center (14,14) = sqrt(32) ~ 5.66
        // Since 5.66 < 8, should collide
        #expect(contact != nil)
    }

    @Test("AABB vs Circle: circle center inside AABB")
    func aabbCircleInside() throws {
        let contact = try #require(NarrowPhase.testAABBvsCircle(
            aabbPos: Vector2(x: 0, y: 0),
            halfExtents: Vector2(x: 20, y: 20),
            circlePos: Vector2(x: 5, y: 0),
            radius: 5
        ))
        #expect(contact.penetration > 0)
    }

    // MARK: - Polygon vs Polygon (SAT)

    @Test("Polygon vs Polygon: overlapping squares")
    func polygonOverlap() throws {
        let squareA = [
            Vector2(x: -10, y: -10), Vector2(x: -10, y: 10),
            Vector2(x: 10, y: 10), Vector2(x: 10, y: -10)
        ]
        let normalsA = computeTestNormals(squareA)

        let squareB = [
            Vector2(x: 5, y: -10), Vector2(x: 5, y: 10),
            Vector2(x: 25, y: 10), Vector2(x: 25, y: -10)
        ]
        let normalsB = computeTestNormals(squareB)

        let contact = try #require(NarrowPhase.testPolygonVsPolygon(
            verticesA: squareA,
            normalsA: normalsA,
            verticesB: squareB,
            normalsB: normalsB
        ))
        #expect(abs(contact.penetration - 5) < 0.1)
    }

    @Test("Polygon vs Polygon: separated")
    func polygonSeparated() {
        let squareA = [
            Vector2(x: -10, y: -10), Vector2(x: -10, y: 10),
            Vector2(x: 10, y: 10), Vector2(x: 10, y: -10)
        ]
        let normalsA = computeTestNormals(squareA)

        let squareB = [
            Vector2(x: 20, y: -10), Vector2(x: 20, y: 10),
            Vector2(x: 40, y: 10), Vector2(x: 40, y: -10)
        ]
        let normalsB = computeTestNormals(squareB)

        let contact = NarrowPhase.testPolygonVsPolygon(
            verticesA: squareA,
            normalsA: normalsA,
            verticesB: squareB,
            normalsB: normalsB
        )
        #expect(contact == nil)
    }

    @Test("Polygon vs Polygon: triangles overlapping")
    func trianglesOverlap() {
        let triA = [
            Vector2(x: 0, y: -15), Vector2(x: -15, y: 10), Vector2(x: 15, y: 10)
        ]
        let normalsA = computeTestNormals(triA)

        let triB = [
            Vector2(x: 10, y: -15), Vector2(x: -5, y: 10), Vector2(x: 25, y: 10)
        ]
        let normalsB = computeTestNormals(triB)

        let contact = NarrowPhase.testPolygonVsPolygon(
            verticesA: triA,
            normalsA: normalsA,
            verticesB: triB,
            normalsB: normalsB
        )
        #expect(contact != nil)
    }

    // MARK: - Polygon vs Circle

    @Test("Polygon vs Circle: circle overlaps polygon face")
    func polygonCircleFace() throws {
        let square = [
            Vector2(x: -10, y: -10), Vector2(x: -10, y: 10),
            Vector2(x: 10, y: 10), Vector2(x: 10, y: -10)
        ]
        let normals = computeTestNormals(square)

        let contact = try #require(NarrowPhase.testPolygonVsCircle(
            vertices: square,
            normals: normals,
            circlePos: Vector2(x: 15, y: 0),
            radius: 8
        ))
        #expect(abs(contact.penetration - 3) < 0.5)
    }

    @Test("Polygon vs Circle: separated")
    func polygonCircleSeparated() {
        let square = [
            Vector2(x: -10, y: -10), Vector2(x: -10, y: 10),
            Vector2(x: 10, y: 10), Vector2(x: 10, y: -10)
        ]
        let normals = computeTestNormals(square)

        let contact = NarrowPhase.testPolygonVsCircle(
            vertices: square,
            normals: normals,
            circlePos: Vector2(x: 30, y: 0),
            radius: 5
        )
        #expect(contact == nil)
    }

    @Test("Polygon vs Circle: circle near vertex")
    func polygonCircleVertex() {
        let square = [
            Vector2(x: -10, y: -10), Vector2(x: -10, y: 10),
            Vector2(x: 10, y: 10), Vector2(x: 10, y: -10)
        ]
        let normals = computeTestNormals(square)

        // Circle positioned near corner
        let contact = NarrowPhase.testPolygonVsCircle(
            vertices: square,
            normals: normals,
            circlePos: Vector2(x: 14, y: 14),
            radius: 8
        )
        // Distance from corner (10,10) to (14,14) = sqrt(32) ~ 5.66, which < 8
        #expect(contact != nil)
    }

    // MARK: - Polygon vs AABB

    @Test("Polygon vs AABB: overlapping")
    func polygonAABBOverlap() {
        let tri = [
            Vector2(x: 0, y: -20), Vector2(x: -15, y: 10), Vector2(x: 15, y: 10)
        ]
        let normals = computeTestNormals(tri)

        let contact = NarrowPhase.testPolygonVsAABB(
            vertices: tri,
            normals: normals,
            aabbPos: Vector2(x: 0, y: 15),
            halfExtents: Vector2(x: 20, y: 10)
        )
        #expect(contact != nil)
    }

    @Test("Polygon vs AABB: separated")
    func polygonAABBSeparated() {
        let tri = [
            Vector2(x: 0, y: -20), Vector2(x: -15, y: 10), Vector2(x: 15, y: 10)
        ]
        let normals = computeTestNormals(tri)

        let contact = NarrowPhase.testPolygonVsAABB(
            vertices: tri,
            normals: normals,
            aabbPos: Vector2(x: 0, y: 30),
            halfExtents: Vector2(x: 10, y: 5)
        )
        #expect(contact == nil)
    }

    // MARK: - Unified Dispatcher

    @Test("Unified test: AABB vs Circle")
    func unifiedAABBCircle() {
        let contact = NarrowPhase.test(
            shapeA: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            posA: Vector2(x: 0, y: 0),
            rotA: 0,
            shapeB: .circle(radius: 8),
            posB: Vector2(x: 15, y: 0),
            rotB: 0
        )
        #expect(contact != nil)
    }

    @Test("Unified test: Circle vs AABB (swapped)")
    func unifiedCircleAABB() throws {
        let contact = try #require(NarrowPhase.test(
            shapeA: .circle(radius: 8),
            posA: Vector2(x: 15, y: 0),
            rotA: 0,
            shapeB: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            posB: Vector2(x: 0, y: 0),
            rotB: 0
        ))
        // Normal should point from circle (A) toward AABB (B), i.e., leftward
        #expect(contact.normal.x < 0)
    }

    @Test("Unified test: Polygon vs Polygon with rotation")
    func unifiedPolygonRotated() {
        let square = ConvexPolygon(vertices: [
            Vector2(x: -10, y: -10), Vector2(x: 10, y: -10),
            Vector2(x: 10, y: 10), Vector2(x: -10, y: 10)
        ])

        // Two overlapping squares, one rotated 45 degrees
        let contact = NarrowPhase.test(
            shapeA: .polygon(square),
            posA: Vector2(x: 0, y: 0),
            rotA: 0,
            shapeB: .polygon(square),
            posB: Vector2(x: 15, y: 0),
            rotB: .pi / 4
        )
        #expect(contact != nil)
    }

    @Test("Unified test: Rotated AABB uses polygon path")
    func unifiedRotatedAABB() {
        // Two AABBs, one rotated — should use polygon path
        let contact = NarrowPhase.test(
            shapeA: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            posA: Vector2(x: 0, y: 0),
            rotA: .pi / 4,
            shapeB: .aabb(halfExtents: Vector2(x: 10, y: 10)),
            posB: Vector2(x: 15, y: 0),
            rotB: 0
        )
        #expect(contact != nil)
    }

    // MARK: - Helpers

    /// Compute normals for test vertices (CCW winding).
    private func computeTestNormals(_ vertices: [Vector2]) -> [Vector2] {
        var normals: [Vector2] = []
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let edge = vertices[j] - vertices[i]
            normals.append(Vector2(x: edge.y, y: -edge.x).normalized)
        }
        return normals
    }
}
