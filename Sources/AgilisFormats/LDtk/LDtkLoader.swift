import Foundation

/// Loads and parses LDtk project files.
public struct LDtkLoader: Sendable {
    public init() {}

    /// Parse an LDtk project from JSON data.
    public func load(from data: Data) throws -> LDtkProject {
        let decoder = JSONDecoder()
        return try decoder.decode(LDtkProject.self, from: data)
    }

    /// Parse an LDtk project from raw bytes.
    public func load(from bytes: [UInt8]) throws -> LDtkProject {
        try load(from: Data(bytes))
    }
}
