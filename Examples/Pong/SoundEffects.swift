import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Procedurally generated retro sound effects for the Pong game.
enum PongSounds {
    struct SoundSet {
        let paddleHit: SoundHandle
        let wallBounce: SoundHandle
        let goalScored: SoundHandle
        let serve: SoundHandle
        let winFanfare: SoundHandle
        let gameOver: SoundHandle

        func unloadAll(audio: AudioBackend) {
            audio.unloadSound(paddleHit)
            audio.unloadSound(wallBounce)
            audio.unloadSound(goalScored)
            audio.unloadSound(serve)
            audio.unloadSound(winFanfare)
            audio.unloadSound(gameOver)
        }
    }

    private static let sampleRate = 44100
    private static let pi = Float.pi

    static func generate(audio: AudioBackend) -> SoundSet {
        SoundSet(
            paddleHit: audio.loadSoundFromData(generatePaddleHit()),
            wallBounce: audio.loadSoundFromData(generateWallBounce()),
            goalScored: audio.loadSoundFromData(generateGoalScored()),
            serve: audio.loadSoundFromData(generateServe()),
            winFanfare: audio.loadSoundFromData(generateWinFanfare()),
            gameOver: audio.loadSoundFromData(generateGameOver())
        )
    }

    // MARK: - Sound Generators

    /// Classic "pong" beep — square wave at 440 Hz, ~0.06s, sharp decay
    private static func generatePaddleHit() -> AudioData {
        let duration: Float = 0.06
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        let freq: Float = 440

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            phase += freq / Float(sampleRate)
            let wave = squareWave(phase) * 0.35
            let envelope = 1.0 - t  // Linear decay
            data[i] = toSample(wave * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Subtle wall bounce — sine wave at 300 Hz, ~0.04s, rapid decay
    private static func generateWallBounce() -> AudioData {
        let duration: Float = 0.04
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        let freq: Float = 300

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.25
            let envelope = 1.0 - t  // Linear decay
            data[i] = toSample(wave * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Goal scored — descending square wave sweep 500→200 Hz, ~0.3s
    private static func generateGoalScored() -> AudioData {
        let duration: Float = 0.3
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(500, 200, t: t)
            phase += freq / Float(sampleRate)
            let wave = squareWave(phase) * 0.3
            let envelope = 1.0 - t * 0.6
            data[i] = toSample(wave * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Serve/launch — rising sine sweep 300→600 Hz, ~0.08s
    private static func generateServe() -> AudioData {
        let duration: Float = 0.08
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(300, 600, t: t)
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.3
            let envelope: Float = t < 0.3 ? t / 0.3 : 1.0 - (t - 0.3) / 0.7  // Attack + decay
            data[i] = toSample(wave * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Victory jingle — ascending 3-note melody C5→E5→G5, ~0.8s
    private static func generateWinFanfare() -> AudioData {
        let notes: [(freq: Float, duration: Float)] = [
            (523.25, 0.2),   // C5
            (659.25, 0.2),   // E5
            (783.99, 0.4),   // G5 (held longer)
        ]
        let totalDuration = notes.reduce(0) { $0 + $1.duration }
        let totalSamples = Int(Float(sampleRate) * totalDuration)
        var data = [Int16](repeating: 0, count: totalSamples)
        var phase: Float = 0
        var sampleOffset = 0

        for note in notes {
            let noteSamples = Int(Float(sampleRate) * note.duration)
            for i in 0..<noteSamples {
                let t = Float(i) / Float(noteSamples)
                phase += note.freq / Float(sampleRate)
                let sq = squareWave(phase) * 0.2
                let sine = sinf(phase * 2 * pi) * 0.1
                // Fade out the last 30% of each note
                let noteEnvelope: Float = t > 0.7 ? (1.0 - t) / 0.3 : 1.0
                let idx = sampleOffset + i
                if idx < totalSamples {
                    data[idx] = toSample((sq + sine) * noteEnvelope)
                }
            }
            sampleOffset += noteSamples
        }

        return makeAudioData(samples: data)
    }

    /// Game over (loss) — descending 3-note minor melody G4→Eb4→C4, ~0.8s
    private static func generateGameOver() -> AudioData {
        let notes: [(freq: Float, duration: Float)] = [
            (392.00, 0.2),   // G4
            (311.13, 0.2),   // Eb4
            (261.63, 0.4),   // C4 (held longer)
        ]
        let totalDuration = notes.reduce(0) { $0 + $1.duration }
        let totalSamples = Int(Float(sampleRate) * totalDuration)
        var data = [Int16](repeating: 0, count: totalSamples)
        var phase: Float = 0
        var sampleOffset = 0

        for note in notes {
            let noteSamples = Int(Float(sampleRate) * note.duration)
            for i in 0..<noteSamples {
                let t = Float(i) / Float(noteSamples)
                phase += note.freq / Float(sampleRate)
                let sq = squareWave(phase) * 0.2
                let sine = sinf(phase * 2 * pi) * 0.1
                let noteEnvelope: Float = t > 0.7 ? (1.0 - t) / 0.3 : 1.0
                let idx = sampleOffset + i
                if idx < totalSamples {
                    data[idx] = toSample((sq + sine) * noteEnvelope)
                }
            }
            sampleOffset += noteSamples
        }

        return makeAudioData(samples: data)
    }

    // MARK: - Helpers

    private static func squareWave(_ phase: Float) -> Float {
        let frac = phase - floorf(phase)
        return frac < 0.5 ? 1.0 : -1.0
    }

    private static func toSample(_ value: Float) -> Int16 {
        let clamped = max(-1.0, min(1.0, value))
        return Int16(clamped * 32000)
    }

    private static func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * t
    }

    private static func makeAudioData(samples: [Int16]) -> AudioData {
        var bytes = [UInt8](repeating: 0, count: samples.count * 2)
        for i in 0..<samples.count {
            let s = samples[i]
            bytes[i * 2] = UInt8(truncatingIfNeeded: s)
            bytes[i * 2 + 1] = UInt8(truncatingIfNeeded: s >> 8)
        }
        return AudioData(
            sampleRate: sampleRate,
            sampleSize: 16,
            channels: 1,
            data: bytes
        )
    }
}
