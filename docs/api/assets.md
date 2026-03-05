# Assets

## AssetManager

`Sources/Agilis/Assets/AssetManager.swift`

A generic cache keyed by file path. Prevents loading the same resource multiple times.

### Methods

```swift
// Load an asset. Returns cached version if available, otherwise calls the loader closure.
func load<T>(_ path: String, loader: () throws -> T) throws -> T

// Manually insert an asset into the cache.
func store<T>(_ asset: T, for path: String)

// Retrieve a cached asset without loading.
func get<T>(_ type: T.Type, for path: String) -> T?

// Remove a single asset from the cache.
func unload(_ path: String)

// Clear the entire cache.
func unloadAll()

// Number of cached assets.
var count: Int
```

### Usage

```swift
// Load a texture (cached on subsequent calls)
let texture = try app.assets.load("player.png") {
    app.renderer.loadTexture(from: "player.png")
}

// Retrieve without loading
if let cached: TextureHandle = app.assets.get(TextureHandle.self, for: "player.png") {
    // Use cached texture
}

// Clean up
app.assets.unload("player.png")
```

---

## AssetLoaderProtocol

`Sources/Agilis/Assets/AssetLoader.swift`

Protocol for implementing typed asset loaders:

```swift
protocol AssetLoaderProtocol {
    associatedtype Asset
    static var supportedExtensions: [String] { get }
    func load(from data: [UInt8], path: String) throws -> Asset
}
```

---

## AssetError

```swift
enum AssetError: Error {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case parseError(String)
    case noLoaderRegistered(String)
}
```
