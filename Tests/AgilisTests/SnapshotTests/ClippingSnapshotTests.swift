import Testing
@testable import Agilis

@Suite("Clipping Snapshots", .serialized)
struct ClippingSnapshotTests {

    @Test("Basic clipping")
    func basicClip() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Clip to center 100x100 region
            r.beginClip(Rect(x: 110, y: 70, width: 100, height: 100))
            // Draw a full-screen rect — only center should appear
            r.drawRect(
                Rect(x: 0, y: 0, width: 320, height: 240),
                color: Color(r: 255, g: 0, b: 0)
            )
            r.endClip()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Clipping", name: "basic-clip")
    }

    @Test("Clip partially intersects circle")
    func clipPartialCircle() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Clip rect that only covers half of the circle
            r.beginClip(Rect(x: 100, y: 60, width: 120, height: 120))
            r.drawCircle(
                center: Vector2(x: 160, y: 120), radius: 80,
                color: Color(r: 0, g: 200, b: 100)
            )
            r.endClip()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Clipping", name: "clip-partial-circle")
    }

    @Test("Nested clipping")
    func clipNested() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Outer clip
            r.beginClip(Rect(x: 40, y: 20, width: 240, height: 200))
            r.drawRect(
                Rect(x: 0, y: 0, width: 320, height: 240),
                color: Color(r: 60, g: 60, b: 60)
            )
            // Inner clip — intersection of both rects
            r.beginClip(Rect(x: 100, y: 60, width: 120, height: 120))
            r.drawRect(
                Rect(x: 0, y: 0, width: 320, height: 240),
                color: Color(r: 255, g: 100, b: 0)
            )
            r.endClip()
            r.endClip()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Clipping", name: "clip-nested")
    }

    @Test("Clip restored after endClip")
    func clipRestored() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Draw clipped red rect
            r.beginClip(Rect(x: 20, y: 20, width: 100, height: 100))
            r.drawRect(
                Rect(x: 0, y: 0, width: 320, height: 240),
                color: Color(r: 255, g: 0, b: 0)
            )
            r.endClip()

            // After endClip, full drawing area should be restored
            // Draw green rect that covers a different area
            r.drawRect(
                Rect(x: 200, y: 120, width: 100, height: 100),
                color: Color(r: 0, g: 255, b: 0)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Clipping", name: "clip-restored")
    }
}
