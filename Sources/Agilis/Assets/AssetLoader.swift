/// An error that can occur during asset loading.
public enum AssetError: Error {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case parseError(String)
    case noLoaderRegistered(String)
}

/// Protocol for pluggable asset loaders. Each loader handles specific file extensions.
public protocol AssetLoaderProtocol {
    /// The type of asset this loader produces.
    associatedtype Asset

    /// File extensions this loader supports (e.g., ["ldtk", "json"]).
    static var supportedExtensions: [String] { get }

    /// Load an asset from raw data.
    func load(from data: [UInt8], path: String) throws -> Asset
}
