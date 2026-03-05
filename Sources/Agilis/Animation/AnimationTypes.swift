import AgilisCore

// MARK: - PlaybackMode

/// How an animation clip plays back.
public enum PlaybackMode: Sendable, Equatable, Codable {
    /// Plays frames 0, 1, 2, ..., N, then loops to 0.
    case forward
    /// Plays frames N, N-1, ..., 0, then loops to N.
    case reverse
    /// Plays 0, 1, ..., N, N-1, ..., 1, then loops (no double endpoints).
    case pingPong
    /// Plays forward once and stops on the last frame.
    case oneShot
}

// MARK: - AnimationFrame

/// A single frame within an animation clip.
///
/// Stores the source rectangle within a sprite sheet and the duration
/// this frame should be displayed for.
public struct AnimationFrame: Sendable, Equatable, Codable {
    /// Region in the sprite sheet texture (pixels).
    public var sourceRect: Rect
    /// How long this frame is displayed, in seconds.
    public var duration: Float

    public init(sourceRect: Rect, duration: Float) {
        self.sourceRect = sourceRect
        self.duration = duration
    }
}

// MARK: - AnimationClip

/// A reusable animation clip: a named sequence of frames with a playback mode.
///
/// Clips are designed to be created once and shared across many entities.
/// They are value types, so assigning them to multiple `SpriteAnimator`
/// components copies the data cheaply (the frames array is copy-on-write).
///
/// ## Creating clips manually
/// ```swift
/// let walkClip = AnimationClip(
///     name: "walk",
///     frames: [
///         AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1),
///         AnimationFrame(sourceRect: Rect(x: 32, y: 0, width: 32, height: 32), duration: 0.1),
///         AnimationFrame(sourceRect: Rect(x: 64, y: 0, width: 32, height: 32), duration: 0.1),
///     ],
///     mode: .forward
/// )
/// ```
///
/// ## Creating clips from a sprite sheet grid
/// ```swift
/// let runClip = AnimationClip.fromSpriteSheet(
///     name: "run", startX: 0, y: 64,
///     frameWidth: 32, frameHeight: 32,
///     count: 6, frameDuration: 0.08
/// )
/// ```
public struct AnimationClip: Sendable, Equatable, Codable {
    /// Human-readable name (e.g. "idle", "walk", "attack").
    public var name: String
    /// The ordered frames in this clip.
    public var frames: [AnimationFrame]
    /// Playback behavior.
    public var mode: PlaybackMode

    /// Total duration of one full cycle (sum of all frame durations), in seconds.
    public var totalDuration: Float {
        frames.reduce(0) { $0 + $1.duration }
    }

    /// The number of frames in this clip.
    public var frameCount: Int { frames.count }

    public init(name: String, frames: [AnimationFrame], mode: PlaybackMode = .forward) {
        self.name = name
        self.frames = frames
        self.mode = mode
    }
}

// MARK: - Sprite Sheet Helpers

extension AnimationClip {
    /// Creates a clip from a row of equally-sized frames in a sprite sheet.
    ///
    /// - Parameters:
    ///   - name: Clip name.
    ///   - startX: X pixel offset of the first frame.
    ///   - y: Y pixel offset of the row.
    ///   - frameWidth: Width of each frame in pixels.
    ///   - frameHeight: Height of each frame in pixels.
    ///   - count: Number of frames.
    ///   - frameDuration: Duration per frame in seconds.
    ///   - mode: Playback mode. Default: `.forward`.
    public static func fromSpriteSheet(
        name: String,
        startX: Float,
        y: Float,
        frameWidth: Float,
        frameHeight: Float,
        count: Int,
        frameDuration: Float,
        mode: PlaybackMode = .forward
    ) -> AnimationClip {
        let frames = (0..<count).map { i in
            AnimationFrame(
                sourceRect: Rect(
                    x: startX + Float(i) * frameWidth,
                    y: y,
                    width: frameWidth,
                    height: frameHeight
                ),
                duration: frameDuration
            )
        }
        return AnimationClip(name: name, frames: frames, mode: mode)
    }
}
