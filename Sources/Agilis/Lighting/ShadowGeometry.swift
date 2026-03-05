import AgilisCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Computed shadow volume for a single occluder relative to a light.
public struct ShadowVolume: Sendable {
    /// Vertices of the shadow polygon in world space, suitable for triangle-fan rendering.
    /// Ordered for triangle-fan rendering from the first vertex.
    public let vertices: [Vector2]
}

/// Input data for a shadow-casting occluder.
public struct ShadowOccluder: Sendable {
    public let shape: CollisionShape
    public let position: Vector2
    public let rotation: Float
    public let offset: Vector2

    public init(shape: CollisionShape, position: Vector2, rotation: Float = 0, offset: Vector2 = .zero) {
        self.shape = shape
        self.position = position
        self.rotation = rotation
        self.offset = offset
    }
}

/// Pure geometry functions for computing 2D shadow volumes.
///
/// For each shadow caster, computes the "silhouette" as seen from the light,
/// then projects it outward to form a shadow polygon that occludes light behind
/// the caster.
///
/// Analogous to `SpatialQuery` and `NarrowPhase` -- pure functions, no state.
public enum ShadowGeometry {

    // MARK: - Public API

    /// Compute shadow volumes for all occluders relative to a point light.
    ///
    /// - Parameters:
    ///   - lightPosition: The light's world-space position.
    ///   - lightRadius: Maximum distance the light reaches.
    ///   - occluders: Shadow-casting shapes with their transforms.
    ///   - shadowExtent: How far shadow volumes extend past the occluder.
    ///     Pass 0 or negative to use `lightRadius` as the extent.
    ///   - shadowBloat: Expand occluder shapes by this many pixels to prevent
    ///     light leaks at corners where adjacent occluders meet. Default 0 (no expansion).
    /// - Returns: An array of shadow volumes, one per occluder that is within range
    ///   and produces a valid shadow.
    public static func computeShadows(
        lightPosition: Vector2,
        lightRadius: Float,
        occluders: [ShadowOccluder],
        shadowExtent: Float = 0,
        shadowBloat: Float = 0
    ) -> [ShadowVolume] {
        let extent = shadowExtent > 0 ? shadowExtent : lightRadius
        var results: [ShadowVolume] = []
        results.reserveCapacity(occluders.count)

        for occluder in occluders {
            let worldOffset = rotatePoint(occluder.offset, by: occluder.rotation)
            let occluderCenter = occluder.position + worldOffset

            switch occluder.shape {
            case .aabb(let halfExtents):
                // Expand AABB slightly to prevent corner light leaks
                let bloatedExtents = shadowBloat > 0
                    ? Vector2(x: halfExtents.x + shadowBloat, y: halfExtents.y + shadowBloat)
                    : halfExtents
                // Convert AABB to polygon vertices in local space
                let localVerts = aabbVertices(halfExtents: bloatedExtents)
                let worldVerts = transformVertices(localVerts, position: occluderCenter, rotation: occluder.rotation)

                // Quick distance check
                let dist = lightPosition.distance(to: occluderCenter)
                let maxHalf = max(bloatedExtents.x, bloatedExtents.y)
                if dist > lightRadius + maxHalf { continue }

                if let shadow = shadowForPolygon(lightPos: lightPosition, vertices: worldVerts, shadowExtent: extent) {
                    results.append(shadow)
                }

            case .circle(let radius):
                let dist = lightPosition.distance(to: occluderCenter)
                if dist > lightRadius + radius { continue }

                if let shadow = shadowForCircle(lightPos: lightPosition, center: occluderCenter, radius: radius, shadowExtent: extent) {
                    results.append(shadow)
                }

            case .polygon(let poly):
                let worldVerts = transformVertices(poly.vertices, position: occluderCenter, rotation: occluder.rotation)

                // Quick distance check using local bounds
                let boundsRadius = Vector2(x: poly.localBounds.width, y: poly.localBounds.height).length * 0.5
                let dist = lightPosition.distance(to: occluderCenter)
                if dist > lightRadius + boundsRadius { continue }

                if let shadow = shadowForPolygon(lightPos: lightPosition, vertices: worldVerts, shadowExtent: extent) {
                    results.append(shadow)
                }
            }
        }

        return results
    }

    // MARK: - Polygon Shadows

    /// Compute the shadow polygon for a convex polygon occluder.
    ///
    /// Algorithm:
    /// 1. Classify each edge as facing toward or away from the light (via outward normal).
    /// 2. Find the two silhouette boundary vertices where facing transitions.
    /// 3. Collect back-facing vertices and project silhouette vertices outward.
    /// 4. Build the shadow polygon.
    ///
    /// For a convex shape, there are exactly two facing transitions (silhouette edges).
    static func shadowForPolygon(
        lightPos: Vector2,
        vertices: [Vector2],
        shadowExtent: Float
    ) -> ShadowVolume? {
        let n = vertices.count
        guard n >= 3 else { return nil }

        // Check if light is inside the polygon
        if pointInConvexPolygon(lightPos, vertices: vertices) {
            return nil
        }

        // Classify each edge: is its outward normal facing toward the light?
        var facing = [Bool](repeating: false, count: n)
        for i in 0..<n {
            let j = (i + 1) % n
            let edge = vertices[j] - vertices[i]
            // Outward normal for CCW winding: (edge.y, -edge.x)
            let normal = Vector2(x: edge.y, y: -edge.x)
            let midpoint = Vector2(x: (vertices[i].x + vertices[j].x) * 0.5,
                                   y: (vertices[i].y + vertices[j].y) * 0.5)
            let toLight = lightPos - midpoint
            facing[i] = normal.dot(toLight) > 0
        }

        // Find the two silhouette boundary indices
        // Silhouette A: where facing transitions from true -> false (vertex at the start of the back-facing run)
        // Silhouette B: where facing transitions from false -> true
        var silhouetteA = -1
        var silhouetteB = -1

        for i in 0..<n {
            let prev = (i + n - 1) % n
            if facing[prev] && !facing[i] {
                // Transition from light-facing to back-facing: vertex i is silhouette A
                silhouetteA = i
            }
            if !facing[prev] && facing[i] {
                // Transition from back-facing to light-facing: vertex i is silhouette B
                silhouetteB = i
            }
        }

        guard silhouetteA >= 0 && silhouetteB >= 0 else { return nil }

        // Build shadow polygon:
        // projected(A) -> A -> back-facing vertices A..B -> B -> projected(B)
        var shadowVerts: [Vector2] = []
        shadowVerts.reserveCapacity(n + 4)

        let vertA = vertices[silhouetteA]
        let vertB = vertices[silhouetteB]

        // Projected silhouette vertex A (away from light)
        let dirA = (vertA - lightPos).normalized
        let projA = vertA + dirA * shadowExtent
        shadowVerts.append(projA)

        // Walk from A to B collecting back-facing vertices
        var idx = silhouetteA
        while true {
            shadowVerts.append(vertices[idx])
            if idx == silhouetteB { break }
            idx = (idx + 1) % n
            // Safety: prevent infinite loop if silhouette detection failed
            if shadowVerts.count > n + 4 { return nil }
        }

        // Projected silhouette vertex B (away from light)
        let dirB = (vertB - lightPos).normalized
        let projB = vertB + dirB * shadowExtent
        shadowVerts.append(projB)

        return ShadowVolume(vertices: shadowVerts)
    }

    // MARK: - Circle Shadows

    /// Compute the shadow polygon for a circle occluder.
    ///
    /// Algorithm:
    /// 1. Compute the two tangent points from the light position to the circle.
    /// 2. Approximate the back arc of the circle (the side away from the light) with segments.
    /// 3. Project the tangent points outward.
    /// 4. Build the shadow polygon.
    static func shadowForCircle(
        lightPos: Vector2,
        center: Vector2,
        radius: Float,
        shadowExtent: Float,
        arcSegments: Int = 10
    ) -> ShadowVolume? {
        let toCenter = center - lightPos
        let dist = toCenter.length

        // Light is inside the circle -- no shadow
        guard dist > radius else { return nil }

        // Angle from light to center
        let baseAngle = atan2f(toCenter.y, toCenter.x)

        // Half-angle of the tangent
        let halfAngle = asinf(radius / dist)

        // Tangent directions from light
        let tangentAngleA = baseAngle + halfAngle
        let tangentAngleB = baseAngle - halfAngle

        // Tangent points on the circle
        // The tangent point is where the tangent line touches the circle.
        // Project from the light along the tangent direction to the perpendicular distance.
        let tangentDist = sqrtf(dist * dist - radius * radius)
        let tangentA = lightPos + Vector2(x: cosf(tangentAngleA), y: sinf(tangentAngleA)) * tangentDist
        let tangentB = lightPos + Vector2(x: cosf(tangentAngleB), y: sinf(tangentAngleB)) * tangentDist

        // Project tangent points away from light
        let dirA = (tangentA - lightPos).normalized
        let projA = tangentA + dirA * shadowExtent
        let dirB = (tangentB - lightPos).normalized
        let projB = tangentB + dirB * shadowExtent

        // Build shadow polygon: projA -> tangentA -> arc (back side) -> tangentB -> projB
        var shadowVerts: [Vector2] = []
        shadowVerts.reserveCapacity(arcSegments + 4)

        shadowVerts.append(projA)
        shadowVerts.append(tangentA)

        // Arc on the back side of the circle (from tangentA angle to tangentB angle, going away from light)
        let angleA = atan2f(tangentA.y - center.y, tangentA.x - center.x)
        let angleB = atan2f(tangentB.y - center.y, tangentB.x - center.x)

        // Walk from angleA to angleB going through the back side (away from light)
        // The back side is the arc that goes through (baseAngle + PI)
        let backAngle = baseAngle + .pi
        var startAngle = angleA
        var endAngle = angleB

        // Ensure we walk through the back side
        // Normalize angles relative to backAngle
        while startAngle > backAngle + .pi { startAngle -= 2 * .pi }
        while startAngle < backAngle - .pi { startAngle += 2 * .pi }
        while endAngle > backAngle + .pi { endAngle -= 2 * .pi }
        while endAngle < backAngle - .pi { endAngle += 2 * .pi }

        // Ensure we go from startAngle to endAngle in the direction that passes through backAngle
        if endAngle < startAngle {
            endAngle += 2 * .pi
        }

        let arcCount = max(2, arcSegments)
        for i in 1..<arcCount {
            let t = Float(i) / Float(arcCount)
            let angle = startAngle + (endAngle - startAngle) * t
            let arcPoint = center + Vector2(x: cosf(angle), y: sinf(angle)) * radius
            shadowVerts.append(arcPoint)
        }

        shadowVerts.append(tangentB)
        shadowVerts.append(projB)

        return ShadowVolume(vertices: shadowVerts)
    }

    // MARK: - Helpers

    static func transformVertices(
        _ vertices: [Vector2],
        position: Vector2,
        rotation: Float
    ) -> [Vector2] {
        GeometryHelpers.transformVertices(vertices, position: position, rotation: rotation)
    }

    /// Generate AABB corner vertices in local space (CCW winding).
    static func aabbVertices(halfExtents: Vector2) -> [Vector2] {
        [
            Vector2(x: -halfExtents.x, y: -halfExtents.y),  // bottom-left
            Vector2(x:  halfExtents.x, y: -halfExtents.y),  // bottom-right
            Vector2(x:  halfExtents.x, y:  halfExtents.y),  // top-right
            Vector2(x: -halfExtents.x, y:  halfExtents.y),  // top-left
        ]
    }

    /// Rotate a point around the origin by a given angle.
    private static func rotatePoint(_ point: Vector2, by angle: Float) -> Vector2 {
        if angle == 0 { return point }
        let c = cosf(angle)
        let s = sinf(angle)
        return Vector2(x: point.x * c - point.y * s, y: point.x * s + point.y * c)
    }

    /// Test if a point is inside a convex polygon (CCW winding).
    /// Uses cross-product winding test.
    private static func pointInConvexPolygon(_ point: Vector2, vertices: [Vector2]) -> Bool {
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            let edge = vertices[j] - vertices[i]
            let toPoint = point - vertices[i]
            // For CCW winding, point is inside if all cross products are positive
            if edge.cross(toPoint) < 0 {
                return false
            }
        }
        return true
    }
}
