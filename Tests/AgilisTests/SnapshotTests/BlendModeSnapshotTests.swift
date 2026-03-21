@testable import Agilis
import Testing

@Suite("Blend Mode Snapshots", .serialized)
struct BlendModeSnapshotTests {

    @Test("Alpha blending")
    func alphaBlending() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Opaque red base
            r.drawRect(
                Rect(x: 60, y: 60, width: 120, height: 120),
                color: Color(r: 255, g: 0, b: 0)
            )
            // Semi-transparent blue on top
            r.drawRect(
                Rect(x: 120, y: 60, width: 120, height: 120),
                color: Color(r: 0, g: 0, b: 255, a: 128)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "BlendModes", name: "alpha-blend")
    }

    @Test("Additive blending")
    func additiveBlending() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Red base
            r.drawRect(
                Rect(x: 60, y: 60, width: 120, height: 120),
                color: Color(r: 255, g: 0, b: 0)
            )
            // Green additive — overlap should produce yellow
            r.beginBlendMode(.additive)
            r.drawRect(
                Rect(x: 120, y: 60, width: 120, height: 120),
                color: Color(r: 0, g: 255, b: 0)
            )
            r.endBlendMode()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "BlendModes", name: "additive-blend")
    }

    @Test("Multiplied blending")
    func multipliedBlending() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // White base
            r.drawRect(
                Rect(x: 40, y: 40, width: 200, height: 160),
                color: .white
            )
            // Dark rect multiplied — should darken the white
            r.beginBlendMode(.multiplied)
            r.drawRect(
                Rect(x: 80, y: 60, width: 120, height: 120),
                color: Color(r: 128, g: 64, b: 32)
            )
            r.endBlendMode()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "BlendModes", name: "multiplied-blend")
    }

    @Test("Premultiplied blending")
    func premultipliedBlending() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 40, g: 40, b: 40))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.beginBlendMode(.premultiplied)
            // Premultiplied half-alpha red: RGB = (128, 0, 0), A = 128
            r.drawRect(
                Rect(x: 60, y: 60, width: 100, height: 100),
                color: Color(r: 128, g: 0, b: 0, a: 128)
            )
            // Premultiplied half-alpha green
            r.drawRect(
                Rect(x: 140, y: 80, width: 100, height: 100),
                color: Color(r: 0, g: 128, b: 0, a: 128)
            )
            r.endBlendMode()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "BlendModes", name: "premultiplied-blend")
    }

    @Test("Blend mode scoped restores default")
    func blendModeScoped() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Base red
            r.drawRect(
                Rect(x: 20, y: 60, width: 80, height: 80),
                color: Color(r: 255, g: 0, b: 0)
            )

            // Additive green in scoped block
            r.beginBlendMode(.additive)
            r.drawRect(
                Rect(x: 120, y: 60, width: 80, height: 80),
                color: Color(r: 0, g: 255, b: 0)
            )
            r.endBlendMode()

            // After endBlendMode, should be back to alpha blending
            // Semi-transparent blue over a white rect
            r.drawRect(
                Rect(x: 220, y: 60, width: 80, height: 80),
                color: .white
            )
            r.drawRect(
                Rect(x: 220, y: 60, width: 80, height: 80),
                color: Color(r: 0, g: 0, b: 255, a: 128)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "BlendModes", name: "scoped-blend")
    }

    @Test("Sprite with additive blend mode")
    func spriteBlendMode() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 64,
            height: 64,
            color: Color(r: 0, g: 200, b: 255)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Base red rect
            r.drawRect(
                Rect(x: 80, y: 60, width: 160, height: 120),
                color: Color(r: 200, g: 0, b: 0)
            )
            // Sprite with additive blend
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.blendMode = .additive
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "BlendModes", name: "sprite-additive")
    }
}
