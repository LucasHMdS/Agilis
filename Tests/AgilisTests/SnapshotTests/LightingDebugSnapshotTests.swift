@testable import Agilis
import Testing

@Suite("Lighting Debug Snapshots", .serialized)
struct LightingDebugSnapshotTests {

    @Test("Debug point light — radius circle and center dot")
    func debugPointLight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()

        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: light)
        world.addComponent(
            Light2D(
                color: Color(r: 255, g: 200, b: 100),
                intensity: 1.0,
                radius: 100
            ),
            to: light
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var options = LightingOptions()
            options.debugDraw = true
            r.drawLightingDebug(world: world, options: options)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "LightingDebug", name: "debug-point-light")
    }

    @Test("Debug spot light — direction and cone")
    func debugSpotLight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()

        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 100)), to: light)
        world.addComponent(
            Light2D(
                lightType: .spot(direction: .pi / 2, coneAngle: .pi / 4),
                color: .white,
                intensity: 1.0,
                radius: 120
            ),
            to: light
        )

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var options = LightingOptions()
            options.debugDraw = true
            r.drawLightingDebug(world: world, options: options)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "LightingDebug", name: "debug-spot-light")
    }

    @Test("Debug shadow caster outlines")
    func debugShadowCasters() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()

        // Light for context
        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 80, y: 80)), to: light)
        world.addComponent(
            Light2D(color: .white, intensity: 1.0, radius: 200, castsShadows: true),
            to: light
        )

        // AABB shadow caster
        let wall1 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 200, y: 100)), to: wall1)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 30, y: 8))), to: wall1)
        world.addComponent(ShadowCaster2D(), to: wall1)

        // Circle shadow caster
        let pillar = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 180)), to: pillar)
        world.addComponent(Collider2D(shape: .circle(radius: 15)), to: pillar)
        world.addComponent(ShadowCaster2D(), to: pillar)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var options = LightingOptions()
            options.debugDraw = true
            r.drawLightingDebug(world: world, options: options)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "LightingDebug", name: "debug-shadow-casters")
    }
}
