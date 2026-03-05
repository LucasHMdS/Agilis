import Testing
@testable import Agilis
@testable import AgilisCore

// MARK: - Test Helpers

/// Thread-safe call tracker for @Sendable closures.
private final class CallTracker: @unchecked Sendable {
    var wasCalled = false
    func fire() { wasCalled = true }
}

/// A scene that records lifecycle calls for testing.
private final class RecordingScene: Scene {
    var didEnterCount = 0
    var willExitCount = 0
    var updateCount = 0
    var renderCount = 0

    func didEnter(app: Application) { didEnterCount += 1 }
    func willExit(app: Application) { willExitCount += 1 }
    func update(app: Application, deltaTime: Double) { updateCount += 1 }
    func render(app: Application, interpolation: Double) { renderCount += 1 }
}

/// A minimal render backend that tracks drawRect calls for overlay verification.
private final class OverlaySpyRenderer: @unchecked Sendable, RenderBackend {
    var _screenSize = Size(width: 800, height: 600)
    var drawnRects: [(rect: Rect, color: Color)] = []

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
    func drawRect(_ rect: Rect, color: Color) { drawnRects.append((rect, color)) }
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
    var screenSize: Size { _screenSize }
}

/// A stub audio backend (all no-ops).
private final class StubAudioBackend: @unchecked Sendable, AudioBackend {
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

/// A stub input backend (all no-ops).
private final class StubInputBackend: @unchecked Sendable, InputBackend {
    func isKeyDown(_ key: Key) -> Bool { false }
    func isMouseButtonDown(_ button: MouseButton) -> Bool { false }
    func mousePosition() -> Vector2 { .zero }
    func mouseDelta() -> Vector2 { .zero }
    func mouseScrollDelta() -> Float { 0 }
    func charPressed() -> Character? { nil }
}

private func makeSceneTestApp() -> (Application, OverlaySpyRenderer) {
    let renderer = OverlaySpyRenderer()
    let audio = StubAudioBackend()
    let input = StubInputBackend()
    let config = WindowConfig(title: "Test", width: 800, height: 600)
    let app = Application(config: config, renderer: renderer, audio: audio, inputBackend: input)
    return (app, renderer)
}

// MARK: - SceneTransition Struct Tests

@Suite("SceneTransition Tests")
struct SceneTransitionStructTests {
    @Test("Default values")
    func defaultValues() {
        let t = SceneTransition()
        #expect(t.duration == 0.5)
        #expect(t.color == .black)
        #expect(t.fadeOutEasing == .sineInOut)
        #expect(t.fadeInEasing == .sineInOut)
        #expect(t.onMidpoint == nil)
    }

    @Test("fade() factory defaults")
    func fadeFactory() {
        let t = SceneTransition.fade()
        #expect(t.duration == 0.5)
        #expect(t.color == .black)
        #expect(t.fadeOutEasing == .sineInOut)
        #expect(t.fadeInEasing == .sineInOut)
    }

    @Test("fade() factory with custom values")
    func fadeFactoryCustom() {
        let t = SceneTransition.fade(duration: 2.0, color: .red, easing: .cubicOut)
        #expect(t.duration == 2.0)
        #expect(t.color == .red)
        #expect(t.fadeOutEasing == .cubicOut)
        #expect(t.fadeInEasing == .cubicOut)
    }

    @Test("flash() factory uses white")
    func flashFactory() {
        let t = SceneTransition.flash()
        #expect(t.duration == 0.4)
        #expect(t.color == .white)
        #expect(t.fadeOutEasing == .quadInOut)
    }

    @Test("instant has zero duration")
    func instant() {
        #expect(SceneTransition.instant.duration == 0)
    }

    @Test("Custom easing per phase")
    func customEasingPerPhase() {
        let t = SceneTransition(
            fadeOutEasing: .cubicIn,
            fadeInEasing: .cubicOut
        )
        #expect(t.fadeOutEasing == .cubicIn)
        #expect(t.fadeInEasing == .cubicOut)
    }
}

// MARK: - SceneManager Transition Integration Tests

@Suite("SceneManager Transition Tests")
struct SceneManagerTransitionTests {
    @Test("replace with transition starts transitioning")
    func replaceStartsTransition() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(with: scene2, transition: .fade(duration: 1.0), app: app)

        #expect(app.sceneManager.isTransitioning)
    }

    @Test("Scene swap does not happen immediately during fadeOut")
    func sceneSwapDeferredDuringFadeOut() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(with: scene2, transition: .fade(duration: 1.0), app: app)

        // Scene1 should still be current (not yet swapped)
        #expect(app.sceneManager.currentScene === scene1)
        #expect(scene1.willExitCount == 0)
        #expect(scene2.didEnterCount == 0)
    }

    @Test("Scene swap happens at midpoint")
    func sceneSwapAtMidpoint() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(with: scene2, transition: .fade(duration: 1.0), app: app)

        // Advance past the fadeOut phase (half duration = 0.5s)
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)

        // Scene should have swapped
        #expect(scene1.willExitCount == 1)
        #expect(scene2.didEnterCount == 1)
        #expect(app.sceneManager.currentScene === scene2)
    }

    @Test("onMidpoint callback fires at midpoint")
    func onMidpointCallback() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()
        let midpointFired = CallTracker()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(
            with: scene2,
            transition: .fade(duration: 1.0) { midpointFired.fire() },
            app: app
        )

        #expect(!midpointFired.wasCalled)
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(midpointFired.wasCalled)
    }

    @Test("Transition completes after full duration")
    func transitionCompletes() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(with: scene2, transition: .fade(duration: 1.0), app: app)

        // fadeOut phase
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(app.sceneManager.isTransitioning) // still in fadeIn

        // fadeIn phase
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(!app.sceneManager.isTransitioning) // complete
    }

    @Test("Old scene is current during fadeOut, new scene after midpoint")
    func currentSceneDuringPhases() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(with: scene2, transition: .fade(duration: 2.0), app: app)

        // During fadeOut
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(app.sceneManager.currentScene === scene1)

        // After midpoint
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(app.sceneManager.currentScene === scene2)
    }

    @Test("push with transition")
    func pushWithTransition() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.push(scene2, transition: .fade(duration: 1.0), app: app)

        // scene1 should NOT get willExit (it's a push, not replace)
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(scene1.willExitCount == 0)
        #expect(scene2.didEnterCount == 1)
    }

    @Test("pop with transition")
    func popWithTransition() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.push(scene2, app: app)
        app.sceneManager.pop(transition: .fade(duration: 1.0), app: app)

        // scene2 should be popped at midpoint
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(scene2.willExitCount == 1)
        #expect(app.sceneManager.currentScene === scene1)
    }

    @Test("replaceAll with transition exits all old scenes")
    func replaceAllWithTransition() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()
        let scene3 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.push(scene2, app: app)
        app.sceneManager.replaceAll(with: scene3, transition: .fade(duration: 1.0), app: app)

        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)

        #expect(scene1.willExitCount == 1)
        #expect(scene2.willExitCount == 1)
        #expect(scene3.didEnterCount == 1)
        #expect(app.sceneManager.currentScene === scene3)
    }
}

// MARK: - Transition Overlay Tests

@Suite("Transition Overlay Tests")
struct TransitionOverlayTests {
    @Test("No overlay when no transition")
    func noOverlayWhenNoTransition() {
        let (app, renderer) = makeSceneTestApp()

        app.sceneManager.renderTransitionOverlay(renderer: renderer)
        #expect(renderer.drawnRects.isEmpty)
    }

    @Test("Overlay drawn during fadeOut")
    func overlayDuringFadeOut() {
        let (app, renderer) = makeSceneTestApp()
        let scene1 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(
            with: RecordingScene(),
            transition: .fade(duration: 2.0, easing: .linear),
            app: app
        )

        // Advance to 50% of fadeOut (halfDuration = 1.0, elapsed = 0.5 → 50%)
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        app.sceneManager.renderTransitionOverlay(renderer: renderer)

        #expect(renderer.drawnRects.count == 1)
        let drawn = renderer.drawnRects[0]
        // With linear easing at 50%, alpha should be ~128
        #expect(drawn.color.a > 100 && drawn.color.a < 156)
        #expect(drawn.color.r == 0)  // black
    }

    @Test("Overlay covers full screen")
    func overlayCoversFullScreen() {
        let (app, renderer) = makeSceneTestApp()
        renderer._screenSize = Size(width: 1920, height: 1080)
        let scene1 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(
            with: RecordingScene(),
            transition: .fade(duration: 2.0, easing: .linear),
            app: app
        )

        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        app.sceneManager.renderTransitionOverlay(renderer: renderer)

        let rect = renderer.drawnRects[0].rect
        #expect(rect.x == 0)
        #expect(rect.y == 0)
        #expect(rect.width == 1920)
        #expect(rect.height == 1080)
    }

    @Test("Overlay uses transition color")
    func overlayUsesTransitionColor() {
        let (app, renderer) = makeSceneTestApp()
        let scene1 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(
            with: RecordingScene(),
            transition: .fade(duration: 2.0, color: .white, easing: .linear),
            app: app
        )

        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        app.sceneManager.renderTransitionOverlay(renderer: renderer)

        let color = renderer.drawnRects[0].color
        #expect(color.r == 255)
        #expect(color.g == 255)
        #expect(color.b == 255)
    }

    @Test("Full alpha at end of fadeOut")
    func fullAlphaAtEndOfFadeOut() {
        let (app, renderer) = makeSceneTestApp()
        let scene1 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(
            with: RecordingScene(),
            transition: .fade(duration: 2.0, easing: .linear),
            app: app
        )

        // Advance to end of fadeOut but not past midpoint (0.99 of 1.0 half)
        app.sceneManager.updateTransition(deltaTime: 0.99, app: app)
        app.sceneManager.renderTransitionOverlay(renderer: renderer)

        // Should be nearly fully opaque
        #expect(renderer.drawnRects[0].color.a >= 250)
    }

    @Test("Overlay fades out during fadeIn phase")
    func overlayFadesDuringFadeIn() {
        let (app, renderer) = makeSceneTestApp()
        let scene1 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(
            with: RecordingScene(),
            transition: .fade(duration: 2.0, easing: .linear),
            app: app
        )

        // Complete fadeOut (triggers midpoint)
        app.sceneManager.updateTransition(deltaTime: 1.0, app: app)

        // Advance to 50% of fadeIn
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        app.sceneManager.renderTransitionOverlay(renderer: renderer)

        // At 50% fadeIn with linear easing, alpha should be ~128
        let alpha = renderer.drawnRects.last!.color.a
        #expect(alpha > 100 && alpha < 156)
    }
}

// MARK: - Edge Case Tests

@Suite("Transition Edge Case Tests")
struct TransitionEdgeCaseTests {
    @Test("Instant transition executes immediately")
    func instantTransition() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(with: scene2, transition: .instant, app: app)

        // Should be immediate — no transition state
        #expect(!app.sceneManager.isTransitioning)
        #expect(scene1.willExitCount == 1)
        #expect(scene2.didEnterCount == 1)
        #expect(app.sceneManager.currentScene === scene2)
    }

    @Test("Instant transition calls onMidpoint")
    func instantTransitionCallsOnMidpoint() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let called = CallTracker()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(
            with: RecordingScene(),
            transition: SceneTransition(duration: 0, onMidpoint: { called.fire() }),
            app: app
        )

        #expect(called.wasCalled)
    }

    @Test("Transition during transition force-completes current")
    func transitionDuringTransition() {
        let (app, _) = makeSceneTestApp()
        let scene1 = RecordingScene()
        let scene2 = RecordingScene()
        let scene3 = RecordingScene()

        app.sceneManager.push(scene1, app: app)
        app.sceneManager.replace(with: scene2, transition: .fade(duration: 2.0), app: app)

        // Mid-fadeOut, start another transition
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        app.sceneManager.replace(with: scene3, transition: .fade(duration: 1.0), app: app)

        // scene2 should have been force-completed (entered immediately)
        #expect(scene1.willExitCount == 1)
        #expect(scene2.didEnterCount == 1)
        // New transition to scene3 is now active
        #expect(app.sceneManager.isTransitioning)
        #expect(app.sceneManager.currentScene === scene2)
    }

    @Test("isTransitioning is false when no transition")
    func isTransitioningFalse() {
        let manager = SceneManager()
        #expect(!manager.isTransitioning)
    }

    @Test("Update with no transition is safe")
    func updateNoTransition() {
        let (app, _) = makeSceneTestApp()

        // Should not crash
        app.sceneManager.updateTransition(deltaTime: 0.016, app: app)
    }

    @Test("Pop transition with empty stack is safe")
    func popEmptyStack() {
        let (app, _) = makeSceneTestApp()

        app.sceneManager.pop(transition: .fade(duration: 1.0), app: app)
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)

        // Should not crash, transition completes
        app.sceneManager.updateTransition(deltaTime: 0.5, app: app)
        #expect(!app.sceneManager.isTransitioning)
    }
}
