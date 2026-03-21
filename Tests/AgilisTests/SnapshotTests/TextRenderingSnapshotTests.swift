@testable import Agilis
import Testing

@Suite("Text Rendering Snapshots", .serialized)
struct TextRenderingSnapshotTests {

    @Test("Basic hello world text")
    func basicText() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawText(
                "Hello World",
                position: Vector2(x: 10, y: 10),
                font: font,
                size: 20,
                color: .white
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TextRendering", name: "basic-hello")
    }

    @Test("Text at different sizes")
    func textSizes() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawText(
                "Size 10",
                position: Vector2(x: 10, y: 10),
                font: font,
                size: 10,
                color: .white
            )
            r.drawText(
                "Size 16",
                position: Vector2(x: 10, y: 40),
                font: font,
                size: 16,
                color: .white
            )
            r.drawText(
                "Size 24",
                position: Vector2(x: 10, y: 80),
                font: font,
                size: 24,
                color: .white
            )
            r.drawText(
                "Size 32",
                position: Vector2(x: 10, y: 130),
                font: font,
                size: 32,
                color: .white
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TextRendering", name: "text-sizes")
    }

    @Test("Text in different colors")
    func textColors() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawText(
                "Red",
                position: Vector2(x: 10, y: 30),
                font: font,
                size: 24,
                color: Color(r: 255, g: 0, b: 0)
            )
            r.drawText(
                "Green",
                position: Vector2(x: 10, y: 80),
                font: font,
                size: 24,
                color: Color(r: 0, g: 255, b: 0)
            )
            r.drawText(
                "Blue",
                position: Vector2(x: 10, y: 130),
                font: font,
                size: 24,
                color: Color(r: 0, g: 0, b: 255)
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TextRendering", name: "text-colors")
    }

    @Test("Text measured box")
    func textMeasuredBox() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))

        let text = "Measured Text"
        let fontSize: Float = 20
        let textSize = renderer.measureText(text, font: font, size: fontSize)
        let padding: Float = 8
        let boxX: Float = 40
        let boxY: Float = 60

        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Draw background rect sized to fit the text
            r.drawRect(
                Rect(
                    x: boxX,
                    y: boxY,
                    width: textSize.width + padding * 2,
                    height: textSize.height + padding * 2
                ),
                color: Color(r: 40, g: 40, b: 100)
            )
            // Draw text inside the rect
            r.drawText(
                text,
                position: Vector2(x: boxX + padding, y: boxY + padding),
                font: font,
                size: fontSize,
                color: .white
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TextRendering", name: "text-measured-box")
    }

    @Test("Multiple lines of text")
    func multipleLines() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let lines = ["Line 1: Hello", "Line 2: World", "Line 3: Testing", "Line 4: Agilis"]
            for (i, line) in lines.enumerated() {
                r.drawText(
                    line,
                    position: Vector2(x: 10, y: Float(20 + i * 30)),
                    font: font,
                    size: 18,
                    color: .white
                )
            }
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TextRendering", name: "text-multiline")
    }

    @Test("Special characters")
    func specialCharacters() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawText(
                "Score: 9999!@#$",
                position: Vector2(x: 10, y: 40),
                font: font,
                size: 20,
                color: .white
            )
            r.drawText(
                "HP: 100/100 [OK]",
                position: Vector2(x: 10, y: 80),
                font: font,
                size: 20,
                color: .white
            )
            r.drawText(
                "Time: 12:34.56",
                position: Vector2(x: 10, y: 120),
                font: font,
                size: 20,
                color: .white
            )
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "TextRendering", name: "text-special-chars")
    }
}
