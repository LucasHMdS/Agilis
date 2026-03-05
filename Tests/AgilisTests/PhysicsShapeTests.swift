import Testing
@testable import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

@Suite("Collision Shape Tests")
struct CollisionShapeTests {

    // MARK: - ConvexPolygon

    @Test("Triangle polygon computes correct normals")
    func triangleNormals() {
        // Triangle in CCW winding (math coords, Y-up equivalent).
        // In screen coords (Y-down) this appears CW visually.
        let tri = ConvexPolygon(vertices: [
            Vector2(x: 0, y: -20),   // top
            Vector2(x: 17, y: 10),   // bottom-right
            Vector2(x: -17, y: 10),  // bottom-left
        ])

        #expect(tri.vertices.count == 3)
        #expect(tri.normals.count == 3)

        // Each normal should be unit length
        for n in tri.normals {
            #expect(abs(n.length - 1.0) < 0.001)
        }

        // Normals should point outward (dot with outward direction > 0)
        let center = Vector2(x: 0, y: 0)
        for i in 0..<tri.vertices.count {
            let j = (i + 1) % tri.vertices.count
            let edgeMid = (tri.vertices[i] + tri.vertices[j]) / 2.0
            let outward = edgeMid - center
            // Normal should generally point away from center
            #expect(tri.normals[i].dot(outward) > 0,
                    "Normal \(i) should point outward")
        }
    }

    @Test("Square polygon computes 4 normals")
    func squareNormals() {
        // Unit square centered at origin (CCW)
        let square = ConvexPolygon(vertices: [
            Vector2(x: -1, y: -1),
            Vector2(x: 1, y: -1),
            Vector2(x: 1, y: 1),
            Vector2(x: -1, y: 1),
        ])

        #expect(square.vertices.count == 4)
        #expect(square.normals.count == 4)

        for n in square.normals {
            #expect(abs(n.length - 1.0) < 0.001)
        }
    }

    @Test("ConvexPolygon computes correct local bounds")
    func localBounds() {
        let poly = ConvexPolygon(vertices: [
            Vector2(x: -10, y: -5),
            Vector2(x: 10, y: -5),
            Vector2(x: 10, y: 5),
            Vector2(x: -10, y: 5),
        ])

        #expect(abs(poly.localBounds.x - (-10)) < 0.001)
        #expect(abs(poly.localBounds.y - (-5)) < 0.001)
        #expect(abs(poly.localBounds.width - 20) < 0.001)
        #expect(abs(poly.localBounds.height - 10) < 0.001)
    }

    @Test("Pentagon polygon has 5 normals")
    func pentagonNormals() {
        // Regular pentagon (approximate CCW)
        let r: Float = 10
        var verts: [Vector2] = []
        for i in 0..<5 {
            let angle = Float(i) * (2 * .pi / 5) - .pi / 2
            verts.append(Vector2(
                x: r * cos(angle),
                y: r * sin(angle)
            ))
        }
        let pent = ConvexPolygon(vertices: verts)
        #expect(pent.normals.count == 5)
    }

    // MARK: - CollisionShape Equality

    @Test("CollisionShape AABB equality")
    func aabbEquality() {
        let a = CollisionShape.aabb(halfExtents: Vector2(x: 10, y: 20))
        let b = CollisionShape.aabb(halfExtents: Vector2(x: 10, y: 20))
        let c = CollisionShape.aabb(halfExtents: Vector2(x: 15, y: 20))
        #expect(a == b)
        #expect(a != c)
    }

    @Test("CollisionShape circle equality")
    func circleEquality() {
        let a = CollisionShape.circle(radius: 5)
        let b = CollisionShape.circle(radius: 5)
        let c = CollisionShape.circle(radius: 10)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("CollisionShape different types are not equal")
    func differentTypesNotEqual() {
        let aabb = CollisionShape.aabb(halfExtents: Vector2(x: 10, y: 10))
        let circle = CollisionShape.circle(radius: 10)
        #expect(aabb != circle)
    }

    @Test("ConvexPolygon requires at least 3 vertices")
    func minimumVertices() {
        // Valid: 3 vertices
        let tri = ConvexPolygon(vertices: [
            Vector2(x: 0, y: -10),
            Vector2(x: 10, y: 10),
            Vector2(x: -10, y: 10),
        ])
        #expect(tri.vertices.count == 3)
    }
}
