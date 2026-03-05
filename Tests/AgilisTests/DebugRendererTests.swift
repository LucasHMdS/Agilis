import Testing
@testable import Agilis

// MARK: - Spy Renderer

private final class DebugRendererSpy: @unchecked Sendable, RenderBackend {
    struct RectOutlineCall {
        let rect: Rect
        let color: Color
        let thickness: Float
    }
    struct CircleOutlineCall {
        let center: Vector2
        let radius: Float
        let color: Color
    }
    struct LineCall {
        let from: Vector2
        let to: Vector2
        let color: Color
    }
    struct CircleCall {
        let center: Vector2
        let radius: Float
        let color: Color
    }
    struct TextCall {
        let text: String
        let position: Vector2
        let color: Color
        let size: Float
    }

    var rectOutlineCalls: [RectOutlineCall] = []
    var circleOutlineCalls: [CircleOutlineCall] = []
    var lineCalls: [LineCall] = []
    var circleCalls: [CircleCall] = []
    var textCalls: [TextCall] = []

    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {
        rectOutlineCalls.append(RectOutlineCall(rect: rect, color: color, thickness: thickness))
    }
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {
        circleOutlineCalls.append(CircleOutlineCall(center: center, radius: radius, color: color))
    }
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {
        lineCalls.append(LineCall(from: start, to: end, color: color))
    }
    func drawCircle(center: Vector2, radius: Float, color: Color) {
        circleCalls.append(CircleCall(center: center, radius: radius, color: color))
    }
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {
        textCalls.append(TextCall(text: text, position: position, color: color, size: size))
    }

    // Unused stubs
    func drawRect(_ rect: Rect, color: Color) {}
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
    func beginClip(_ rect: Rect) {}
    func endClip() {}
    func beginCamera(_ camera: Camera2D) {}
    func endCamera() {}
    var screenSize: Size { Size(width: 800, height: 600) }
}

private let testFont = FontHandle(id: 1)

// MARK: - AnimationDebugRendererOptions Tests

@Suite("AnimationDebugRendererOptions Tests")
struct AnimationDebugRendererOptionsTests {

    @Test("Default options")
    func defaults() {
        let options = AnimationDebugRendererOptions()
        #expect(options.drawSourceRects == true)
        #expect(options.drawAnimatorState == true)
        #expect(options.sourceRectColor == .green)
        #expect(options.stateTextColor == .white)
        #expect(options.fontSize == 12)
    }

    @Test("Custom options")
    func custom() {
        let options = AnimationDebugRendererOptions(drawSourceRects: false, drawAnimatorState: false, fontSize: 16)
        #expect(options.drawSourceRects == false)
        #expect(options.drawAnimatorState == false)
        #expect(options.fontSize == 16)
    }
}

// MARK: - AnimationDebugRenderer Tests

@Suite("AnimationDebugRenderer Tests")
struct AnimationDebugRendererTests {

    @Test("Draws source rect outline for animated sprite")
    func drawsSourceRect() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()

        let clip = AnimationClip(name: "walk", frames: [
            AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1)
        ])
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 200)), to: entity)
        world.addComponent(SpriteAnimator(clip: clip), to: entity)
        world.addComponent(Sprite(texture: .invalid), to: entity)

        renderer.drawAnimationDebug(world: world, font: testFont)

        #expect(renderer.rectOutlineCalls.count == 1)
        #expect(renderer.rectOutlineCalls[0].color == .green)
    }

    @Test("Draws animator state text")
    func drawsAnimatorState() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()

        let clip = AnimationClip(name: "idle", frames: [
            AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 16, height: 16), duration: 0.2),
            AnimationFrame(sourceRect: Rect(x: 16, y: 0, width: 16, height: 16), duration: 0.2)
        ])
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: entity)
        world.addComponent(SpriteAnimator(clip: clip), to: entity)
        world.addComponent(Sprite(texture: .invalid), to: entity)

        renderer.drawAnimationDebug(world: world, font: testFont)

        let stateTexts = renderer.textCalls.filter { $0.text.contains("idle") }
        #expect(!stateTexts.isEmpty)
        // Playing indicator
        let playingTexts = renderer.textCalls.filter { $0.text.contains(">") }
        #expect(!playingTexts.isEmpty)
    }

    @Test("Respects disabled source rects option")
    func disabledSourceRects() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()

        let clip = AnimationClip(name: "run", frames: [
            AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1)
        ])
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.addComponent(SpriteAnimator(clip: clip), to: entity)
        world.addComponent(Sprite(texture: .invalid), to: entity)

        let options = AnimationDebugRendererOptions(drawSourceRects: false)
        renderer.drawAnimationDebug(world: world, font: testFont, options: options)

        #expect(renderer.rectOutlineCalls.isEmpty)
    }

    @Test("Respects disabled animator state option")
    func disabledAnimatorState() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()

        let clip = AnimationClip(name: "walk", frames: [
            AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1)
        ])
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.addComponent(SpriteAnimator(clip: clip), to: entity)
        world.addComponent(Sprite(texture: .invalid), to: entity)

        let options = AnimationDebugRendererOptions(drawAnimatorState: false)
        renderer.drawAnimationDebug(world: world, font: testFont, options: options)

        #expect(renderer.textCalls.isEmpty)
    }

    @Test("No draw calls for empty world")
    func emptyWorld() {
        let renderer = DebugRendererSpy()
        let world = World()

        renderer.drawAnimationDebug(world: world, font: testFont)

        #expect(renderer.rectOutlineCalls.isEmpty)
        #expect(renderer.textCalls.isEmpty)
    }
}

// MARK: - TweenDebugRendererOptions Tests

@Suite("TweenDebugRendererOptions Tests")
struct TweenDebugRendererOptionsTests {

    @Test("Default options")
    func defaults() {
        let options = TweenDebugRendererOptions()
        #expect(options.drawPaths == true)
        #expect(options.drawProgress == true)
        #expect(options.pathColor == .magenta)
        #expect(options.fontSize == 12)
    }

    @Test("Custom options")
    func custom() {
        let options = TweenDebugRendererOptions(drawPaths: false, pathColor: .red)
        #expect(options.drawPaths == false)
        #expect(options.pathColor == .red)
    }
}

// MARK: - TweenDebugInfo Tests

@Suite("TweenDebugInfo Tests")
struct TweenDebugInfoTests {

    @Test("Stores all fields")
    func fields() {
        let entity = Entity(index: 5, generation: 1)
        let info = TweenDebugInfo(entity: entity, targetType: "pos", progress: 0.5, targetPosition: Vector2(x: 100, y: 200))

        #expect(info.entity == entity)
        #expect(info.targetType == "pos")
        #expect(info.progress == 0.5)
        #expect(info.targetPosition == Vector2(x: 100, y: 200))
    }

    @Test("Nil target position for non-position tweens")
    func nilTarget() {
        let info = TweenDebugInfo(entity: Entity(index: 0, generation: 0), targetType: "rot", progress: 0.3, targetPosition: nil)
        #expect(info.targetPosition == nil)
    }
}

// MARK: - TweenDebugRenderer Tests

@Suite("TweenDebugRenderer Tests")
struct TweenDebugRendererTests {

    @Test("Draws path line for position tween")
    func drawsPathLine() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: entity)

        let info = TweenDebugInfo(entity: entity, targetType: "pos", progress: 0.5, targetPosition: Vector2(x: 200, y: 300))
        renderer.drawTweenDebug(infos: [info], world: world, font: testFont)

        #expect(renderer.lineCalls.count == 1)
        #expect(renderer.circleCalls.count == 1) // target dot
    }

    @Test("Draws progress text")
    func drawsProgress() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: entity)

        let info = TweenDebugInfo(entity: entity, targetType: "scale", progress: 0.75, targetPosition: nil)
        renderer.drawTweenDebug(infos: [info], world: world, font: testFont)

        let progressTexts = renderer.textCalls.filter { $0.text.contains("75%") }
        #expect(!progressTexts.isEmpty)
        let typeTexts = renderer.textCalls.filter { $0.text.contains("scale") }
        #expect(!typeTexts.isEmpty)
    }

    @Test("No path line when drawPaths disabled")
    func disabledPaths() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)

        let info = TweenDebugInfo(entity: entity, targetType: "pos", progress: 0.5, targetPosition: Vector2(x: 100, y: 100))
        let options = TweenDebugRendererOptions(drawPaths: false)
        renderer.drawTweenDebug(infos: [info], world: world, font: testFont, options: options)

        #expect(renderer.lineCalls.isEmpty)
        #expect(renderer.circleCalls.isEmpty)
    }

    @Test("No text when drawProgress disabled")
    func disabledProgress() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)

        let info = TweenDebugInfo(entity: entity, targetType: "pos", progress: 0.5, targetPosition: Vector2(x: 100, y: 100))
        let options = TweenDebugRendererOptions(drawProgress: false)
        renderer.drawTweenDebug(infos: [info], world: world, font: testFont, options: options)

        #expect(renderer.textCalls.isEmpty)
    }

    @Test("Skips dead entities")
    func skipsDeadEntities() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.destroyEntity(entity)

        let info = TweenDebugInfo(entity: entity, targetType: "pos", progress: 0.5, targetPosition: Vector2(x: 100, y: 100))
        renderer.drawTweenDebug(infos: [info], world: world, font: testFont)

        #expect(renderer.lineCalls.isEmpty)
        #expect(renderer.textCalls.isEmpty)
    }

    @Test("No path line when targetPosition is nil")
    func noPathForNonPositionTween() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: entity)

        let info = TweenDebugInfo(entity: entity, targetType: "rot", progress: 0.5, targetPosition: nil)
        renderer.drawTweenDebug(infos: [info], world: world, font: testFont)

        #expect(renderer.lineCalls.isEmpty)
        #expect(renderer.circleCalls.isEmpty)
        // But progress text should still appear
        #expect(!renderer.textCalls.isEmpty)
    }

    @Test("Empty infos array draws nothing")
    func emptyInfos() {
        let renderer = DebugRendererSpy()
        let world = World()

        renderer.drawTweenDebug(infos: [], world: world, font: testFont)

        #expect(renderer.lineCalls.isEmpty)
        #expect(renderer.textCalls.isEmpty)
    }
}

// MARK: - TweenSystem debugTweenInfo Tests

@Suite("TweenSystem debugTweenInfo Tests")
struct TweenSystemDebugInfoTests {

    @Test("Returns empty for no tweens")
    func emptyWhenNoTweens() {
        let world = World()
        let tweens = TweenSystem()
        world.addSystem(tweens)

        let infos = tweens.debugTweenInfo(world: world)
        #expect(infos.isEmpty)
    }

    @Test("Returns info for active position tween")
    func activePositionTween() {
        let world = World()
        let tweens = TweenSystem()
        world.addSystem(tweens)

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 0, y: 0)), to: entity)

        tweens.moveTo(entity, target: Vector2(x: 100, y: 100), duration: 1.0, in: world)

        let infos = tweens.debugTweenInfo(world: world)
        #expect(infos.count == 1)
        #expect(infos[0].targetType == "pos")
        #expect(infos[0].targetPosition == Vector2(x: 100, y: 100))
        #expect(infos[0].entity == entity)
    }

    @Test("Returns info for scale tween without target position")
    func scaleTween() {
        let world = World()
        let tweens = TweenSystem()
        world.addSystem(tweens)

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)

        tweens.scaleTo(entity, target: Vector2(x: 2, y: 2), duration: 1.0, in: world)

        let infos = tweens.debugTweenInfo(world: world)
        #expect(infos.count == 1)
        #expect(infos[0].targetType == "scale")
        #expect(infos[0].targetPosition == nil)
    }

    @Test("Progress advances after update")
    func progressAdvances() {
        let world = World()
        let tweens = TweenSystem()
        world.addSystem(tweens)

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)

        tweens.moveTo(entity, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)

        // Run a half-second update
        world.update(deltaTime: 0.5)

        let infos = tweens.debugTweenInfo(world: world)
        #expect(infos.count == 1)
        #expect(infos[0].progress >= 0.4 && infos[0].progress <= 0.6)
    }
}

// MARK: - ParticleDebugRendererOptions Tests

@Suite("ParticleDebugRendererOptions Tests")
struct ParticleDebugRendererOptionsTests {

    @Test("Default options")
    func defaults() {
        let options = ParticleDebugRendererOptions()
        #expect(options.drawEmissionShape == true)
        #expect(options.drawParticleCount == true)
        #expect(options.emissionShapeColor == .yellow)
        #expect(options.fontSize == 12)
    }

    @Test("Custom options")
    func custom() {
        let options = ParticleDebugRendererOptions(drawEmissionShape: false, emissionShapeColor: .red)
        #expect(options.drawEmissionShape == false)
        #expect(options.emissionShapeColor == .red)
    }
}

// MARK: - ParticleDebugRenderer Tests

@Suite("ParticleDebugRenderer Tests")
struct ParticleDebugRendererTests {

    @Test("Draws crosshair for point emission shape")
    func pointShape() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: entity)
        world.addComponent(ParticleEmitter(emissionShape: .point), to: entity)

        renderer.drawParticleDebug(world: world, font: testFont)

        // Crosshair = 2 lines
        #expect(renderer.lineCalls.count == 2)
    }

    @Test("Draws circle outline for circle emission shape")
    func circleShape() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: entity)
        world.addComponent(ParticleEmitter(emissionShape: .circle(radius: 50)), to: entity)

        renderer.drawParticleDebug(world: world, font: testFont)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleOutlineCalls[0].radius == 50)
    }

    @Test("Draws ring outline with center dot for ring emission shape")
    func ringShape() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 200, y: 200)), to: entity)
        world.addComponent(ParticleEmitter(emissionShape: .ring(radius: 30)), to: entity)

        renderer.drawParticleDebug(world: world, font: testFont)

        #expect(renderer.circleOutlineCalls.count == 1)
        #expect(renderer.circleCalls.count == 1) // center dot
    }

    @Test("Draws rect outline for rect emission shape")
    func rectShape() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: entity)
        world.addComponent(ParticleEmitter(emissionShape: .rect(width: 80, height: 60)), to: entity)

        renderer.drawParticleDebug(world: world, font: testFont)

        #expect(renderer.rectOutlineCalls.count == 1)
    }

    @Test("Draws particle count label")
    func particleCountLabel() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 100)), to: entity)
        world.addComponent(ParticleEmitter(maxParticles: 200, isEmitting: true), to: entity)

        renderer.drawParticleDebug(world: world, font: testFont)

        let countTexts = renderer.textCalls.filter { $0.text.contains("/200") }
        #expect(!countTexts.isEmpty)
        let statusTexts = renderer.textCalls.filter { $0.text.contains("[ON]") }
        #expect(!statusTexts.isEmpty)
    }

    @Test("Shows OFF status when not emitting")
    func notEmitting() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.addComponent(ParticleEmitter(isEmitting: false), to: entity)

        renderer.drawParticleDebug(world: world, font: testFont)

        let statusTexts = renderer.textCalls.filter { $0.text.contains("[OFF]") }
        #expect(!statusTexts.isEmpty)
    }

    @Test("Respects disabled emission shape option")
    func disabledEmissionShape() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.addComponent(ParticleEmitter(emissionShape: .circle(radius: 50)), to: entity)

        let options = ParticleDebugRendererOptions(drawEmissionShape: false)
        renderer.drawParticleDebug(world: world, font: testFont, options: options)

        #expect(renderer.circleOutlineCalls.isEmpty)
    }

    @Test("Respects disabled particle count option")
    func disabledParticleCount() {
        let renderer = DebugRendererSpy()
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Transform2D(position: .zero), to: entity)
        world.addComponent(ParticleEmitter(), to: entity)

        let options = ParticleDebugRendererOptions(drawParticleCount: false)
        renderer.drawParticleDebug(world: world, font: testFont, options: options)

        #expect(renderer.textCalls.isEmpty)
    }

    @Test("No draw calls for empty world")
    func emptyWorld() {
        let renderer = DebugRendererSpy()
        let world = World()

        renderer.drawParticleDebug(world: world, font: testFont)

        #expect(renderer.lineCalls.isEmpty)
        #expect(renderer.textCalls.isEmpty)
    }
}

// MARK: - TileMapDebugRendererOptions Tests

@Suite("TileMapDebugRendererOptions Tests")
struct TileMapDebugRendererOptionsTests {

    @Test("Default options")
    func defaults() {
        let options = TileMapDebugRendererOptions()
        #expect(options.drawGrid == true)
        #expect(options.drawCullingRect == true)
        #expect(options.cullingRectColor == .yellow)
    }

    @Test("Custom options")
    func custom() {
        let options = TileMapDebugRendererOptions(drawGrid: false, drawCullingRect: false)
        #expect(options.drawGrid == false)
        #expect(options.drawCullingRect == false)
    }
}

// MARK: - TileMapDebugRenderer Tests

@Suite("TileMapDebugRenderer Tests")
struct TileMapDebugRendererTests {

    private func makeTestTileMap() -> TileMap {
        let tiles = (0..<100).map { Tile(id: $0 + 1) }
        let layer = TileLayer(name: "ground", width: 10, height: 10, tiles: tiles)
        let tileset = Tileset(texture: .invalid, tileWidth: 32, tileHeight: 32, columns: 10, firstGid: 1, tileCount: 100)
        return TileMap(layers: [layer], tilesets: [tileset], tileWidth: 32, tileHeight: 32, width: 10, height: 10)
    }

    @Test("Draws culling rect")
    func drawsCullingRect() {
        let renderer = DebugRendererSpy()
        let camera = Camera2D(target: .zero, offset: .zero, zoom: 1.0)
        let tileMap = makeTestTileMap()

        renderer.drawTileMapDebug(tileMap: tileMap, camera: camera)

        // Should draw at least one rect outline for culling rect
        let yellowRects = renderer.rectOutlineCalls.filter { $0.color == .yellow }
        #expect(!yellowRects.isEmpty)
    }

    @Test("Draws grid lines")
    func drawsGridLines() {
        let renderer = DebugRendererSpy()
        let camera = Camera2D(target: Vector2(x: 160, y: 160), offset: Vector2(x: 400, y: 300), zoom: 1.0)
        let tileMap = makeTestTileMap()

        renderer.drawTileMapDebug(tileMap: tileMap, camera: camera)

        // Grid lines are drawn with the gridColor (semi-transparent white)
        // Should have both vertical and horizontal lines
        #expect(renderer.lineCalls.count > 0)
    }

    @Test("No grid when drawGrid disabled")
    func disabledGrid() {
        let renderer = DebugRendererSpy()
        let camera = Camera2D(target: Vector2(x: 160, y: 160), offset: Vector2(x: 400, y: 300), zoom: 1.0)
        let tileMap = makeTestTileMap()

        let options = TileMapDebugRendererOptions(drawGrid: false)
        renderer.drawTileMapDebug(tileMap: tileMap, camera: camera, options: options)

        #expect(renderer.lineCalls.isEmpty)
    }

    @Test("No culling rect when disabled")
    func disabledCullingRect() {
        let renderer = DebugRendererSpy()
        let camera = Camera2D(target: .zero, offset: .zero, zoom: 1.0)
        let tileMap = makeTestTileMap()

        let options = TileMapDebugRendererOptions(drawGrid: false, drawCullingRect: false)
        renderer.drawTileMapDebug(tileMap: tileMap, camera: camera, options: options)

        #expect(renderer.rectOutlineCalls.isEmpty)
    }

    @Test("Zero tile size draws nothing")
    func zeroTileSize() {
        let renderer = DebugRendererSpy()
        let camera = Camera2D()
        let tileMap = TileMap(layers: [], tilesets: [], tileWidth: 0, tileHeight: 0, width: 10, height: 10)

        renderer.drawTileMapDebug(tileMap: tileMap, camera: camera)

        #expect(renderer.lineCalls.isEmpty)
        #expect(renderer.rectOutlineCalls.isEmpty)
    }
}

// MARK: - UIDebugRendererOptions Tests

@Suite("UIDebugRendererOptions Tests")
struct UIDebugRendererOptionsTests {

    @Test("Default options")
    func defaults() {
        let options = UIDebugRendererOptions()
        #expect(options.drawBounds == true)
        #expect(options.boundsColor == .cyan)
        #expect(options.fontSize == 10)
    }

    @Test("Custom options")
    func custom() {
        let options = UIDebugRendererOptions(drawBounds: false, boundsColor: .red, fontSize: 14)
        #expect(options.drawBounds == false)
        #expect(options.boundsColor == .red)
        #expect(options.fontSize == 14)
    }
}

// MARK: - UIDebugRenderer Tests

@Suite("UIDebugRenderer Tests")
struct UIDebugRendererTests {

    @Test("Draws bounds for root with children")
    func drawsBounds() {
        let renderer = DebugRendererSpy()
        let ctx = UIContext(font: testFont)
        ctx.root.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        let child = UINode(id: "button1")
        child.frame = Rect(x: 10, y: 10, width: 100, height: 30)
        ctx.root.add(child)

        renderer.drawUIDebug(context: ctx, font: testFont)

        // Should draw at least root rect + child rect
        #expect(renderer.rectOutlineCalls.count >= 2)
    }

    @Test("Draws node ID labels")
    func drawsNodeIds() {
        let renderer = DebugRendererSpy()
        let ctx = UIContext(font: testFont)
        ctx.root.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        let child = UINode(id: "myLabel")
        child.frame = Rect(x: 10, y: 10, width: 100, height: 30)
        ctx.root.add(child)

        renderer.drawUIDebug(context: ctx, font: testFont)

        let idTexts = renderer.textCalls.filter { $0.text == "myLabel" }
        #expect(!idTexts.isEmpty)
    }

    @Test("Recurses into nested containers")
    func recursesContainers() {
        let renderer = DebugRendererSpy()
        let ctx = UIContext(font: testFont)
        ctx.root.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        let panel = UIContainer(id: "panel")
        panel.frame = Rect(x: 10, y: 10, width: 200, height: 200)
        ctx.root.add(panel)

        let inner = UINode(id: "innerNode")
        inner.frame = Rect(x: 20, y: 20, width: 50, height: 50)
        panel.add(inner)

        renderer.drawUIDebug(context: ctx, font: testFont)

        // root + panel + inner = 3 rect outlines
        #expect(renderer.rectOutlineCalls.count >= 3)
        let innerTexts = renderer.textCalls.filter { $0.text == "innerNode" }
        #expect(!innerTexts.isEmpty)
    }

    @Test("Skips zero-size nodes")
    func skipsZeroSize() {
        let renderer = DebugRendererSpy()
        let ctx = UIContext(font: testFont)
        ctx.root.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        let zeroNode = UINode(id: "hidden")
        zeroNode.frame = Rect(x: 0, y: 0, width: 0, height: 0)
        ctx.root.add(zeroNode)

        renderer.drawUIDebug(context: ctx, font: testFont)

        let hiddenTexts = renderer.textCalls.filter { $0.text == "hidden" }
        #expect(hiddenTexts.isEmpty)
    }

    @Test("No bounds when drawBounds disabled")
    func disabledBounds() {
        let renderer = DebugRendererSpy()
        let ctx = UIContext(font: testFont)
        ctx.root.frame = Rect(x: 0, y: 0, width: 800, height: 600)

        let child = UINode(id: "child")
        child.frame = Rect(x: 10, y: 10, width: 100, height: 30)
        ctx.root.add(child)

        let options = UIDebugRendererOptions(drawBounds: false)
        renderer.drawUIDebug(context: ctx, font: testFont, options: options)

        #expect(renderer.rectOutlineCalls.isEmpty)
        #expect(renderer.textCalls.isEmpty)
    }
}
