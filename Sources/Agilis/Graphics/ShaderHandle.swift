/// An opaque handle to a GPU shader program. Created by the render backend.
public struct ShaderHandle: Sendable, Hashable, Codable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    public static let invalid = ShaderHandle(id: 0)
}
