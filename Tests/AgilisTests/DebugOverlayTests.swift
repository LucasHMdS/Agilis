import Testing
@testable import Agilis

// MARK: - Spy Renderer for Overlay

private final class OverlaySpyRenderer: @unchecked Sendable, RenderBackend {
    var rectCalls: [(rect: Rect, color: Color)] = []
    var textCalls: [(text: String, position: Vector2, color: Color)] = []
    var lineCalls: [(from: Vector2, to: Vector2)] = []

    func drawRect(_ rect: Rect, color: Color) {
        rectCalls.append((rect, color))
    }
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {
        textCalls.append((text, position, color))
    }
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {
        lineCalls.append((start, end))
    }

    // Unused stubs
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {}
    func drawSprite(_ sprite: Sprite) {}
    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func loadDefaultFont() -> FontHandle { FontHandle(id: 1) }
    func loadFont(from path: String, size: Int) -> FontHandle { .invalid }
    func destroyFont(_ handle: FontHandle) {}
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size { Size(width: Float(text.count) * 7, height: size) }
    func drawCircle(center: Vector2, radius: Float, color: Color) {}
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {}
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { Size(width: 800, height: 600) }
}

// MARK: - Mock Application

private final class MockAudioEngineO: @unchecked Sendable, AudioBackend {
    func initialize() throws {}
    func shutdown() {}
    func loadSound(from path: String) -> SoundHandle { .invalid }
    func playSound(_ handle: SoundHandle, volume: Float, pitch: Float, looping: Bool) {}
    func stopSound(_ handle: SoundHandle) {}
    func unloadSound(_ handle: SoundHandle) {}
    func loadMusic(from path: String) -> MusicHandle { .invalid }
    func playMusic(_ handle: MusicHandle, volume: Float, looping: Bool) {}
    func pauseMusic(_ handle: MusicHandle) {}
    func resumeMusic(_ handle: MusicHandle) {}
    func stopMusic(_ handle: MusicHandle) {}
    func updateMusicStream(_ handle: MusicHandle) {}
    func unloadMusic(_ handle: MusicHandle) {}
    func setMasterVolume(_ volume: Float) {}
}

private final class MockNativeInputO: @unchecked Sendable, InputBackend {
    func isKeyDown(_ key: Key) -> Bool { false }
    func isMouseButtonDown(_ button: MouseButton) -> Bool { false }
    func mousePosition() -> Vector2 { .zero }
    func mouseDelta() -> Vector2 { .zero }
    func mouseScrollDelta() -> Float { 0 }
    func charPressed() -> Character? { nil }
}

private func makeTestAppO() -> Application {
    let renderer = OverlaySpyRenderer()
    let audio = MockAudioEngineO()
    let input = MockNativeInputO()
    let config = WindowConfig(title: "Test", width: 800, height: 600)
    return Application(config: config, renderer: renderer, audio: audio, inputBackend: input)
}

// MARK: - DebugOverlayOptions Tests

@Suite("DebugOverlayOptions Tests")
struct DebugOverlayOptionsTests {

    @Test("Default options have expected values")
    func defaults() {
        let options = DebugOverlayOptions()
        #expect(options.showFPS == true)
        #expect(options.showFrameGraph == true)
        #expect(options.showEntityStats == true)
        #expect(options.showSystemTimings == true)
        #expect(options.showLog == true)
        #expect(options.logLineCount == 8)
        #expect(options.fontSize == 14)
        #expect(options.graphSamples == 120)
    }

    @Test("Custom options")
    func custom() {
        let options = DebugOverlayOptions(showFPS: false, showFrameGraph: false, logLineCount: 4)
        #expect(options.showFPS == false)
        #expect(options.showFrameGraph == false)
        #expect(options.logLineCount == 4)
    }
}

// MARK: - DebugOverlay Tests

@Suite("DebugOverlay Tests")
struct DebugOverlayTests {

    @Test("Renders FPS text when visible")
    func rendersFPS() {
        let app = makeTestAppO()
        let renderer = app.renderer as! OverlaySpyRenderer
        let overlay = DebugOverlay(font: FontHandle(id: 1))
        overlay.recordFrame(frameTime: 1.0 / 60.0)

        overlay.render(renderer: renderer, app: app)

        let fpsTexts = renderer.textCalls.filter { $0.text.contains("FPS") }
        #expect(!fpsTexts.isEmpty)
    }

    @Test("Does not render when invisible")
    func hiddenRendersNothing() {
        let app = makeTestAppO()
        let renderer = app.renderer as! OverlaySpyRenderer
        let overlay = DebugOverlay(font: FontHandle(id: 1))
        overlay.isVisible = false

        overlay.render(renderer: renderer, app: app)

        #expect(renderer.textCalls.isEmpty)
        #expect(renderer.rectCalls.isEmpty)
    }

    @Test("Renders entity stats")
    func rendersEntityStats() {
        let app = makeTestAppO()
        let renderer = app.renderer as! OverlaySpyRenderer
        let overlay = DebugOverlay(font: FontHandle(id: 1))

        app.world.createEntity()
        app.world.createEntity()

        overlay.render(renderer: renderer, app: app)

        let entityTexts = renderer.textCalls.filter { $0.text.contains("Entities: 2") }
        #expect(!entityTexts.isEmpty)
    }

    @Test("Renders log entries from ring buffer")
    func rendersLog() {
        let app = makeTestAppO()
        let renderer = app.renderer as! OverlaySpyRenderer
        let overlay = DebugOverlay(font: FontHandle(id: 1))

        let buffer = RingBufferLogOutput(capacity: 10, minimumLevel: .trace)
        buffer.write(LogEntry(level: .info, category: "Test", message: "Hello", timestamp: 0))
        overlay.logBuffer = buffer

        overlay.render(renderer: renderer, app: app)

        let logTexts = renderer.textCalls.filter { $0.text.contains("Hello") }
        #expect(!logTexts.isEmpty)
    }

    @Test("Disabling sections hides them")
    func disabledSections() {
        let app = makeTestAppO()
        let renderer = app.renderer as! OverlaySpyRenderer
        let options = DebugOverlayOptions(
            showFPS: false,
            showFrameGraph: false,
            showEntityStats: false,
            showSystemTimings: false,
            showLog: false
        )
        let overlay = DebugOverlay(font: FontHandle(id: 1), options: options)
        overlay.recordFrame(frameTime: 1.0 / 60.0)

        overlay.render(renderer: renderer, app: app)

        #expect(renderer.textCalls.isEmpty)
    }

    @Test("Frame graph draws bars after recording frames")
    func frameGraph() {
        let app = makeTestAppO()
        let renderer = app.renderer as! OverlaySpyRenderer
        let options = DebugOverlayOptions(showFPS: false, showEntityStats: false,
                                          showSystemTimings: false, showLog: false)
        let overlay = DebugOverlay(font: FontHandle(id: 1), options: options)

        // Record several frames
        for _ in 0..<10 {
            overlay.recordFrame(frameTime: 1.0 / 60.0)
        }

        overlay.render(renderer: renderer, app: app)

        // Should have drawn background rects and bar rects for the graph
        #expect(renderer.rectCalls.count > 1)
    }

    @Test("System timings are rendered after world update")
    func systemTimings() {
        let app = makeTestAppO()
        let renderer = app.renderer as! OverlaySpyRenderer
        let options = DebugOverlayOptions(showFPS: false, showFrameGraph: false,
                                          showEntityStats: false, showLog: false)
        let overlay = DebugOverlay(font: FontHandle(id: 1), options: options)

        // Add a system and run an update to populate timings
        let system = TestTimingSystem()
        app.world.addSystem(system)
        app.world.update(deltaTime: 1.0 / 60.0)

        overlay.render(renderer: renderer, app: app)

        let systemTexts = renderer.textCalls.filter { $0.text.contains("TestTimingSystem") }
        #expect(!systemTexts.isEmpty)
    }
}

// MARK: - Test System for Timing

private final class TestTimingSystem: System, @unchecked Sendable {
    func update(context: SystemContext) {}
}
