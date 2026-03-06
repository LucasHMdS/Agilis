import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Procedurally generated retro sound effects for the Mario game.
enum MarioSounds {
    struct SoundSet {
        let jump: SoundHandle
        let coin: SoundHandle
        let stomp: SoundHandle
        let hurt: SoundHandle
        let blockHit: SoundHandle
        let levelComplete: SoundHandle
        let gameOver: SoundHandle

        func unloadAll(audio: any AudioBackend) {
            audio.unloadSound(jump)
            audio.unloadSound(coin)
            audio.unloadSound(stomp)
            audio.unloadSound(hurt)
            audio.unloadSound(blockHit)
            audio.unloadSound(levelComplete)
            audio.unloadSound(gameOver)
        }
    }

    private static let sampleRate = 44100
    private static let pi = Float.pi

    static func generate(audio: any AudioBackend) -> SoundSet {
        SoundSet(
            jump: audio.loadSoundFromData(generateJump()),
            coin: audio.loadSoundFromData(generateCoin()),
            stomp: audio.loadSoundFromData(generateStomp()),
            hurt: audio.loadSoundFromData(generateHurt()),
            blockHit: audio.loadSoundFromData(generateBlockHit()),
            levelComplete: audio.loadSoundFromData(generateLevelComplete()),
            gameOver: audio.loadSoundFromData(generateGameOver())
        )
    }

    // MARK: - Sound Generators

    /// Rising square wave sweep 400→800 Hz, ~0.15s
    private static func generateJump() -> AudioData {
        let duration: Float = 0.15
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(400, 800, t: t)
            phase += freq / Float(sampleRate)
            let wave = squareWave(phase) * 0.3
            let envelope = 1.0 - t  // Linear decay
            data[i] = toSample(wave * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Two-note square wave: B5 (~988 Hz) then E6 (~1319 Hz), ~0.2s
    private static func generateCoin() -> AudioData {
        let duration: Float = 0.2
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        let halfPoint = samples / 2

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq: Float = i < halfPoint ? 988.0 : 1319.0
            phase += freq / Float(sampleRate)
            let wave = squareWave(phase) * 0.25
            let envelope = 1.0 - t * 0.7  // Gentle decay
            data[i] = toSample(wave * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Descending sine + noise burst, ~0.15s
    private static func generateStomp() -> AudioData {
        let duration: Float = 0.15
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        var noiseState: UInt32 = 12345

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(300, 80, t: t)
            phase += freq / Float(sampleRate)
            let sine = sinf(phase * 2 * pi) * 0.3
            // Simple noise (LFSR-ish)
            noiseState = noiseState &* 1103515245 &+ 12345
            let noise = (Float(noiseState >> 16 & 0x7FFF) / 16383.5 - 1.0) * 0.15
            let envelope = 1.0 - t
            data[i] = toSample((sine + noise * (1.0 - t)) * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Descending square wave 600→150 Hz, ~0.4s
    private static func generateHurt() -> AudioData {
        let duration: Float = 0.4
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(600, 150, t: t)
            phase += freq / Float(sampleRate)
            let wave = squareWave(phase) * 0.25
            let envelope = 1.0 - t * 0.8
            data[i] = toSample(wave * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Short sine+square ping at ~800 Hz, ~0.1s
    private static func generateBlockHit() -> AudioData {
        let duration: Float = 0.1
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        let freq: Float = 800

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            phase += freq / Float(sampleRate)
            let sine = sinf(phase * 2 * pi) * 0.2
            let sq = squareWave(phase) * 0.15
            let envelope = 1.0 - t  // Sharp decay
            data[i] = toSample((sine + sq) * envelope)
        }

        return makeAudioData(samples: data)
    }

    /// Ascending melody: C5→E5→G5→C6, ~1.1s total
    private static func generateLevelComplete() -> AudioData {
        let notes: [(freq: Float, duration: Float)] = [
            (523.25, 0.2),   // C5
            (659.25, 0.2),   // E5
            (783.99, 0.2),   // G5
            (1046.50, 0.5),  // C6 (held longer)
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

    /// Game over — descending minor sequence E4→C4→A3→F3, ~1.2s
    private static func generateGameOver() -> AudioData {
        let notes: [(freq: Float, duration: Float)] = [
            (329.63, 0.25),   // E4
            (261.63, 0.25),   // C4
            (220.00, 0.25),   // A3
            (174.61, 0.45),   // F3 (held longer, low and final)
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
        // Convert Int16 array to [UInt8] (little-endian)
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
