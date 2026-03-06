/// An opaque handle to a GPU render target (off-screen framebuffer). Created by the render backend.
public struct RenderTargetHandle: Sendable, Hashable {
    public let id: UInt32

    public init(id: UInt32) {
        self.id = id
    }

    public static let invalid = RenderTargetHandle(id: 0)
}
