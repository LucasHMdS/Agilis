/// An opaque handle to a loaded sound effect (in-memory).
public struct SoundHandle: Sendable, Hashable {
    public let id: UInt32
    public init(id: UInt32) { self.id = id }
    public static let invalid = SoundHandle(id: 0)
}

/// An opaque handle to a streaming music track.
public struct MusicHandle: Sendable, Hashable {
    public let id: UInt32
    public init(id: UInt32) { self.id = id }
    public static let invalid = MusicHandle(id: 0)
}

/// Supported audio file formats.
public enum AudioFormat: String, Sendable {
    case wav
    case ogg
    case mp3
    case flac
}

/// The abstraction over platform-specific audio playback.
public protocol AudioBackend: AnyObject, Sendable {
    /// Initialize the audio subsystem.
    func initialize() throws

    /// Shut down audio and release resources.
    func shutdown()

    // MARK: - Sound Effects (in-memory)

    /// Load a sound from a file path.
    func loadSound(from path: String) -> SoundHandle

    /// Load a sound from raw PCM audio data.
    func loadSoundFromData(_ data: AudioData) -> SoundHandle

    /// Play a sound effect.
    func playSound(_ handle: SoundHandle, volume: Float, pitch: Float, looping: Bool)

    /// Stop a playing sound.
    func stopSound(_ handle: SoundHandle)

    /// Unload a sound and free memory.
    func unloadSound(_ handle: SoundHandle)

    // MARK: - Music (streaming)

    /// Load a music track for streaming playback.
    func loadMusic(from path: String) -> MusicHandle

    /// Start or restart music playback.
    func playMusic(_ handle: MusicHandle, volume: Float, looping: Bool)

    /// Pause music playback.
    func pauseMusic(_ handle: MusicHandle)

    /// Resume paused music.
    func resumeMusic(_ handle: MusicHandle)

    /// Stop music playback.
    func stopMusic(_ handle: MusicHandle)

    /// Must be called each frame to feed the audio stream buffer.
    func updateMusicStream(_ handle: MusicHandle)

    /// Unload a music track.
    func unloadMusic(_ handle: MusicHandle)

    // MARK: - Playback Queries

    /// Whether a sound effect is currently playing.
    func isSoundPlaying(_ handle: SoundHandle) -> Bool

    /// Whether a music stream is currently playing.
    func isMusicPlaying(_ handle: MusicHandle) -> Bool

    // MARK: - Volume Control

    /// Set volume of a currently loaded sound (0.0 to 1.0).
    func setSoundVolume(_ handle: SoundHandle, volume: Float)

    /// Set volume of a currently loaded music stream (0.0 to 1.0).
    func setMusicVolume(_ handle: MusicHandle, volume: Float)

    // MARK: - Global

    /// Set the master volume (0.0 to 1.0).
    func setMasterVolume(_ volume: Float)
}

// MARK: - Default Implementations

extension AudioBackend {
    public func isSoundPlaying(_ handle: SoundHandle) -> Bool { false }
    public func isMusicPlaying(_ handle: MusicHandle) -> Bool { false }
    public func setSoundVolume(_ handle: SoundHandle, volume: Float) {}
    public func setMusicVolume(_ handle: MusicHandle, volume: Float) {}
}

// MARK: - Default AudioData Implementation

extension AudioBackend {
    public func loadSoundFromData(_ data: AudioData) -> SoundHandle { .invalid }
}

// MARK: - Throwing Resource Loading

extension AudioBackend {
    /// Load a sound effect, throwing on failure instead of returning `.invalid`.
    public func loadSoundOrThrow(from path: String) throws -> SoundHandle {
        let handle = loadSound(from: path)
        guard handle != .invalid else { throw ResourceError.soundLoadFailed(path: path) }
        return handle
    }

    /// Load a music track, throwing on failure instead of returning `.invalid`.
    public func loadMusicOrThrow(from path: String) throws -> MusicHandle {
        let handle = loadMusic(from: path)
        guard handle != .invalid else { throw ResourceError.musicLoadFailed(path: path) }
        return handle
    }
}
