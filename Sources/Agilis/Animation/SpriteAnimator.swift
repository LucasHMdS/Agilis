

// MARK: - AnimationEvent

/// Events emitted by the animation system during playback.
public enum AnimationEvent: Sendable, Equatable, Codable {
    /// The animation looped back to the beginning (or reversed direction for ping-pong).
    case looped
    /// A one-shot animation finished playing (stopped on last frame).
    case completed
}

// MARK: - SpriteAnimator

/// ECS component that tracks sprite animation playback state for an entity.
///
/// Attach this alongside a `Sprite` component. The `AnimationSystem` will
/// advance the animator each frame and write the current frame's `sourceRect`
/// into the entity's `Sprite`.
///
/// ## Usage
/// ```swift
/// let entity = world.createEntity()
/// world.addComponent(Sprite(texture: spriteSheet), to: entity)
/// world.addComponent(SpriteAnimator(clip: walkClip), to: entity)
/// ```
///
/// ## Playback Control
/// ```swift
/// world.updateComponent(SpriteAnimator.self, on: entity) { animator in
///     if isWalking {
///         animator.setClip(walkClip)   // No-op if already playing "walk"
///     } else {
///         animator.setClip(idleClip)
///     }
/// }
/// ```
public struct SpriteAnimator: Component, Sendable, SerializableComponent {
    public static let componentName = "SpriteAnimator"

    /// The animation clip being played.
    public var clip: AnimationClip

    /// Index of the current frame within `clip.frames`.
    public var currentFrameIndex: Int

    /// Time elapsed within the current frame, in seconds.
    public var frameTime: Float

    /// Whether the animation is currently playing.
    public var isPlaying: Bool

    /// Playback speed multiplier. 1.0 = normal, 2.0 = double speed, 0.5 = half speed.
    public var speed: Float

    /// Event from the most recent update tick, if any. Cleared each tick by AnimationSystem.
    /// Gameplay systems running after AnimationSystem can read this.
    public var lastEvent: AnimationEvent?

    /// Internal: current direction for ping-pong mode (+1 or -1).
    internal var pingPongDirection: Int

    public init(
        clip: AnimationClip,
        startPlaying: Bool = true,
        speed: Float = 1.0
    ) {
        self.clip = clip
        self.currentFrameIndex = 0
        self.frameTime = 0
        self.isPlaying = startPlaying
        self.speed = speed
        self.lastEvent = nil
        self.pingPongDirection = 1
    }

    // MARK: - Playback Control

    /// Start or resume playback.
    public mutating func play() {
        isPlaying = true
    }

    /// Pause playback at the current frame.
    public mutating func pause() {
        isPlaying = false
    }

    /// Stop playback and reset to the first frame.
    public mutating func stop() {
        isPlaying = false
        currentFrameIndex = 0
        frameTime = 0
        pingPongDirection = 1
    }

    /// Reset to the first frame and start playing.
    public mutating func restart() {
        currentFrameIndex = 0
        frameTime = 0
        pingPongDirection = 1
        isPlaying = true
        lastEvent = nil
    }

    /// Switch to a different animation clip, resetting playback state.
    /// Does nothing if the clip has the same name (prevents restarting mid-animation).
    public mutating func setClip(_ newClip: AnimationClip) {
        guard newClip.name != clip.name else { return }
        clip = newClip
        currentFrameIndex = 0
        frameTime = 0
        pingPongDirection = 1
        isPlaying = true
        lastEvent = nil
    }

    /// Force-switch to a different clip, even if it has the same name.
    public mutating func forceSetClip(_ newClip: AnimationClip) {
        clip = newClip
        currentFrameIndex = 0
        frameTime = 0
        pingPongDirection = 1
        isPlaying = true
        lastEvent = nil
    }

    /// Jump to a specific frame index (clamped to valid range).
    public mutating func setFrame(_ index: Int) {
        guard !clip.frames.isEmpty else { return }
        currentFrameIndex = max(0, min(index, clip.frames.count - 1))
        frameTime = 0
    }

    // MARK: - Read-Only Accessors

    /// The source rectangle of the current frame, or `.zero` if no frames.
    public var currentSourceRect: Rect {
        guard !clip.frames.isEmpty else { return Rect() }
        return clip.frames[currentFrameIndex].sourceRect
    }

    /// Whether a one-shot animation has finished.
    public var isFinished: Bool {
        guard clip.mode == .oneShot else { return false }
        return !isPlaying && currentFrameIndex == clip.frames.count - 1
    }

    /// Normalized progress through the current clip (0.0 to 1.0).
    public var progress: Float {
        guard clip.frames.count > 1 else { return 0 }
        return Float(currentFrameIndex) / Float(clip.frames.count - 1)
    }

    // MARK: - Codable (skip lastEvent — transient, cleared each tick)

    private enum CodingKeys: String, CodingKey {
        case clip, currentFrameIndex, frameTime, isPlaying, speed, pingPongDirection
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clip, forKey: .clip)
        try container.encode(currentFrameIndex, forKey: .currentFrameIndex)
        try container.encode(frameTime, forKey: .frameTime)
        try container.encode(isPlaying, forKey: .isPlaying)
        try container.encode(speed, forKey: .speed)
        try container.encode(pingPongDirection, forKey: .pingPongDirection)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.clip = try container.decode(AnimationClip.self, forKey: .clip)
        self.currentFrameIndex = try container.decode(Int.self, forKey: .currentFrameIndex)
        self.frameTime = try container.decode(Float.self, forKey: .frameTime)
        self.isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
        self.speed = try container.decode(Float.self, forKey: .speed)
        self.pingPongDirection = try container.decode(Int.self, forKey: .pingPongDirection)
        self.lastEvent = nil
    }
}
