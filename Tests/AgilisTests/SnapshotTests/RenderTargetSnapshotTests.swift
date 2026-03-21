@testable import Agilis
import Testing

@Suite("Render Target Snapshots", .serialized)
struct RenderTargetSnapshotTests {

    @Test("Basic render target composite")
    func basicRenderTarget() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let rt = renderer.createRenderTarget(width: 320, height: 240)
        #expect(rt != .invalid)
        defer { renderer.destroyRenderTarget(rt) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Draw to render target
            r.beginRenderTarget(rt)
            r.drawRect(
                Rect(x: 80, y: 60, width: 160, height: 120),
                color: Color(r: 0, g: 200, b: 100)
            )
            r.drawCircle(
                center: Vector2(x: 160, y: 120),
                radius: 40,
                color: Color(r: 255, g: 200, b: 0)
            )
            r.endRenderTarget()

            // Composite RT to screen
            r.drawRenderTarget(rt, position: .zero)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "RenderTargets", name: "basic-rt")
    }

    @Test("Render target Y-flip correctness")
    func renderTargetYFlip() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let rt = renderer.createRenderTarget(width: 320, height: 240)
        #expect(rt != .invalid)
        defer { renderer.destroyRenderTarget(rt) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.beginRenderTarget(rt)
            // Draw asymmetric triangle: red on top, wider at bottom
            r.drawTriangle(
                Vector2(x: 160, y: 40),    // top vertex
                Vector2(x: 80, y: 200),    // bottom-left
                Vector2(x: 240, y: 200),   // bottom-right
                color: Color(r: 255, g: 0, b: 0)
            )
            // Blue marker in top-left corner
            r.drawRect(
                Rect(x: 10, y: 10, width: 30, height: 30),
                color: Color(r: 0, g: 0, b: 255)
            )
            r.endRenderTarget()

            r.drawRenderTarget(rt, position: .zero)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "RenderTargets", name: "rt-y-flip")
    }

    @Test("Render target scaled to full screen")
    func renderTargetScaled() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        // Small render target
        let rt = renderer.createRenderTarget(width: 80, height: 60)
        #expect(rt != .invalid)
        defer { renderer.destroyRenderTarget(rt) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.beginRenderTarget(rt)
            r.drawRect(
                Rect(x: 10, y: 10, width: 30, height: 20),
                color: Color(r: 255, g: 0, b: 0)
            )
            r.drawCircle(
                center: Vector2(x: 60, y: 40),
                radius: 15,
                color: Color(r: 0, g: 255, b: 0)
            )
            r.endRenderTarget()

            // Scale to full screen
            r.drawRenderTarget(rt, destination: Rect(x: 0, y: 0, width: 320, height: 240))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "RenderTargets", name: "rt-scaled")
    }

    @Test("Render target as sprite texture")
    func renderTargetAsTexture() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let rt = renderer.createRenderTarget(width: 64, height: 64)
        #expect(rt != .invalid)
        defer { renderer.destroyRenderTarget(rt) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Draw content to RT
            r.beginRenderTarget(rt)
            r.drawRect(
                Rect(x: 0, y: 0, width: 64, height: 64),
                color: Color(r: 40, g: 40, b: 40)
            )
            r.drawCircle(
                center: Vector2(x: 32, y: 32),
                radius: 20,
                color: Color(r: 255, g: 128, b: 0)
            )
            r.endRenderTarget()

            // Use RT texture in a sprite
            let rtTex = r.renderTargetTexture(rt)
            var sprite = Sprite(texture: rtTex)
            sprite.position = Vector2(x: 60, y: 40)
            sprite.scale = Vector2(x: 2, y: 2)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "RenderTargets", name: "rt-as-texture")
    }
}
