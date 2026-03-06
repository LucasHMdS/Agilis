/// An axis-aligned rectangle defined by origin and size.
public struct Rect: Sendable, Hashable, Codable {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float

    public init(x: Float = 0, y: Float = 0, width: Float = 0, height: Float = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(origin: Vector2, size: Size) {
        self.x = origin.x
        self.y = origin.y
        self.width = size.width
        self.height = size.height
    }

    public var origin: Vector2 {
        get { Vector2(x: x, y: y) }
        set { x = newValue.x; y = newValue.y }
    }

    public var size: Size {
        get { Size(width: width, height: height) }
        set { width = newValue.width; height = newValue.height }
    }

    public var center: Vector2 {
        Vector2(x: x + width * 0.5, y: y + height * 0.5)
    }

    public var minX: Float { x }
    public var maxX: Float { x + width }
    public var minY: Float { y }
    public var maxY: Float { y + height }

    public func contains(_ point: Vector2) -> Bool {
        point.x >= minX && point.x <= maxX &&
        point.y >= minY && point.y <= maxY
    }

    public func intersects(_ other: Rect) -> Bool {
        minX < other.maxX && maxX > other.minX &&
        minY < other.maxY && maxY > other.minY
    }

    public func intersection(_ other: Rect) -> Rect? {
        let overlapX = max(minX, other.minX)
        let overlapY = max(minY, other.minY)
        let overlapMaxX = min(maxX, other.maxX)
        let overlapMaxY = min(maxY, other.maxY)

        guard overlapX < overlapMaxX && overlapY < overlapMaxY else { return nil }
        return Rect(x: overlapX, y: overlapY, width: overlapMaxX - overlapX, height: overlapMaxY - overlapY)
    }
}
