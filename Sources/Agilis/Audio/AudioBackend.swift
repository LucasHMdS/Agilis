/// Protocol for audio backends.
///
/// Abstracts audio playback so that test mocks can stand in for the
/// concrete ``AudioEngine`` without requiring audio hardware.
public protocol AudioBackend: AnyObject, Sendable {
    func initialize() throws
    func shutdown()

    // Sound effects (in-memory)
    func loadSound(from path: String) -> SoundHandle
    func loadSoundFromData(_ data: AudioData) -> SoundHandle
    func playSound(_ handle: SoundHandle, volume: Float, pitch: Float, looping: Bool)
    func stopSound(_ handle: SoundHandle)
    func unloadSound(_ handle: SoundHandle)

    // Music (streaming)
    func loadMusic(from path: String) -> MusicHandle
    func playMusic(_ handle: MusicHandle, volume: Float, looping: Bool)
    func pauseMusic(_ handle: MusicHandle)
    func resumeMusic(_ handle: MusicHandle)
    func stopMusic(_ handle: MusicHandle)
    func updateMusicStream(_ handle: MusicHandle)
    func unloadMusic(_ handle: MusicHandle)

    // Volume
    func setMasterVolume(_ volume: Float)

    // Queries
    func isSoundPlaying(_ handle: SoundHandle) -> Bool
    func isMusicPlaying(_ handle: MusicHandle) -> Bool
    func setSoundVolume(_ handle: SoundHandle, volume: Float)
    func setMusicVolume(_ handle: MusicHandle, volume: Float)
}

// MARK: - Default Implementations

extension AudioBackend {
    public func loadSoundFromData(_ data: AudioData) -> SoundHandle { .invalid }
    public func isSoundPlaying(_ handle: SoundHandle) -> Bool { false }
    public func isMusicPlaying(_ handle: MusicHandle) -> Bool { false }
    public func setSoundVolume(_ handle: SoundHandle, volume: Float) {}
    public func setMusicVolume(_ handle: MusicHandle, volume: Float) {}
}

// MARK: - AudioEngine Conformance

extension AudioEngine: AudioBackend {}
