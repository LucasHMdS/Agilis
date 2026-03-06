/// A 2D size with floating-point dimensions.
public struct Size: Sendable, Hashable, Codable {
    public var width: Float
    public var height: Float

    public init(width: Float = 0, height: Float = 0) {
        self.width = width
        self.height = height
    }

    public static let zero = Size(width: 0, height: 0)
}
