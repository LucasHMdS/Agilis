/// Built-in audio groups for independent volume control.
///
/// Each group has its own volume multiplier. Effective playback volume
/// is the sound's base volume multiplied by its group's volume.
///
/// ```swift
/// app.audioManager.setGroupVolume(.sfx, volume: 0.5)
/// app.audioManager.playSound(explosionHandle, group: .sfx)
/// ```
public enum AudioGroup: String, Sendable, Hashable, CaseIterable {
    /// Background music.
    case music
    /// Sound effects (explosions, footsteps, etc.).
    case sfx
    /// UI sounds (button clicks, menu navigation, etc.).
    case ui
}
