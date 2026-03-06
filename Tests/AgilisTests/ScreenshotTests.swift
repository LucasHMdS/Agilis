import Testing
@testable import Agilis

// MARK: - Mock Renderer for Screenshot Tests

private final class ScreenshotMockRenderer: @unchecked Sendable, Renderer {
    var screenshotPaths: [String] = []
    var captureCallCount = 0
    var captureResult: ImageData? = nil

    func takeScreenshot(path: String) {
        screenshotPaths.append(path)
    }

    func captureScreen() -> ImageData? {
        captureCallCount += 1
        return captureResult
    }

    // Unused Renderer stubs
    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func loadTextureFromImage(_ image: ImageData) -> TextureHandle { .invalid }
    func drawSprite(_ sprite: Sprite) {}
    func drawRect(_ rect: Rect, color: Color) {}
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {}
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {}
    func drawCircle(center: Vector2, radius: Float, color: Color) {}
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {}
    func loadDefaultFont() -> FontHandle { .invalid }
    func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
    func destroyFont(_ handle: FontHandle) {}
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {}
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size { .zero }
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { Size(width: 800, height: 600) }
}

// MARK: - Screenshot Protocol Tests

@Suite("Screenshot Protocol Tests")
struct ScreenshotProtocolTests {

    @Test("takeScreenshot records path")
    func takeScreenshot() {
        let renderer = ScreenshotMockRenderer()
        renderer.takeScreenshot(path: "test.png")
        renderer.takeScreenshot(path: "another.png")

        #expect(renderer.screenshotPaths.count == 2)
        #expect(renderer.screenshotPaths[0] == "test.png")
        #expect(renderer.screenshotPaths[1] == "another.png")
    }

    @Test("captureScreen returns nil by default on mock")
    func captureScreenNil() {
        let renderer = ScreenshotMockRenderer()
        let result = renderer.captureScreen()
        #expect(result == nil)
        #expect(renderer.captureCallCount == 1)
    }

    @Test("captureScreen returns ImageData when set")
    func captureScreenReturnsData() {
        let renderer = ScreenshotMockRenderer()
        let pixels: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255]
        renderer.captureResult = ImageData(width: 2, height: 1, pixels: pixels)

        let result = renderer.captureScreen()
        #expect(result != nil)
        #expect(result?.width == 2)
        #expect(result?.height == 1)
        #expect(result?.pixels.count == 8)
    }
}

// MARK: - Default Implementation Tests

@Suite("Screenshot Default Implementations")
struct ScreenshotDefaultTests {

    /// A minimal renderer that only implements required methods, using defaults for screenshots.
    private final class MinimalRenderer: @unchecked Sendable, Renderer {
        func initialize(config: WindowConfig) throws {}
        func shutdown() {}
        func shouldClose() -> Bool { false }
        func beginFrame() {}
        func endFrame() {}
        func setBackgroundColor(_ color: Color) {}
        func loadTexture(from path: String) -> TextureHandle { .invalid }
        func textureSize(_ handle: TextureHandle) -> Size { .zero }
        func destroyTexture(_ handle: TextureHandle) {}
        func drawSprite(_ sprite: Sprite) {}
        func drawRect(_ rect: Rect, color: Color) {}
        func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {}
        func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {}
        func drawCircle(center: Vector2, radius: Float, color: Color) {}
        func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {}
        func loadDefaultFont() -> FontHandle { .invalid }
        func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
        func destroyFont(_ handle: FontHandle) {}
        func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {}
        func measureText(_ text: String, font: FontHandle, size: Float) -> Size { .zero }
        func beginClip(_ rect: Rect) {}
        func endClip() {}
        func beginCamera(_ camera: Camera2D) {}
        func endCamera() {}
        var screenSize: Size { .zero }
    }

    @Test("Default captureScreen returns nil")
    func defaultCaptureScreen() {
        let renderer = MinimalRenderer()
        #expect(renderer.captureScreen() == nil)
    }

    @Test("Default takeScreenshot does not crash")
    func defaultTakeScreenshot() {
        let renderer = MinimalRenderer()
        renderer.takeScreenshot(path: "test.png")
        // No crash = success
    }
}

// MARK: - ImageData Tests

@Suite("ImageData Tests")
struct ImageDataTests {

    @Test("Init stores width, height, and pixels")
    func initFields() {
        let pixels: [UInt8] = [255, 128, 64, 255]
        let image = ImageData(width: 1, height: 1, pixels: pixels)
        #expect(image.width == 1)
        #expect(image.height == 1)
        #expect(image.pixels.count == 4)
        #expect(image.pixels[0] == 255)
        #expect(image.pixels[1] == 128)
    }
}
