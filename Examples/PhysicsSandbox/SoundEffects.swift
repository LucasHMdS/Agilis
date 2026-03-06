import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

enum SandboxSounds {
    struct SoundSet {
        let impact: SoundHandle
        let explosion: SoundHandle
        let jointBreak: SoundHandle
        let launch: SoundHandle

        func unloadAll(audio: any AudioBackend) {
            audio.unloadSound(impact)
            audio.unloadSound(explosion)
            audio.unloadSound(jointBreak)
            audio.unloadSound(launch)
        }
    }

    private static let sampleRate = 44100
    private static let pi = Float.pi

    static func generate(audio: any AudioBackend) -> SoundSet {
        SoundSet(
            impact: audio.loadSoundFromData(generateImpact()),
            explosion: audio.loadSoundFromData(generateExplosion()),
            jointBreak: audio.loadSoundFromData(generateJointBreak()),
            launch: audio.loadSoundFromData(generateLaunch())
        )
    }

    // Thud — low sine + noise burst, ~0.1s
    private static func generateImpact() -> AudioData {
        let duration: Float = 0.1
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            phase += 80.0 / Float(sampleRate)
            let sine = sinf(phase * 2 * pi) * 0.4
            let envelope = 1.0 - t
            data[i] = toSample(sine * envelope * envelope)
        }
        return makeAudioData(samples: data)
    }

    // Explosion — descending noise sweep, ~0.25s
    private static func generateExplosion() -> AudioData {
        let duration: Float = 0.25
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(200, 40, t: t)
            phase += freq / Float(sampleRate)
            let wave = squareWave(phase) * 0.3
            let noise = (Float(i % 7) / 3.5 - 1.0) * 0.15
            let envelope = (1.0 - t) * (1.0 - t)
            data[i] = toSample((wave + noise) * envelope)
        }
        return makeAudioData(samples: data)
    }

    // Joint break — sharp crack, ~0.05s
    private static func generateJointBreak() -> AudioData {
        let duration: Float = 0.05
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(800, 200, t: t)
            phase += freq / Float(sampleRate)
            let wave = squareWave(phase) * 0.35
            let envelope = 1.0 - t * t
            data[i] = toSample(wave * envelope)
        }
        return makeAudioData(samples: data)
    }

    // Launch — rising whoosh, ~0.08s
    private static func generateLaunch() -> AudioData {
        let duration: Float = 0.08
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0

        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = lerp(200, 800, t: t)
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.3
            let envelope: Float = t < 0.3 ? t / 0.3 : 1.0 - (t - 0.3) / 0.7
            data[i] = toSample(wave * envelope)
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
