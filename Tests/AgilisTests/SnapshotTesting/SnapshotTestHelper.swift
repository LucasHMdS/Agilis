@testable import Agilis
import Testing
#if canImport(Foundation)
import Foundation
#endif

/// Result of comparing two images pixel-by-pixel.
struct ImageComparisonResult: Sendable {
    /// Total number of pixels compared.
    let totalPixels: Int
    /// Number of pixels that differ beyond the tolerance.
    let differentPixels: Int
    /// Maximum per-channel difference found.
    let maxChannelDiff: UInt8
    /// Whether the comparison passed (within thresholds).
    let passed: Bool

    /// Percentage of pixels that differ (0.0 - 100.0).
    var diffPercentage: Float {
        guard totalPixels > 0 else { return 0 }
        return (Float(differentPixels) / Float(totalPixels)) * 100.0
    }
}

/// Configuration for snapshot comparison tolerances.
struct SnapshotConfig: Sendable {
    /// Per-channel tolerance: if abs(actual - expected) <= channelTolerance for all
    /// four channels, the pixel is considered matching. Default 2 to absorb
    /// minor GPU rounding differences.
    var channelTolerance: UInt8 = 2
    /// Maximum allowed percentage of differing pixels. Default 0.1%.
    var maxDiffPercentage: Float = 0.1

    static let `default` = SnapshotConfig()
    /// Strict: zero tolerance, zero diff. Use for solid color tests.
    static let strict = SnapshotConfig(channelTolerance: 0, maxDiffPercentage: 0)
}

/// Manages reference image storage and pixel-level comparison for snapshot tests.
enum SnapshotTestHelper {

    /// Compare captured image against a reference PNG.
    ///
    /// - First run (no reference): saves captured image as the new reference.
    /// - Subsequent runs: loads reference and compares pixel-by-pixel.
    /// - On failure: saves `<name>_actual.png` and `<name>_diff.png` for debugging.
    /// - Set `UPDATE_SNAPSHOTS=1` environment variable to force-regenerate references.
    static func assertSnapshot(
        _ actual: ImageData,
        suite: String,
        name: String,
        config: SnapshotConfig = .default,
        sourceFile: String = #filePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let refPath = referenceImagePath(suite: suite, name: name, sourceFile: sourceFile)

        #if canImport(Foundation)
        let shouldUpdate = ProcessInfo.processInfo.environment["UPDATE_SNAPSHOTS"] == "1"
        #else
        let shouldUpdate = false
        #endif

        if shouldUpdate {
            ensureDirectoryExists(for: refPath)
            guard actual.save(to: refPath) else {
                Issue.record("Failed to save reference image to \(refPath)",
                             sourceLocation: sourceLocation)
                return
            }
            return
        }

        // Try to load existing reference
        guard let reference = ImageData.load(from: refPath) else {
            // No reference exists — first run: save and pass
            ensureDirectoryExists(for: refPath)
            guard actual.save(to: refPath) else {
                Issue.record("Failed to save initial reference image to \(refPath)",
                             sourceLocation: sourceLocation)
                return
            }
            return
        }

        // Compare
        let result = compareImages(actual: actual, expected: reference, config: config)

        if !result.passed {
            // Save actual and diff images for debugging
            let dir = directoryOf(refPath)
            let actualPath = "\(dir)/\(name)_actual.png"
            let diffPath = "\(dir)/\(name)_diff.png"
            actual.save(to: actualPath)

            if actual.width == reference.width && actual.height == reference.height {
                let diffImage = generateDiffImage(
                    actual: actual,
                    expected: reference,
                    tolerance: config.channelTolerance
                )
                diffImage.save(to: diffPath)
            }

            Issue.record(
                """
                Snapshot mismatch for '\(name)':
                  Diff: \(String(format: "%.3f", result.diffPercentage))% pixels differ \
                (threshold: \(config.maxDiffPercentage)%)
                  Max channel diff: \(result.maxChannelDiff) (tolerance: \(config.channelTolerance))
                  Different pixels: \(result.differentPixels)/\(result.totalPixels)
                  Reference: \(refPath)
                  Actual:    \(actualPath)
                  Diff:      \(diffPath)
                  Run with UPDATE_SNAPSHOTS=1 to update reference images.
                """,
                sourceLocation: sourceLocation
            )
        }
    }

    // MARK: - Image Comparison

    /// Compare two images pixel-by-pixel.
    static func compareImages(
        actual: ImageData,
        expected: ImageData,
        config: SnapshotConfig
    ) -> ImageComparisonResult {
        // Dimension mismatch is an immediate failure
        guard actual.width == expected.width,
              actual.height == expected.height else {
            let total = max(
                actual.width * actual.height,
                expected.width * expected.height
            )
            return ImageComparisonResult(
                totalPixels: total,
                differentPixels: total,
                maxChannelDiff: 255,
                passed: false
            )
        }

        let pixelCount = actual.width * actual.height
        var differentPixels = 0
        var maxDiff: UInt8 = 0

        for i in 0..<pixelCount {
            let offset = i * 4
            var pixelDiffers = false

            for c in 0..<4 {
                let a = actual.pixels[offset + c]
                let e = expected.pixels[offset + c]
                let diff = a > e ? a - e : e - a
                if diff > maxDiff { maxDiff = diff }
                if diff > config.channelTolerance {
                    pixelDiffers = true
                }
            }

            if pixelDiffers {
                differentPixels += 1
            }
        }

        let diffPercentage = pixelCount > 0
            ? (Float(differentPixels) / Float(pixelCount)) * 100.0
            : 0

        return ImageComparisonResult(
            totalPixels: pixelCount,
            differentPixels: differentPixels,
            maxChannelDiff: maxDiff,
            passed: diffPercentage <= config.maxDiffPercentage
        )
    }

    /// Generate a visual diff image. Matching pixels are black;
    /// differing pixels show the absolute channel differences amplified.
    static func generateDiffImage(
        actual: ImageData,
        expected: ImageData,
        tolerance: UInt8
    ) -> ImageData {
        let w = actual.width
        let h = actual.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)

        for i in 0..<(w * h) {
            let offset = i * 4
            var differs = false

            for c in 0..<4 {
                let a = actual.pixels[offset + c]
                let e = expected.pixels[offset + c]
                let diff = a > e ? a - e : e - a
                if diff > tolerance { differs = true }
            }

            if differs {
                let rDiff = abs(Int(actual.pixels[offset]) - Int(expected.pixels[offset]))
                let gDiff = abs(Int(actual.pixels[offset + 1]) - Int(expected.pixels[offset + 1]))
                let bDiff = abs(Int(actual.pixels[offset + 2]) - Int(expected.pixels[offset + 2]))
                pixels[offset]     = UInt8(min(255, rDiff * 4 + 64))
                pixels[offset + 1] = UInt8(min(255, gDiff * 4))
                pixels[offset + 2] = UInt8(min(255, bDiff * 4))
                pixels[offset + 3] = 255
            } else {
                pixels[offset]     = 0
                pixels[offset + 1] = 0
                pixels[offset + 2] = 0
                pixels[offset + 3] = 255
            }
        }

        return ImageData(width: w, height: h, pixels: pixels)
    }

    // MARK: - Path Helpers

    /// Reference image path: `Tests/AgilisTests/__Snapshots__/<suite>/<name>.png`
    static func referenceImagePath(
        suite: String,
        name: String,
        sourceFile: String = #filePath
    ) -> String {
        let testsDir = findTestsDirectory(from: sourceFile)
        return "\(testsDir)/__Snapshots__/\(suite)/\(name).png"
    }

    private static func findTestsDirectory(from sourceFile: String) -> String {
        let normalized = sourceFile.replacingOccurrences(of: "\\", with: "/")
        if let range = normalized.range(of: "Tests/AgilisTests") {
            return String(normalized[normalized.startIndex..<range.upperBound])
        }
        // Fallback: go up two directories from source file
        return directoryOf(directoryOf(sourceFile))
    }

    private static func directoryOf(_ path: String) -> String {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        if let lastSlash = normalized.lastIndex(of: "/") {
            return String(normalized[normalized.startIndex..<lastSlash])
        }
        return "."
    }

    private static func ensureDirectoryExists(for filePath: String) {
        #if canImport(Foundation)
        let dir = directoryOf(filePath)
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        #endif
    }
}
