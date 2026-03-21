@testable import Agilis
import Testing

@Suite("Shape Drawing Snapshots", .serialized)
struct ShapeDrawingSnapshotTests {

    @Test("Filled rectangle")
    func filledRectangle() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawRect(
                Rect(x: 60, y: 40, width: 200, height: 120),
                color: Color(r: 0, g: 128, b: 255)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "filled-rect")
    }

    @Test("Rectangle outline")
    func rectOutline() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawRectOutline(
                Rect(x: 40, y: 30, width: 240, height: 150),
                color: Color(r: 255, g: 200, b: 0),
                thickness: 3
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "rect-outline")
    }

    @Test("Filled circle")
    func filledCircle() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawCircle(
                center: Vector2(x: 160, y: 120),
                radius: 60,
                color: Color(r: 0, g: 200, b: 100)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "filled-circle")
    }

    @Test("Circle outline")
    func circleOutline() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawCircleOutline(
                center: Vector2(x: 160, y: 120),
                radius: 80,
                color: Color(r: 255, g: 100, b: 200),
                thickness: 3
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "circle-outline")
    }

    @Test("Line segments at different thicknesses")
    func lineSegments() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Horizontal line
            r.drawLine(
                from: Vector2(x: 20, y: 40),
                to: Vector2(x: 300, y: 40),
                color: Color(r: 255, g: 0, b: 0),
                thickness: 1
            )
            // Vertical line
            r.drawLine(
                from: Vector2(x: 160, y: 20),
                to: Vector2(x: 160, y: 220),
                color: Color(r: 0, g: 255, b: 0),
                thickness: 2
            )
            // Diagonal line
            r.drawLine(
                from: Vector2(x: 20, y: 200),
                to: Vector2(x: 300, y: 80),
                color: Color(r: 0, g: 128, b: 255),
                thickness: 4
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "line-segments")
    }

    @Test("Filled triangle")
    func filledTriangle() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTriangle(
                Vector2(x: 160, y: 30),
                Vector2(x: 60, y: 200),
                Vector2(x: 260, y: 200),
                color: Color(r: 255, g: 128, b: 0)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "filled-triangle")
    }

    @Test("Overlapping shapes verify draw order")
    func overlappingShapes() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // First: red rect (should be behind)
            r.drawRect(
                Rect(x: 60, y: 60, width: 120, height: 120),
                color: Color(r: 255, g: 0, b: 0)
            )
            // Second: green rect (overlapping, should be on top)
            r.drawRect(
                Rect(x: 120, y: 90, width: 120, height: 120),
                color: Color(r: 0, g: 255, b: 0)
            )
            // Third: blue circle (overlapping both, should be on top)
            r.drawCircle(
                center: Vector2(x: 200, y: 140),
                radius: 50,
                color: Color(r: 0, g: 0, b: 255)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "overlapping-shapes")
    }

    @Test("Semi-transparent shapes")
    func semiTransparentShapes() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 40, g: 40, b: 40))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawRect(
                Rect(x: 40, y: 40, width: 150, height: 150),
                color: Color(r: 255, g: 0, b: 0, a: 128)
            )
            r.drawRect(
                Rect(x: 100, y: 70, width: 150, height: 150),
                color: Color(r: 0, g: 0, b: 255, a: 128)
            )
            r.drawCircle(
                center: Vector2(x: 200, y: 100),
                radius: 60,
                color: Color(r: 0, g: 255, b: 0, a: 100)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "semitransparent-shapes")
    }

    @Test("Small shapes for sub-pixel precision")
    func smallShapes() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Thin lines
            r.drawLine(
                from: Vector2(x: 20, y: 50),
                to: Vector2(x: 100, y: 50),
                color: .white,
                thickness: 1
            )
            r.drawLine(
                from: Vector2(x: 20, y: 70),
                to: Vector2(x: 100, y: 70),
                color: .white,
                thickness: 2
            )
            r.drawLine(
                from: Vector2(x: 20, y: 90),
                to: Vector2(x: 100, y: 90),
                color: .white,
                thickness: 3
            )
            // Small circles
            r.drawCircle(
                center: Vector2(x: 160, y: 60),
                radius: 3,
                color: Color(r: 255, g: 0, b: 0)
            )
            r.drawCircle(
                center: Vector2(x: 180, y: 60),
                radius: 5,
                color: Color(r: 0, g: 255, b: 0)
            )
            r.drawCircle(
                center: Vector2(x: 210, y: 60),
                radius: 8,
                color: Color(r: 0, g: 0, b: 255)
            )
            // Small rects
            r.drawRect(
                Rect(x: 160, y: 100, width: 4, height: 4),
                color: Color(r: 255, g: 255, b: 0)
            )
            r.drawRect(
                Rect(x: 180, y: 100, width: 8, height: 8),
                color: Color(r: 0, g: 255, b: 255)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "ShapeDrawing", name: "small-shapes")
    }
}
