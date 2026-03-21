#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - Result Types

/// The result of a ray intersecting an entity's collider.
///
/// Contains the entity that was hit, the world-space contact point,
/// the surface normal at the hit point, and the distance from the ray origin.
public struct RaycastHit: Sendable {
    /// The entity whose collider was hit.
    public let entity: Entity
    /// World-space point where the ray intersects the collider surface.
    public let point: Vector2
    /// Surface normal at the hit point (unit vector, pointing outward).
    public let normal: Vector2
    /// Distance from the ray origin to the hit point (>= 0).
    public let distance: Float

    public init(entity: Entity, point: Vector2, normal: Vector2, distance: Float) {
        self.entity = entity
        self.point = point
        self.normal = normal
        self.distance = distance
    }
}

/// An entity whose collider contains a queried point.
public struct PointQueryResult: Sendable {
    /// The entity whose collider contains the point.
    public let entity: Entity

    public init(entity: Entity) {
        self.entity = entity
    }
}

/// An entity whose collider overlaps a queried rectangle.
public struct AreaQueryResult: Sendable {
    /// The entity whose collider overlaps the query area.
    public let entity: Entity

    public init(entity: Entity) {
        self.entity = entity
    }
}

// MARK: - SpatialQuery

/// Pure geometry functions for spatial queries: ray casting, point tests, and area overlap.
///
/// Analogous to `NarrowPhase` for collision detection. Each function operates on
/// raw geometry (positions, shapes, vertices) without ECS knowledge.
///
/// The `PhysicsWorld2D` extension in `PhysicsWorld2D+Queries.swift` provides
/// the high-level ECS-integrated API that calls these geometry functions.
public enum SpatialQuery {

    // MARK: - Ray Intersection

    /// Result of a ray-shape intersection (internal tuple, converted to RaycastHit by callers).
    public typealias RayHit = (distance: Float, point: Vector2, normal: Vector2)

    /// Cast a ray against a collision shape at a given position and rotation.
    ///
    /// Dispatches to the appropriate shape-specific test, handling rotation
    /// by promoting AABBs to polygons and transforming polygon vertices.
    ///
    /// - Parameters:
    ///   - origin: Ray start point in world space.
    ///   - direction: Normalized ray direction.
    ///   - tMax: Maximum ray distance.
    ///   - shape: The collision shape to test.
    ///   - shapePos: World-space position of the shape center.
    ///   - shapeRot: Rotation of the shape in radians.
    /// - Returns: Hit info, or nil if no intersection within tMax.
    public static func raycast(
        origin: Vector2,
        direction: Vector2,
        tMax: Float,
        shape: CollisionShape,
        shapePos: Vector2,
        shapeRot: Float
    ) -> RayHit? {
        switch shape {
        case .aabb(let halfExtents):
            if shapeRot == 0 {
                return rayVsAABB(
                    origin: origin,
                    direction: direction,
                    tMax: tMax,
                    aabbPos: shapePos,
                    halfExtents: halfExtents
                )
            }
            // Rotated AABB: promote to polygon
            let verts = rotatedAABBVertices(pos: shapePos, half: halfExtents, rot: shapeRot)
            return rayVsPolygon(
                origin: origin,
                direction: direction,
                tMax: tMax,
                vertices: verts
            )

        case .circle(let radius):
            return rayVsCircle(
                origin: origin,
                direction: direction,
                tMax: tMax,
                circlePos: shapePos,
                radius: radius
            )

        case .polygon(let poly):
            let verts = transformVertices(poly.vertices, position: shapePos, rotation: shapeRot)
            return rayVsPolygon(
                origin: origin,
                direction: direction,
                tMax: tMax,
                vertices: verts
            )
        }
    }

    /// Cast a ray against an axis-aligned bounding box (slab method).
    public static func rayVsAABB(
        origin: Vector2,
        direction: Vector2,
        tMax: Float,
        aabbPos: Vector2,
        halfExtents: Vector2
    ) -> RayHit? {
        let minX = aabbPos.x - halfExtents.x
        let maxX = aabbPos.x + halfExtents.x
        let minY = aabbPos.y - halfExtents.y
        let maxY = aabbPos.y + halfExtents.y

        var tNear: Float = -.greatestFiniteMagnitude
        var tFar: Float = .greatestFiniteMagnitude
        var nearNormal = Vector2.zero

        // X axis slab
        if abs(direction.x) < PhysicsConstants.Tolerance.crossProduct {
            // Ray is parallel to X slab
            if origin.x < minX || origin.x > maxX { return nil }
        } else {
            let invD = 1.0 / direction.x
            var t1 = (minX - origin.x) * invD
            var t2 = (maxX - origin.x) * invD
            var normal = Vector2(x: -1, y: 0)
            if t1 > t2 {
                swap(&t1, &t2)
                normal = Vector2(x: 1, y: 0)
            }
            if t1 > tNear {
                tNear = t1
                nearNormal = normal
            }
            tFar = min(tFar, t2)
            if tNear > tFar { return nil }
        }

        // Y axis slab
        if abs(direction.y) < PhysicsConstants.Tolerance.crossProduct {
            if origin.y < minY || origin.y > maxY { return nil }
        } else {
            let invD = 1.0 / direction.y
            var t1 = (minY - origin.y) * invD
            var t2 = (maxY - origin.y) * invD
            var normal = Vector2(x: 0, y: -1)
            if t1 > t2 {
                swap(&t1, &t2)
                normal = Vector2(x: 0, y: 1)
            }
            if t1 > tNear {
                tNear = t1
                nearNormal = normal
            }
            tFar = min(tFar, t2)
            if tNear > tFar { return nil }
        }

        // Check valid hit range
        if tFar < 0 { return nil }

        if tNear < 0 {
            // Ray origin is inside the AABB
            return (distance: 0, point: origin, normal: .zero)
        }

        if tNear > tMax { return nil }

        let point = origin + direction * tNear
        return (distance: tNear, point: point, normal: nearNormal)
    }

    /// Cast a ray against a circle (quadratic formula).
    public static func rayVsCircle(
        origin: Vector2,
        direction: Vector2,
        tMax: Float,
        circlePos: Vector2,
        radius: Float
    ) -> RayHit? {
        let oc = origin - circlePos
        let a = direction.dot(direction)  // 1.0 if normalized
        let b = 2.0 * oc.dot(direction)
        let c = oc.dot(oc) - radius * radius

        guard a > 1e-12 else { return nil }  // zero-length direction

        let discriminant = b * b - 4.0 * a * c
        guard discriminant >= 0 else { return nil }

        let sqrtDisc = sqrtf(discriminant)
        let invA2 = 1.0 / (2.0 * a)
        let t0 = (-b - sqrtDisc) * invA2
        let t1 = (-b + sqrtDisc) * invA2

        // Pick the smallest non-negative t
        let t: Float
        if t0 >= 0 && t0 <= tMax {
            t = t0
        } else if t1 >= 0 && t1 <= tMax {
            // Ray starts inside the circle (t0 < 0)
            if t0 < 0 {
                return (distance: 0, point: origin, normal: .zero)
            }
            t = t1
        } else {
            return nil
        }

        let point = origin + direction * t
        let normal = (point - circlePos).normalized
        return (distance: t, point: point, normal: normal)
    }

    /// Cast a ray against a convex polygon using edge-segment intersection.
    ///
    /// Tests the ray against each edge of the polygon and returns the closest
    /// intersection. Works for any vertex winding order.
    ///
    /// - Parameters:
    ///   - origin: Ray start point in world space.
    ///   - direction: Normalized ray direction.
    ///   - tMax: Maximum ray distance.
    ///   - vertices: World-space polygon vertices (convex, ordered CW or CCW).
    /// - Returns: Hit info, or nil if no intersection within tMax.
    public static func rayVsPolygon(
        origin: Vector2,
        direction: Vector2,
        tMax: Float,
        vertices: [Vector2]
    ) -> RayHit? {
        guard vertices.count >= 3 else { return nil }

        // Check if origin is inside the polygon
        if pointInPolygon(point: origin, vertices: vertices) {
            return (distance: 0, point: origin, normal: .zero)
        }

        // Test ray against each edge segment
        var closestT = tMax
        var hitNormal = Vector2.zero
        var found = false

        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let v0 = vertices[i]
            let v1 = vertices[j]
            let edge = v1 - v0

            // Solve: origin + t * direction = v0 + s * edge
            // Using 2D cross product: t = (v0-origin) × edge / (direction × edge)
            let denom = direction.x * edge.y - direction.y * edge.x
            if abs(denom) < PhysicsConstants.Tolerance.crossProduct { continue } // parallel

            let dx = v0.x - origin.x
            let dy = v0.y - origin.y

            let t = (dx * edge.y - dy * edge.x) / denom
            let s = (dx * direction.y - dy * direction.x) / denom

            if t >= 0 && t <= closestT && s >= 0 && s <= 1 {
                closestT = t
                // Pick edge normal that faces toward ray origin
                let rawN = Vector2(x: edge.y, y: -edge.x)
                hitNormal = (denom < 0 ? rawN : Vector2(x: -rawN.x, y: -rawN.y)).normalized
                found = true
            }
        }

        guard found else { return nil }
        let point = origin + direction * closestT
        return (distance: closestT, point: point, normal: hitNormal)
    }

    // MARK: - Point-in-Shape

    /// Test whether a point is inside a collision shape at a given position and rotation.
    public static func pointTest(
        point: Vector2,
        shape: CollisionShape,
        shapePos: Vector2,
        shapeRot: Float
    ) -> Bool {
        switch shape {
        case .aabb(let halfExtents):
            if shapeRot == 0 {
                return pointInAABB(point: point, aabbPos: shapePos, halfExtents: halfExtents)
            }
            let verts = rotatedAABBVertices(pos: shapePos, half: halfExtents, rot: shapeRot)
            return pointInPolygon(point: point, vertices: verts)

        case .circle(let radius):
            return pointInCircle(point: point, circlePos: shapePos, radius: radius)

        case .polygon(let poly):
            let verts = transformVertices(poly.vertices, position: shapePos, rotation: shapeRot)
            return pointInPolygon(point: point, vertices: verts)
        }
    }

    /// Test whether a point is inside an axis-aligned bounding box.
    public static func pointInAABB(
        point: Vector2,
        aabbPos: Vector2,
        halfExtents: Vector2
    ) -> Bool {
        abs(point.x - aabbPos.x) <= halfExtents.x &&
        abs(point.y - aabbPos.y) <= halfExtents.y
    }

    /// Test whether a point is inside a circle.
    public static func pointInCircle(
        point: Vector2,
        circlePos: Vector2,
        radius: Float
    ) -> Bool {
        (point - circlePos).lengthSquared <= radius * radius
    }

    /// Test whether a point is inside a convex polygon.
    ///
    /// Uses the cross-product winding test: a point is inside a convex polygon
    /// if all cross products of (edge × point-to-vertex) have the same sign.
    /// Works for both CW and CCW vertex orderings.
    public static func pointInPolygon(
        point: Vector2,
        vertices: [Vector2]
    ) -> Bool {
        guard vertices.count >= 3 else { return false }
        var positive = false
        var negative = false
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let edge = vertices[j] - vertices[i]
            let toPoint = point - vertices[i]
            let cross = edge.x * toPoint.y - edge.y * toPoint.x
            if cross > 0 { positive = true }
            if cross < 0 { negative = true }
            if positive && negative { return false }
        }
        return true
    }

    // MARK: - Area Overlap

    /// Test whether a rectangle overlaps a collision shape at a given position and rotation.
    public static func areaTest(
        rect: Rect,
        shape: CollisionShape,
        shapePos: Vector2,
        shapeRot: Float
    ) -> Bool {
        switch shape {
        case .aabb(let halfExtents):
            if shapeRot == 0 {
                return rectOverlapsAABB(rect: rect, aabbPos: shapePos, halfExtents: halfExtents)
            }
            let verts = rotatedAABBVertices(pos: shapePos, half: halfExtents, rot: shapeRot)
            let norms = computeNormals(verts)
            return rectOverlapsPolygon(rect: rect, vertices: verts, normals: norms)

        case .circle(let radius):
            return rectOverlapsCircle(rect: rect, circlePos: shapePos, radius: radius)

        case .polygon(let poly):
            let verts = transformVertices(poly.vertices, position: shapePos, rotation: shapeRot)
            let norms = rotateNormals(poly.normals, rotation: shapeRot)
            return rectOverlapsPolygon(rect: rect, vertices: verts, normals: norms)
        }
    }

    /// Test whether a rectangle overlaps an axis-aligned bounding box.
    public static func rectOverlapsAABB(
        rect: Rect,
        aabbPos: Vector2,
        halfExtents: Vector2
    ) -> Bool {
        let shapeRect = Rect(
            x: aabbPos.x - halfExtents.x,
            y: aabbPos.y - halfExtents.y,
            width: halfExtents.x * 2,
            height: halfExtents.y * 2
        )
        return rect.intersects(shapeRect)
    }

    /// Test whether a rectangle overlaps a circle.
    ///
    /// Finds the closest point on the rectangle to the circle center,
    /// then checks if the distance is within the radius.
    public static func rectOverlapsCircle(
        rect: Rect,
        circlePos: Vector2,
        radius: Float
    ) -> Bool {
        let closestX = clamp(circlePos.x, min: rect.minX, max: rect.maxX)
        let closestY = clamp(circlePos.y, min: rect.minY, max: rect.maxY)
        let dx = circlePos.x - closestX
        let dy = circlePos.y - closestY
        return dx * dx + dy * dy <= radius * radius
    }

    /// Test whether a rectangle overlaps a convex polygon using SAT.
    ///
    /// Tests the 2 rect axes (x, y) and all polygon normals as potential
    /// separating axes.
    public static func rectOverlapsPolygon(
        rect: Rect,
        vertices: [Vector2],
        normals: [Vector2]
    ) -> Bool {
        guard vertices.count >= 3 else { return false }

        let rectCenter = rect.center
        let rectHalfW = rect.width * 0.5
        let rectHalfH = rect.height * 0.5

        // Test X axis (1, 0)
        let (polyMinX, polyMaxX) = projectVerticesOnAxis(vertices, axis: Vector2.unitX)
        let rectMinX = rectCenter.x - rectHalfW
        let rectMaxX = rectCenter.x + rectHalfW
        if polyMaxX < rectMinX || polyMinX > rectMaxX { return false }

        // Test Y axis (0, 1)
        let (polyMinY, polyMaxY) = projectVerticesOnAxis(vertices, axis: Vector2.unitY)
        let rectMinY = rectCenter.y - rectHalfH
        let rectMaxY = rectCenter.y + rectHalfH
        if polyMaxY < rectMinY || polyMinY > rectMaxY { return false }

        // Test polygon normals
        for normal in normals {
            let (polyMin, polyMax) = projectVerticesOnAxis(vertices, axis: normal)
            // Project rect using AABB shortcut
            let rectProj = rectCenter.dot(normal)
            let rectExtent = abs(rectHalfW * normal.x) + abs(rectHalfH * normal.y)
            let rectMinProj = rectProj - rectExtent
            let rectMaxProj = rectProj + rectExtent
            if polyMax < rectMinProj || polyMin > rectMaxProj { return false }
        }

        return true
    }

    // MARK: - Private Helpers

    /// Project all vertices onto an axis and return (min, max) projections.
    private static func projectVerticesOnAxis(_ vertices: [Vector2], axis: Vector2) -> (min: Float, max: Float) {
        var minProj = vertices[0].dot(axis)
        var maxProj = minProj
        for i in 1..<vertices.count {
            let proj = vertices[i].dot(axis)
            if proj < minProj { minProj = proj }
            if proj > maxProj { maxProj = proj }
        }
        return (minProj, maxProj)
    }

    // Delegates to GeometryHelpers for shared implementations
    private static func transformVertices(_ vertices: [Vector2], position: Vector2, rotation: Float) -> [Vector2] {
        GeometryHelpers.transformVertices(vertices, position: position, rotation: rotation)
    }

    private static func rotateNormals(_ normals: [Vector2], rotation: Float) -> [Vector2] {
        GeometryHelpers.rotateNormals(normals, rotation: rotation)
    }

    private static func rotatedAABBVertices(pos: Vector2, half: Vector2, rot: Float) -> [Vector2] {
        GeometryHelpers.rotatedAABBVertices(pos: pos, half: half, rot: rot)
    }

    private static func computeNormals(_ vertices: [Vector2]) -> [Vector2] {
        GeometryHelpers.computeNormals(vertices)
    }
}
