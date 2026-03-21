@testable import Agilis
import Testing
#if canImport(Foundation)
import Foundation
#endif

// MARK: - GPU Serialization Lock

/// Global lock to prevent concurrent ANGLE/D3D11 GPU access across test suites.
/// Swift Testing's `.serialized` trait only serializes tests WITHIN a suite.
/// Multiple `.serialized` suites can still run in parallel, causing D3D11 device
/// removal errors when multiple EGL contexts compete for the GPU.
/// This lock ensures only one headless renderer is active at a time.
#if canImport(Foundation)
private let gpuLock = NSLock()
#endif

// MARK: - Shared Headless Renderer Helpers

/// Shared utilities for snapshot tests.
/// All snapshot test suites should use these instead of duplicating helpers.
enum SnapshotTestUtilities {

    /// Acquire the GPU lock before creating a renderer.
    static func lockGPU() {
        #if canImport(Foundation)
        gpuLock.lock()
        #endif
    }

    /// Release the GPU lock after shutting down the renderer.
    static func unlockGPU() {
        #if canImport(Foundation)
        gpuLock.unlock()
        #endif
    }

    /// Create a headless renderer for snapshot testing.
    /// Returns nil if GPU initialization fails (e.g., no GPU available in CI).
    /// Automatically acquires the GPU lock. Caller MUST call shutdownRenderer() to release it.
    static func createHeadlessRenderer(
        width: Int = 320, height: Int = 240
    ) -> Renderer? {
        lockGPU()
        let renderer = Renderer()
        do {
            try renderer.initializeHeadless(width: width, height: height)
            return renderer
        } catch {
            unlockGPU()
            return nil
        }
    }

    /// Shutdown renderer and release the GPU lock acquired by createHeadlessRenderer().
    static func shutdownRenderer(_ renderer: Renderer) {
        renderer.shutdown()
        unlockGPU()
    }

    /// Render a frame and capture the result.
    /// Draws are done between beginFrame/endFrame, capture happens before endFrame
    /// so the pbuffer content is guaranteed to be available.
    static func captureFrame(
        renderer: Renderer,
        draw: (Renderer) -> Void
    ) -> ImageData? {
        renderer.beginFrame()
        draw(renderer)
        let image = renderer.captureScreen()
        renderer.endFrame()
        return image
    }

    /// Run a snapshot test with proper GPU locking.
    /// This acquires the GPU lock (via createHeadlessRenderer), runs the test body,
    /// and ensures cleanup happens correctly (via shutdownRenderer).
    static func withRenderer(
        width: Int = 320,
        height: Int = 240,
        body: (Renderer) throws -> Void
    ) throws {
        guard let renderer = createHeadlessRenderer(width: width, height: height) else {
            try #require(Bool(false), "Headless renderer unavailable")
            return
        }
        defer { shutdownRenderer(renderer) }
        try body(renderer)
    }
}

// MARK: - Programmatic Texture Generators

extension SnapshotTestUtilities {

    /// Create a solid-colored texture.
    static func createSolidTexture(
        renderer: Renderer,
        width: Int = 32,
        height: Int = 32,
        color: Color = .white
    ) -> TextureHandle {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            pixels[i * 4]     = color.r
            pixels[i * 4 + 1] = color.g
            pixels[i * 4 + 2] = color.b
            pixels[i * 4 + 3] = color.a
        }
        let image = ImageData(width: width, height: height, pixels: pixels)
        return renderer.loadTextureFromImage(image)
    }

    /// Create a checkerboard texture with two alternating tile colors.
    static func createCheckerboardTexture(
        renderer: Renderer,
        width: Int = 64,
        height: Int = 64,
        tileSize: Int = 16,
        colorA: Color = .white,
        colorB: Color = Color(r: 0, g: 0, b: 0)
    ) -> TextureHandle {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let tileX = x / tileSize
                let tileY = y / tileSize
                let color = (tileX + tileY) % 2 == 0 ? colorA : colorB
                let i = (y * width + x) * 4
                pixels[i]     = color.r
                pixels[i + 1] = color.g
                pixels[i + 2] = color.b
                pixels[i + 3] = color.a
            }
        }
        let image = ImageData(width: width, height: height, pixels: pixels)
        return renderer.loadTextureFromImage(image)
    }

    /// Create a horizontal gradient texture from one color to another.
    static func createGradientTexture(
        renderer: Renderer,
        width: Int = 64,
        height: Int = 64,
        fromColor: Color = Color(r: 255, g: 0, b: 0),
        toColor: Color = Color(r: 0, g: 0, b: 255)
    ) -> TextureHandle {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let t = Float(x) / Float(max(width - 1, 1))
                let r = UInt8(Float(fromColor.r) * (1 - t) + Float(toColor.r) * t)
                let g = UInt8(Float(fromColor.g) * (1 - t) + Float(toColor.g) * t)
                let b = UInt8(Float(fromColor.b) * (1 - t) + Float(toColor.b) * t)
                let a = UInt8(Float(fromColor.a) * (1 - t) + Float(toColor.a) * t)
                let i = (y * width + x) * 4
                pixels[i]     = r
                pixels[i + 1] = g
                pixels[i + 2] = b
                pixels[i + 3] = a
            }
        }
        let image = ImageData(width: width, height: height, pixels: pixels)
        return renderer.loadTextureFromImage(image)
    }

    /// Create a 4-quadrant RGBY pattern texture for verifying rotation/flip.
    /// Top-left: Red, Top-right: Green, Bottom-left: Blue, Bottom-right: Yellow.
    static func createPatternTexture(
        renderer: Renderer,
        width: Int = 32,
        height: Int = 32
    ) -> TextureHandle {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let halfW = width / 2
        let halfH = height / 2
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let color: Color
                if x < halfW && y < halfH {
                    color = Color(r: 255, g: 0, b: 0)       // Top-left: Red
                } else if x >= halfW && y < halfH {
                    color = Color(r: 0, g: 255, b: 0)       // Top-right: Green
                } else if x < halfW && y >= halfH {
                    color = Color(r: 0, g: 0, b: 255)       // Bottom-left: Blue
                } else {
                    color = Color(r: 255, g: 255, b: 0)     // Bottom-right: Yellow
                }
                pixels[i]     = color.r
                pixels[i + 1] = color.g
                pixels[i + 2] = color.b
                pixels[i + 3] = color.a
            }
        }
        let image = ImageData(width: width, height: height, pixels: pixels)
        return renderer.loadTextureFromImage(image)
    }

    /// Create a nine-patch-style texture with distinct border and center colors.
    /// Borders are one color, center is another — useful for testing nine-patch rendering.
    static func createNinePatchTexture(
        renderer: Renderer,
        width: Int = 48,
        height: Int = 48,
        borderSize: Int = 12,
        borderColor: Color = Color(r: 200, g: 50, b: 50),
        centerColor: Color = Color(r: 50, g: 50, b: 200)
    ) -> TextureHandle {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let isBorder = x < borderSize || x >= width - borderSize ||
                               y < borderSize || y >= height - borderSize
                let color = isBorder ? borderColor : centerColor
                pixels[i]     = color.r
                pixels[i + 1] = color.g
                pixels[i + 2] = color.b
                pixels[i + 3] = color.a
            }
        }
        let image = ImageData(width: width, height: height, pixels: pixels)
        return renderer.loadTextureFromImage(image)
    }
}
