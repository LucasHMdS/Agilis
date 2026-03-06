

/// A convex polygon defined by vertices in local (body-relative) space.
/// Vertices must be in counter-clockwise winding order and form a convex shape.
public struct ConvexPolygon: Sendable, Equatable, Codable {
    /// Vertices in local space, counter-clockwise winding.
    public let vertices: [Vector2]

    /// Outward-facing edge normals (unit vectors), precomputed.
    /// `normals[i]` is the normal of the edge from `vertices[i]` to `vertices[(i+1) % count]`.
    public let normals: [Vector2]

    /// Axis-aligned bounding box in local space.
    public let localBounds: Rect

    /// Creates a convex polygon from vertices in counter-clockwise winding order.
    /// Normals and local bounds are computed automatically.
    ///
    /// - Parameter vertices: At least 3 vertices forming a convex polygon in CCW order.
    public init(vertices: [Vector2]) {
        guard vertices.count >= 3 else {
            fatalError("ConvexPolygon requires at least 3 vertices, got \(vertices.count)")
        }

        // Validate CCW winding via signed area (shoelace formula).
        // Positive = CCW in standard math coords. CW polygons produce
        // inward normals that silently break SAT collision detection.
        var signedArea2: Float = 0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            signedArea2 += vertices[i].x * vertices[j].y
            signedArea2 -= vertices[j].x * vertices[i].y
        }
        guard signedArea2 > 0 else {
            fatalError(
                "ConvexPolygon vertices must be in counter-clockwise order "
                + "(signed area = \(signedArea2 * 0.5)). Reverse the vertex array."
            )
        }

        self.vertices = vertices

        // Compute outward-facing normals for each edge
        var computedNormals: [Vector2] = []
        computedNormals.reserveCapacity(vertices.count)
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let edge = vertices[j] - vertices[i]
            // Right-hand perpendicular (outward for CCW winding)
            let normal = Vector2(x: edge.y, y: -edge.x).normalized
            computedNormals.append(normal)
        }
        self.normals = computedNormals

        // Compute local AABB
        var minX = vertices[0].x
        var maxX = vertices[0].x
        var minY = vertices[0].y
        var maxY = vertices[0].y
        for i in 1..<vertices.count {
            let v = vertices[i]
            if v.x < minX { minX = v.x }
            if v.x > maxX { maxX = v.x }
            if v.y < minY { minY = v.y }
            if v.y > maxY { maxY = v.y }
        }
        self.localBounds = Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Codable (vertices only — normals and bounds recompute on decode)

    private enum CodingKeys: String, CodingKey {
        case vertices
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vertices, forKey: .vertices)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let verts = try container.decode([Vector2].self, forKey: .vertices)
        self.init(vertices: verts)
    }
}

/// A collision shape attached to a `Collider2D`. Uses an enum to avoid existential overhead.
public enum CollisionShape: Sendable, Equatable, Codable {
    /// Axis-aligned bounding box defined by half-extents (half-width, half-height).
    case aabb(halfExtents: Vector2)

    /// Circle defined by radius.
    case circle(radius: Float)

    /// Convex polygon with precomputed normals and local bounds.
    case polygon(ConvexPolygon)
}
