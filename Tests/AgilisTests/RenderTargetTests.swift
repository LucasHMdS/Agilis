import Testing
@testable import Agilis

// MARK: - Mock Render Target Backend

/// A mock renderer that implements render target methods with in-memory tracking.
final class MockRTRenderer: @unchecked Sendable, RenderBackend {
    private var nextId: UInt32 = 1
    private var targets: [UInt32: (width: Int, height: Int)] = [:]
    private var targetTextureIds: [UInt32: UInt32] = [:]
    var activeTarget: RenderTargetHandle?
    var drawnSprites: [Sprite] = []

    func createRenderTarget(width: Int, height: Int) -> RenderTargetHandle {
        guard width > 0 && height > 0 else { return .invalid }
        let rtId = nextId
        nextId += 1
        targets[rtId] = (width: width, height: height)
        let texId = nextId
        nextId += 1
        targetTextureIds[rtId] = texId
        return RenderTargetHandle(id: rtId)
    }

    func beginRenderTarget(_ handle: RenderTargetHandle) {
        guard targets[handle.id] != nil else { return }
        activeTarget = handle
    }

    func endRenderTarget() {
        activeTarget = nil
    }

    func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle {
        guard let texId = targetTextureIds[handle.id] else { return .invalid }
        return TextureHandle(id: texId)
    }

    func renderTargetSize(_ handle: RenderTargetHandle) -> Size {
        guard let info = targets[handle.id] else { return .zero }
        return Size(width: Float(info.width), height: Float(info.height))
    }

    func destroyRenderTarget(_ handle: RenderTargetHandle) {
        targets.removeValue(forKey: handle.id)
        targetTextureIds.removeValue(forKey: handle.id)
    }

    // Renderer stubs
    func initialize(config: WindowConfig) throws {}
    func shutdown() {}
    func shouldClose() -> Bool { false }
    func beginFrame() {}
    func endFrame() {}
    func setBackgroundColor(_ color: Color) {}
    func loadTexture(from path: String) -> TextureHandle { .invalid }
    func textureSize(_ handle: TextureHandle) -> Size { .zero }
    func destroyTexture(_ handle: TextureHandle) {}
    func drawSprite(_ sprite: Sprite) { drawnSprites.append(sprite) }
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

// MARK: - Handle Tests

@Suite("RenderTargetHandle Tests")
struct RenderTargetHandleTests {

    @Test("Invalid handle has id 0")
    func invalidHandle() {
        #expect(RenderTargetHandle.invalid.id == 0)
    }

    @Test("Handles with same id are equal")
    func equality() {
        let a = RenderTargetHandle(id: 42)
        let b = RenderTargetHandle(id: 42)
        #expect(a == b)
    }

    @Test("Handles with different ids are not equal")
    func inequality() {
        let a = RenderTargetHandle(id: 1)
        let b = RenderTargetHandle(id: 2)
        #expect(a != b)
    }

    @Test("Can be used as dictionary key")
    func hashable() {
        let handle = RenderTargetHandle(id: 5)
        var dict: [RenderTargetHandle: String] = [:]
        dict[handle] = "test"
        #expect(dict[handle] == "test")
    }
}

// MARK: - Default Implementation Tests

@Suite("RenderTarget Default Implementations")
struct RenderTargetDefaultTests {

    /// Uses SpyRenderer from SpriteBatchTests which does NOT override RT methods.
    @Test("Default createRenderTarget returns invalid")
    func defaultCreate() {
        let renderer = SpyRenderer()
        let handle = renderer.createRenderTarget(width: 100, height: 100)
        #expect(handle == .invalid)
    }

    @Test("Default renderTargetTexture returns invalid")
    func defaultTexture() {
        let renderer = SpyRenderer()
        #expect(renderer.renderTargetTexture(.invalid) == .invalid)
    }

    @Test("Default renderTargetSize returns zero")
    func defaultSize() {
        let renderer = SpyRenderer()
        let size = renderer.renderTargetSize(.invalid)
        #expect(size.width == 0)
        #expect(size.height == 0)
    }

    @Test("Default begin/end/destroy don't crash")
    func defaultNoOps() {
        let renderer = SpyRenderer()
        renderer.beginRenderTarget(.invalid)
        renderer.endRenderTarget()
        renderer.destroyRenderTarget(.invalid)
    }
}

// MARK: - Mock Backend Tests

@Suite("RenderTarget Mock Backend Tests")
struct RenderTargetMockTests {

    @Test("Create returns valid handle")
    func createReturnsValid() {
        let renderer = MockRTRenderer()
        let handle = renderer.createRenderTarget(width: 320, height: 240)
        #expect(handle != .invalid)
    }

    @Test("renderTargetTexture returns valid handle")
    func textureIsValid() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 100, height: 100)
        let tex = renderer.renderTargetTexture(rt)
        #expect(tex != .invalid)
    }

    @Test("renderTargetSize returns correct dimensions")
    func sizeIsCorrect() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 320, height: 240)
        let size = renderer.renderTargetSize(rt)
        #expect(size.width == 320)
        #expect(size.height == 240)
    }

    @Test("begin/end sets and clears active target")
    func beginEndState() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 100, height: 100)

        #expect(renderer.activeTarget == nil)
        renderer.beginRenderTarget(rt)
        #expect(renderer.activeTarget == rt)
        renderer.endRenderTarget()
        #expect(renderer.activeTarget == nil)
    }

    @Test("Destroy invalidates subsequent lookups")
    func destroyInvalidates() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 100, height: 100)
        renderer.destroyRenderTarget(rt)

        #expect(renderer.renderTargetTexture(rt) == .invalid)
        #expect(renderer.renderTargetSize(rt).width == 0)
    }

    @Test("Multiple render targets coexist independently")
    func multipleTargets() {
        let renderer = MockRTRenderer()
        let rt1 = renderer.createRenderTarget(width: 100, height: 100)
        let rt2 = renderer.createRenderTarget(width: 200, height: 150)

        #expect(rt1 != rt2)
        #expect(renderer.renderTargetSize(rt1).width == 100)
        #expect(renderer.renderTargetSize(rt2).width == 200)
        #expect(renderer.renderTargetTexture(rt1) != renderer.renderTargetTexture(rt2))

        renderer.destroyRenderTarget(rt1)
        #expect(renderer.renderTargetTexture(rt1) == .invalid)
        #expect(renderer.renderTargetTexture(rt2) != .invalid)
    }

    @Test("Begin with invalid handle is a no-op")
    func beginInvalidNoOp() {
        let renderer = MockRTRenderer()
        renderer.beginRenderTarget(.invalid)
        #expect(renderer.activeTarget == nil)
    }

    @Test("Begin with destroyed handle is a no-op")
    func beginDestroyedNoOp() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 100, height: 100)
        renderer.destroyRenderTarget(rt)
        renderer.beginRenderTarget(rt)
        #expect(renderer.activeTarget == nil)
    }
}

// MARK: - drawRenderTarget Convenience Tests

@Suite("drawRenderTarget Convenience Tests")
struct DrawRenderTargetTests {

    @Test("drawRenderTarget draws sprite with flipY true")
    func drawFlipsY() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 320, height: 240)

        renderer.drawRenderTarget(rt, position: Vector2(x: 10, y: 20))

        #expect(renderer.drawnSprites.count == 1)
        let sprite = renderer.drawnSprites[0]
        #expect(sprite.flipY == true)
        #expect(sprite.position.x == 10)
        #expect(sprite.position.y == 20)
        #expect(sprite.sourceRect.width == 320)
        #expect(sprite.sourceRect.height == 240)
    }

    @Test("drawRenderTarget with destination scales correctly")
    func drawWithDestination() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 320, height: 240)

        renderer.drawRenderTarget(rt, destination: Rect(x: 0, y: 0, width: 640, height: 480))

        #expect(renderer.drawnSprites.count == 1)
        let sprite = renderer.drawnSprites[0]
        #expect(sprite.flipY == true)
        #expect(sprite.scale.x == 2.0)
        #expect(sprite.scale.y == 2.0)
    }

    @Test("drawRenderTarget with invalid handle does nothing")
    func drawInvalidNoOp() {
        let renderer = MockRTRenderer()
        renderer.drawRenderTarget(.invalid)
        #expect(renderer.drawnSprites.isEmpty)
    }

    @Test("drawRenderTarget applies tint")
    func drawWithTint() {
        let renderer = MockRTRenderer()
        let rt = renderer.createRenderTarget(width: 100, height: 100)
        let tint = Color(r: 255, g: 0, b: 0, a: 128)

        renderer.drawRenderTarget(rt, tint: tint)

        #expect(renderer.drawnSprites.count == 1)
        #expect(renderer.drawnSprites[0].tint == tint)
    }
}
