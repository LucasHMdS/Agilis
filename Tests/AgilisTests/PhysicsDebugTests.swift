import Testing
@testable import Agilis

// MARK: - Spy Renderer

/// Records drawRectOutline, drawCircleOutline, drawLine, and drawCircle calls.
private final class DebugSpyRenderer: @unchecked Sendable, RenderBackend {
    struct RectOutlineCall: Equatable {
        let rect: Rect
        let color: Color
        let thickness: Float
    }
    struct CircleOutlineCall: Equatable {
        let center: Vector2
        let radius: Float
        let color: Color
        let thickness: Float
    }
    struct LineCall {
        let from: Vector2
        let to: Vector2
        let color: Color
        let thickness: Float
    }
    struct CircleCall: Equatable {
        let center: Vector2
        let radius: Float
        let color: Color
    }

    var rectOutlineCalls: [RectOutlineCall] = []
    var circleOutlineCalls: [CircleOutlineCall] = []
    var lineCalls: [LineCall] = []
    var circleCalls: [CircleCall] = []

    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {
        rectOutlineCalls.append(RectOutlineCall(rect: rect, color: color, thickness: thickness))
    }
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {
        circleOutlineCalls.append(CircleOutlineCall(center: center, radius: radius, color: color, thickness: thickness))
    }
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {
        lineCalls.append(LineCall(from: start, to: end, color: color, thickness: thickness))
    }
    func drawCircle(center: Vector2, radius: Float, color: Color) {
        circleCalls.append(CircleCall(center: center, radius: radius, color: color))
    }

    // Unused Renderer stubs
    func drawRect(_ rect: Rect, color: Color) {}
    func drawSprite(_ sprite: Sprite) {}
    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func loadDefaultFont() -> FontHandle { .invalid }
    func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
    func destroyFont(_ handle: FontHandle) {}
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {}
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size { .zero }
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { Size(width: 800, height: 600) }
}

// MARK: - PhysicsDebugRendererOptions Tests

@Suite("PhysicsDebugRendererOptions Tests")
struct PhysicsDebugRendererOptionsTests {

    @Test("Default options have expected values")
    func defaultOptions() {
        let options = PhysicsDebugRendererOptions()
        #expect(options.drawColliders == true)
        #expect(options.drawContacts == true)
        #expect(options.drawVelocities == false)
        #expect(options.drawNormals == false)
        #expect(options.colliderThickness == 1.0)
        #expect(options.normalLength == 15.0)
        #expect(options.velocityScale == 0.1)
        #expect(options.contactPointRadius == 3.0)
        #expect(options.dynamicColor == .cyan)
        #expect(options.kinematicColor == .yellow)
        #expect(options.staticColor == .gray)
        #expect(options.triggerColor == .green)
        #expect(options.contactColor == .red)
        #expect(options.velocityColor == .magenta)
        #expect(options.normalColor == Color(r: 255, g: 165, b: 0))
    }

    @Test("Custom options are stored correctly")
    func customOptions() {
        let options = PhysicsDebugRendererOptions(
            drawColliders: false,
            drawContacts: false,
            drawVelocities: true,
            drawNormals: true,
            colliderThickness: 3.0,
            normalLength: 20.0,
            velocityScale: 0.5,
            contactPointRadius: 5.0,
            dynamicColor: .red,
            kinematicColor: .blue,
            staticColor: .white,
            triggerColor: .magenta,
            contactColor: .cyan,
            velocityColor: .yellow,
            normalColor: .green
        )
        #expect(options.drawColliders == false)
        #expect(options.drawContacts == false)
        #expect(options.drawVelocities == true)
        #expect(options.drawNormals == true)
        #expect(options.colliderThickness == 3.0)
        #expect(options.normalLength == 20.0)
        #expect(options.velocityScale == 0.5)
        #expect(options.contactPointRadius == 5.0)
        #expect(options.dynamicColor == .red)
        #expect(options.kinematicColor == .blue)
        #expect(options.staticColor == .white)
        #expect(options.triggerColor == .magenta)
        #expect(options.contactColor == .cyan)
        #expect(options.velocityColor == .yellow)
        #expect(options.normalColor == .green)
    }

    @Test("Options are mutable after creation")
    func mutableOptions() {
        var options = PhysicsDebugRendererOptions()
        options.drawVelocities = true
        options.dynamicColor = .white
        #expect(options.drawVelocities == true)
        #expect(options.dynamicColor == .white)
    }
}

// MARK: - Physics Debug Drawing Tests

@Suite("Physics Debug Drawing Tests")
struct PhysicsDebugDrawingTests {

    @Test("AABB collider draws rect outline")
    func aabbDrawsRectOutline() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 200)), to: e)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 20, y: 15))), to: e)

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.rectOutlineCalls.count == 1)
        let call = renderer.rectOutlineCalls[0]
        #expect(call.rect.x == 80)    // 100 - 20
        #expect(call.rect.y == 185)   // 200 - 15
        #expect(call.rect.width == 40) // 20 * 2
        #expect(call.rect.height == 30) // 15 * 2
    }

    @Test("Circle collider draws circle outline")
    func circleDrawsCircleOutline() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 75)), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 25)), to: e)

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        let call = renderer.circleOutlineCalls[0]
        #expect(call.center == Vector2(x: 50, y: 75))
        #expect(call.radius == 25)
    }

    @Test("Polygon collider draws line segments")
    func polygonDrawsLines() {
        let world = World()
        let renderer = DebugSpyRenderer()

        // Triangle at origin (no rotation)
        let triangle = ConvexPolygon(vertices: [
            Vector2(x: 0, y: -10),
            Vector2(x: 10, y: 10),
            Vector2(x: -10, y: 10),
        ])
        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: e)
        world.addComponent(Collider2D(shape: .polygon(triangle)), to: e)

        renderer.drawPhysicsDebug(world: world)

        // Triangle has 3 edges → 3 lines
        #expect(renderer.lineCalls.count == 3)

        // Verify first line: vertex 0 to vertex 1
        let line0 = renderer.lineCalls[0]
        #expect(line0.from == Vector2(x: 100, y: 90))  // (0,-10) + (100,100)
        #expect(line0.to == Vector2(x: 110, y: 110))    // (10,10) + (100,100)

        // Verify last line closes the polygon: vertex 2 to vertex 0
        let line2 = renderer.lineCalls[2]
        #expect(line2.from == Vector2(x: 90, y: 110))   // (-10,10) + (100,100)
        #expect(line2.to == Vector2(x: 100, y: 90))     // (0,-10) + (100,100)
    }

    @Test("Rotated AABB draws four lines instead of rect outline")
    func rotatedAABBDrawsLines() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(
            Transform2D(position: Vector2(x: 0, y: 0), rotation: .pi / 2),
            to: e
        )
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 10, y: 5))), to: e)

        renderer.drawPhysicsDebug(world: world)

        // Should use 4 lines (not a rect outline) since it's rotated
        #expect(renderer.rectOutlineCalls.count == 0)
        #expect(renderer.lineCalls.count == 4)
    }

    @Test("Contact points draw filled circles and normal lines")
    func contactPointsDrawn() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let events = [
            CollisionEvent(
                entityA: Entity(index: 0, generation: 0),
                entityB: Entity(index: 1, generation: 0),
                type: .began,
                contact: Contact(
                    normal: Vector2(x: 0, y: -1),
                    penetration: 2.0,
                    point: Vector2(x: 150, y: 300)
                )
            )
        ]

        renderer.drawPhysicsDebug(world: world, events: events)

        // Filled circle for contact point
        #expect(renderer.circleCalls.count == 1)
        #expect(renderer.circleCalls[0].center == Vector2(x: 150, y: 300))
        #expect(renderer.circleCalls[0].radius == 3.0) // default contactPointRadius
        #expect(renderer.circleCalls[0].color == .red) // default contactColor

        // Normal line from contact point
        #expect(renderer.lineCalls.count == 1)
        #expect(renderer.lineCalls[0].from == Vector2(x: 150, y: 300))
        // normal (0, -1) * 15 (default normalLength) → endpoint at (150, 285)
        #expect(renderer.lineCalls[0].to == Vector2(x: 150, y: 285))
        #expect(renderer.lineCalls[0].color == .red)
    }

    @Test("Ongoing contacts are also drawn")
    func ongoingContactsDrawn() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let events = [
            CollisionEvent(
                entityA: Entity(index: 0, generation: 0),
                entityB: Entity(index: 1, generation: 0),
                type: .ongoing,
                contact: Contact(
                    normal: Vector2(x: 1, y: 0),
                    penetration: 1.0,
                    point: Vector2(x: 50, y: 50)
                )
            )
        ]

        renderer.drawPhysicsDebug(world: world, events: events)

        #expect(renderer.circleCalls.count == 1)
        #expect(renderer.lineCalls.count == 1)
    }

    @Test("Ended contacts are not drawn")
    func endedContactsSkipped() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let events = [
            CollisionEvent(
                entityA: Entity(index: 0, generation: 0),
                entityB: Entity(index: 1, generation: 0),
                type: .ended,
                contact: nil
            )
        ]

        renderer.drawPhysicsDebug(world: world, events: events)

        #expect(renderer.circleCalls.count == 0)
        #expect(renderer.lineCalls.count == 0)
    }

    @Test("Velocity vectors draw lines from position")
    func velocityVectorsDrawn() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: e)
        world.addComponent(Velocity2D(linear: Vector2(x: 200, y: 0)), to: e)

        var options = PhysicsDebugRendererOptions()
        options.drawColliders = false
        options.drawContacts = false
        options.drawVelocities = true

        renderer.drawPhysicsDebug(world: world, options: options)

        #expect(renderer.lineCalls.count == 1)
        let call = renderer.lineCalls[0]
        #expect(call.from == Vector2(x: 100, y: 100))
        // velocity (200, 0) * scale 0.1 → endpoint at (120, 100)
        #expect(call.to == Vector2(x: 120, y: 100))
        #expect(call.color == .magenta) // default velocityColor
    }

    @Test("Zero velocity entities are skipped")
    func zeroVelocitySkipped() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: e)
        world.addComponent(Velocity2D(linear: .zero), to: e)

        var options = PhysicsDebugRendererOptions()
        options.drawColliders = false
        options.drawContacts = false
        options.drawVelocities = true

        renderer.drawPhysicsDebug(world: world, options: options)

        #expect(renderer.lineCalls.count == 0)
    }

    @Test("Collider offset is applied to position")
    func colliderOffsetApplied() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: e)
        world.addComponent(
            Collider2D(shape: .circle(radius: 10), offset: Vector2(x: 20, y: -10)),
            to: e
        )

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        // Position (100,100) + offset (20,-10) = (120, 90)
        #expect(renderer.circleOutlineCalls[0].center == Vector2(x: 120, y: 90))
    }
}

// MARK: - Physics Debug Body Type Colors Tests

@Suite("Physics Debug Body Type Colors Tests")
struct PhysicsDebugBodyTypeColorTests {

    @Test("Dynamic body uses dynamic color")
    func dynamicBodyColor() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: e)

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].color == .cyan)
    }

    @Test("Kinematic body uses kinematic color")
    func kinematicBodyColor() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)
        world.addComponent(RigidBody2D(bodyType: .kinematic), to: e)

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].color == .yellow)
    }

    @Test("Static body uses static color")
    func staticBodyColor() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)
        world.addComponent(RigidBody2D(bodyType: .static), to: e)

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].color == .gray)
    }

    @Test("Trigger collider uses trigger color regardless of body type")
    func triggerColor() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(
            Collider2D(shape: .circle(radius: 10), isTrigger: true),
            to: e
        )
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: e)

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].color == .green)
    }

    @Test("Entity without RigidBody2D uses static color")
    func noRigidBodyUsesStaticColor() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)
        // No RigidBody2D added

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].color == .gray)
    }

    @Test("Custom body type colors are used")
    func customBodyTypeColors() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)
        world.addComponent(RigidBody2D(bodyType: .dynamic), to: e)

        var options = PhysicsDebugRendererOptions()
        options.dynamicColor = .white

        renderer.drawPhysicsDebug(world: world, options: options)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].color == .white)
    }
}

// MARK: - Physics Debug Edge Cases Tests

@Suite("Physics Debug Edge Cases Tests")
struct PhysicsDebugEdgeCaseTests {

    @Test("Empty world draws nothing")
    func emptyWorldDrawsNothing() {
        let world = World()
        let renderer = DebugSpyRenderer()

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.rectOutlineCalls.isEmpty)
        #expect(renderer.circleOutlineCalls.isEmpty)
        #expect(renderer.lineCalls.isEmpty)
        #expect(renderer.circleCalls.isEmpty)
    }

    @Test("No collision events draws no contacts")
    func noEventsNoContacts() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)

        renderer.drawPhysicsDebug(world: world, events: [])

        // Should draw collider but no contacts
        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleCalls.isEmpty)
    }

    @Test("Disabling drawColliders skips collider outlines")
    func disableColliders() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)

        var options = PhysicsDebugRendererOptions()
        options.drawColliders = false

        renderer.drawPhysicsDebug(world: world, options: options)

        #expect(renderer.circleOutlineCalls.isEmpty)
        #expect(renderer.rectOutlineCalls.isEmpty)
        #expect(renderer.lineCalls.isEmpty)
    }

    @Test("Disabling drawContacts skips contact points")
    func disableContacts() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let events = [
            CollisionEvent(
                entityA: Entity(index: 0, generation: 0),
                entityB: Entity(index: 1, generation: 0),
                type: .began,
                contact: Contact(
                    normal: Vector2(x: 0, y: -1),
                    penetration: 2.0,
                    point: Vector2(x: 50, y: 50)
                )
            )
        ]

        var options = PhysicsDebugRendererOptions()
        options.drawContacts = false

        renderer.drawPhysicsDebug(world: world, events: events, options: options)

        #expect(renderer.circleCalls.isEmpty)
        #expect(renderer.lineCalls.isEmpty)
    }

    @Test("Entity with Transform2D but no Collider2D is skipped")
    func noColliderSkipped() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: e)
        // No Collider2D

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.rectOutlineCalls.isEmpty)
        #expect(renderer.circleOutlineCalls.isEmpty)
        #expect(renderer.lineCalls.isEmpty)
    }

    @Test("Multiple entities all draw their colliders")
    func multipleEntitiesDrawn() {
        let world = World()
        let renderer = DebugSpyRenderer()

        // Circle entity
        let e1 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: e1)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e1)

        // AABB entity
        let e2 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 200, y: 200)), to: e2)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 30, y: 20))), to: e2)

        renderer.drawPhysicsDebug(world: world)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.rectOutlineCalls.count == 1)
    }

    @Test("Custom collider thickness is applied")
    func customThicknessApplied() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .circle(radius: 10)), to: e)

        var options = PhysicsDebugRendererOptions()
        options.colliderThickness = 5.0

        renderer.drawPhysicsDebug(world: world, options: options)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].thickness == 5.0)
    }

    @Test("Normals enabled draws edge normals for AABB")
    func normalsDrawnForAABB() {
        let world = World()
        let renderer = DebugSpyRenderer()

        let e = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: e)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 10, y: 10))), to: e)

        var options = PhysicsDebugRendererOptions()
        options.drawColliders = false
        options.drawNormals = true

        renderer.drawPhysicsDebug(world: world, options: options)

        // AABB has 4 edges → 4 normals
        #expect(renderer.lineCalls.count == 4)
        // All normal lines should use the normal color (orange)
        for call in renderer.lineCalls {
            #expect(call.color == Color(r: 255, g: 165, b: 0))
        }
    }

    @Test("Normals enabled draws edge normals for polygon")
    func normalsDrawnForPolygon() {
        let world = World()
        let renderer = DebugSpyRenderer()

        // Pentagon
        let pentagon = ConvexPolygon(vertices: [
            Vector2(x: 0, y: -10),
            Vector2(x: 10, y: -3),
            Vector2(x: 6, y: 10),
            Vector2(x: -6, y: 10),
            Vector2(x: -10, y: -3),
        ])
        let e = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: e)
        world.addComponent(Collider2D(shape: .polygon(pentagon)), to: e)

        var options = PhysicsDebugRendererOptions()
        options.drawColliders = false
        options.drawNormals = true

        renderer.drawPhysicsDebug(world: world, options: options)

        // Pentagon has 5 edges → 5 normals
        #expect(renderer.lineCalls.count == 5)
    }
}
