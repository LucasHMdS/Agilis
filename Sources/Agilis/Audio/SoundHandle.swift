/// An opaque handle to a loaded sound effect.
public struct SoundHandle: Sendable, Hashable, Codable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    public static let invalid = SoundHandle(id: 0)
}
