/// A 2D camera with position, zoom, and rotation.
public struct Camera2D: Sendable {
    /// The camera's target position in world coordinates.
    public var target: Vector2

    /// The offset from the screen center (in screen coordinates).
    public var offset: Vector2

    /// Zoom level (1.0 = normal, 2.0 = 2x zoom in).
    public var zoom: Float

    /// Rotation in radians.
    public var rotation: Float

    public init(
        target: Vector2 = .zero,
        offset: Vector2 = .zero,
        zoom: Float = 1.0,
        rotation: Float = 0
    ) {
        self.target = target
        self.offset = offset
        self.zoom = zoom
        self.rotation = rotation
    }
}
