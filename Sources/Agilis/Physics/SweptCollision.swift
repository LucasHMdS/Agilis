import AgilisCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Swept collision tests for Continuous Collision Detection (CCD).
///
/// Computes the time of impact (TOI) for a shape moving linearly from `startPos`
/// to `endPos` against a stationary shape. TOI is in [0, 1] where 0 = start of
/// frame displacement, 1 = end. Returns nil if no collision occurs during the sweep.
///
/// Follows the same stateless enum pattern as `NarrowPhase`, `SpatialQuery`,
/// and `ImpulseResolver`.
public enum SweptCollision {

    /// Small skin width to pull back from the exact TOI point, ensuring the
    /// discrete narrow phase detects a small penetration and generates a contact.
    static let skinWidth: Float = 0.01

    // MARK: - Public Helpers

    /// The minimum extent (smallest dimension) of a collision shape.
    /// Used as an early-out threshold: if displacement < minimumExtent, discrete is sufficient.
    public static func minimumExtent(of shape: CollisionShape) -> Float {
        switch shape {
        case .circle(let radius):
            return radius
        case .aabb(let halfExtents):
            return min(halfExtents.x, halfExtents.y)
        case .polygon(let poly):
            return min(poly.localBounds.width, poly.localBounds.height) * 0.5
        }
    }

    /// The maximum distance any point on the shape moves due to rotation alone.
    ///
    /// For circles, this is always 0 (rotation doesn't change collision profile).
    /// For AABBs and polygons, this is the bounding radius times the absolute angular displacement
    /// (arc length of the farthest vertex).
    ///
    /// - Parameters:
    ///   - shape: The collision shape.
    ///   - angularDisplacement: Absolute change in rotation (radians) during the sweep.
    /// - Returns: The maximum arc distance any vertex sweeps through.
    public static func angularSweepExtent(of shape: CollisionShape, angularDisplacement: Float) -> Float {
        switch shape {
        case .circle:
            return 0 // Circles are rotationally symmetric
        case .aabb, .polygon:
            return boundingRadius(of: shape) * abs(angularDisplacement)
        }
    }

    /// The bounding radius of a collision shape (distance from center to farthest point).
    /// Used for conservative polygon fallback — sweep the bounding circle instead.
    public static func boundingRadius(of shape: CollisionShape) -> Float {
        switch shape {
        case .circle(let radius):
            return radius
        case .aabb(let halfExtents):
            return sqrtf(halfExtents.x * halfExtents.x + halfExtents.y * halfExtents.y)
        case .polygon(let poly):
            var maxR: Float = 0
            for v in poly.vertices {
                let r = v.x * v.x + v.y * v.y
                if r > maxR { maxR = r }
            }
            return sqrtf(maxR)
        }
    }

    // MARK: - Unified Dispatcher

    /// Compute the time of impact for a shape swept linearly from `startPos` to `endPos`
    /// against a stationary shape.
    ///
    /// - Parameters:
    ///   - movingShape: The collision shape of the moving body.
    ///   - startPos: World-space center of the moving shape at the start of the sweep.
    ///   - endPos: World-space center of the moving shape at the end of the sweep.
    ///   - movingRot: Rotation of the moving shape (treated as constant during sweep).
    ///   - staticShape: The collision shape of the stationary body.
    ///   - staticPos: World-space center of the stationary shape.
    ///   - staticRot: Rotation of the stationary shape.
    /// - Returns: TOI in [0, 1] where contact first occurs, or nil if no contact.
    public static func timeOfImpact(
        movingShape: CollisionShape, startPos: Vector2, endPos: Vector2, movingRot: Float,
        staticShape: CollisionShape, staticPos: Vector2, staticRot: Float
    ) -> Float? {
        switch (movingShape, staticShape) {
        // Circle vs *
        case (.circle(let radiusA), .circle(let radiusB)):
            return sweptCircleVsCircle(
                startPos: startPos, endPos: endPos, radiusA: radiusA,
                circlePos: staticPos, radiusB: radiusB
            )

        case (.circle(let radius), .aabb(let halfExtents)):
            if staticRot == 0 {
                return sweptCircleVsAABB(
                    startPos: startPos, endPos: endPos, radius: radius,
                    aabbPos: staticPos, halfExtents: halfExtents
                )
            }
            // Rotated AABB: promote to polygon
            let verts = rotatedAABBVertices(pos: staticPos, half: halfExtents, rot: staticRot)
            return sweptCircleVsPolygon(
                startPos: startPos, endPos: endPos, radius: radius,
                vertices: verts
            )

        case (.circle(let radius), .polygon(let poly)):
            let verts = transformVertices(poly.vertices, position: staticPos, rotation: staticRot)
            return sweptCircleVsPolygon(
                startPos: startPos, endPos: endPos, radius: radius,
                vertices: verts
            )

        // AABB vs *
        case (.aabb(let halfA), .aabb(let halfB)):
            if movingRot == 0 && staticRot == 0 {
                return sweptAABBvsAABB(
                    startPos: startPos, endPos: endPos, halfA: halfA,
                    aabbPos: staticPos, halfB: halfB
                )
            }
            // Rotated: conservative bounding circle fallback
            let r = boundingRadius(of: movingShape)
            return sweptCircleVsAABBOrPolygon(
                startPos: startPos, endPos: endPos, radius: r,
                staticShape: staticShape, staticPos: staticPos, staticRot: staticRot
            )

        case (.aabb(let halfA), .circle(let radiusB)):
            if movingRot == 0 {
                return sweptAABBvsCircle(
                    startPos: startPos, endPos: endPos, halfExtents: halfA,
                    circlePos: staticPos, radius: radiusB
                )
            }
            // Rotated AABB: conservative bounding circle fallback
            let r = boundingRadius(of: movingShape)
            return sweptCircleVsCircle(
                startPos: startPos, endPos: endPos, radiusA: r,
                circlePos: staticPos, radiusB: radiusB
            )

        case (.aabb, .polygon):
            // Conservative: bounding circle of moving AABB
            let r = boundingRadius(of: movingShape)
            return sweptCircleVsAABBOrPolygon(
                startPos: startPos, endPos: endPos, radius: r,
                staticShape: staticShape, staticPos: staticPos, staticRot: staticRot
            )

        // Polygon vs * — all conservative bounding circle
        case (.polygon, _):
            let r = boundingRadius(of: movingShape)
            return sweptCircleVsAABBOrPolygon(
                startPos: startPos, endPos: endPos, radius: r,
                staticShape: staticShape, staticPos: staticPos, staticRot: staticRot
            )
        }
    }

    /// Compute the time of impact for a shape swept linearly from `startPos` to `endPos`
    /// while rotating from `startRot` to `endRot`, against a stationary shape.
    ///
    /// For circles, rotation is ignored (rotationally symmetric) and the exact path is used.
    /// For AABBs and polygons with non-zero angular displacement, the moving shape is
    /// conservatively bounded by its bounding circle to account for the rotating profile.
    /// When angular displacement is zero, delegates to the original single-rotation overload
    /// for exact (non-conservative) results where available.
    ///
    /// - Parameters:
    ///   - movingShape: The collision shape of the moving body.
    ///   - startPos: World-space center at the start of the sweep.
    ///   - endPos: World-space center at the end of the sweep.
    ///   - startRot: Rotation at the start of the sweep (radians).
    ///   - endRot: Rotation at the end of the sweep (radians).
    ///   - staticShape: The collision shape of the stationary body.
    ///   - staticPos: World-space center of the stationary shape.
    ///   - staticRot: Rotation of the stationary shape.
    /// - Returns: TOI in [0, 1] where contact first occurs, or nil if no contact.
    public static func timeOfImpact(
        movingShape: CollisionShape, startPos: Vector2, endPos: Vector2,
        startRot: Float, endRot: Float,
        staticShape: CollisionShape, staticPos: Vector2, staticRot: Float
    ) -> Float? {
        let angularDisplacement = abs(endRot - startRot)

        // If no angular displacement, delegate to the original (potentially exact) path
        if angularDisplacement < PhysicsConstants.Tolerance.displacement {
            return timeOfImpact(
                movingShape: movingShape, startPos: startPos, endPos: endPos,
                movingRot: endRot,
                staticShape: staticShape, staticPos: staticPos, staticRot: staticRot
            )
        }

        // Circles are rotationally symmetric — rotation has no effect on collision profile
        if case .circle = movingShape {
            return timeOfImpact(
                movingShape: movingShape, startPos: startPos, endPos: endPos,
                movingRot: endRot,
                staticShape: staticShape, staticPos: staticPos, staticRot: staticRot
            )
        }

        // Non-circle with angular displacement: use conservative bounding circle.
        // The shape's profile changes during rotation, so we sweep the bounding circle
        // to guarantee no tunneling. This matches the existing conservative pattern
        // used for polygon shapes and rotated AABBs.
        let r = boundingRadius(of: movingShape)
        return sweptCircleVsAABBOrPolygon(
            startPos: startPos, endPos: endPos, radius: r,
            staticShape: staticShape, staticPos: staticPos, staticRot: staticRot
        )
    }

    // MARK: - Swept Circle Tests

    /// Swept circle vs static circle using Minkowski expansion.
    /// Expands the target circle by the moving circle's radius and ray-casts the center.
    static func sweptCircleVsCircle(
        startPos: Vector2, endPos: Vector2, radiusA: Float,
        circlePos: Vector2, radiusB: Float
    ) -> Float? {
        let displacement = endPos - startPos
        let maxDist = displacement.length
        guard maxDist > PhysicsConstants.Tolerance.displacement else { return nil }

        let direction = displacement * (1.0 / maxDist)
        let expandedRadius = radiusA + radiusB

        guard let hit = SpatialQuery.rayVsCircle(
            origin: startPos, direction: direction, tMax: maxDist,
            circlePos: circlePos, radius: expandedRadius
        ) else { return nil }

        // Skip already-overlapping (distance 0) — let discrete handle it
        guard hit.distance > 0 else { return nil }

        return hit.distance / maxDist
    }

    /// Swept circle vs static AABB using Minkowski expansion.
    /// Expands the AABB by the circle radius (rounded rectangle approximation).
    static func sweptCircleVsAABB(
        startPos: Vector2, endPos: Vector2, radius: Float,
        aabbPos: Vector2, halfExtents: Vector2
    ) -> Float? {
        let displacement = endPos - startPos
        let maxDist = displacement.length
        guard maxDist > PhysicsConstants.Tolerance.displacement else { return nil }

        let direction = displacement * (1.0 / maxDist)

        // Expand AABB by circle radius (Minkowski sum faces)
        let expandedHalf = Vector2(x: halfExtents.x + radius, y: halfExtents.y + radius)

        guard let hit = SpatialQuery.rayVsAABB(
            origin: startPos, direction: direction, tMax: maxDist,
            aabbPos: aabbPos, halfExtents: expandedHalf
        ) else { return nil }

        // Skip already-overlapping
        guard hit.distance > 0 else { return nil }

        // Check if the hit is in a corner region — the Minkowski sum of AABB + circle
        // has rounded corners, but our expanded AABB has square corners.
        // If the hit point is in the corner "excess" region, re-test against the corner circle.
        let hitPoint = hit.point
        let cornerX = abs(hitPoint.x - aabbPos.x) - halfExtents.x
        let cornerY = abs(hitPoint.y - aabbPos.y) - halfExtents.y

        if cornerX > 0 && cornerY > 0 {
            // Hit is in the corner region — test against the actual corner circle
            let cornerPos = Vector2(
                x: aabbPos.x + (hitPoint.x > aabbPos.x ? halfExtents.x : -halfExtents.x),
                y: aabbPos.y + (hitPoint.y > aabbPos.y ? halfExtents.y : -halfExtents.y)
            )

            guard let cornerHit = SpatialQuery.rayVsCircle(
                origin: startPos, direction: direction, tMax: maxDist,
                circlePos: cornerPos, radius: radius
            ) else { return nil }

            guard cornerHit.distance > 0 else { return nil }
            return cornerHit.distance / maxDist
        }

        return hit.distance / maxDist
    }

    /// Swept circle vs static convex polygon.
    /// Uses Minkowski offset: offset each edge outward by radius, add vertex circles.
    static func sweptCircleVsPolygon(
        startPos: Vector2, endPos: Vector2, radius: Float,
        vertices: [Vector2]
    ) -> Float? {
        guard vertices.count >= 3 else { return nil }

        let displacement = endPos - startPos
        let maxDist = displacement.length
        guard maxDist > PhysicsConstants.Tolerance.displacement else { return nil }

        let direction = displacement * (1.0 / maxDist)

        // Check if start position is already inside the expanded polygon (Minkowski sum).
        // If the center is inside the original polygon, it's overlapping.
        if SpatialQuery.pointInPolygon(point: startPos, vertices: vertices) {
            return nil // Already overlapping, let discrete handle it
        }

        var closestT: Float = maxDist
        var found = false

        let n = vertices.count
        for i in 0..<n {
            let v0 = vertices[i]
            let v1 = vertices[(i + 1) % n]
            let edge = v1 - v0

            // Compute outward normal for this edge
            let edgeLen = edge.length
            guard edgeLen > PhysicsConstants.Tolerance.crossProduct else { continue }
            let normal = Vector2(x: edge.y / edgeLen, y: -edge.x / edgeLen)

            // Offset edge outward by radius
            let ov0 = v0 + normal * radius
            let ov1 = v1 + normal * radius

            // Ray vs offset edge segment
            let oEdge = ov1 - ov0
            let denom = direction.x * oEdge.y - direction.y * oEdge.x
            if abs(denom) < PhysicsConstants.Tolerance.crossProduct { continue }

            let dx = ov0.x - startPos.x
            let dy = ov0.y - startPos.y

            let t = (dx * oEdge.y - dy * oEdge.x) / denom
            let s = (dx * direction.y - dy * direction.x) / denom

            if t > 0 && t < closestT && s >= 0 && s <= 1 {
                closestT = t
                found = true
            }

            // Ray vs vertex circle at v0
            if let vHit = SpatialQuery.rayVsCircle(
                origin: startPos, direction: direction, tMax: closestT,
                circlePos: v0, radius: radius
            ), vHit.distance > 0 && vHit.distance < closestT {
                closestT = vHit.distance
                found = true
            }
        }

        guard found else { return nil }
        return closestT / maxDist
    }

    // MARK: - Swept AABB Tests

    /// Swept AABB vs static AABB using Minkowski difference.
    /// Expands the target AABB by the moving AABB's half-extents and ray-casts the center.
    static func sweptAABBvsAABB(
        startPos: Vector2, endPos: Vector2, halfA: Vector2,
        aabbPos: Vector2, halfB: Vector2
    ) -> Float? {
        let displacement = endPos - startPos
        let maxDist = displacement.length
        guard maxDist > PhysicsConstants.Tolerance.displacement else { return nil }

        let direction = displacement * (1.0 / maxDist)

        // Minkowski sum: expand target by source half-extents
        let expandedHalf = Vector2(x: halfA.x + halfB.x, y: halfA.y + halfB.y)

        guard let hit = SpatialQuery.rayVsAABB(
            origin: startPos, direction: direction, tMax: maxDist,
            aabbPos: aabbPos, halfExtents: expandedHalf
        ) else { return nil }

        // Skip already-overlapping
        guard hit.distance > 0 else { return nil }

        return hit.distance / maxDist
    }

    /// Swept AABB vs static circle.
    /// Uses Minkowski sum: the locus of AABB centers that overlap the circle is a rounded rectangle.
    /// Implemented as expanded AABB + corner circle checks (same approach as sweptCircleVsAABB).
    static func sweptAABBvsCircle(
        startPos: Vector2, endPos: Vector2, halfExtents: Vector2,
        circlePos: Vector2, radius: Float
    ) -> Float? {
        let displacement = endPos - startPos
        let maxDist = displacement.length
        guard maxDist > PhysicsConstants.Tolerance.displacement else { return nil }

        let direction = displacement * (1.0 / maxDist)

        // Minkowski sum: expand circle position into a rounded rect
        // The expanded AABB centered at circlePos with half-extents (halfExtents.x + radius, halfExtents.y + radius)
        let expandedHalf = Vector2(x: halfExtents.x + radius, y: halfExtents.y + radius)

        guard let hit = SpatialQuery.rayVsAABB(
            origin: startPos, direction: direction, tMax: maxDist,
            aabbPos: circlePos, halfExtents: expandedHalf
        ) else { return nil }

        guard hit.distance > 0 else { return nil }

        // Corner check: if hit is in the corner excess region
        let hitPoint = hit.point
        let cornerX = abs(hitPoint.x - circlePos.x) - halfExtents.x
        let cornerY = abs(hitPoint.y - circlePos.y) - halfExtents.y

        if cornerX > 0 && cornerY > 0 {
            // Re-test against the actual corner circle at the nearest AABB corner of the expanded rect
            let cornerPos = Vector2(
                x: circlePos.x + (hitPoint.x > circlePos.x ? halfExtents.x : -halfExtents.x),
                y: circlePos.y + (hitPoint.y > circlePos.y ? halfExtents.y : -halfExtents.y)
            )

            guard let cornerHit = SpatialQuery.rayVsCircle(
                origin: startPos, direction: direction, tMax: maxDist,
                circlePos: cornerPos, radius: radius
            ) else { return nil }

            guard cornerHit.distance > 0 else { return nil }
            return cornerHit.distance / maxDist
        }

        return hit.distance / maxDist
    }

    // MARK: - Conservative Fallback

    /// Conservative swept circle fallback for any static shape.
    /// Used when the moving shape is a polygon or a rotated AABB.
    private static func sweptCircleVsAABBOrPolygon(
        startPos: Vector2, endPos: Vector2, radius: Float,
        staticShape: CollisionShape, staticPos: Vector2, staticRot: Float
    ) -> Float? {
        switch staticShape {
        case .circle(let radiusB):
            return sweptCircleVsCircle(
                startPos: startPos, endPos: endPos, radiusA: radius,
                circlePos: staticPos, radiusB: radiusB
            )

        case .aabb(let halfExtents):
            if staticRot == 0 {
                return sweptCircleVsAABB(
                    startPos: startPos, endPos: endPos, radius: radius,
                    aabbPos: staticPos, halfExtents: halfExtents
                )
            }
            let verts = rotatedAABBVertices(pos: staticPos, half: halfExtents, rot: staticRot)
            return sweptCircleVsPolygon(
                startPos: startPos, endPos: endPos, radius: radius,
                vertices: verts
            )

        case .polygon(let poly):
            let verts = transformVertices(poly.vertices, position: staticPos, rotation: staticRot)
            return sweptCircleVsPolygon(
                startPos: startPos, endPos: endPos, radius: radius,
                vertices: verts
            )
        }
    }

    // Delegates to GeometryHelpers for shared implementations
    private static func transformVertices(_ vertices: [Vector2], position: Vector2, rotation: Float) -> [Vector2] {
        GeometryHelpers.transformVertices(vertices, position: position, rotation: rotation)
    }

    private static func rotatedAABBVertices(pos: Vector2, half: Vector2, rot: Float) -> [Vector2] {
        GeometryHelpers.rotatedAABBVertices(pos: pos, half: half, rot: rot)
    }
}
