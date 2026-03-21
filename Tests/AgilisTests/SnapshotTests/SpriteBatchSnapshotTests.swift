@testable import Agilis
import Testing

@Suite("Sprite Batch Snapshots", .serialized)
struct SpriteBatchSnapshotTests {

    @Test("Single sprite through batch")
    func batchSingle() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 32,
            height: 32,
            color: Color(r: 0, g: 200, b: 100)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let batch = SpriteBatch()
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 144, y: 104)
            batch.add(sprite)
            batch.flush(to: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "SpriteBatch", name: "batch-single")
    }

    @Test("Multiple sprites through batch")
    func batchMultiple() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 24,
            height: 24,
            color: Color(r: 255, g: 100, b: 0)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let batch = SpriteBatch()
            for i in 0..<3 {
                var sprite = Sprite(texture: tex)
                sprite.position = Vector2(x: Float(60 + i * 80), y: Float(60 + i * 40))
                batch.add(sprite)
            }
            batch.flush(to: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "SpriteBatch", name: "batch-multiple")
    }

    @Test("Sort by texture groups draw calls")
    func sortByTexture() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let redTex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 32,
            height: 32,
            color: Color(r: 255, g: 0, b: 0)
        )
        let blueTex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 32,
            height: 32,
            color: Color(r: 0, g: 0, b: 255)
        )
        defer { renderer.destroyTexture(redTex); renderer.destroyTexture(blueTex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let batch = SpriteBatch(sortMode: .byTexture)
            // Interleave textures: red, blue, red, blue
            var s1 = Sprite(texture: redTex)
            s1.position = Vector2(x: 40, y: 80)
            batch.add(s1)

            var s2 = Sprite(texture: blueTex)
            s2.position = Vector2(x: 120, y: 80)
            batch.add(s2)

            var s3 = Sprite(texture: redTex)
            s3.position = Vector2(x: 200, y: 80)
            batch.add(s3)

            var s4 = Sprite(texture: blueTex)
            s4.position = Vector2(x: 260, y: 80)
            batch.add(s4)

            batch.flush(to: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "SpriteBatch", name: "batch-sort-texture")
    }

    @Test("Sort by layer")
    func sortByLayer() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let redTex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 60,
            height: 60,
            color: Color(r: 255, g: 0, b: 0)
        )
        let greenTex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 60,
            height: 60,
            color: Color(r: 0, g: 255, b: 0)
        )
        defer { renderer.destroyTexture(redTex); renderer.destroyTexture(greenTex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let batch = SpriteBatch(sortMode: .byLayer)
            // Add green at layer 2 first (should render on top despite being added first)
            var green = Sprite(texture: greenTex)
            green.position = Vector2(x: 140, y: 100)
            batch.add(green, layer: 2)

            // Add red at layer 0 (should render behind)
            var red = Sprite(texture: redTex)
            red.position = Vector2(x: 110, y: 80)
            batch.add(red, layer: 0)

            batch.flush(to: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "SpriteBatch", name: "batch-sort-layer")
    }

    @Test("No sorting — insertion order")
    func sortNone() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let redTex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 50,
            height: 50,
            color: Color(r: 255, g: 0, b: 0)
        )
        let blueTex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 50,
            height: 50,
            color: Color(r: 0, g: 0, b: 255)
        )
        defer { renderer.destroyTexture(redTex); renderer.destroyTexture(blueTex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            let batch = SpriteBatch(sortMode: .none)
            // Red first (behind), then blue (on top due to insertion order)
            var red = Sprite(texture: redTex)
            red.position = Vector2(x: 110, y: 80)
            batch.add(red)

            var blue = Sprite(texture: blueTex)
            blue.position = Vector2(x: 140, y: 100)
            batch.add(blue)

            batch.flush(to: r)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "SpriteBatch", name: "batch-sort-none")
    }
}
