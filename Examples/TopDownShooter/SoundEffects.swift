import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

enum ShooterSounds {
    struct SoundSet {
        let pistolFire: SoundHandle
        let shotgunFire: SoundHandle
        let laserFire: SoundHandle
        let enemyHit: SoundHandle
        let enemyDie: SoundHandle
        let playerHurt: SoundHandle
        let waveStart: SoundHandle

        func unloadAll(audio: any AudioBackend) {
            audio.unloadSound(pistolFire)
            audio.unloadSound(shotgunFire)
            audio.unloadSound(laserFire)
            audio.unloadSound(enemyHit)
            audio.unloadSound(enemyDie)
            audio.unloadSound(playerHurt)
            audio.unloadSound(waveStart)
        }
    }

    private static let sampleRate = 44100
    private static let pi = Float.pi

    static func generate(audio: any AudioBackend) -> SoundSet {
        SoundSet(
            pistolFire: audio.loadSoundFromData(genPistol()),
            shotgunFire: audio.loadSoundFromData(genShotgun()),
            laserFire: audio.loadSoundFromData(genLaser()),
            enemyHit: audio.loadSoundFromData(genHit()),
            enemyDie: audio.loadSoundFromData(genDie()),
            playerHurt: audio.loadSoundFromData(genHurt()),
            waveStart: audio.loadSoundFromData(genWaveStart())
        )
    }

    private static func genPistol() -> AudioData {
        genTone(freq0: 600, freq1: 200, dur: 0.06, vol: 0.35, square: true)
    }

    private static func genShotgun() -> AudioData {
        genTone(freq0: 300, freq1: 80, dur: 0.1, vol: 0.4, square: true)
    }

    private static func genLaser() -> AudioData {
        genTone(freq0: 1200, freq1: 800, dur: 0.12, vol: 0.25, square: false)
    }

    private static func genHit() -> AudioData {
        genTone(freq0: 400, freq1: 200, dur: 0.04, vol: 0.2, square: false)
    }

    private static func genDie() -> AudioData {
        genTone(freq0: 500, freq1: 100, dur: 0.2, vol: 0.3, square: true)
    }

    private static func genHurt() -> AudioData {
        genTone(freq0: 200, freq1: 100, dur: 0.15, vol: 0.3, square: false)
    }

    private static func genWaveStart() -> AudioData {
        let dur: Float = 0.4
        let samples = Int(Float(sampleRate) * dur)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq: Float = t < 0.5 ? 400 + t * 400 : 600 + (t - 0.5) * 200
            phase += freq / Float(sampleRate)
            let wave = sinf(phase * 2 * pi) * 0.2
            let sq = ((phase - floorf(phase)) < 0.5 ? Float(1) : Float(-1)) * 0.1
            let env: Float = t > 0.7 ? (1.0 - t) / 0.3 : 1.0
            data[i] = toSample((wave + sq) * env)
        }
        return makeAudioData(samples: data)
    }

    private static func genTone(freq0: Float, freq1: Float, dur: Float, vol: Float, square: Bool) -> AudioData {
        let samples = Int(Float(sampleRate) * dur)
        var data = [Int16](repeating: 0, count: samples)
        var phase: Float = 0
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let freq = freq0 + (freq1 - freq0) * t
            phase += freq / Float(sampleRate)
            let wave: Float
            if square {
                wave = ((phase - floorf(phase)) < 0.5 ? Float(1) : Float(-1)) * vol
            } else {
                wave = sinf(phase * 2 * pi) * vol
            }
            let envelope = 1.0 - t
            data[i] = toSample(wave * envelope)
        }
        return makeAudioData(samples: data)
    }

    private static func toSample(_ value: Float) -> Int16 {
        Int16(max(-1.0, min(1.0, value)) * 32000)
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
