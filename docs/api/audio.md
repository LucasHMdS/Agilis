# Audio

## AudioBackend

`Sources/AgilisCore/Audio/AudioBackend.swift`

Abstraction over platform-specific audio playback. Two categories: **sound effects** (loaded entirely into memory, low latency) and **music** (streamed from disk, for longer tracks).

### Lifecycle

```swift
func initialize() throws
func shutdown()
```

### Sound Effects (In-Memory)

Best for short clips: footsteps, explosions, UI clicks.

```swift
func loadSound(from path: String) -> SoundHandle
func playSound(_ handle: SoundHandle, volume: Float, pitch: Float, looping: Bool)
func stopSound(_ handle: SoundHandle)
func unloadSound(_ handle: SoundHandle)
func isSoundPlaying(_ handle: SoundHandle) -> Bool       // Default: false
func setSoundVolume(_ handle: SoundHandle, volume: Float) // Default: no-op
```

### Music (Streaming)

Best for background music and ambient audio.

```swift
func loadMusic(from path: String) -> MusicHandle
func playMusic(_ handle: MusicHandle, volume: Float, looping: Bool)
func pauseMusic(_ handle: MusicHandle)
func resumeMusic(_ handle: MusicHandle)
func stopMusic(_ handle: MusicHandle)
func updateMusicStream(_ handle: MusicHandle)   // Must call each frame
func unloadMusic(_ handle: MusicHandle)
func isMusicPlaying(_ handle: MusicHandle) -> Bool       // Default: false
func setMusicVolume(_ handle: MusicHandle, volume: Float) // Default: no-op
```

### Global

```swift
func setMasterVolume(_ volume: Float)   // 0.0 to 1.0
```

---

## AudioManager

`Sources/Agilis/Audio/AudioManager.swift`

High-level audio manager wrapping `AudioBackend`. Provides group volumes, fading, and crossfading. Automatically updated each frame by `Application`.

Access via `app.audioManager`.

### Audio Groups

```swift
public enum AudioGroup {
    case music
    case sfx
    case ui
}
```

```swift
func setGroupVolume(_ group: AudioGroup, volume: Float)
func groupVolume(for group: AudioGroup) -> Float
```

Effective volume = base volume x group volume. Changing group volume retroactively updates all playing sounds in that group.

### Sound Effects

```swift
func playSound(_ handle: SoundHandle, volume: Float = 1.0,
               pitch: Float = 1.0, group: AudioGroup = .sfx)
func playUISound(_ handle: SoundHandle, volume: Float = 1.0)  // Shorthand for .ui group
```

### Music

Single-track music with optional fade transitions.

```swift
func playMusic(_ handle: MusicHandle, volume: Float = 1.0,
               looping: Bool = true, fadeDuration: Float = 0)
func fadeOutMusic(duration: Float)
func crossfadeToMusic(_ handle: MusicHandle, volume: Float = 1.0,
                      looping: Bool = true, duration: Float = 1.0)
```

### Usage

```swift
// Group volumes
app.audioManager.setGroupVolume(.sfx, volume: 0.5)

// Play sounds
app.audioManager.playSound(explosionHandle, group: .sfx)
app.audioManager.playUISound(clickHandle)

// Music with fade
app.audioManager.playMusic(bgmHandle, fadeDuration: 2.0)
app.audioManager.crossfadeToMusic(bossMusic, duration: 1.5)
app.audioManager.fadeOutMusic(duration: 1.0)
```

---

## Handles

### SoundHandle / MusicHandle

Opaque `UInt32` handles. Same pattern as `TextureHandle`:

```swift
struct SoundHandle: Sendable, Hashable {
    let id: UInt32
    static let invalid = SoundHandle(id: 0)
}

struct MusicHandle: Sendable, Hashable {
    let id: UInt32
    static let invalid = MusicHandle(id: 0)
}
```

---

## AudioFormat

Supported file formats:

```swift
enum AudioFormat: String {
    case wav, ogg, mp3, flac
}
```

---

## Usage Example

```swift
final class GameScene: Scene {
    private var jumpSound: SoundHandle = .invalid
    private var bgMusic: MusicHandle = .invalid

    func didEnter(app: Application) {
        jumpSound = app.audio.loadSound(from: "jump.wav")
        bgMusic = app.audio.loadMusic(from: "background.ogg")

        // Use AudioManager for high-level features
        app.audioManager.setGroupVolume(.sfx, volume: 0.8)
        app.audioManager.playMusic(bgMusic, fadeDuration: 1.0)
    }

    func update(app: Application, deltaTime: Double) {
        if app.input.isKeyPressed(.space) {
            app.audioManager.playSound(jumpSound, group: .sfx)
        }
    }

    func willExit(app: Application) {
        app.audioManager.fadeOutMusic(duration: 0.5)
        app.audio.unloadSound(jumpSound)
    }
}
```
