import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

enum RPGSounds {
    struct SoundSet {
        let pickup: SoundHandle
        let chestOpen: SoundHandle
        let save: SoundHandle
        let load: SoundHandle

        func unloadAll(audio: any AudioBackend) {
            audio.unloadSound(pickup)
            audio.unloadSound(chestOpen)
            audio.unloadSound(save)
            audio.unloadSound(load)
        }
    }

    private static let sampleRate = 44100
    private static let pi = Float.pi

    static func generate(audio: any AudioBackend) -> SoundSet {
        SoundSet(
            pickup: audio.loadSoundFromData(generatePickup()),
            chestOpen: audio.loadSoundFromData(generateChestOpen()),
            save: audio.loadSoundFromData(generateSave()),
            load: audio.loadSoundFromData(generateLoad())
        )
    }

    // Pickup — bright ascending tone
    private static func generatePickup() -> AudioData {
        let duration: Float = 0.12
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = 400 + t * 400
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.3
            let envelope = 1.0 - t
            data[i] = toSample(wave * envelope)
        }
        return makeAudioData(samples: data)
    }

    // Chest open — low thud + creak
    private static func generateChestOpen() -> AudioData {
        let duration: Float = 0.2
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq: Float = t < 0.3 ? 150 : 250 + t * 100
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.25
            let envelope = 1.0 - t * 0.7
            data[i] = toSample(wave * envelope)
        }
        return makeAudioData(samples: data)
    }

    // Save — confirmation chime (two ascending notes)
    private static func generateSave() -> AudioData {
        let duration: Float = 0.3
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq: Float = t < 0.5 ? 523 : 659
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.2
            let sq = squareWave(phase) * 0.1
            let noteT = t < 0.5 ? t * 2 : (t - 0.5) * 2
            let envelope: Float = noteT > 0.7 ? (1.0 - noteT) / 0.3 : 1.0
            data[i] = toSample((wave + sq) * envelope)
        }
        return makeAudioData(samples: data)
    }

    // Load — descending then ascending sweep
    private static func generateLoad() -> AudioData {
        let duration: Float = 0.25
        let samples = Int(Float(sampleRate) * duration)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq: Float = t < 0.5 ? 600 - t * 400 : 400 + (t - 0.5) * 600
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.25
            let envelope = 1.0 - t * 0.5
            data[i] = toSample(wave * envelope)
        }
        return makeAudioData(samples: data)
    }

    private static func squareWave(_ phase: Float) -> Float {
        let frac = phase - floorf(phase)
        return frac < 0.5 ? 1.0 : -1.0
    }

    private static func toSample(_ value: Float) -> Int16 {
        let clamped = max(-1.0, min(1.0, value))
        return Int16(clamped * 32000)
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
