/// An opaque handle to a loaded font. Created by the render backend.
public struct FontHandle: Sendable, Hashable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    public static let invalid = FontHandle(id: 0)
}
