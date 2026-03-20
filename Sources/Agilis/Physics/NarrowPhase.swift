#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Narrow-phase collision detection for all shape pair combinations.
///
/// All test functions return a `Contact` where the normal points from shape A toward shape B,
/// or `nil` if the shapes do not overlap.
public enum NarrowPhase {

    // MARK: - AABB vs AABB

    /// Test two axis-aligned bounding boxes for overlap.
    public static func testAABBvsAABB(
        posA: Vector2,
        halfA: Vector2,
        posB: Vector2,
        halfB: Vector2
    ) -> Contact? {
        let dx = posB.x - posA.x
        let dy = posB.y - posA.y
        let overlapX = halfA.x + halfB.x - abs(dx)
        let overlapY = halfA.y + halfB.y - abs(dy)

        guard overlapX > 0 && overlapY > 0 else { return nil }

        // Choose the axis with minimum penetration
        if overlapX < overlapY {
            let normalX: Float = dx < 0 ? -1 : 1
            let normal = Vector2(x: normalX, y: 0)
            let point = Vector2(
                x: posA.x + halfA.x * normalX,
                y: posB.y
            )
            return Contact(normal: normal, penetration: overlapX, point: point)
        } else {
            let normalY: Float = dy < 0 ? -1 : 1
            let normal = Vector2(x: 0, y: normalY)
            let point = Vector2(
                x: posB.x,
                y: posA.y + halfA.y * normalY
            )
            return Contact(normal: normal, penetration: overlapY, point: point)
        }
    }

    // MARK: - Circle vs Circle

    /// Test two circles for overlap.
    public static func testCircleVsCircle(
        posA: Vector2,
        radiusA: Float,
        posB: Vector2,
        radiusB: Float
    ) -> Contact? {
        let diff = posB - posA
        let distSq = diff.lengthSquared
        let radiusSum = radiusA + radiusB

        guard distSq < radiusSum * radiusSum else { return nil }

        let dist = distSq.squareRoot()

        // Handle concentric circles
        if dist < PhysicsConstants.Tolerance.vectorLength {
            return Contact(
                normal: Vector2.unitX,
                penetration: radiusSum,
                point: posA
            )
        }

        let normal = diff / dist
        let penetration = radiusSum - dist
        let point = posA + normal * radiusA

        return Contact(normal: normal, penetration: penetration, point: point)
    }

    // MARK: - AABB vs Circle

    /// Test an AABB against a circle for overlap.
    public static func testAABBvsCircle(
        aabbPos: Vector2,
        halfExtents: Vector2,
        circlePos: Vector2,
        radius: Float
    ) -> Contact? {
        // Find the closest point on the AABB to the circle center
        let closestX = clamp(
            circlePos.x,
            min: aabbPos.x - halfExtents.x,
            max: aabbPos.x + halfExtents.x
        )
        let closestY = clamp(
            circlePos.y,
            min: aabbPos.y - halfExtents.y,
            max: aabbPos.y + halfExtents.y
        )
        let closest = Vector2(x: closestX, y: closestY)

        let diff = circlePos - closest
        let distSq = diff.lengthSquared

        guard distSq < radius * radius else { return nil }

        let dist = distSq.squareRoot()

        // Circle center is inside the AABB
        if dist < PhysicsConstants.Tolerance.vectorLength {
            // Push out along the axis with minimum penetration
            let dx = halfExtents.x - abs(circlePos.x - aabbPos.x)
            let dy = halfExtents.y - abs(circlePos.y - aabbPos.y)

            if dx < dy {
                let sign: Float = circlePos.x < aabbPos.x ? -1 : 1
                let normal = Vector2(x: sign, y: 0)
                let penetration = dx + radius
                let point = Vector2(
                    x: aabbPos.x + halfExtents.x * sign,
                    y: circlePos.y
                )
                return Contact(
                    normal: normal,
                    penetration: penetration,
                    point: point
                )
            } else {
                let sign: Float = circlePos.y < aabbPos.y ? -1 : 1
                let normal = Vector2(x: 0, y: sign)
                let penetration = dy + radius
                let point = Vector2(
                    x: circlePos.x,
                    y: aabbPos.y + halfExtents.y * sign
                )
                return Contact(
                    normal: normal,
                    penetration: penetration,
                    point: point
                )
            }
        }

        let normal = diff / dist
        let penetration = radius - dist
        return Contact(normal: normal, penetration: penetration, point: closest)
    }

    // MARK: - Polygon vs Polygon (SAT)

    /// Test two convex polygons for overlap using the Separating Axis Theorem.
    /// Vertices and normals must be in world space.
    public static func testPolygonVsPolygon(
        verticesA: [Vector2],
        normalsA: [Vector2],
        verticesB: [Vector2],
        normalsB: [Vector2]
    ) -> Contact? {
        var minOverlap: Float = .infinity
        var bestNormal = Vector2.zero

        // Test normals from polygon A
        for normal in normalsA {
            let (minA, maxA) = projectVertices(verticesA, onto: normal)
            let (minB, maxB) = projectVertices(verticesB, onto: normal)
            let overlap = min(maxA, maxB) - max(minA, minB)
            if overlap <= 0 { return nil }
            if overlap < minOverlap {
                minOverlap = overlap
                bestNormal = normal
            }
        }

        // Test normals from polygon B
        for normal in normalsB {
            let (minA, maxA) = projectVertices(verticesA, onto: normal)
            let (minB, maxB) = projectVertices(verticesB, onto: normal)
            let overlap = min(maxA, maxB) - max(minA, minB)
            if overlap <= 0 { return nil }
            if overlap < minOverlap {
                minOverlap = overlap
                bestNormal = normal
            }
        }

        // Ensure normal points from A toward B
        let centerA = centroid(of: verticesA)
        let centerB = centroid(of: verticesB)
        if bestNormal.dot(centerB - centerA) < 0 {
            bestNormal = -bestNormal
        }

        // Find contact point: deepest vertex of B into A along -normal
        let contactPoint = deepestPoint(in: verticesB, along: -bestNormal)

        return Contact(
            normal: bestNormal,
            penetration: minOverlap,
            point: contactPoint
        )
    }

    // MARK: - Polygon vs Circle

    /// Test a convex polygon against a circle using SAT with Voronoi region handling.
    /// Vertices and normals must be in world space.
    public static func testPolygonVsCircle(
        vertices: [Vector2],
        normals: [Vector2],
        circlePos: Vector2,
        radius: Float
    ) -> Contact? {
        var minOverlap: Float = .infinity
        var bestNormal = Vector2.zero

        // Test polygon edge normals
        for normal in normals {
            let (minP, maxP) = projectVertices(vertices, onto: normal)
            let circleProj = circlePos.dot(normal)
            let circleMin = circleProj - radius
            let circleMax = circleProj + radius
            let overlap = min(maxP, circleMax) - max(minP, circleMin)
            if overlap <= 0 { return nil }
            if overlap < minOverlap {
                minOverlap = overlap
                bestNormal = normal
            }
        }

        // Find nearest vertex to circle center (Voronoi region axis)
        var nearestDist: Float = .infinity
        var nearestVertex = vertices[0]
        for v in vertices {
            let d = (v - circlePos).lengthSquared
            if d < nearestDist {
                nearestDist = d
                nearestVertex = v
            }
        }

        let voronoiDir = circlePos - nearestVertex
        let voronoiLen = voronoiDir.length
        if voronoiLen > PhysicsConstants.Tolerance.vectorLength {
            let voronoiAxis = voronoiDir / voronoiLen

            let (minP, maxP) = projectVertices(vertices, onto: voronoiAxis)
            let circleProj = circlePos.dot(voronoiAxis)
            let circleMin = circleProj - radius
            let circleMax = circleProj + radius
            let overlap = min(maxP, circleMax) - max(minP, circleMin)
            if overlap <= 0 { return nil }
            if overlap < minOverlap {
                minOverlap = overlap
                bestNormal = voronoiAxis
            }
        }

        // Ensure normal points from polygon toward circle
        let polyCenter = centroid(of: vertices)
        if bestNormal.dot(circlePos - polyCenter) < 0 {
            bestNormal = -bestNormal
        }

        // Contact point: on circle surface toward polygon
        let contactPoint = circlePos - bestNormal * radius

        return Contact(
            normal: bestNormal,
            penetration: minOverlap,
            point: contactPoint
        )
    }

    // MARK: - Polygon vs AABB

    /// Test a convex polygon against an AABB.
    /// Converts the AABB to polygon vertices and delegates to polygon-polygon SAT.
    /// Polygon vertices and normals must be in world space.
    public static func testPolygonVsAABB(
        vertices: [Vector2],
        normals: [Vector2],
        aabbPos: Vector2,
        halfExtents: Vector2
    ) -> Contact? {
        let aabbVerts = aabbVertices(pos: aabbPos, half: halfExtents)
        let aabbNorms = aabbNormals()
        return testPolygonVsPolygon(
            verticesA: vertices,
            normalsA: normals,
            verticesB: aabbVerts,
            normalsB: aabbNorms
        )
    }

    // MARK: - Unified Dispatcher

    // Test two collision shapes given their world-space positions and rotations.
    // Handles all shape combinations by dispatching to the appropriate test function.
    //
    // - Parameters:
    //   - shapeA: The collision shape of entity A.
    //   - posA: World-space position of entity A (transform position + collider offset).
    //   - rotA: Rotation of entity A in radians.
    //   - shapeB: The collision shape of entity B.
    //   - posB: World-space position of entity B.
    //   - rotB: Rotation of entity B in radians.
    // - Returns: A `Contact` if the shapes overlap, `nil` otherwise.
    public static func test(
        shapeA: CollisionShape,
        posA: Vector2,
        rotA: Float,
        shapeB: CollisionShape,
        posB: Vector2,
        rotB: Float
    ) -> Contact? {
        switch (shapeA, shapeB) {

        // AABB vs AABB
        case (.aabb(let halfA), .aabb(let halfB)):
            return testAABBvsAABB(
                posA: posA,
                halfA: halfA,
                posB: posB,
                halfB: halfB,
                rotA: rotA,
                rotB: rotB
            )

        // Circle vs Circle
        case (.circle(let rA), .circle(let rB)):
            return testCircleVsCircle(
                posA: posA,
                radiusA: rA,
                posB: posB,
                radiusB: rB
            )

        // AABB vs Circle
        case (.aabb(let half), .circle(let r)):
            return testAABBvsCircleDispatch(
                aabbPos: posA,
                half: half,
                rotA: rotA,
                circlePos: posB,
                radius: r
            )

        // Circle vs AABB (swap and negate normal)
        case (.circle(let r), .aabb(let half)):
            return testCircleVsAABBDispatch(
                circlePos: posA,
                radius: r,
                aabbPos: posB,
                half: half,
                rotB: rotB
            )

        // Polygon vs Polygon
        case (.polygon(let polyA), .polygon(let polyB)):
            return testPolygonVsPolygonDispatch(
                polyA: polyA,
                posA: posA,
                rotA: rotA,
                polyB: polyB,
                posB: posB,
                rotB: rotB
            )

        // Polygon vs Circle
        case (.polygon(let poly), .circle(let r)):
            return testPolygonVsCircleDispatch(
                poly: poly,
                polyPos: posA,
                polyRot: rotA,
                circlePos: posB,
                radius: r
            )

        // Circle vs Polygon (swap and negate)
        case (.circle(let r), .polygon(let poly)):
            return testCircleVsPolygonDispatch(
                circlePos: posA,
                radius: r,
                poly: poly,
                polyPos: posB,
                polyRot: rotB
            )

        // Polygon vs AABB
        case (.polygon(let poly), .aabb(let half)):
            return testPolygonVsAABBDispatch(
                poly: poly,
                polyPos: posA,
                polyRot: rotA,
                aabbPos: posB,
                half: half,
                rotB: rotB
            )

        // AABB vs Polygon (swap and negate)
        case (.aabb(let half), .polygon(let poly)):
            return testAABBvsPolygonDispatch(
                aabbPos: posA,
                half: half,
                rotA: rotA,
                poly: poly,
                polyPos: posB,
                polyRot: rotB
            )
        }
    }

    // MARK: - Dispatch Helpers

    private static func testAABBvsAABB(
        posA: Vector2,
        halfA: Vector2,
        posB: Vector2,
        halfB: Vector2,
        rotA: Float,
        rotB: Float
    ) -> Contact? {
        if rotA == 0 && rotB == 0 {
            return testAABBvsAABB(
                posA: posA,
                halfA: halfA,
                posB: posB,
                halfB: halfB
            )
        }
        // Rotated AABBs: promote to polygon
        let vertsA = rotatedAABBVertices(pos: posA, half: halfA, rot: rotA)
        let normsA = computeNormals(vertsA)
        let vertsB = rotatedAABBVertices(pos: posB, half: halfB, rot: rotB)
        let normsB = computeNormals(vertsB)
        return testPolygonVsPolygon(
            verticesA: vertsA,
            normalsA: normsA,
            verticesB: vertsB,
            normalsB: normsB
        )
    }

    private static func testAABBvsCircleDispatch(
        aabbPos: Vector2,
        half: Vector2,
        rotA: Float,
        circlePos: Vector2,
        radius: Float
    ) -> Contact? {
        if rotA == 0 {
            return testAABBvsCircle(
                aabbPos: aabbPos,
                halfExtents: half,
                circlePos: circlePos,
                radius: radius
            )
        }
        let verts = rotatedAABBVertices(pos: aabbPos, half: half, rot: rotA)
        let norms = computeNormals(verts)
        return testPolygonVsCircle(
            vertices: verts,
            normals: norms,
            circlePos: circlePos,
            radius: radius
        )
    }

    private static func testCircleVsAABBDispatch(
        circlePos: Vector2,
        radius: Float,
        aabbPos: Vector2,
        half: Vector2,
        rotB: Float
    ) -> Contact? {
        if rotB == 0 {
            guard let c = testAABBvsCircle(
                aabbPos: aabbPos,
                halfExtents: half,
                circlePos: circlePos,
                radius: radius
            ) else { return nil }
            return Contact(
                normal: -c.normal,
                penetration: c.penetration,
                point: c.point
            )
        }
        let verts = rotatedAABBVertices(pos: aabbPos, half: half, rot: rotB)
        let norms = computeNormals(verts)
        guard let c = testPolygonVsCircle(
            vertices: verts,
            normals: norms,
            circlePos: circlePos,
            radius: radius
        ) else { return nil }
        return Contact(
            normal: -c.normal,
            penetration: c.penetration,
            point: c.point
        )
    }

    private static func testPolygonVsPolygonDispatch(
        polyA: ConvexPolygon,
        posA: Vector2,
        rotA: Float,
        polyB: ConvexPolygon,
        posB: Vector2,
        rotB: Float
    ) -> Contact? {
        let vertsA = transformVertices(
            polyA.vertices,
            position: posA,
            rotation: rotA
        )
        let normsA = rotateNormals(polyA.normals, rotation: rotA)
        let vertsB = transformVertices(
            polyB.vertices,
            position: posB,
            rotation: rotB
        )
        let normsB = rotateNormals(polyB.normals, rotation: rotB)
        return testPolygonVsPolygon(
            verticesA: vertsA,
            normalsA: normsA,
            verticesB: vertsB,
            normalsB: normsB
        )
    }

    private static func testPolygonVsCircleDispatch(
        poly: ConvexPolygon,
        polyPos: Vector2,
        polyRot: Float,
        circlePos: Vector2,
        radius: Float
    ) -> Contact? {
        let verts = transformVertices(
            poly.vertices,
            position: polyPos,
            rotation: polyRot
        )
        let norms = rotateNormals(poly.normals, rotation: polyRot)
        return testPolygonVsCircle(
            vertices: verts,
            normals: norms,
            circlePos: circlePos,
            radius: radius
        )
    }

    private static func testCircleVsPolygonDispatch(
        circlePos: Vector2,
        radius: Float,
        poly: ConvexPolygon,
        polyPos: Vector2,
        polyRot: Float
    ) -> Contact? {
        let verts = transformVertices(
            poly.vertices,
            position: polyPos,
            rotation: polyRot
        )
        let norms = rotateNormals(poly.normals, rotation: polyRot)
        guard let c = testPolygonVsCircle(
            vertices: verts,
            normals: norms,
            circlePos: circlePos,
            radius: radius
        ) else { return nil }
        return Contact(
            normal: -c.normal,
            penetration: c.penetration,
            point: c.point
        )
    }

    private static func testPolygonVsAABBDispatch(
        poly: ConvexPolygon,
        polyPos: Vector2,
        polyRot: Float,
        aabbPos: Vector2,
        half: Vector2,
        rotB: Float
    ) -> Contact? {
        let polyVerts = transformVertices(
            poly.vertices,
            position: polyPos,
            rotation: polyRot
        )
        let polyNorms = rotateNormals(poly.normals, rotation: polyRot)
        if rotB == 0 {
            return testPolygonVsAABB(
                vertices: polyVerts,
                normals: polyNorms,
                aabbPos: aabbPos,
                halfExtents: half
            )
        }
        let aabbVerts = rotatedAABBVertices(
            pos: aabbPos,
            half: half,
            rot: rotB
        )
        let aabbNorms = computeNormals(aabbVerts)
        return testPolygonVsPolygon(
            verticesA: polyVerts,
            normalsA: polyNorms,
            verticesB: aabbVerts,
            normalsB: aabbNorms
        )
    }

    private static func testAABBvsPolygonDispatch(
        aabbPos: Vector2,
        half: Vector2,
        rotA: Float,
        poly: ConvexPolygon,
        polyPos: Vector2,
        polyRot: Float
    ) -> Contact? {
        let polyVerts = transformVertices(
            poly.vertices,
            position: polyPos,
            rotation: polyRot
        )
        let polyNorms = rotateNormals(poly.normals, rotation: polyRot)
        if rotA == 0 {
            guard let c = testPolygonVsAABB(
                vertices: polyVerts,
                normals: polyNorms,
                aabbPos: aabbPos,
                halfExtents: half
            ) else { return nil }
            return Contact(
                normal: -c.normal,
                penetration: c.penetration,
                point: c.point
            )
        }
        let aabbVerts = rotatedAABBVertices(
            pos: aabbPos,
            half: half,
            rot: rotA
        )
        let aabbNorms = computeNormals(aabbVerts)
        guard let c = testPolygonVsPolygon(
            verticesA: polyVerts,
            normalsA: polyNorms,
            verticesB: aabbVerts,
            normalsB: aabbNorms
        ) else { return nil }
        return Contact(
            normal: -c.normal,
            penetration: c.penetration,
            point: c.point
        )
    }

    // MARK: - Private Helpers

    /// Project all vertices onto an axis and return (min, max) projections.
    private static func projectVertices(
        _ vertices: [Vector2],
        onto axis: Vector2
    ) -> (min: Float, max: Float) {
        var minProj = vertices[0].dot(axis)
        var maxProj = minProj
        for i in 1..<vertices.count {
            let proj = vertices[i].dot(axis)
            if proj < minProj { minProj = proj }
            if proj > maxProj { maxProj = proj }
        }
        return (minProj, maxProj)
    }

    /// Compute the centroid (average) of a set of vertices.
    private static func centroid(of vertices: [Vector2]) -> Vector2 {
        var sum = Vector2.zero
        for v in vertices { sum += v }
        return sum / Float(vertices.count)
    }

    /// Find the vertex that is deepest along a direction (minimum projection).
    private static func deepestPoint(
        in vertices: [Vector2],
        along direction: Vector2
    ) -> Vector2 {
        var bestProj = vertices[0].dot(direction)
        var bestVertex = vertices[0]
        for i in 1..<vertices.count {
            let proj = vertices[i].dot(direction)
            if proj < bestProj {
                bestProj = proj
                bestVertex = vertices[i]
            }
        }
        return bestVertex
    }

    // Delegates to GeometryHelpers for shared implementations
    private static func transformVertices(
        _ vertices: [Vector2],
        position: Vector2,
        rotation: Float
    ) -> [Vector2] {
        GeometryHelpers.transformVertices(
            vertices,
            position: position,
            rotation: rotation
        )
    }

    private static func rotateNormals(
        _ normals: [Vector2],
        rotation: Float
    ) -> [Vector2] {
        GeometryHelpers.rotateNormals(normals, rotation: rotation)
    }

    private static func rotatedAABBVertices(
        pos: Vector2,
        half: Vector2,
        rot: Float
    ) -> [Vector2] {
        GeometryHelpers.rotatedAABBVertices(
            pos: pos,
            half: half,
            rot: rot
        )
    }

    private static func computeNormals(_ vertices: [Vector2]) -> [Vector2] {
        GeometryHelpers.computeNormals(vertices)
    }

    /// Generate 4 vertices for an AABB (no rotation) in CCW order.
    private static func aabbVertices(
        pos: Vector2,
        half: Vector2
    ) -> [Vector2] {
        [
            Vector2(x: pos.x - half.x, y: pos.y - half.y),
            Vector2(x: pos.x - half.x, y: pos.y + half.y),
            Vector2(x: pos.x + half.x, y: pos.y + half.y),
            Vector2(x: pos.x + half.x, y: pos.y - half.y)
        ]
    }

    /// The 4 normals for an axis-aligned rectangle.
    private static func aabbNormals() -> [Vector2] {
        [
            Vector2(x: -1, y: 0),
            Vector2(x: 0, y: 1),
            Vector2(x: 1, y: 0),
            Vector2(x: 0, y: -1)
        ]
    }
}
