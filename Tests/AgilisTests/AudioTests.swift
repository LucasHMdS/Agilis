import Testing
@testable import Agilis
@testable import AgilisCore

// MARK: - Tracking Audio Backend

/// A mock audio backend that records all calls and tracks playing state.
final class TrackingAudioBackend: @unchecked Sendable, AudioBackend {
    // Call tracking
    var playSoundCalls: [(handle: SoundHandle, volume: Float, pitch: Float, looping: Bool)] = []
    var playMusicCalls: [(handle: MusicHandle, volume: Float, looping: Bool)] = []
    var stopSoundCalls: [SoundHandle] = []
    var stopMusicCalls: [MusicHandle] = []
    var pauseMusicCalls: [MusicHandle] = []
    var resumeMusicCalls: [MusicHandle] = []
    var updateMusicStreamCalls: [MusicHandle] = []
    var setSoundVolumeCalls: [(handle: SoundHandle, volume: Float)] = []
    var setMusicVolumeCalls: [(handle: MusicHandle, volume: Float)] = []

    // Playing state
    var soundsPlaying: Set<UInt32> = []
    var musicPlaying: Set<UInt32> = []

    // Volume state (last set value per handle)
    var soundVolumes: [UInt32: Float] = [:]
    var musicVolumes: [UInt32: Float] = [:]

    func initialize() throws {}
    func shutdown() {}

    func loadSound(from path: String) -> SoundHandle { .invalid }
    func loadMusic(from path: String) -> MusicHandle { .invalid }

    func playSound(_ handle: SoundHandle, volume: Float, pitch: Float, looping: Bool) {
        playSoundCalls.append((handle, volume, pitch, looping))
        soundsPlaying.insert(handle.id)
        soundVolumes[handle.id] = volume
    }

    func stopSound(_ handle: SoundHandle) {
        stopSoundCalls.append(handle)
        soundsPlaying.remove(handle.id)
    }

    func unloadSound(_ handle: SoundHandle) {}

    func playMusic(_ handle: MusicHandle, volume: Float, looping: Bool) {
        playMusicCalls.append((handle, volume, looping))
        musicPlaying.insert(handle.id)
        musicVolumes[handle.id] = volume
    }

    func pauseMusic(_ handle: MusicHandle) {
        pauseMusicCalls.append(handle)
    }

    func resumeMusic(_ handle: MusicHandle) {
        resumeMusicCalls.append(handle)
    }

    func stopMusic(_ handle: MusicHandle) {
        stopMusicCalls.append(handle)
        musicPlaying.remove(handle.id)
    }

    func updateMusicStream(_ handle: MusicHandle) {
        updateMusicStreamCalls.append(handle)
    }

    func unloadMusic(_ handle: MusicHandle) {}

    func setMasterVolume(_ volume: Float) {}

    func isSoundPlaying(_ handle: SoundHandle) -> Bool {
        soundsPlaying.contains(handle.id)
    }

    func isMusicPlaying(_ handle: MusicHandle) -> Bool {
        musicPlaying.contains(handle.id)
    }

    func setSoundVolume(_ handle: SoundHandle, volume: Float) {
        setSoundVolumeCalls.append((handle, volume))
        soundVolumes[handle.id] = volume
    }

    func setMusicVolume(_ handle: MusicHandle, volume: Float) {
        setMusicVolumeCalls.append((handle, volume))
        musicVolumes[handle.id] = volume
    }
}

// MARK: - Test Helpers

private let sfxHandle = SoundHandle(id: 1)
private let sfxHandle2 = SoundHandle(id: 2)
private let musicHandle1 = MusicHandle(id: 1)
private let musicHandle2 = MusicHandle(id: 2)

// MARK: - AudioGroup Tests

@Suite("AudioGroup Tests")
struct AudioGroupTests {
    @Test("All cases exist")
    func allCases() {
        let cases = AudioGroup.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.music))
        #expect(cases.contains(.sfx))
        #expect(cases.contains(.ui))
    }

    @Test("Hashable and Equatable")
    func hashable() {
        let set: Set<AudioGroup> = [.music, .sfx, .ui, .music]
        #expect(set.count == 3)
    }

    @Test("Raw values")
    func rawValues() {
        #expect(AudioGroup.music.rawValue == "music")
        #expect(AudioGroup.sfx.rawValue == "sfx")
        #expect(AudioGroup.ui.rawValue == "ui")
    }
}

// MARK: - AudioManager Tests

@Suite("AudioManager Group Volume Tests")
struct AudioManagerGroupVolumeTests {
    @Test("Default group volumes are 1.0")
    func defaultGroupVolumes() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)
        #expect(manager.groupVolume(for: .music) == 1.0)
        #expect(manager.groupVolume(for: .sfx) == 1.0)
        #expect(manager.groupVolume(for: .ui) == 1.0)
    }

    @Test("Set group volume")
    func setGroupVolume() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)
        manager.setGroupVolume(.sfx, volume: 0.5)
        #expect(manager.groupVolume(for: .sfx) == 0.5)
        #expect(manager.groupVolume(for: .music) == 1.0)
    }

    @Test("Group volume clamps to 0-1")
    func groupVolumeClamps() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)
        manager.setGroupVolume(.sfx, volume: -0.5)
        #expect(manager.groupVolume(for: .sfx) == 0.0)
        manager.setGroupVolume(.sfx, volume: 2.0)
        #expect(manager.groupVolume(for: .sfx) == 1.0)
    }

    @Test("Changing group volume updates active sounds")
    func changingGroupVolumeUpdatesSounds() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playSound(sfxHandle, volume: 0.75, group: .sfx)
        manager.setGroupVolume(.sfx, volume: 0.5)

        // Should have called setSoundVolume with effective = 0.75 * 0.5 = 0.375
        #expect(backend.setSoundVolumeCalls.count == 1)
        let expected: Float = 0.375
        #expect(backend.setSoundVolumeCalls[0].volume == expected)
    }

    @Test("Changing music group volume updates current music")
    func changingMusicGroupVolumeUpdatesMusic() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 0.75)
        manager.setGroupVolume(.music, volume: 0.5)

        // Should have called setMusicVolume with effective = 0.75 * 0.5 = 0.375
        #expect(backend.setMusicVolumeCalls.count == 1)
        let expected: Float = 0.375
        #expect(backend.setMusicVolumeCalls[0].volume == expected)
    }
}

@Suite("AudioManager Sound Tests")
struct AudioManagerSoundTests {
    @Test("Play sound applies group volume")
    func playSoundAppliesGroupVolume() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.setGroupVolume(.sfx, volume: 0.5)
        manager.playSound(sfxHandle, volume: 0.75, group: .sfx)

        #expect(backend.playSoundCalls.count == 1)
        let expected: Float = 0.375
        #expect(backend.playSoundCalls[0].volume == expected)
    }

    @Test("Play sound defaults to SFX group")
    func playSoundDefaultsToSfx() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.setGroupVolume(.sfx, volume: 0.5)
        manager.playSound(sfxHandle)

        // Default volume 1.0, sfx group 0.5 → effective 0.5
        #expect(backend.playSoundCalls[0].volume == 0.5)
    }

    @Test("playUISound uses UI group")
    func playUISound() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.setGroupVolume(.ui, volume: 0.3)
        manager.playUISound(sfxHandle, volume: 1.0)

        #expect(backend.playSoundCalls[0].volume == 0.3)
    }

    @Test("isSoundPlaying delegates to backend")
    func isSoundPlayingDelegates() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        #expect(!manager.isSoundPlaying(sfxHandle))
        backend.soundsPlaying.insert(sfxHandle.id)
        #expect(manager.isSoundPlaying(sfxHandle))
    }

    @Test("Pitch is passed through")
    func pitchPassthrough() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playSound(sfxHandle, pitch: 1.5)
        #expect(backend.playSoundCalls[0].pitch == 1.5)
    }
}

@Suite("AudioManager Music Tests")
struct AudioManagerMusicTests {
    @Test("Play music basic")
    func playMusicBasic() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 0.7, looping: false)

        #expect(backend.playMusicCalls.count == 1)
        #expect(backend.playMusicCalls[0].volume == 0.7)
        #expect(backend.playMusicCalls[0].looping == false)
    }

    @Test("Play music stops previous music")
    func playMusicStopsPrevious() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1)
        manager.playMusic(musicHandle2)

        #expect(backend.stopMusicCalls.count == 1)
        #expect(backend.stopMusicCalls[0].id == musicHandle1.id)
    }

    @Test("Stop music")
    func stopMusic() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1)
        manager.stopMusic()

        #expect(backend.stopMusicCalls.count == 1)
        #expect(!manager.isMusicPlaying())
    }

    @Test("Pause and resume music")
    func pauseResumeMusic() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1)
        manager.pauseMusic()
        #expect(backend.pauseMusicCalls.count == 1)

        manager.resumeMusic()
        #expect(backend.resumeMusicCalls.count == 1)
    }

    @Test("isMusicPlaying delegates to backend")
    func isMusicPlayingDelegates() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        #expect(!manager.isMusicPlaying())
        manager.playMusic(musicHandle1)
        #expect(manager.isMusicPlaying())
    }

    @Test("Music group volume applied")
    func musicGroupVolumeApplied() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.setGroupVolume(.music, volume: 0.5)
        manager.playMusic(musicHandle1, volume: 0.75)

        // Effective = 0.75 * 0.5 = 0.375
        let expected: Float = 0.375
        #expect(backend.playMusicCalls[0].volume == expected)
    }

    @Test("Update calls updateMusicStream")
    func updateCallsMusicStream() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1)
        manager.update(deltaTime: 0.016)

        #expect(backend.updateMusicStreamCalls.count == 1)
        #expect(backend.updateMusicStreamCalls[0].id == musicHandle1.id)
    }
}

@Suite("AudioManager Fade Tests")
struct AudioManagerFadeTests {
    @Test("Play music with fade-in starts at zero volume")
    func fadeInStartsAtZero() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0, fadeDuration: 2.0)

        // Should start at 0 volume
        #expect(backend.playMusicCalls[0].volume == 0.0)
    }

    @Test("Fade-in progresses over time")
    func fadeInProgresses() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0, fadeDuration: 2.0)

        // After 1 second (50% progress), volume should be ~0.5
        manager.update(deltaTime: 1.0)

        let lastVolume = backend.setMusicVolumeCalls.last!.volume
        #expect(lastVolume > 0.4 && lastVolume < 0.6)
    }

    @Test("Fade-in completes at target volume")
    func fadeInCompletes() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 0.8, fadeDuration: 1.0)

        // After full duration
        manager.update(deltaTime: 1.0)

        let lastVolume = backend.setMusicVolumeCalls.last!.volume
        #expect(lastVolume == 0.8)

        // No more volume updates after completion
        backend.setMusicVolumeCalls.removeAll()
        manager.update(deltaTime: 0.016)
        #expect(backend.setMusicVolumeCalls.isEmpty)
    }

    @Test("Fade out music")
    func fadeOut() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0)
        manager.fadeOutMusic(duration: 2.0)

        // At 50%
        manager.update(deltaTime: 1.0)
        let midVolume = backend.setMusicVolumeCalls.last!.volume
        #expect(midVolume > 0.4 && midVolume < 0.6)

        // At 100% — should stop
        manager.update(deltaTime: 1.0)
        #expect(backend.stopMusicCalls.count == 1)
    }

    @Test("Fade respects music group volume")
    func fadeRespectsGroupVolume() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.setGroupVolume(.music, volume: 0.5)
        manager.playMusic(musicHandle1, volume: 1.0, fadeDuration: 1.0)

        // After full fade, effective = 1.0 * 0.5 = 0.5
        manager.update(deltaTime: 1.0)
        let lastVolume = backend.setMusicVolumeCalls.last!.volume
        #expect(lastVolume == 0.5)
    }

    @Test("Zero duration fade plays at full volume immediately")
    func zeroDurationFade() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 0.8, fadeDuration: 0)

        // Should start at full volume, no fade
        #expect(backend.playMusicCalls[0].volume == 0.8)
    }
}

@Suite("AudioManager Crossfade Tests")
struct AudioManagerCrossfadeTests {
    @Test("Crossfade starts both streams")
    func crossfadeStartsBothStreams() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0)
        manager.crossfadeToMusic(musicHandle2, volume: 1.0, duration: 2.0)

        // Two playMusic calls (original + new)
        #expect(backend.playMusicCalls.count == 2)
        // New starts at 0
        #expect(backend.playMusicCalls[1].volume == 0.0)
    }

    @Test("Crossfade outgoing fades out")
    func crossfadeOutgoingFadesOut() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0)
        manager.crossfadeToMusic(musicHandle2, volume: 1.0, duration: 2.0)

        // After 1 second, outgoing should be at ~0.5
        manager.update(deltaTime: 1.0)

        let outgoingVolumes = backend.setMusicVolumeCalls.filter { $0.handle.id == musicHandle1.id }
        #expect(!outgoingVolumes.isEmpty)
        let outgoingVolume = outgoingVolumes.last!.volume
        #expect(outgoingVolume > 0.4 && outgoingVolume < 0.6)
    }

    @Test("Crossfade incoming fades in")
    func crossfadeIncomingFadesIn() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0)
        manager.crossfadeToMusic(musicHandle2, volume: 1.0, duration: 2.0)

        // After 1 second, incoming should be at ~0.5
        manager.update(deltaTime: 1.0)

        let incomingVolumes = backend.setMusicVolumeCalls.filter { $0.handle.id == musicHandle2.id }
        #expect(!incomingVolumes.isEmpty)
        let incomingVolume = incomingVolumes.last!.volume
        #expect(incomingVolume > 0.4 && incomingVolume < 0.6)
    }

    @Test("Crossfade completes: outgoing stops, incoming at full volume")
    func crossfadeCompletes() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0)
        manager.crossfadeToMusic(musicHandle2, volume: 0.8, duration: 1.0)

        // Complete the crossfade
        manager.update(deltaTime: 1.0)

        // Outgoing should be stopped
        let stopsForHandle1 = backend.stopMusicCalls.filter { $0.id == musicHandle1.id }
        #expect(!stopsForHandle1.isEmpty)

        // Incoming should be at target volume
        let incomingVolumes = backend.setMusicVolumeCalls.filter { $0.handle.id == musicHandle2.id }
        #expect(incomingVolumes.last!.volume == 0.8)
    }

    @Test("Crossfade during crossfade stops old outgoing")
    func crossfadeDuringCrossfade() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        let musicHandle3 = MusicHandle(id: 3)

        manager.playMusic(musicHandle1, volume: 1.0)
        manager.crossfadeToMusic(musicHandle2, volume: 1.0, duration: 2.0)

        // Mid-crossfade, start another
        manager.update(deltaTime: 0.5)
        manager.crossfadeToMusic(musicHandle3, volume: 1.0, duration: 1.0)

        // musicHandle1 should have been stopped (old outgoing)
        let stopsForHandle1 = backend.stopMusicCalls.filter { $0.id == musicHandle1.id }
        #expect(!stopsForHandle1.isEmpty)
    }

    @Test("Crossfade updates both music streams")
    func crossfadeUpdatesBothStreams() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playMusic(musicHandle1, volume: 1.0)
        manager.crossfadeToMusic(musicHandle2, volume: 1.0, duration: 2.0)
        backend.updateMusicStreamCalls.removeAll()

        manager.update(deltaTime: 0.016)

        // Both streams should get updateMusicStream
        let stream1Updates = backend.updateMusicStreamCalls.filter { $0.id == musicHandle1.id }
        let stream2Updates = backend.updateMusicStreamCalls.filter { $0.id == musicHandle2.id }
        #expect(!stream1Updates.isEmpty)
        #expect(!stream2Updates.isEmpty)
    }
}

@Suite("AudioManager Update Tests")
struct AudioManagerUpdateTests {
    @Test("Update cleans up finished sounds")
    func updateCleansUpFinishedSounds() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.playSound(sfxHandle, volume: 0.5, group: .sfx)
        // Sound is "playing"

        // Change group volume — should update the sound
        manager.setGroupVolume(.sfx, volume: 0.8)
        #expect(backend.setSoundVolumeCalls.count == 1)

        // Mark the sound as finished
        backend.soundsPlaying.remove(sfxHandle.id)
        manager.update(deltaTime: 0.016)

        // Now changing group volume shouldn't update anything
        backend.setSoundVolumeCalls.removeAll()
        manager.setGroupVolume(.sfx, volume: 0.3)
        #expect(backend.setSoundVolumeCalls.isEmpty)
    }

    @Test("No music — update is safe")
    func noMusicUpdateSafe() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        // Should not crash
        manager.update(deltaTime: 0.016)
        #expect(backend.updateMusicStreamCalls.isEmpty)
    }

    @Test("Pause and resume with no music is safe")
    func pauseResumeNoMusic() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.pauseMusic()
        manager.resumeMusic()
        #expect(backend.pauseMusicCalls.isEmpty)
        #expect(backend.resumeMusicCalls.isEmpty)
    }

    @Test("Fade out with no music is safe")
    func fadeOutNoMusic() {
        let backend = TrackingAudioBackend()
        let manager = AudioManager(backend: backend)

        manager.fadeOutMusic(duration: 1.0)
        manager.update(deltaTime: 0.5)
        // Should not crash
    }
}
