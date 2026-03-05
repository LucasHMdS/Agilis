import AgilisCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Shared geometry helpers used by NarrowPhase, SpatialQuery, SweptCollision,
/// PhysicsDebugRenderer, and ShadowGeometry.
///
/// Consolidates previously duplicated transform/normal functions into a
/// single source of truth to prevent bug-fix divergence.
internal enum GeometryHelpers {

    /// Transform vertices from local space to world space.
    static func transformVertices(
        _ vertices: [Vector2],
        position: Vector2,
        rotation: Float
    ) -> [Vector2] {
        if abs(rotation) < PhysicsConstants.Tolerance.displacement {
            return vertices.map { $0 + position }
        }
        let c = cosf(rotation)
        let s = sinf(rotation)
        return vertices.map { v in
            Vector2(
                x: v.x * c - v.y * s + position.x,
                y: v.x * s + v.y * c + position.y
            )
        }
    }

    /// Transform vertices in-place into a pre-allocated buffer.
    /// The buffer is resized to match the vertex count and reused across calls.
    static func transformVertices(
        _ vertices: [Vector2],
        position: Vector2,
        rotation: Float,
        into buffer: inout [Vector2]
    ) {
        buffer.removeAll(keepingCapacity: true)
        if abs(rotation) < PhysicsConstants.Tolerance.displacement {
            for v in vertices {
                buffer.append(v + position)
            }
        } else {
            let c = cosf(rotation)
            let s = sinf(rotation)
            for v in vertices {
                buffer.append(Vector2(
                    x: v.x * c - v.y * s + position.x,
                    y: v.x * s + v.y * c + position.y
                ))
            }
        }
    }

    /// Rotate normals by a given angle.
    static func rotateNormals(
        _ normals: [Vector2],
        rotation: Float
    ) -> [Vector2] {
        if abs(rotation) < PhysicsConstants.Tolerance.displacement { return normals }
        let c = cosf(rotation)
        let s = sinf(rotation)
        return normals.map { n in
            Vector2(x: n.x * c - n.y * s, y: n.x * s + n.y * c)
        }
    }

    /// Compute outward-facing normals from vertices in CCW winding order.
    /// Degenerate edges (zero-length) are skipped to avoid zero normals corrupting SAT.
    static func computeNormals(_ vertices: [Vector2]) -> [Vector2] {
        var result: [Vector2] = []
        result.reserveCapacity(vertices.count)
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let edge = vertices[j] - vertices[i]
            let normal = Vector2(x: edge.y, y: -edge.x).normalized
            if normal.x != 0 || normal.y != 0 {
                result.append(normal)
            }
        }
        return result
    }

    /// Generate 4 world-space vertices for a rotated AABB in CCW order.
    static func rotatedAABBVertices(
        pos: Vector2,
        half: Vector2,
        rot: Float
    ) -> [Vector2] {
        let local: [Vector2] = [
            Vector2(x: -half.x, y: -half.y),
            Vector2(x: -half.x, y: half.y),
            Vector2(x: half.x, y: half.y),
            Vector2(x: half.x, y: -half.y),
        ]
        return transformVertices(local, position: pos, rotation: rot)
    }
}
