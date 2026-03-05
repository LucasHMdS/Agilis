import AgilisCore

/// Manages audio playback with group volumes, fading, and crossfading.
///
/// Wraps an ``AudioBackend`` and provides higher-level audio features.
/// Call ``update(deltaTime:)`` each frame to advance fades and update music streams.
///
/// ## Volume Groups
/// Three built-in groups (`.music`, `.sfx`, `.ui`) each have an independent
/// volume multiplier. Effective volume = group volume × individual sound volume.
///
/// ## Usage
/// ```swift
/// app.audioManager.setGroupVolume(.sfx, volume: 0.5)
/// app.audioManager.playSound(explosionHandle, group: .sfx)
/// app.audioManager.playMusic(bgmHandle, fadeDuration: 2.0)
/// ```
public final class AudioManager: @unchecked Sendable {

    /// The underlying audio backend.
    public let backend: AudioBackend

    // MARK: - Group Volumes

    private var groupVolumes: [AudioGroup: Float] = [
        .music: 1.0,
        .sfx: 1.0,
        .ui: 1.0,
    ]

    // MARK: - Active Sound Tracking

    /// Tracks sounds played through the manager so group volume changes
    /// can be applied retroactively to currently-playing sounds.
    private struct ActiveSound {
        let handle: SoundHandle
        let group: AudioGroup
        let baseVolume: Float
    }

    private var activeSounds: [ActiveSound] = []

    // MARK: - Music State

    private struct MusicState {
        let handle: MusicHandle
        var baseVolume: Float
        var currentVolume: Float
        var fade: FadeState?
        let looping: Bool
    }

    private var currentMusic: MusicState?

    // MARK: - Crossfade State

    private struct CrossfadeState {
        var outgoing: MusicState
    }

    private var crossfade: CrossfadeState?

    // MARK: - Fade

    private struct FadeState {
        let fromVolume: Float
        let toVolume: Float
        let duration: Float
        var elapsed: Float
        let stopOnComplete: Bool

        var progress: Float {
            guard duration > 0 else { return 1.0 }
            return clamp(elapsed / duration, min: 0, max: 1)
        }

        var currentVolume: Float {
            lerp(fromVolume, toVolume, t: progress)
        }

        var isComplete: Bool {
            elapsed >= duration
        }
    }

    // MARK: - Init

    /// Create an audio manager wrapping the given backend.
    public init(backend: AudioBackend) {
        self.backend = backend
    }

    // MARK: - Group Volume

    /// Get the volume for an audio group (0.0 to 1.0).
    public func groupVolume(for group: AudioGroup) -> Float {
        groupVolumes[group] ?? 1.0
    }

    /// Set the volume for an audio group (0.0 to 1.0).
    /// Immediately adjusts all currently playing sounds in this group.
    public func setGroupVolume(_ group: AudioGroup, volume: Float) {
        let clamped = clamp(volume, min: 0, max: 1)
        groupVolumes[group] = clamped

        // Update active sounds in this group
        for sound in activeSounds where sound.group == group {
            let effective = sound.baseVolume * clamped
            backend.setSoundVolume(sound.handle, volume: effective)
        }

        // Update music if group is .music
        if group == .music {
            if let state = currentMusic {
                let effective = state.currentVolume * clamped
                backend.setMusicVolume(state.handle, volume: effective)
            }
            if let cf = crossfade {
                let effective = cf.outgoing.currentVolume * clamped
                backend.setMusicVolume(cf.outgoing.handle, volume: effective)
            }
        }
    }

    // MARK: - Sound Effects

    /// Play a sound effect with group volume applied.
    ///
    /// - Parameters:
    ///   - handle: The sound to play.
    ///   - volume: Base volume (0.0 to 1.0), before group volume.
    ///   - pitch: Pitch multiplier (1.0 = normal).
    ///   - group: Audio group for volume control (default: `.sfx`).
    public func playSound(
        _ handle: SoundHandle,
        volume: Float = 1.0,
        pitch: Float = 1.0,
        group: AudioGroup = .sfx
    ) {
        guard handle != .invalid else { return }
        let effective = volume * (groupVolumes[group] ?? 1.0)
        backend.playSound(handle, volume: effective, pitch: pitch, looping: false)
        activeSounds.append(ActiveSound(handle: handle, group: group, baseVolume: volume))
    }

    /// Play a UI sound (convenience for `.ui` group).
    public func playUISound(_ handle: SoundHandle, volume: Float = 1.0) {
        playSound(handle, volume: volume, group: .ui)
    }

    /// Whether a sound is currently playing.
    public func isSoundPlaying(_ handle: SoundHandle) -> Bool {
        backend.isSoundPlaying(handle)
    }

    // MARK: - Music

    /// Play music with optional fade-in. Stops any currently playing music.
    ///
    /// - Parameters:
    ///   - handle: The music to play.
    ///   - volume: Base volume (0.0 to 1.0), before group volume.
    ///   - looping: Whether to loop (default: true).
    ///   - fadeDuration: Fade-in duration in seconds. 0 = instant.
    public func playMusic(
        _ handle: MusicHandle,
        volume: Float = 1.0,
        looping: Bool = true,
        fadeDuration: Float = 0
    ) {
        guard handle != .invalid else { return }
        // Stop current music immediately
        stopCurrentMusic()

        let startVolume: Float = fadeDuration > 0 ? 0 : volume
        let fade: FadeState? = fadeDuration > 0
            ? FadeState(fromVolume: 0, toVolume: volume,
                        duration: fadeDuration, elapsed: 0,
                        stopOnComplete: false)
            : nil

        let musicGroupVolume = groupVolumes[.music] ?? 1.0
        let effectiveStart = startVolume * musicGroupVolume
        backend.playMusic(handle, volume: effectiveStart, looping: looping)

        currentMusic = MusicState(
            handle: handle,
            baseVolume: volume,
            currentVolume: startVolume,
            fade: fade,
            looping: looping
        )
    }

    /// Crossfade from the current music to new music.
    ///
    /// The current track fades out while the new track fades in,
    /// both over the specified duration.
    ///
    /// - Parameters:
    ///   - handle: The new music to fade in.
    ///   - volume: Base volume for the new track (0.0 to 1.0).
    ///   - looping: Whether the new track loops (default: true).
    ///   - duration: Crossfade duration in seconds.
    public func crossfadeToMusic(
        _ handle: MusicHandle,
        volume: Float = 1.0,
        looping: Bool = true,
        duration: Float = 1.0
    ) {
        // If already crossfading, stop the outgoing track immediately
        if let cf = crossfade {
            backend.stopMusic(cf.outgoing.handle)
            crossfade = nil
        }

        // Move current music to outgoing
        if var outgoing = currentMusic {
            outgoing.fade = FadeState(
                fromVolume: outgoing.currentVolume,
                toVolume: 0,
                duration: duration,
                elapsed: 0,
                stopOnComplete: true
            )
            crossfade = CrossfadeState(outgoing: outgoing)
        }

        // Start new music as incoming with fade-in
        backend.playMusic(handle, volume: 0, looping: looping)

        currentMusic = MusicState(
            handle: handle,
            baseVolume: volume,
            currentVolume: 0,
            fade: FadeState(
                fromVolume: 0,
                toVolume: volume,
                duration: duration,
                elapsed: 0,
                stopOnComplete: false
            ),
            looping: looping
        )
    }

    /// Fade out and stop the current music.
    ///
    /// - Parameter duration: Fade-out duration in seconds.
    public func fadeOutMusic(duration: Float = 1.0) {
        guard var state = currentMusic else { return }
        state.fade = FadeState(
            fromVolume: state.currentVolume,
            toVolume: 0,
            duration: duration,
            elapsed: 0,
            stopOnComplete: true
        )
        currentMusic = state
    }

    /// Stop the current music immediately.
    public func stopMusic() {
        stopCurrentMusic()
    }

    /// Pause the current music.
    public func pauseMusic() {
        guard let state = currentMusic else { return }
        backend.pauseMusic(state.handle)
    }

    /// Resume the current music.
    public func resumeMusic() {
        guard let state = currentMusic else { return }
        backend.resumeMusic(state.handle)
    }

    /// Whether music is currently playing.
    public func isMusicPlaying() -> Bool {
        guard let state = currentMusic else { return false }
        return backend.isMusicPlaying(state.handle)
    }

    // MARK: - Update

    /// Call once per frame to advance fades and update music streams.
    ///
    /// This also cleans up finished sounds from the active-sound tracking list
    /// and calls `updateMusicStream` on all active music handles.
    public func update(deltaTime: Float) {
        // Clean up finished sounds from tracking
        activeSounds.removeAll { !backend.isSoundPlaying($0.handle) }

        let musicGroupVolume = groupVolumes[.music] ?? 1.0

        // Update current music fade
        if var state = currentMusic {
            backend.updateMusicStream(state.handle)

            if var fade = state.fade {
                fade.elapsed += deltaTime
                state.currentVolume = fade.currentVolume
                let effective = state.currentVolume * musicGroupVolume
                backend.setMusicVolume(state.handle, volume: effective)

                if fade.isComplete {
                    if fade.stopOnComplete {
                        backend.stopMusic(state.handle)
                        currentMusic = nil
                    } else {
                        state.currentVolume = fade.toVolume
                        state.fade = nil
                        currentMusic = state
                    }
                } else {
                    state.fade = fade
                    currentMusic = state
                }
            }
        }

        // Update crossfade outgoing
        if var cf = crossfade {
            backend.updateMusicStream(cf.outgoing.handle)

            if var fade = cf.outgoing.fade {
                fade.elapsed += deltaTime
                cf.outgoing.currentVolume = fade.currentVolume
                let effective = cf.outgoing.currentVolume * musicGroupVolume
                backend.setMusicVolume(cf.outgoing.handle, volume: effective)

                if fade.isComplete {
                    backend.stopMusic(cf.outgoing.handle)
                    crossfade = nil
                } else {
                    cf.outgoing.fade = fade
                    crossfade = cf
                }
            }
        }
    }

    // MARK: - Private

    private func stopCurrentMusic() {
        if let cf = crossfade {
            backend.stopMusic(cf.outgoing.handle)
            crossfade = nil
        }
        if let state = currentMusic {
            backend.stopMusic(state.handle)
            currentMusic = nil
        }
    }
}
