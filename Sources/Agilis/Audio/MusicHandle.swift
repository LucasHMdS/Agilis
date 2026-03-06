/// An opaque handle to a streaming music track.
public struct MusicHandle: Sendable, Hashable, Codable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    public static let invalid = MusicHandle(id: 0)
}
