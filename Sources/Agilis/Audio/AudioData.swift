/// Raw PCM audio sample data, before audio device upload.
public struct AudioData: Sendable {
    /// Sample rate in Hz (e.g., 44100).
    public let sampleRate: Int
    /// Bits per sample (8 or 16).
    public let sampleSize: Int
    /// Number of channels (1 = mono, 2 = stereo).
    public let channels: Int
    /// Raw PCM sample data as bytes.
    /// For 16-bit mono: 2 bytes per sample, little-endian signed Int16.
    /// For 8-bit mono: 1 byte per sample, unsigned UInt8 (128 = silence).
    public let data: [UInt8]

    public init(sampleRate: Int, sampleSize: Int, channels: Int, data: [UInt8]) {
        self.sampleRate = sampleRate
        self.sampleSize = sampleSize
        self.channels = channels
        self.data = data
    }

    /// Computed number of audio frames.
    public var frameCount: Int {
        let bytesPerFrame = (sampleSize / 8) * channels
        guard bytesPerFrame > 0 else { return 0 }
        return data.count / bytesPerFrame
    }
}
