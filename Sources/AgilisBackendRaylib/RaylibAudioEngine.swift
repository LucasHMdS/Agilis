import AgilisCore
import RaylibC

/// Raylib implementation of the AudioBackend protocol.
public final class RaylibAudioEngine: @unchecked Sendable, AudioBackend {
    private var sounds: [UInt32: RaylibC.Sound] = [:]
    private var musicStreams: [UInt32: RaylibC.Music] = [:]
    private var nextSoundId: UInt32 = 1
    private var nextMusicId: UInt32 = 1

    public init() {}

    public func initialize() throws {
        InitAudioDevice()
    }

    public func shutdown() {
        for (_, s) in sounds {
            UnloadSound(s)
        }
        for (_, m) in musicStreams {
            UnloadMusicStream(m)
        }
        sounds.removeAll()
        musicStreams.removeAll()
        CloseAudioDevice()
    }

    // MARK: - Sound Effects

    public func loadSound(from path: String) -> SoundHandle {
        let s = LoadSound(path)
        let handle = SoundHandle(id: nextSoundId)
        sounds[nextSoundId] = s
        nextSoundId += 1
        return handle
    }

    public func loadSoundFromData(_ audioData: AudioData) -> SoundHandle {
        let bytesPerFrame = (audioData.sampleSize / 8) * audioData.channels
        let byteCount = audioData.frameCount * bytesPerFrame
        guard byteCount > 0, audioData.data.count >= byteCount else { return .invalid }
        // Use C malloc — raylib's UnloadWave calls free()
        guard let dataCopy = malloc(byteCount) else { return .invalid }
        audioData.data.withUnsafeBufferPointer { buf in
            dataCopy.copyMemory(from: buf.baseAddress!, byteCount: byteCount)
        }
        let wave = Wave(
            frameCount: UInt32(audioData.frameCount),
            sampleRate: UInt32(audioData.sampleRate),
            sampleSize: UInt32(audioData.sampleSize),
            channels: UInt32(audioData.channels),
            data: dataCopy
        )
        let s = LoadSoundFromWave(wave)
        UnloadWave(wave)
        let handle = SoundHandle(id: nextSoundId)
        sounds[nextSoundId] = s
        nextSoundId += 1
        return handle
    }

    public func playSound(_ handle: SoundHandle, volume: Float, pitch: Float, looping: Bool) {
        guard let s = sounds[handle.id] else { return }
        SetSoundVolume(s, volume)
        SetSoundPitch(s, pitch)
        PlaySound(s)
    }

    public func stopSound(_ handle: SoundHandle) {
        guard let s = sounds[handle.id] else { return }
        StopSound(s)
    }

    public func unloadSound(_ handle: SoundHandle) {
        guard let s = sounds.removeValue(forKey: handle.id) else { return }
        UnloadSound(s)
    }

    // MARK: - Music

    public func loadMusic(from path: String) -> MusicHandle {
        let m = LoadMusicStream(path)
        let handle = MusicHandle(id: nextMusicId)
        musicStreams[nextMusicId] = m
        nextMusicId += 1
        return handle
    }

    public func playMusic(_ handle: MusicHandle, volume: Float, looping: Bool) {
        guard var m = musicStreams[handle.id] else { return }
        m.looping = looping
        SetMusicVolume(m, volume)
        PlayMusicStream(m)
        musicStreams[handle.id] = m
    }

    public func pauseMusic(_ handle: MusicHandle) {
        guard let m = musicStreams[handle.id] else { return }
        PauseMusicStream(m)
    }

    public func resumeMusic(_ handle: MusicHandle) {
        guard let m = musicStreams[handle.id] else { return }
        ResumeMusicStream(m)
    }

    public func stopMusic(_ handle: MusicHandle) {
        guard let m = musicStreams[handle.id] else { return }
        StopMusicStream(m)
    }

    public func updateMusicStream(_ handle: MusicHandle) {
        guard let m = musicStreams[handle.id] else { return }
        UpdateMusicStream(m)
    }

    public func unloadMusic(_ handle: MusicHandle) {
        guard let m = musicStreams.removeValue(forKey: handle.id) else { return }
        UnloadMusicStream(m)
    }

    // MARK: - Playback Queries

    public func isSoundPlaying(_ handle: SoundHandle) -> Bool {
        guard let s = sounds[handle.id] else { return false }
        return IsSoundPlaying(s)
    }

    public func isMusicPlaying(_ handle: MusicHandle) -> Bool {
        guard let m = musicStreams[handle.id] else { return false }
        return IsMusicStreamPlaying(m)
    }

    // MARK: - Volume Control

    public func setSoundVolume(_ handle: SoundHandle, volume: Float) {
        guard let s = sounds[handle.id] else { return }
        SetSoundVolume(s, volume)
    }

    public func setMusicVolume(_ handle: MusicHandle, volume: Float) {
        guard let m = musicStreams[handle.id] else { return }
        SetMusicVolume(m, volume)
    }

    // MARK: - Global

    public func setMasterVolume(_ volume: Float) {
        SetMasterVolume(volume)
    }
}
