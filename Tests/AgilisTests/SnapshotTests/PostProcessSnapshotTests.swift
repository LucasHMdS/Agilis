@testable import Agilis
import Testing

@Suite("Post Process Snapshots", .serialized)
struct PostProcessSnapshotTests {

    /// Draw a reference scene with shapes for post-process testing.
    private static func drawScene(_ r: Renderer) {
        r.drawRect(
            Rect(x: 40, y: 30, width: 100, height: 80),
            color: Color(r: 255, g: 50, b: 50)
        )
        r.drawRect(
            Rect(x: 160, y: 60, width: 80, height: 100),
            color: Color(r: 50, g: 255, b: 50)
        )
        r.drawCircle(
            center: Vector2(x: 260, y: 120),
            radius: 40,
            color: Color(r: 50, g: 50, b: 255)
        )
        r.drawCircle(
            center: Vector2(x: 100, y: 180),
            radius: 25,
            color: Color(r: 255, g: 255, b: 0)
        )
    }

    /// Helper to capture a frame with a single post-process effect applied.
    private static func captureWithEffect(
        renderer: Renderer,
        effect: any PostProcessEffect
    ) -> ImageData? {
        let pipeline = PostProcessPipeline()
        pipeline.add(effect)
        pipeline.initialize(renderer: renderer)
        defer { pipeline.shutdown(renderer: renderer) }

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        return SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            pipeline.beginCapture(renderer: r)
            Self.drawScene(r)
            pipeline.endCaptureAndApply(renderer: r, deltaTime: 0)
        }
    }

    @Test("Vignette effect")
    func vignette() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let image = try #require(Self.captureWithEffect(
            renderer: renderer,
            effect: VignetteEffect(intensity: 0.6, radius: 0.7, softness: 0.4)
        ))
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "vignette")
    }

    @Test("Pixelate effect")
    func pixelate() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let image = try #require(Self.captureWithEffect(
            renderer: renderer,
            effect: PixelateEffect(pixelSize: 6.0)
        ))
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "pixelate")
    }

    @Test("Scanlines effect")
    func scanlines() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let image = try #require(Self.captureWithEffect(
            renderer: renderer,
            effect: ScanlinesEffect(lineSpacing: 3.0, lineIntensity: 0.3)
        ))
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "scanlines")
    }

    @Test("Chromatic aberration effect")
    func chromaticAberration() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let image = try #require(Self.captureWithEffect(
            renderer: renderer,
            effect: ChromaticAberrationEffect(amount: 0.005)
        ))
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "chromatic-aberration")
    }

    @Test("Color grading — increased contrast")
    func colorGradingContrast() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let image = try #require(Self.captureWithEffect(
            renderer: renderer,
            effect: ColorGradingEffect(contrast: 1.8)
        ))
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "color-grading-contrast")
    }

    @Test("Color grading — full desaturation")
    func colorGradingDesaturate() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let image = try #require(Self.captureWithEffect(
            renderer: renderer,
            effect: ColorGradingEffect(saturation: 0)
        ))
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "color-grading-desat")
    }

    @Test("Bloom effect")
    func bloom() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let image = try #require(Self.captureWithEffect(
            renderer: renderer,
            effect: BloomEffect(threshold: 0.5, intensity: 1.5)
        ))
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "bloom")
    }

    @Test("Pipeline with two effects chained")
    func pipelineChain() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let pipeline = PostProcessPipeline()
        pipeline.add(VignetteEffect(intensity: 0.5))
        pipeline.add(ColorGradingEffect(saturation: 0.5))
        pipeline.initialize(renderer: renderer)
        defer { pipeline.shutdown(renderer: renderer) }

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            pipeline.beginCapture(renderer: r)
            Self.drawScene(r)
            pipeline.endCaptureAndApply(renderer: r, deltaTime: 0)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "pipeline-chain")
    }

    @Test("All effects disabled — passthrough")
    func disabledPassthrough() throws {
        guard let renderer = SnapshotTestUtilities.createHeadlessRenderer() else {
            try #require(Bool(false), "Headless renderer unavailable"); return
        }
        defer { SnapshotTestUtilities.shutdownRenderer(renderer) }

        let pipeline = PostProcessPipeline()
        let vignette = VignetteEffect(intensity: 0.8)
        vignette.isEnabled = false
        let pixelate = PixelateEffect(pixelSize: 8)
        pixelate.isEnabled = false
        pipeline.add(vignette)
        pipeline.add(pixelate)
        pipeline.initialize(renderer: renderer)
        defer { pipeline.shutdown(renderer: renderer) }

        renderer.setBackgroundColor(Color(r: 30, g: 30, b: 30))
        let image = try #require(SnapshotTestUtilities.captureFrame(renderer: renderer) { r in
            pipeline.beginCapture(renderer: r)
            Self.drawScene(r)
            pipeline.endCaptureAndApply(renderer: r, deltaTime: 0)
        })
        SnapshotTestHelper.assertSnapshot(image, suite: "PostProcess", name: "disabled-passthrough")
    }
}
