import Testing
@testable import Agilis

@Suite("Camera 2D Snapshots", .serialized)
struct Camera2DSnapshotTests {

    /// Draw a reference scene: a red rect, green rect, and blue circle.
    private static func drawReferenceScene(_ r: Renderer) {
        r.drawRect(
            Rect(x: 50, y: 50, width: 80, height: 60),
            color: Color(r: 255, g: 0, b: 0)
        )
        r.drawRect(
            Rect(x: 180, y: 80, width: 60, height: 80),
            color: Color(r: 0, g: 255, b: 0)
        )
        r.drawCircle(
            center: Vector2(x: 160, y: 180), radius: 30,
            color: Color(r: 0, g: 100, b: 255)
        )
    }

    @Test("Default identity camera")
    func defaultIdentity() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let camera = Camera2D()
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "default-identity")
    }

    @Test("Pan right — shapes shift left")
    func panRight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.target = Vector2(x: 100, y: 0)
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "pan-right")
    }

    @Test("Pan down — shapes shift up")
    func panDown() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.target = Vector2(x: 0, y: 100)
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "pan-down")
    }

    @Test("Zoom in 2x — shapes appear larger")
    func zoomIn() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.zoom = 2.0
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "zoom-in-2x")
    }

    @Test("Zoom out half — shapes appear smaller")
    func zoomOut() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.zoom = 0.5
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "zoom-out-half")
    }

    @Test("Camera with offset centers target on screen")
    func withOffset() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.target = Vector2(x: 160, y: 120)
            camera.offset = Vector2(x: 160, y: 120)
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "offset-centered")
    }

    @Test("Camera 45 degree rotation")
    func rotation() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.target = Vector2(x: 160, y: 120)
            camera.offset = Vector2(x: 160, y: 120)
            camera.rotation = .pi / 4  // 45 degrees
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "rotation-45deg")
    }

    @Test("Combined camera transform")
    func combinedTransform() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var camera = Camera2D()
            camera.target = Vector2(x: 160, y: 120)
            camera.offset = Vector2(x: 160, y: 120)
            camera.zoom = 1.5
            camera.rotation = .pi / 6  // 30 degrees
            r.beginCamera(camera)
            Self.drawReferenceScene(r)
            r.endCamera()
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Camera2D", name: "combined-transform")
    }
}
