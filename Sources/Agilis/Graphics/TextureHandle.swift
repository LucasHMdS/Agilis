/// An opaque handle to a GPU texture. Created by the render backend.
public struct TextureHandle: Sendable, Hashable, Codable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    public static let invalid = TextureHandle(id: 0)
}
