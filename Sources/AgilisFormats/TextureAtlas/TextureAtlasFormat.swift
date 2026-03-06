import Foundation

/// A TexturePacker-compatible JSON atlas format.
public struct TextureAtlasData: Codable, Sendable {
    public let frames: [String: AtlasFrame]
    public let meta: AtlasMeta
}

public struct AtlasFrame: Codable, Sendable {
    public let frame: AtlasRect
    public let rotated: Bool
    public let trimmed: Bool
    public let spriteSourceSize: AtlasRect
    public let sourceSize: AtlasSize
}

public struct AtlasRect: Codable, Sendable {
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int
}

public struct AtlasSize: Codable, Sendable {
    public let w: Int
    public let h: Int
}

public struct AtlasMeta: Codable, Sendable {
    public let image: String
    public let size: AtlasSize
    public let scale: String?
}

/// Loads TexturePacker JSON atlas files.
public struct TextureAtlasLoader: Sendable {
    public init() {}

    /// Parse a texture atlas from JSON data.
    public func load(from data: Data) throws -> TextureAtlasData {
        let decoder = JSONDecoder()
        return try decoder.decode(TextureAtlasData.self, from: data)
    }

    /// Parse from raw bytes.
    public func load(from bytes: [UInt8]) throws -> TextureAtlasData {
        try load(from: Data(bytes))
    }
}
