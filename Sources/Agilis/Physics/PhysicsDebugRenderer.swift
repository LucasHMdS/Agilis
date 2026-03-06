

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - Options

/// Configuration for physics debug rendering.
///
/// Controls which overlays are drawn, their colors, and line thicknesses.
///
/// ## Usage
/// ```swift
/// var options = PhysicsDebugRendererOptions()
/// options.drawVelocities = true
/// options.dynamicColor = .blue
/// app.renderer.drawPhysicsDebug(world: app.world, options: options)
/// ```
public struct PhysicsDebugRendererOptions: Sendable {
    /// Draw collider shape outlines.
    public var drawColliders: Bool
    /// Draw contact points and normals from collision events.
    public var drawContacts: Bool
    /// Draw velocity vectors for entities with `Velocity2D`.
    public var drawVelocities: Bool
    /// Draw surface normals on collider shapes.
    public var drawNormals: Bool
    /// Draw joint connections and anchor points.
    public var drawJoints: Bool
    /// Draw CCD sweep paths (previous position to current position) for CCD-enabled bodies.
    public var drawCCDPaths: Bool

    /// Line thickness for collider outlines.
    public var colliderThickness: Float
    /// Length of drawn surface normals in pixels.
    public var normalLength: Float
    /// Scale factor for velocity vectors (pixels per unit velocity).
    public var velocityScale: Float
    /// Radius of drawn contact points.
    public var contactPointRadius: Float

    /// Color for dynamic body colliders.
    public var dynamicColor: Color
    /// Color for kinematic body colliders.
    public var kinematicColor: Color
    /// Color for static body colliders.
    public var staticColor: Color
    /// Color for trigger colliders.
    public var triggerColor: Color
    /// Color for contact points and normals.
    public var contactColor: Color
    /// Color for velocity vectors.
    public var velocityColor: Color
    /// Color for surface normals.
    public var normalColor: Color
    /// Color for joint connection lines.
    public var jointColor: Color
    /// Color for joint anchor points.
    public var jointAnchorColor: Color
    /// Radius of drawn joint anchor points.
    public var jointAnchorRadius: Float
    /// Color for CCD sweep path lines.
    public var ccdPathColor: Color

    /// Create debug rendering options with default values.
    public init(
        drawColliders: Bool = true,
        drawContacts: Bool = true,
        drawVelocities: Bool = false,
        drawNormals: Bool = false,
        drawJoints: Bool = true,
        drawCCDPaths: Bool = false,
        colliderThickness: Float = 1.0,
        normalLength: Float = 15.0,
        velocityScale: Float = 0.1,
        contactPointRadius: Float = 3.0,
        dynamicColor: Color = .cyan,
        kinematicColor: Color = .yellow,
        staticColor: Color = .gray,
        triggerColor: Color = .green,
        contactColor: Color = .red,
        velocityColor: Color = .magenta,
        normalColor: Color = Color(r: 255, g: 165, b: 0),
        jointColor: Color = Color(r: 0, g: 200, b: 255),
        jointAnchorColor: Color = Color(r: 255, g: 200, b: 0),
        jointAnchorRadius: Float = 4.0,
        ccdPathColor: Color = Color(r: 255, g: 100, b: 0)
    ) {
        self.drawColliders = drawColliders
        self.drawContacts = drawContacts
        self.drawVelocities = drawVelocities
        self.drawNormals = drawNormals
        self.drawJoints = drawJoints
        self.drawCCDPaths = drawCCDPaths
        self.colliderThickness = colliderThickness
        self.normalLength = normalLength
        self.velocityScale = velocityScale
        self.contactPointRadius = contactPointRadius
        self.dynamicColor = dynamicColor
        self.kinematicColor = kinematicColor
        self.staticColor = staticColor
        self.triggerColor = triggerColor
        self.contactColor = contactColor
        self.velocityColor = velocityColor
        self.normalColor = normalColor
        self.jointColor = jointColor
        self.jointAnchorColor = jointAnchorColor
        self.jointAnchorRadius = jointAnchorRadius
        self.ccdPathColor = ccdPathColor
    }
}

// MARK: - Renderer Extension

extension RenderBackend {

    /// Draw physics debug overlays for all entities with colliders.
    ///
    /// Renders collider outlines color-coded by body type, contact points,
    /// collision normals, and velocity vectors.
    ///
    /// Call this in your scene's `render()` method, typically last so the
    /// debug overlays appear on top of everything.
    ///
    /// ## Usage
    /// ```swift
    /// override func render(app: Application, interpolation: Double) {
    ///     // ... draw sprites ...
    ///     app.renderer.drawPhysicsDebug(world: app.world)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - world: The ECS world containing physics entities.
    ///   - events: Collision events from the current frame (for contact point visualization).
    ///   - options: Rendering options controlling colors, toggles, and thicknesses.
    public func drawPhysicsDebug(
        world: World,
        events: [CollisionEvent] = [],
        options: PhysicsDebugRendererOptions = PhysicsDebugRendererOptions()
    ) {
        // Draw collider outlines
        if options.drawColliders || options.drawNormals {
            world.forEach { (entity: Entity, transform: inout Transform2D, collider: inout Collider2D) in
                let color = colliderColor(
                    for: entity,
                    collider: collider,
                    world: world,
                    options: options
                )

                let worldPos = transform.position + collider.offset

                if options.drawColliders {
                    drawColliderShape(
                        shape: collider.shape,
                        position: worldPos,
                        rotation: transform.rotation,
                        color: color,
                        thickness: options.colliderThickness
                    )
                }

                if options.drawNormals {
                    drawShapeNormals(
                        shape: collider.shape,
                        position: worldPos,
                        rotation: transform.rotation,
                        length: options.normalLength,
                        color: options.normalColor,
                        thickness: options.colliderThickness
                    )
                }
            }
        }

        // Draw contact points and normals
        if options.drawContacts {
            for event in events {
                guard event.type == .began || event.type == .ongoing,
                      let contact = event.contact else { continue }

                // Contact point
                drawCircle(
                    center: contact.point,
                    radius: options.contactPointRadius,
                    color: options.contactColor
                )

                // Contact normal
                let normalEnd = contact.point + contact.normal * options.normalLength
                drawLine(
                    from: contact.point,
                    to: normalEnd,
                    color: options.contactColor,
                    thickness: options.colliderThickness
                )
            }
        }

        // Draw velocity vectors
        if options.drawVelocities {
            world.forEach { (_: Entity, transform: inout Transform2D, velocity: inout Velocity2D) in
                let speed = velocity.linear.x * velocity.linear.x + velocity.linear.y * velocity.linear.y
                guard speed > 0.001 else { return }

                let endPoint = transform.position + velocity.linear * options.velocityScale
                drawLine(
                    from: transform.position,
                    to: endPoint,
                    color: options.velocityColor,
                    thickness: options.colliderThickness
                )
            }
        }

        // Draw CCD sweep paths (previous → current position for CCD bodies)
        if options.drawCCDPaths {
            world.forEach { (_: Entity, transform: inout Transform2D, prev: inout PreviousTransform2D,
                              body: inout RigidBody2D) in
                guard body.useCCD && body.bodyType == .dynamic else { return }
                let dx = transform.position.x - prev.position.x
                let dy = transform.position.y - prev.position.y
                let dRot = abs(transform.rotation - prev.rotation)
                guard dx * dx + dy * dy > 0.01 || dRot > 0.01 else { return }
                drawLine(
                    from: prev.position,
                    to: transform.position,
                    color: options.ccdPathColor,
                    thickness: options.colliderThickness
                )
                // Small circle at clamped position
                drawCircle(center: transform.position, radius: 2, color: options.ccdPathColor)
            }
        }
    }

    // MARK: - Private Helpers

    /// Determine the color for a collider based on its entity's body type.
    private func colliderColor(
        for entity: Entity,
        collider: Collider2D,
        world: World,
        options: PhysicsDebugRendererOptions
    ) -> Color {
        // Trigger overrides body type color
        if collider.isTrigger {
            return options.triggerColor
        }

        // Color by body type if RigidBody2D is present
        if let body = world.getComponent(RigidBody2D.self, from: entity) {
            switch body.bodyType {
            case .dynamic: return options.dynamicColor
            case .kinematic: return options.kinematicColor
            case .static: return options.staticColor
            }
        }

        // No RigidBody2D — default to static color (entity acts as static)
        return options.staticColor
    }

    /// Draw a collider shape outline.
    private func drawColliderShape(
        shape: CollisionShape,
        position: Vector2,
        rotation: Float,
        color: Color,
        thickness: Float
    ) {
        switch shape {
        case .aabb(let halfExtents):
            if rotation == 0 {
                // Axis-aligned: simple rect outline
                let rect = Rect(
                    x: position.x - halfExtents.x,
                    y: position.y - halfExtents.y,
                    width: halfExtents.x * 2,
                    height: halfExtents.y * 2
                )
                drawRectOutline(rect, color: color, thickness: thickness)
            } else {
                // Rotated AABB: compute 4 corners and draw lines
                let corners = aabbCorners(halfExtents: halfExtents, position: position, rotation: rotation)
                for i in 0..<4 {
                    let j = (i + 1) % 4
                    drawLine(from: corners[i], to: corners[j], color: color, thickness: thickness)
                }
            }

        case .circle(let radius):
            drawCircleOutline(center: position, radius: radius, color: color, thickness: thickness)

        case .polygon(let polygon):
            let worldVerts = transformVertices(polygon.vertices, position: position, rotation: rotation)
            let count = worldVerts.count
            guard count >= 3 else { return }
            for i in 0..<count {
                let j = (i + 1) % count
                drawLine(from: worldVerts[i], to: worldVerts[j], color: color, thickness: thickness)
            }
        }
    }

    /// Draw surface normals for a collider shape.
    private func drawShapeNormals(
        shape: CollisionShape,
        position: Vector2,
        rotation: Float,
        length: Float,
        color: Color,
        thickness: Float
    ) {
        switch shape {
        case .aabb(let halfExtents):
            // AABB has 4 face normals. Draw from edge midpoints.
            let corners: [Vector2]
            if rotation == 0 {
                corners = [
                    Vector2(x: position.x - halfExtents.x, y: position.y - halfExtents.y), // top-left
                    Vector2(x: position.x + halfExtents.x, y: position.y - halfExtents.y), // top-right
                    Vector2(x: position.x + halfExtents.x, y: position.y + halfExtents.y), // bottom-right
                    Vector2(x: position.x - halfExtents.x, y: position.y + halfExtents.y), // bottom-left
                ]
            } else {
                corners = aabbCorners(halfExtents: halfExtents, position: position, rotation: rotation)
            }
            drawEdgeNormals(corners: corners, length: length, color: color, thickness: thickness)

        case .circle:
            // Circle normals are infinite; skip drawing them
            break

        case .polygon(let polygon):
            let worldVerts = transformVertices(polygon.vertices, position: position, rotation: rotation)
            drawEdgeNormals(corners: worldVerts, length: length, color: color, thickness: thickness)
        }
    }

    /// Draw outward-facing normals from edge midpoints for a convex polygon.
    private func drawEdgeNormals(
        corners: [Vector2],
        length: Float,
        color: Color,
        thickness: Float
    ) {
        let count = corners.count
        for i in 0..<count {
            let j = (i + 1) % count
            let midpoint = Vector2(
                x: (corners[i].x + corners[j].x) * 0.5,
                y: (corners[i].y + corners[j].y) * 0.5
            )
            let edge = corners[j] - corners[i]
            // Right-hand perpendicular (outward for CCW winding in math coords)
            let normal = Vector2(x: edge.y, y: -edge.x).normalized
            let normalEnd = midpoint + normal * length
            drawLine(from: midpoint, to: normalEnd, color: color, thickness: thickness)
        }
    }

    /// Compute the 4 world-space corners of a rotated AABB.
    private func aabbCorners(halfExtents: Vector2, position: Vector2, rotation: Float) -> [Vector2] {
        let localCorners = [
            Vector2(x: -halfExtents.x, y: -halfExtents.y),
            Vector2(x:  halfExtents.x, y: -halfExtents.y),
            Vector2(x:  halfExtents.x, y:  halfExtents.y),
            Vector2(x: -halfExtents.x, y:  halfExtents.y),
        ]
        return transformVertices(localCorners, position: position, rotation: rotation)
    }

    private func transformVertices(_ vertices: [Vector2], position: Vector2, rotation: Float) -> [Vector2] {
        GeometryHelpers.transformVertices(vertices, position: position, rotation: rotation)
    }

    // MARK: - Joint Debug Rendering

    /// Draw debug overlays for all active physics joints.
    ///
    /// Shows joint connections as lines between body centers and anchor points,
    /// with filled circles at anchor positions.
    ///
    /// ## Usage
    /// ```swift
    /// app.renderer.drawJointsDebug(physics: physics, world: app.world)
    /// ```
    ///
    /// - Parameters:
    ///   - physics: The physics world containing joints.
    ///   - world: The ECS world containing entity transforms.
    ///   - options: Rendering options controlling colors and toggles.
    public func drawJointsDebug(
        physics: PhysicsWorld2D,
        world: World,
        options: PhysicsDebugRendererOptions = PhysicsDebugRendererOptions()
    ) {
        guard options.drawJoints else { return }

        let jointInfos = physics.debugJointInfo(world: world)
        for info in jointInfos {
            let posA = world.getComponent(Transform2D.self, from: info.entityA)?.position ?? info.worldAnchorA
            let posB = world.getComponent(Transform2D.self, from: info.entityB)?.position ?? info.worldAnchorB

            switch info.jointType {
            case "revolute":
                // Lines from body centers to shared anchor + anchor circle
                let anchor = info.worldAnchorA  // Both anchors converge to same point
                drawLine(from: posA, to: anchor, color: options.jointColor, thickness: options.colliderThickness)
                drawLine(from: posB, to: anchor, color: options.jointColor, thickness: options.colliderThickness)
                drawCircle(center: anchor, radius: options.jointAnchorRadius, color: options.jointAnchorColor)

            case "distance":
                // Line between two world anchors
                drawLine(from: info.worldAnchorA, to: info.worldAnchorB,
                         color: options.jointColor, thickness: options.colliderThickness)
                drawCircle(center: info.worldAnchorA, radius: options.jointAnchorRadius, color: options.jointAnchorColor)
                drawCircle(center: info.worldAnchorB, radius: options.jointAnchorRadius, color: options.jointAnchorColor)

            case "weld":
                // X mark at anchor + lines to body centers
                let anchor = info.worldAnchorA
                drawLine(from: posA, to: anchor, color: options.jointColor, thickness: options.colliderThickness)
                drawLine(from: posB, to: anchor, color: options.jointColor, thickness: options.colliderThickness)
                // Draw an X at the anchor
                let sz = options.jointAnchorRadius
                drawLine(from: Vector2(x: anchor.x - sz, y: anchor.y - sz),
                         to: Vector2(x: anchor.x + sz, y: anchor.y + sz),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)
                drawLine(from: Vector2(x: anchor.x + sz, y: anchor.y - sz),
                         to: Vector2(x: anchor.x - sz, y: anchor.y + sz),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)

            case "prismatic":
                // Lines from body centers to anchor + axis line through anchor
                let anchor = info.worldAnchorA
                drawLine(from: posA, to: anchor, color: options.jointColor, thickness: options.colliderThickness)
                drawLine(from: posB, to: anchor, color: options.jointColor, thickness: options.colliderThickness)
                drawCircle(center: anchor, radius: options.jointAnchorRadius, color: options.jointAnchorColor)
                // Draw axis line through anchor (40px each direction)
                if let axis = info.axis {
                    let axisLen: Float = 40.0
                    let axisStart = Vector2(x: anchor.x - axis.x * axisLen, y: anchor.y - axis.y * axisLen)
                    let axisEnd = Vector2(x: anchor.x + axis.x * axisLen, y: anchor.y + axis.y * axisLen)
                    drawLine(from: axisStart, to: axisEnd,
                             color: options.jointAnchorColor, thickness: options.colliderThickness)
                }

            case "rope":
                // Line between anchors + anchor circles + diamond at midpoint
                drawLine(from: info.worldAnchorA, to: info.worldAnchorB,
                         color: options.jointColor, thickness: options.colliderThickness)
                drawCircle(center: info.worldAnchorA, radius: options.jointAnchorRadius, color: options.jointAnchorColor)
                drawCircle(center: info.worldAnchorB, radius: options.jointAnchorRadius, color: options.jointAnchorColor)
                // Diamond at midpoint to distinguish from distance joint
                let mid = Vector2(
                    x: (info.worldAnchorA.x + info.worldAnchorB.x) * 0.5,
                    y: (info.worldAnchorA.y + info.worldAnchorB.y) * 0.5
                )
                let sz = options.jointAnchorRadius
                drawLine(from: Vector2(x: mid.x, y: mid.y - sz),
                         to: Vector2(x: mid.x + sz, y: mid.y),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)
                drawLine(from: Vector2(x: mid.x + sz, y: mid.y),
                         to: Vector2(x: mid.x, y: mid.y + sz),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)
                drawLine(from: Vector2(x: mid.x, y: mid.y + sz),
                         to: Vector2(x: mid.x - sz, y: mid.y),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)
                drawLine(from: Vector2(x: mid.x - sz, y: mid.y),
                         to: Vector2(x: mid.x, y: mid.y - sz),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)

            case "motor":
                // Line from posA to posB + cross at posA + circle at posB
                drawLine(from: posA, to: posB, color: options.jointColor, thickness: options.colliderThickness)
                let sz = options.jointAnchorRadius
                // Cross mark at reference body (A)
                drawLine(from: Vector2(x: posA.x - sz, y: posA.y - sz),
                         to: Vector2(x: posA.x + sz, y: posA.y + sz),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)
                drawLine(from: Vector2(x: posA.x + sz, y: posA.y - sz),
                         to: Vector2(x: posA.x - sz, y: posA.y + sz),
                         color: options.jointAnchorColor, thickness: options.colliderThickness)
                // Circle at driven body (B)
                drawCircle(center: posB, radius: options.jointAnchorRadius, color: options.jointAnchorColor)

            default:
                // Generic fallback: line between anchors
                drawLine(from: info.worldAnchorA, to: info.worldAnchorB,
                         color: options.jointColor, thickness: options.colliderThickness)
            }
        }
    }
}
