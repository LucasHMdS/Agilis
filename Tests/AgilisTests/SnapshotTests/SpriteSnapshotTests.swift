import Testing
@testable import Agilis

@Suite("Sprite Snapshots", .serialized)
struct SpriteSnapshotTests {

    @Test("Basic sprite position")
    func basicPosition() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 32, height: 32,
            color: Color(r: 0, g: 200, b: 100)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 50, y: 50)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "basic-position")
    }

    @Test("Source rect cropping")
    func sourceRectCrop() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createCheckerboardTexture(
            renderer: renderer, width: 64, height: 64, tileSize: 16
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 100, y: 80)
            // Crop to top-left 32x32
            sprite.sourceRect = Rect(x: 0, y: 0, width: 32, height: 32)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "source-rect-crop")
    }

    @Test("Uniform 2x scale")
    func scale2x() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createCheckerboardTexture(
            renderer: renderer, width: 32, height: 32, tileSize: 8
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 80, y: 56)
            sprite.scale = Vector2(x: 2, y: 2)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "scale-2x")
    }

    @Test("Non-uniform scale")
    func nonUniformScale() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 32, height: 32,
            color: Color(r: 255, g: 128, b: 0)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 80, y: 80)
            sprite.scale = Vector2(x: 2.0, y: 0.5)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "non-uniform-scale")
    }

    @Test("45 degree rotation")
    func rotation45() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createPatternTexture(
            renderer: renderer, width: 32, height: 32
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 144, y: 104)
            sprite.origin = Vector2(x: 16, y: 16)
            sprite.rotation = .pi / 4
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "rotation-45deg")
    }

    @Test("90 degree rotation")
    func rotation90() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createPatternTexture(
            renderer: renderer, width: 32, height: 32
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 144, y: 104)
            sprite.origin = Vector2(x: 16, y: 16)
            sprite.rotation = .pi / 2
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "rotation-90deg")
    }

    @Test("Origin at center")
    func originCenter() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 40, height: 40,
            color: Color(r: 100, g: 100, b: 255)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Draw crosshair at center point
            r.drawLine(
                from: Vector2(x: 150, y: 120), to: Vector2(x: 170, y: 120),
                color: .white, thickness: 1
            )
            r.drawLine(
                from: Vector2(x: 160, y: 110), to: Vector2(x: 160, y: 130),
                color: .white, thickness: 1
            )
            // Sprite with center origin placed at (160, 120)
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 160, y: 120)
            sprite.origin = Vector2(x: 20, y: 20)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "origin-center")
    }

    @Test("Origin at bottom-right")
    func originBottomRight() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 40, height: 40,
            color: Color(r: 255, g: 200, b: 0)
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            // Draw marker at anchor point
            r.drawCircle(
                center: Vector2(x: 160, y: 120), radius: 3,
                color: .white
            )
            // Origin at bottom-right: sprite should extend up-left from position
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 160, y: 120)
            sprite.origin = Vector2(x: 40, y: 40)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "origin-bottom-right")
    }

    @Test("Flip X")
    func flipX() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createPatternTexture(
            renderer: renderer, width: 64, height: 64
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.flipX = true
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "flip-x")
    }

    @Test("Flip Y")
    func flipY() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createPatternTexture(
            renderer: renderer, width: 64, height: 64
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.flipY = true
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "flip-y")
    }

    @Test("Flip both X and Y")
    func flipBoth() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createPatternTexture(
            renderer: renderer, width: 64, height: 64
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.flipX = true
            sprite.flipY = true
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "flip-both")
    }

    @Test("Red tint on white sprite")
    func tintRed() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 64, height: 64,
            color: .white
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.tint = Color(r: 255, g: 0, b: 0)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "tint-red")
    }

    @Test("Semi-transparent tint")
    func tintSemiTransparent() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 64, height: 64,
            color: .white
        )
        defer { renderer.destroyTexture(tex) }

        renderer.setBackgroundColor(Color(r: 40, g: 40, b: 40))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            var sprite = Sprite(texture: tex)
            sprite.position = Vector2(x: 128, y: 88)
            sprite.tint = Color(r: 255, g: 255, b: 255, a: 128)
            r.drawSprite(sprite)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "Sprite", name: "tint-semitransparent")
    }
}
