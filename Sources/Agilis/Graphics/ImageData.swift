/// Image data loaded from a file, before GPU upload.
public struct ImageData: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8] // RGBA, 4 bytes per pixel

    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}
