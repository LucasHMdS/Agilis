import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

enum DungeonSounds {
    struct SoundSet {
        let footstep: SoundHandle
        let enemyAlert: SoundHandle

        func unloadAll(audio: any AudioBackend) {
            audio.unloadSound(footstep)
            audio.unloadSound(enemyAlert)
        }
    }

    private static let sampleRate = 44_100
    private static let pi = Float.pi

    static func generate(audio: any AudioBackend) -> SoundSet {
        SoundSet(
            footstep: audio.loadSoundFromData(generateFootstep()),
            enemyAlert: audio.loadSoundFromData(generateEnemyAlert())
        )
    }

    // Soft footstep — low thud
    private static func generateFootstep() -> AudioData {
        let duration: Float = 0.05
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            phase += 100.0 / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.2
            let envelope = (1.0 - t) * (1.0 - t)
            data[i] = toSample(wave * envelope)
        }
        return makeAudioData(samples: data)
    }

    // Enemy alert — sharp rising tone
    private static func generateEnemyAlert() -> AudioData {
        let duration: Float = 0.15
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq: Float = 400 + t * 600
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.3
            let sq = (phase - floorf(phase)) < 0.5 ? Float(1) : Float(-1)
            let envelope = 1.0 - t * 0.5
            data[i] = toSample((wave * 0.7 + sq * 0.1) * envelope)
        }
        return makeAudioData(samples: data)
    }

    private static func toSample(_ value: Float) -> Int16 {
        Int16(max(-1.0, min(1.0, value)) * 32_000)
    }

    private static func makeAudioData(samples: [Int16]) -> AudioData {
        var bytes = [UInt8](repeating: 0, count: samples.count * 2)
        for i in 0..<samples.count {
            let s = samples[i]
            bytes[i * 2] = UInt8(truncatingIfNeeded: s)
            bytes[i * 2 + 1] = UInt8(truncatingIfNeeded: s >> 8)
        }
        return AudioData(sampleRate: sampleRate, sampleSize: 16, channels: 1, data: bytes)
    }
}
