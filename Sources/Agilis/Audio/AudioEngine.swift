import MiniaudioC

/// Concrete audio engine backed by MiniAudio.
///
/// Handles sound effect playback (in-memory), music streaming,
/// volume control, and the audio device lifecycle.
public final class AudioEngine: @unchecked Sendable {

    // MARK: - Internal Types

    private struct SoundInfo {
        let sound: UnsafeMutablePointer<ma_sound>
        /// Non-nil for sounds loaded from raw PCM data (AudioData).
        /// Cleaned up with `ma_audio_buffer_uninit_and_free`.
        let audioBuffer: UnsafeMutablePointer<ma_audio_buffer>?
    }

    private struct MusicInfo {
        let sound: UnsafeMutablePointer<ma_sound>
    }

    // MARK: - State

    private var engine: UnsafeMutablePointer<ma_engine>?
    private var sounds: [UInt32: SoundInfo] = [:]
    private var nextSoundId: UInt32 = 1
    private var music: [UInt32: MusicInfo] = [:]
    private var nextMusicId: UInt32 = 1

    // MARK: - Lifecycle

    public func initialize() throws {
        let eng = UnsafeMutablePointer<ma_engine>.allocate(capacity: 1)
        var config = ma_engine_config_init()
        let result = ma_engine_init(&config, eng)
        guard result == MA_SUCCESS else {
            eng.deallocate()
            // Non-fatal: engine stays nil, all audio calls become no-ops
            return
        }
        engine = eng
    }

    public func shutdown() {
        for (_, info) in sounds {
            ma_sound_uninit(info.sound)
            info.sound.deallocate()
            if let buf = info.audioBuffer {
                ma_audio_buffer_uninit_and_free(buf)
            }
        }
        sounds.removeAll()

        for (_, info) in music {
            ma_sound_uninit(info.sound)
            info.sound.deallocate()
        }
        music.removeAll()

        if let eng = engine {
            ma_engine_uninit(eng)
            eng.deallocate()
            engine = nil
        }
    }

    // MARK: - Sound Effects

    public func loadSound(from path: String) -> SoundHandle {
        guard let eng = engine else { return .invalid }

        let snd = UnsafeMutablePointer<ma_sound>.allocate(capacity: 1)
        let flags = UInt32(MA_SOUND_FLAG_DECODE.rawValue)
            | UInt32(MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue)
        let result = ma_sound_init_from_file(eng, path, flags, nil, nil, snd)
        guard result == MA_SUCCESS else {
            snd.deallocate()
            return .invalid
        }

        let id = nextSoundId
        nextSoundId += 1
        sounds[id] = SoundInfo(sound: snd, audioBuffer: nil)
        return SoundHandle(id: id)
    }

    public func loadSoundFromData(_ data: AudioData) -> SoundHandle {
        guard let eng = engine else { return .invalid }
        guard !data.data.isEmpty, data.frameCount > 0 else { return .invalid }

        let format: ma_format
        switch data.sampleSize {
        case 8:  format = ma_format_u8
        case 16: format = ma_format_s16
        default: return .invalid
        }

        // alloc_and_init copies the PCM data internally
        var audioBufPtr: UnsafeMutablePointer<ma_audio_buffer>?
        let bufResult = data.data.withUnsafeBufferPointer { ptr -> ma_result in
            var config = ma_audio_buffer_config_init(
                format,
                UInt32(data.channels),
                UInt64(data.frameCount),
                ptr.baseAddress,
                nil
            )
            config.sampleRate = UInt32(data.sampleRate)
            return ma_audio_buffer_alloc_and_init(&config, &audioBufPtr)
        }
        guard bufResult == MA_SUCCESS, let audioBuf = audioBufPtr else {
            return .invalid
        }

        // Create sound from audio buffer (which is a data source)
        let snd = UnsafeMutablePointer<ma_sound>.allocate(capacity: 1)
        let flags = UInt32(MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue)
        let sndResult = ma_sound_init_from_data_source(
            eng,
            UnsafeMutableRawPointer(audioBuf),
            flags,
            nil,
            snd
        )
        guard sndResult == MA_SUCCESS else {
            ma_audio_buffer_uninit_and_free(audioBuf)
            snd.deallocate()
            return .invalid
        }

        let id = nextSoundId
        nextSoundId += 1
        sounds[id] = SoundInfo(sound: snd, audioBuffer: audioBuf)
        return SoundHandle(id: id)
    }

    public func playSound(_ handle: SoundHandle, volume: Float = 1.0, pitch: Float = 1.0, looping: Bool = false) {
        guard let info = sounds[handle.id] else { return }
        ma_sound_seek_to_pcm_frame(info.sound, 0)
        ma_sound_set_volume(info.sound, volume)
        ma_sound_set_pitch(info.sound, pitch)
        ma_sound_set_looping(info.sound, looping ? 1 : 0)
        ma_sound_start(info.sound)
    }

    public func stopSound(_ handle: SoundHandle) {
        guard let info = sounds[handle.id] else { return }
        ma_sound_stop(info.sound)
    }

    public func unloadSound(_ handle: SoundHandle) {
        guard let info = sounds.removeValue(forKey: handle.id) else { return }
        ma_sound_uninit(info.sound)
        info.sound.deallocate()
        if let buf = info.audioBuffer {
            ma_audio_buffer_uninit_and_free(buf)
        }
    }

    public func isSoundPlaying(_ handle: SoundHandle) -> Bool {
        guard let info = sounds[handle.id] else { return false }
        return ma_sound_is_playing(info.sound) != 0
    }

    public func setSoundVolume(_ handle: SoundHandle, volume: Float) {
        guard let info = sounds[handle.id] else { return }
        ma_sound_set_volume(info.sound, volume)
    }

    // MARK: - Music (Streaming)

    public func loadMusic(from path: String) -> MusicHandle {
        guard let eng = engine else { return .invalid }

        let snd = UnsafeMutablePointer<ma_sound>.allocate(capacity: 1)
        let flags = UInt32(MA_SOUND_FLAG_STREAM.rawValue)
            | UInt32(MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue)
        let result = ma_sound_init_from_file(eng, path, flags, nil, nil, snd)
        guard result == MA_SUCCESS else {
            snd.deallocate()
            return .invalid
        }

        let id = nextMusicId
        nextMusicId += 1
        music[id] = MusicInfo(sound: snd)
        return MusicHandle(id: id)
    }

    public func playMusic(_ handle: MusicHandle, volume: Float = 1.0, looping: Bool = true) {
        guard let info = music[handle.id] else { return }
        ma_sound_seek_to_pcm_frame(info.sound, 0)
        ma_sound_set_volume(info.sound, volume)
        ma_sound_set_looping(info.sound, looping ? 1 : 0)
        ma_sound_start(info.sound)
    }

    public func pauseMusic(_ handle: MusicHandle) {
        guard let info = music[handle.id] else { return }
        ma_sound_stop(info.sound)
    }

    public func resumeMusic(_ handle: MusicHandle) {
        guard let info = music[handle.id] else { return }
        ma_sound_start(info.sound)
    }

    public func stopMusic(_ handle: MusicHandle) {
        guard let info = music[handle.id] else { return }
        ma_sound_stop(info.sound)
        ma_sound_seek_to_pcm_frame(info.sound, 0)
    }

    public func updateMusicStream(_ handle: MusicHandle) {
        // No-op — miniaudio handles streaming internally
    }

    public func unloadMusic(_ handle: MusicHandle) {
        guard let info = music.removeValue(forKey: handle.id) else { return }
        ma_sound_uninit(info.sound)
        info.sound.deallocate()
    }

    public func isMusicPlaying(_ handle: MusicHandle) -> Bool {
        guard let info = music[handle.id] else { return false }
        return ma_sound_is_playing(info.sound) != 0
    }

    public func setMusicVolume(_ handle: MusicHandle, volume: Float) {
        guard let info = music[handle.id] else { return }
        ma_sound_set_volume(info.sound, volume)
    }

    // MARK: - Master Volume

    public func setMasterVolume(_ volume: Float) {
        guard let eng = engine else { return }
        ma_engine_set_volume(eng, volume)
    }

}

