import Testing
@testable import Agilis

@Suite("Debug Renderer Snapshots", .serialized)
struct DebugRendererSnapshotTests {

    @Test("TileMap debug grid lines")
    func tileMapGrid() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        // Create a minimal tilemap for debug rendering
        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 32, height: 32
        )
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 1, firstGid: 1, tileCount: 1)
        let tiles = [Tile](repeating: Tile(id: 1), count: 16)
        let layer = TileLayer(name: "main", width: 4, height: 4, tiles: tiles)
        let tileMap = TileMap(
            layers: [layer], tilesets: [tileset],
            tileWidth: 32, tileHeight: 32, width: 4, height: 4
        )

        let camera = Camera2D()

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTileMap(tileMap, position: .zero, camera: camera)
            var options = TileMapDebugRendererOptions()
            options.drawGrid = true
            options.drawCullingRect = false
            r.drawTileMapDebug(tileMap: tileMap, position: .zero, camera: camera, options: options)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "tilemap-debug-grid")
    }

    @Test("TileMap debug culling rect")
    func tileMapCullingRect() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 32, height: 32
        )
        defer { renderer.destroyTexture(tex) }

        let tileset = Tileset(texture: tex, tileWidth: 32, tileHeight: 32,
                              columns: 1, firstGid: 1, tileCount: 1)
        let tiles = [Tile](repeating: Tile(id: 1), count: 64) // 8x8
        let layer = TileLayer(name: "main", width: 8, height: 8, tiles: tiles)
        let tileMap = TileMap(
            layers: [layer], tilesets: [tileset],
            tileWidth: 32, tileHeight: 32, width: 8, height: 8
        )

        var camera = Camera2D()
        camera.target = Vector2(x: 128, y: 128)
        camera.offset = Vector2(x: 160, y: 120)

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.beginCamera(camera)
            r.drawTileMap(tileMap, position: .zero, camera: camera)
            r.endCamera()
            var options = TileMapDebugRendererOptions()
            options.drawGrid = false
            options.drawCullingRect = true
            r.drawTileMapDebug(tileMap: tileMap, position: .zero, camera: camera, options: options)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "tilemap-debug-culling")
    }

    @Test("Particle debug — point emitter")
    func particlePointEmitter() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let world = World()

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)
        world.addComponent(ParticleEmitter(
            emissionShape: .point, renderShape: .circle(radius: 3)
        ), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticleDebug(world: world, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "particle-debug-point")
    }

    @Test("Particle debug — circle emitter")
    func particleCircleEmitter() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let world = World()

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)
        world.addComponent(ParticleEmitter(
            emissionShape: .circle(radius: 40), renderShape: .circle(radius: 3)
        ), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticleDebug(world: world, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "particle-debug-circle")
    }

    @Test("Particle debug — rect emitter")
    func particleRectEmitter() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let world = World()

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 160, y: 120)), to: entity)
        world.addComponent(ParticleEmitter(
            emissionShape: .rect(width: 80, height: 50), renderShape: .circle(radius: 3)
        ), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawParticleDebug(world: world, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "particle-debug-rect")
    }

    @Test("UI debug bounds and ID labels")
    func uiDebugBounds() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()

        let context = UIContext(font: font)
        let panel = UIPanel(layout: .vertical(spacing: 8), padding: 12)
        panel.backgroundColor = Color(r: 40, g: 40, b: 60)
        panel.add(UILabel("Label 1", fontSize: 14))
        panel.add(UIButton("Button", fontSize: 14))
        context.add(panel)

        // Manual layout
        UILayoutEngine.performLayout(
            on: context.root,
            in: Rect(x: 0, y: 0, width: 320, height: 240),
            renderer: renderer, font: font
        )

        renderer.setBackgroundColor(Color(r: 20, g: 20, b: 20))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            context.root.render(renderer: r, theme: context.theme)
            r.drawUIDebug(context: context, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "ui-debug-bounds")
    }

    @Test("Tween debug path line")
    func tweenPathLine() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let world = World()

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 80, y: 80)), to: entity)

        let infos = [
            TweenDebugInfo(
                entity: entity,
                targetType: "position",
                progress: 0.4,
                targetPosition: Vector2(x: 240, y: 180)
            )
        ]

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTweenDebug(infos: infos, world: world, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "tween-debug-path")
    }

    @Test("Tween debug progress label")
    func tweenProgress() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let world = World()

        let e1 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 80)), to: e1)

        let e2 = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 200, y: 150)), to: e2)

        let infos = [
            TweenDebugInfo(entity: e1, targetType: "scale", progress: 0.7, targetPosition: nil),
            TweenDebugInfo(entity: e2, targetType: "rotation", progress: 0.3, targetPosition: nil),
        ]

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawTweenDebug(infos: infos, world: world, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "tween-debug-progress")
    }

    @Test("Animation debug source rect and state")
    func animationSourceRect() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let font = renderer.loadDefaultFont()
        let world = World()

        let tex = SnapshotTestUtilities.createSolidTexture(
            renderer: renderer, width: 128, height: 32,
            color: Color(r: 100, g: 100, b: 200)
        )
        defer { renderer.destroyTexture(tex) }

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 120, y: 100)), to: entity)

        var sprite = Sprite(texture: tex)
        sprite.sourceRect = Rect(x: 0, y: 0, width: 32, height: 32)
        sprite.position = Vector2(x: 120, y: 100)
        world.addComponent(sprite, to: entity)

        let clip = AnimationClip(
            name: "walk",
            frames: [
                AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1),
                AnimationFrame(sourceRect: Rect(x: 32, y: 0, width: 32, height: 32), duration: 0.1),
            ]
        )
        world.addComponent(SpriteAnimator(clip: clip), to: entity)

        renderer.setBackgroundColor(Color(r: 0, g: 0, b: 0))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            r.drawSprite(sprite)
            r.drawAnimationDebug(world: world, font: font)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "DebugRenderers", name: "anim-debug-source-rect")
    }
}
