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

    /// Create a texture with a centered opaque rectangle surrounded by transparent pixels.
    /// The outline shader needs alpha edges to produce a visible outline.
    private static func createPaddedTexture(
        renderer: Renderer,
        size: Int = 64,
        padding: Int = 8,
        color: Color = Color(r: 60, g: 120, b: 200)
    ) -> TextureHandle {
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let i = (y * size + x) * 4
                let inside = x >= padding && x < size - padding
                    && y >= padding && y < size - padding
                if inside {
                    pixels[i]     = color.r
                    pixels[i + 1] = color.g
                    pixels[i + 2] = color.b
                    pixels[i + 3] = 255
                }
                // else stays 0,0,0,0 (transparent)
            }
        }
        let image = ImageData(width: size, height: size, pixels: pixels)
        return renderer.loadTextureFromImage(image)
    }

    @Test("White outline")
    func outlineWhite() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        // Padded texture with transparent border — outline shader needs alpha edges
        let tex = Self.createPaddedTexture(renderer: renderer)
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.material = library.outline(
                color: .white,
                width: 3.0,
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

        // Use a checkerboard texture so wave distortion is clearly visible
        let tex = SnapshotTestUtilities.createCheckerboardTexture(
            renderer: renderer,
            width: 64,
            height: 64,
            tileSize: 8,
            colorA: Color(r: 200, g: 100, b: 50),
            colorB: Color(r: 50, g: 100, b: 200)
        )
        let library = MaterialLibrary()
        library.initialize(renderer: renderer)
        defer { library.shutdown(); renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            // High amplitude + non-zero time for clearly visible wave displacement
            sprite.material = library.wave(
                time: 1.5,
                amplitude: 0.08,
                frequency: 8,
                speed: 3
            )
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Materials", name: "wave-distortion")
    }
}
