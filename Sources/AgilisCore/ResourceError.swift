/// Errors thrown by resource loading convenience methods.
public enum ResourceError: Error, Sendable {
    /// A texture failed to load from the given path.
    case textureLoadFailed(path: String)
    /// A font failed to load from the given path.
    case fontLoadFailed(path: String)
    /// A shader failed to compile.
    case shaderCompilationFailed
    /// A sound effect failed to load from the given path.
    case soundLoadFailed(path: String)
    /// A music track failed to load from the given path.
    case musicLoadFailed(path: String)
    /// A texture failed to create from image data.
    case textureFromImageFailed
}
