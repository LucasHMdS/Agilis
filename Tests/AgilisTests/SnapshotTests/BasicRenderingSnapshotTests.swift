import Testing
@testable import Agilis

@Suite("Basic Rendering Snapshots", .serialized)
struct BasicRenderingSnapshotTests {

    @Test("Solid color clear")
    func solidColorClear() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable")
            return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 255, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { _ in
            // No drawing — just the clear color
        })
        #expect(image.width == 320)
        #expect(image.height == 240)

        // Verify every pixel is red (strict — no tolerance needed for clear color)
        for i in stride(from: 0, to: image.pixels.count, by: 4) {
            #expect(image.pixels[i] == 255)      // R
            #expect(image.pixels[i + 1] == 0)    // G
            #expect(image.pixels[i + 2] == 0)    // B
            #expect(image.pixels[i + 3] == 255)  // A
        }
    }

    @Test("Draw colored rectangle")
    func drawColoredRect() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable")
            return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawRect(
                Rect(x: 10, y: 10, width: 100, height: 50),
                color: Color(r: 255, g: 0, b: 0)
            )
        })
        SnapshotTestHelper.assertSnapshot(
            image, suite: "BasicRendering", name: "red-rect"
        )
    }

    @Test("Draw multiple shapes")
    func drawMultipleShapes() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable")
            return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawRect(
                Rect(x: 10, y: 10, width: 80, height: 60),
                color: Color(r: 255, g: 0, b: 0)
            )
            r.drawRect(
                Rect(x: 100, y: 40, width: 60, height: 80),
                color: Color(r: 0, g: 255, b: 0)
            )
            r.drawRect(
                Rect(x: 200, y: 20, width: 40, height: 100),
                color: Color(r: 0, g: 0, b: 255)
            )
            r.drawCircle(
                center: Vector2(x: 160, y: 180), radius: 30,
                color: Color(r: 255, g: 255, b: 0)
            )
        })
        SnapshotTestHelper.assertSnapshot(
            image, suite: "BasicRendering", name: "multiple-shapes"
        )
    }

    @Test("Draw lines")
    func drawLines() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable")
            return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawLine(
                from: Vector2(x: 0, y: 0), to: Vector2(x: 320, y: 240),
                color: Color(r: 255, g: 255, b: 255), thickness: 2
            )
            r.drawLine(
                from: Vector2(x: 320, y: 0), to: Vector2(x: 0, y: 240),
                color: Color(r: 0, g: 255, b: 255), thickness: 3
            )
        })
        SnapshotTestHelper.assertSnapshot(
            image, suite: "BasicRendering", name: "lines"
        )
    }

    @Test("Blend mode additive")
    func blendModeAdditive() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable")
            return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawRect(
                Rect(x: 50, y: 50, width: 100, height: 100),
                color: Color(r: 255, g: 0, b: 0)
            )
            r.beginBlendMode(.additive)
            r.drawRect(
                Rect(x: 100, y: 50, width: 100, height: 100),
                color: Color(r: 0, g: 255, b: 0)
            )
            r.endBlendMode()
        })
        SnapshotTestHelper.assertSnapshot(
            image, suite: "BasicRendering", name: "additive-blend"
        )
    }
}
