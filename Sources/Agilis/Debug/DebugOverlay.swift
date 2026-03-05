import AgilisCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Configuration for the debug overlay HUD.
public struct DebugOverlayOptions: Sendable {
    /// Show FPS counter and frame time.
    public var showFPS: Bool
    /// Show frame time bar graph.
    public var showFrameGraph: Bool
    /// Show entity and component store counts.
    public var showEntityStats: Bool
    /// Show per-system timing breakdown.
    public var showSystemTimings: Bool
    /// Show on-screen log from ring buffer.
    public var showLog: Bool
    /// Maximum number of log lines to display.
    public var logLineCount: Int
    /// Font size for overlay text.
    public var fontSize: Float
    /// Background color for overlay panels.
    public var backgroundColor: Color
    /// Default text color.
    public var textColor: Color
    /// Color for warning-level log entries.
    public var warningColor: Color
    /// Color for error-level log entries.
    public var errorColor: Color
    /// Number of frame time samples in the graph.
    public var graphSamples: Int

    public init(
        showFPS: Bool = true,
        showFrameGraph: Bool = true,
        showEntityStats: Bool = true,
        showSystemTimings: Bool = true,
        showLog: Bool = true,
        logLineCount: Int = 8,
        fontSize: Float = 14,
        backgroundColor: Color = Color(r: 0, g: 0, b: 0, a: 180),
        textColor: Color = .white,
        warningColor: Color = .yellow,
        errorColor: Color = .red,
        graphSamples: Int = 120
    ) {
        self.showFPS = showFPS
        self.showFrameGraph = showFrameGraph
        self.showEntityStats = showEntityStats
        self.showSystemTimings = showSystemTimings
        self.showLog = showLog
        self.logLineCount = logLineCount
        self.fontSize = fontSize
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.warningColor = warningColor
        self.errorColor = errorColor
        self.graphSamples = graphSamples
    }
}

/// Unified debug HUD overlay.
///
/// Renders performance stats, ECS info, system timings, and log entries on top of the game.
/// All drawing is in screen space (no camera transform).
///
/// ## Usage
/// ```swift
/// let overlay = DebugOverlay(font: app.renderer.loadDefaultFont())
/// overlay.logBuffer = ringBuffer  // optional: show log entries
///
/// // In render():
/// overlay.render(renderer: app.renderer, app: app)
/// ```
public final class DebugOverlay: @unchecked Sendable {

    /// Font used for text rendering.
    public let font: FontHandle

    /// Options controlling what is displayed.
    public var options: DebugOverlayOptions

    /// Optional ring buffer for on-screen log display.
    public var logBuffer: RingBufferLogOutput?

    /// Whether the overlay is visible.
    public var isVisible: Bool = true

    private var frameHistory: [Double]
    private var frameWriteIndex: Int = 0
    private var frameCount: Int = 0

    public init(font: FontHandle, options: DebugOverlayOptions = DebugOverlayOptions()) {
        self.font = font
        self.options = options
        self.frameHistory = [Double](repeating: 0, count: options.graphSamples)
    }

    /// Record a frame time sample. Call once per frame before `render()`.
    public func recordFrame(frameTime: Double) {
        frameHistory[frameWriteIndex] = frameTime
        frameWriteIndex = (frameWriteIndex + 1) % frameHistory.count
        if frameCount < frameHistory.count { frameCount += 1 }
    }

    /// Draw the debug overlay. Call at the end of `render()`, outside any camera block.
    public func render(renderer: RenderBackend, app: Application) {
        guard isVisible else { return }

        let padding: Float = 6
        let lineHeight = options.fontSize + 2
        var y: Float = padding

        // FPS + Frame Time
        if options.showFPS {
            let fps = app.fps
            let ms = app.frameTime * 1000.0
            let text = "\(fps) FPS  \(String(format: "%.1f", ms))ms"
            let bg = Rect(x: 0, y: y - 2, width: 200, height: lineHeight + 4)
            renderer.drawRect(bg, color: options.backgroundColor)
            renderer.drawText(text, position: Vector2(x: padding, y: y),
                              font: font, size: options.fontSize, color: fpsColor(fps))
            y += lineHeight + 4
        }

        // Frame Time Graph
        if options.showFrameGraph && frameCount > 1 {
            let graphWidth: Float = 200
            let graphHeight: Float = 40
            let bg = Rect(x: 0, y: y, width: graphWidth + padding * 2, height: graphHeight + 4)
            renderer.drawRect(bg, color: options.backgroundColor)

            let barWidth = graphWidth / Float(frameHistory.count)
            let targetFT: Double = 1.0 / 60.0
            let maxFT = targetFT * 3.0

            for i in 0..<frameCount {
                let idx = (frameWriteIndex - frameCount + i + frameHistory.count) % frameHistory.count
                let ft = frameHistory[idx]
                let normalized = Float(min(ft / maxFT, 1.0))
                let barHeight = normalized * graphHeight

                let barColor: Color
                if ft <= targetFT * 1.1 {
                    barColor = Color(r: 80, g: 200, b: 80, a: 255)  // green
                } else if ft <= targetFT * 2.0 {
                    barColor = Color(r: 200, g: 200, b: 80, a: 255) // yellow
                } else {
                    barColor = Color(r: 200, g: 80, b: 80, a: 255)  // red
                }

                let bx = padding + Float(i) * barWidth
                let by = y + 2 + graphHeight - barHeight
                renderer.drawRect(
                    Rect(x: bx, y: by, width: max(barWidth - 1, 1), height: barHeight),
                    color: barColor
                )
            }

            // Target line (16.67ms)
            let targetY = y + 2 + graphHeight - graphHeight * Float(targetFT / maxFT)
            renderer.drawLine(
                from: Vector2(x: padding, y: targetY),
                to: Vector2(x: padding + graphWidth, y: targetY),
                color: Color(r: 255, g: 255, b: 255, a: 100),
                thickness: 1
            )

            y += graphHeight + 6
        }

        // Entity Stats
        if options.showEntityStats {
            let text = "Entities: \(app.world.entityCount)  Components: \(app.world.componentStoreCount)"
            let bg = Rect(x: 0, y: y - 2, width: 300, height: lineHeight + 4)
            renderer.drawRect(bg, color: options.backgroundColor)
            renderer.drawText(text, position: Vector2(x: padding, y: y),
                              font: font, size: options.fontSize, color: options.textColor)
            y += lineHeight + 4
        }

        // System Timings
        if options.showSystemTimings {
            let timings = app.world.systemTimings
            if !timings.isEmpty {
                let sectionHeight = lineHeight * Float(timings.count + 1) + 4
                let bg = Rect(x: 0, y: y - 2, width: 300, height: sectionHeight)
                renderer.drawRect(bg, color: options.backgroundColor)

                renderer.drawText("Systems:", position: Vector2(x: padding, y: y),
                                  font: font, size: options.fontSize, color: options.textColor)
                y += lineHeight

                for timing in timings {
                    let ms = timing.duration * 1000.0
                    let text = "  \(timing.name): \(String(format: "%.2f", ms))ms"
                    let color = ms > 2.0 ? options.warningColor : options.textColor
                    renderer.drawText(text, position: Vector2(x: padding, y: y),
                                      font: font, size: options.fontSize, color: color)
                    y += lineHeight
                }
                y += 4
            }
        }

        // On-Screen Log
        if options.showLog, let buffer = logBuffer {
            let entries = buffer.entries
            let displayEntries = entries.suffix(options.logLineCount)
            if !displayEntries.isEmpty {
                let sectionHeight = lineHeight * Float(displayEntries.count) + 4
                let screenWidth = renderer.screenSize.width
                let bg = Rect(x: 0, y: y - 2, width: screenWidth, height: sectionHeight)
                renderer.drawRect(bg, color: options.backgroundColor)

                for entry in displayEntries {
                    let color: Color
                    switch entry.level {
                    case .error: color = options.errorColor
                    case .warn: color = options.warningColor
                    default: color = options.textColor
                    }

                    let text = "[\(entry.level)] [\(entry.category)] \(entry.message)"
                    renderer.drawText(text, position: Vector2(x: padding, y: y),
                                      font: font, size: options.fontSize, color: color)
                    y += lineHeight
                }
            }
        }
    }

    // MARK: - Private

    private func fpsColor(_ fps: Int) -> Color {
        if fps >= 55 {
            return Color(r: 80, g: 200, b: 80, a: 255)  // green
        } else if fps >= 30 {
            return options.warningColor
        } else {
            return options.errorColor
        }
    }
}
