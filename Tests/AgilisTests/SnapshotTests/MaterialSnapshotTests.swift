@testable import Agilis
import Testing

@Suite("Material Snapshots", .serialized)
struct MaterialSnapshotTests {

    /// Helper: create a renderer, MaterialLibrary, and a test sprite texture.
    private static func setupMaterial(
        renderer: Renderer
    ) -> (MaterialLibrary, TextureHandle) {
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)

        let tex = SnapshotTestUtilities.createGradientTexture(
            renderer: renderer,
            width: 64,
            height: 64,
            fromColor: Color(r: 200, g: 100, b: 50),
            toColor: Color(r: 50, g: 100, b: 200)
        )
        return (library, tex)
    }

    @Test("Flash white — full amount")
    func flashWhite() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.flash(color: .white, amount: 1.0)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "flash-white")
    }

    @Test("Flash red — half amount")
    func flashPartial() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.flash(color: Color(r: 255, g: 0, b: 0), amount: 0.5)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "flash-red-half")
    }

    @Test("Full grayscale")
    func grayscaleFull() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.grayscale(amount: 1.0)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "grayscale-full")
    }

    @Test("Partial grayscale")
    func grayscalePartial() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.grayscale(amount: 0.5)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "grayscale-half")
    }

    @Test("Dissolve at 50%")
    func dissolveHalf() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 40, g: 40, b: 40))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.dissolve(threshold: 0.5)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "dissolve-half")
    }

    @Test("Dissolve with edge color")
    func dissolveEdge() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.dissolve(
                threshold: 0.4,
                edgeWidth: 0.08,
                edgeColor: Color(r: 255, g: 0, b: 0)
            )
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "dissolve-edge-color")
    }

    @Test("White outline")
    func outlineWhite() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.outline(
                color: .white,
                width: 2.0,
                textureSize: Vector2(x: 64, y: 64)
            )
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "outline-white")
    }

    @Test("Color replace — red to blue")
    func colorReplace() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        // Create a texture with a distinct red region
        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer,
            width: 64,
            height: 64,
            color: Color(r: 255, g: 0, b: 0)
        )
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.colorReplace(
                target: Color(r: 255, g: 0, b: 0),
                replacement: Color(r: 0, g: 0, b: 255),
                tolerance: 0.1
            )
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "color-replace")
    }

    @Test("Wave distortion")
    func waveEffect() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let (library, tex) = Self.setupMaterial(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.wave(time: 0, amplitude: 0.03, frequency: 10, speed: 3)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "wave-distortion")
    }
}
