import Foundation

/// Manages loading, caching, and unloading of game assets.
public final class AssetManager: @unchecked Sendable {
    deinit {}

    private var cache: [String: (typeId: ObjectIdentifier, asset: Any)] = [:]

    public init() {}

    /// Resolves a relative asset filename to an absolute path.
    ///
    /// On iOS, assets live inside the app bundle, so this prepends
    /// `Bundle.main.resourcePath`. On desktop platforms the path is
    /// returned unchanged (assets are loaded relative to the executable).
    public static func bundlePath(for filename: String) -> String {
        #if os(iOS) || os(tvOS)
        return (Bundle.main.resourcePath ?? "") + "/" + filename
        #else
        return filename
        #endif
    }

    /// Load an asset from a file path, returning a cached version if available.
    /// The loader closure is only called if the asset is not already cached.
    ///
    /// If a cached asset exists for this path but has a different type, the old
    /// entry is replaced with a freshly loaded asset of the requested type.
    public func load<T>(_ path: String, loader: () throws -> T) throws -> T {
        let requestedType = ObjectIdentifier(T.self)
        if let entry = cache[path], entry.typeId == requestedType,
           let asset = entry.asset as? T {
            return asset
        }
        let asset = try loader()
        cache[path] = (typeId: requestedType, asset: asset)
        return asset
    }

    /// Store an asset in the cache manually.
    public func store<T>(_ asset: T, for path: String) {
        cache[path] = (typeId: ObjectIdentifier(T.self), asset: asset)
    }

    /// Retrieve a cached asset, or nil if not loaded or if the type doesn't match.
    public func get<T>(_: T.Type, for path: String) -> T? {
        guard let entry = cache[path],
              entry.typeId == ObjectIdentifier(T.self) else { return nil }
        return entry.asset as? T
    }

    /// Remove an asset from the cache.
    public func unload(_ path: String) {
        cache.removeValue(forKey: path)
    }

    /// Remove all cached assets.
    public func unloadAll() {
        cache.removeAll()
    }

    /// Number of cached assets.
    public var count: Int {
        cache.count
    }

    /// A Boolean value that indicates whether the cache is empty.
    public var isEmpty: Bool {
        cache.isEmpty
    }
}
