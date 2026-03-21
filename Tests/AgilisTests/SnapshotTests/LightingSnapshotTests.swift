@testable import Agilis
import Testing

@Suite("Lighting Snapshots", .serialized)
struct LightingSnapshotTests {

    /// Draw a base scene of colored rectangles for lighting to affect.
    private static func drawBaseScene(_ r: Renderer) {
        // Floor
        r.drawRect(
            Rect(x: 0, y: 0, width: 320, height: 240),
            color: Color(r: 100, g: 100, b: 120)
        )
        // Objects
        r.drawRect(
            Rect(x: 40, y: 40, width: 60, height: 40),
            color: Color(r: 200, g: 80, b: 80)
        )
        r.drawRect(
            Rect(x: 200, y: 100, width: 80, height: 60),
            color: Color(r: 80, g: 200, b: 80)
        )
        r.drawCircle(
            center: Vector2(x: 160, y: 180),
            radius: 30,
            color: Color(r: 80, g: 80, b: 200)
        )
    }

    @Test("Ambient light only")
    func ambientOnly() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 60, g: 60, b: 80)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "ambient-only")
    }

    @Test("Single point light")
    func singlePointLight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 10, g: 10, b: 20)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: light)
        world.addComponent(
            Light2D(color: .white, intensity: 1.5, radius: 200),
            to: light
        )

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "point-light")
    }

    @Test("Colored point light")
    func coloredPointLight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 10, g: 10, b: 15)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: light)
        world.addComponent(
            Light2D(
                color: Color(r: 255, g: 200, b: 100),
                intensity: 1.5,
                radius: 250
            ),
            to: light
        )

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "point-light-colored")
    }

    @Test("Two point lights additive overlap")
    func twoPointLights() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 5, g: 5, b: 10)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        // Red light on left
        let l1 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 120)), to: l1)
        world.addComponent(
            Light2D(color: Color(r: 255, g: 50, b: 50), intensity: 1.2, radius: 180),
            to: l1
        )

        // Blue light on right
        let l2 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 220, y: 120)), to: l2)
        world.addComponent(
            Light2D(color: Color(r: 50, g: 50, b: 255), intensity: 1.2, radius: 180),
            to: l2
        )

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "two-point-lights")
    }

    @Test("Spot light")
    func spotLight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 10, g: 10, b: 15)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 60)), to: light)
        world.addComponent(
            Light2D(
                lightType: .spot(direction: .pi / 2, coneAngle: .pi / 4),
                color: .white,
                intensity: 1.5,
                radius: 200
            ),
            to: light
        )

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "spot-light")
    }

    @Test("Point light with shadow caster")
    func pointLightWithShadow() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 10, g: 10, b: 15)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        // Light source
        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 80, y: 80)), to: light)
        world.addComponent(
            Light2D(color: .white, intensity: 1.5, radius: 300, castsShadows: true),
            to: light
        )

        // Shadow caster
        let wall = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 200, y: 120)), to: wall)
        world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 30, y: 10))), to: wall)
        world.addComponent(ShadowCaster2D(), to: wall)

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "point-light-shadow")
    }

    @Test("Light falloff comparison")
    func falloffComparison() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 5, g: 5, b: 10)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        // Linear falloff (left)
        let l1 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 80, y: 120)), to: l1)
        world.addComponent(
            Light2D(color: .white, intensity: 1.5, radius: 120, falloff: 1.0),
            to: l1
        )

        // Quadratic falloff (right)
        let l2 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 240, y: 120)), to: l2)
        world.addComponent(
            Light2D(color: .white, intensity: 1.5, radius: 120, falloff: 2.0),
            to: l2
        )

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "light-falloff")
    }

    @Test("Disabled light has no effect")
    func disabledLight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let world = World()
        let lighting = LightingSystem(options: LightingOptions(
            ambientColor: Color(r: 40, g: 40, b: 50)
        ))
        lighting.initialize(renderer: renderer)
        world.addSystem(lighting)
        defer { lighting.shutdown(renderer: renderer) }

        let light = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: light)
        world.addComponent(
            Light2D(color: .white, intensity: 2.0, radius: 300, isEnabled: false),
            to: light
        )

        world.update(deltaTime: 0.016)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            Self.drawBaseScene(r)
            lighting.renderLightMap(renderer: r)
            lighting.compositeLightMap(renderer: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Lighting", name: "light-disabled")
    }
}
