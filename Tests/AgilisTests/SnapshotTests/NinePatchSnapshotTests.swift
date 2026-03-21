@testable import Agilis
import Testing

@Suite("Nine Patch Snapshots", .serialized)
struct NinePatchSnapshotTests {

    @Test("Basic nine-patch rendering")
    func basicNinePatch() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createNinePatchTexture(
            renderer: renderer, width: 48, height: 48, borderSize: 12
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let patch = NinePatchSprite(
                texture: tex,
                sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
                border: 12
            )
            r.drawNinePatch(patch, destination: Rect(x: 30, y: 40, width: 260, height: 160))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "NinePatch", name: "basic-ninepatch")
    }

    @Test("Small destination")
    func smallDestination() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createNinePatchTexture(
            renderer: renderer, width: 48, height: 48, borderSize: 12
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let patch = NinePatchSprite(
                texture: tex,
                sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
                border: 12
            )
            // Destination smaller than 2x border
            r.drawNinePatch(patch, destination: Rect(x: 120, y: 90, width: 20, height: 20))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "NinePatch", name: "small-destination")
    }

    @Test("Asymmetric border sizes")
    func asymmetricBorder() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createNinePatchTexture(
            renderer: renderer,
            width: 48,
            height: 48,
            borderSize: 8,
            borderColor: Color(r: 200, g: 100, b: 0),
            centerColor: Color(r: 50, g: 100, b: 200)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var patch = NinePatchSprite(
                texture: tex,
                sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
                border: 8
            )
            // Set asymmetric borders
            patch.borderTop = 6
            patch.borderRight = 16
            patch.borderBottom = 10
            patch.borderLeft = 4
            r.drawNinePatch(patch, destination: Rect(x: 40, y: 30, width: 240, height: 180))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "NinePatch", name: "asymmetric-border")
    }

    @Test("Tinted nine-patch")
    func tinted() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createNinePatchTexture(
            renderer: renderer,
            width: 48,
            height: 48,
            borderSize: 12,
            borderColor: .white,
            centerColor: Color(r: 200, g: 200, b: 200)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var patch = NinePatchSprite(
                texture: tex,
                sourceRect: Rect(x: 0, y: 0, width: 48, height: 48),
                border: 12,
                tint: Color(r: 255, g: 0, b: 0)
            )
            r.drawNinePatch(patch, destination: Rect(x: 40, y: 40, width: 240, height: 160))
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "NinePatch", name: "ninepatch-tinted")
    }
}
