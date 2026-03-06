import StbC

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

    /// Loads an image from a PNG/JPG/BMP/TGA file on disk.
    /// Returns nil if the file cannot be loaded.
    public static func load(from path: String) -> ImageData? {
        var w: Int32 = 0
        var h: Int32 = 0
        var channels: Int32 = 0
        guard let pixels = stbi_load(path, &w, &h, &channels, 4) else {
            return nil
        }
        defer { stbi_image_free(pixels) }

        let count = Int(w) * Int(h) * 4
        let buffer = Array(UnsafeBufferPointer(start: pixels, count: count))
        return ImageData(width: Int(w), height: Int(h), pixels: buffer)
    }

    /// Saves the image as a PNG file.
    /// Returns true on success, false on failure.
    @discardableResult
    public func save(to path: String) -> Bool {
        pixels.withUnsafeBufferPointer { ptr in
            let result = stbi_write_png(
                path, Int32(width), Int32(height), 4,
                ptr.baseAddress, Int32(width * 4)
            )
            return result != 0
        }
    }
}
