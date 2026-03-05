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

/// The abstraction over platform-specific rendering.
/// Each backend (Raylib, Metal, OpenGL, WebGPU) provides a conforming type.
public protocol RenderBackend: AnyObject, Sendable {
    /// Initialize the rendering context and open a window.
    func initialize(config: WindowConfig) throws

    /// Shut down the renderer and release resources.
    func shutdown()

    /// Returns true if the window close has been requested.
    func shouldClose() -> Bool

    /// Begin a new frame.
    func beginFrame()

    /// End the current frame and present.
    func endFrame()

    /// Set the background clear color.
    func setBackgroundColor(_ color: Color)

    // MARK: - Textures

    /// Load a texture from a file path. Returns a handle for drawing.
    func loadTexture(from path: String) -> TextureHandle

    /// Get the size of a loaded texture.
    func textureSize(_ handle: TextureHandle) -> Size

    /// Destroy a texture and free GPU memory.
    func destroyTexture(_ handle: TextureHandle)

    /// Create a texture from raw pixel data (RGBA, 4 bytes per pixel).
    func loadTextureFromImage(_ image: ImageData) -> TextureHandle

    // MARK: - Drawing

    /// Draw a sprite.
    func drawSprite(_ sprite: Sprite)

    /// Draw multiple sprites. Backends may optimize this for batching.
    func drawSprites(_ sprites: [Sprite])

    /// Draw a filled rectangle.
    func drawRect(_ rect: Rect, color: Color)

    /// Draw a rectangle outline.
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float)

    /// Draw a line between two points.
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float)

    /// Draw a filled circle.
    func drawCircle(center: Vector2, radius: Float, color: Color)

    /// Draw a circle outline.
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float)

    // MARK: - Fonts & Text

    /// Load the default built-in font.
    func loadDefaultFont() -> FontHandle

    /// Load a font from a file path at a specific pixel size.
    func loadFont(from path: String, size: Int) -> FontHandle

    /// Destroy a font and free resources.
    func destroyFont(_ handle: FontHandle)

    /// Draw text at a position with a font, size, and color.
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color)

    /// Measure the pixel size a string would occupy when rendered.
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size

    // MARK: - Clipping

    /// Begin clipping all drawing to the given rectangle.
    func beginClip(_ rect: Rect)

    /// End clipping and restore full drawing area.
    func endClip()

    // MARK: - Camera

    /// Begin drawing with a 2D camera transform.
    func beginCamera(_ camera: Camera2D)

    /// End camera-transformed drawing.
    func endCamera()

    // MARK: - Render Targets

    /// Create an off-screen render target of the given size.
    /// Returns `.invalid` if creation fails.
    func createRenderTarget(width: Int, height: Int) -> RenderTargetHandle

    /// Begin redirecting all drawing commands to the given render target.
    func beginRenderTarget(_ handle: RenderTargetHandle)

    /// Stop drawing to the current render target and resume drawing to the screen.
    func endRenderTarget()

    /// Get the texture handle for the render target's color buffer.
    /// This texture can be used with drawSprite to draw the render target's contents.
    func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle

    /// Get the size of a render target.
    func renderTargetSize(_ handle: RenderTargetHandle) -> Size

    /// Destroy a render target and free its GPU resources.
    /// Also invalidates the associated texture handle from `renderTargetTexture`.
    func destroyRenderTarget(_ handle: RenderTargetHandle)

    // MARK: - Blend Mode

    /// Begin drawing with the given blend mode. Affects all subsequent draw calls
    /// until `endBlendMode()` is called. For sprites, prefer setting `Sprite.blendMode`
    /// instead — the renderer handles blend mode changes automatically.
    func beginBlendMode(_ mode: BlendMode)

    /// End the current blend mode and restore the default (alpha blending).
    func endBlendMode()

    // MARK: - Shaders

    /// Load a shader from vertex and fragment source strings.
    /// Pass nil for vertexSource to use the default vertex shader.
    /// Returns `.invalid` if compilation fails.
    func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle

    /// Activate a shader for subsequent draw calls.
    func beginShader(_ handle: ShaderHandle)

    /// Deactivate the current shader and restore default rendering.
    func endShader()

    /// Set a float uniform on a shader.
    func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float)

    /// Set a Vec2 uniform on a shader.
    func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2)

    /// Set a Vec3 uniform on a shader (three floats, typically RGB 0-1).
    func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float)

    /// Set a Vec4 uniform on a shader (four floats, typically RGBA 0-1).
    func setShaderVec4(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float, w: Float)

    /// Set an integer uniform on a shader.
    func setShaderInt(_ handle: ShaderHandle, name: String, value: Int32)

    /// Set a texture sampler uniform on a shader.
    func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle)

    /// Destroy a shader and free GPU resources.
    func destroyShader(_ handle: ShaderHandle)

    // MARK: - Drawing (Polygons)

    /// Draw a filled triangle.
    func drawTriangle(_ v1: Vector2, _ v2: Vector2, _ v3: Vector2, color: Color)

    // MARK: - Screen

    /// The current screen/window size.
    var screenSize: Size { get }

    // MARK: - Screenshots

    /// Save a screenshot of the current framebuffer to a file.
    ///
    /// The file format is determined by the extension (`.png` recommended).
    /// Call after all rendering is complete (e.g. at the end of `render()`).
    func takeScreenshot(path: String)

    /// Capture the current framebuffer as raw pixel data.
    ///
    /// Returns an `ImageData` with RGBA pixels, or `nil` if capture fails.
    /// Call after all rendering is complete (e.g. at the end of `render()`).
    func captureScreen() -> ImageData?
}

// MARK: - Default Render Target Implementations

extension RenderBackend {
    public func createRenderTarget(width: Int, height: Int) -> RenderTargetHandle { .invalid }
    public func beginRenderTarget(_ handle: RenderTargetHandle) {}
    public func endRenderTarget() {}
    public func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle { .invalid }
    public func renderTargetSize(_ handle: RenderTargetHandle) -> Size { .zero }
    public func destroyRenderTarget(_ handle: RenderTargetHandle) {}
}

// MARK: - Default ImageData Texture Implementation

extension RenderBackend {
    public func loadTextureFromImage(_ image: ImageData) -> TextureHandle { .invalid }
}

// MARK: - Default Blend Mode Implementation

extension RenderBackend {
    public func beginBlendMode(_ mode: BlendMode) {}
    public func endBlendMode() {}
}

// MARK: - Default Shader Implementations

extension RenderBackend {
    public func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle { .invalid }
    public func beginShader(_ handle: ShaderHandle) {}
    public func endShader() {}
    public func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float) {}
    public func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2) {}
    public func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float) {}
    public func setShaderVec4(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float, w: Float) {}
    public func setShaderInt(_ handle: ShaderHandle, name: String, value: Int32) {}
    public func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle) {}
    public func destroyShader(_ handle: ShaderHandle) {}
}

// MARK: - Material Support

extension RenderBackend {
    /// Apply all uniforms from a material to the GPU shader.
    ///
    /// Call this before `beginShader` to set uniform values, or between
    /// sprites that share the same shader but need different uniform values.
    ///
    /// ```swift
    /// let material = Material2D(shader: myShader, uniforms: [
    ///     "time": .float(elapsed),
    ///     "flashColor": .color(.white)
    /// ])
    /// renderer.applyMaterial(material)
    /// renderer.beginShader(material.shader)
    /// // draw...
    /// renderer.endShader()
    /// ```
    public func applyMaterial(_ material: Material2D) {
        for (name, value) in material.uniforms {
            switch value {
            case .float(let v):
                setShaderFloat(material.shader, name: name, value: v)
            case .vec2(let v):
                setShaderVec2(material.shader, name: name, value: v)
            case .vec3(let x, let y, let z):
                setShaderVec3(material.shader, name: name, x: x, y: y, z: z)
            case .vec4(let x, let y, let z, let w):
                setShaderVec4(material.shader, name: name, x: x, y: y, z: z, w: w)
            case .int(let v):
                setShaderInt(material.shader, name: name, value: v)
            case .color(let c):
                setShaderVec4(material.shader, name: name,
                    x: Float(c.r) / 255.0, y: Float(c.g) / 255.0,
                    z: Float(c.b) / 255.0, w: Float(c.a) / 255.0)
            case .texture(let t):
                setShaderTexture(material.shader, name: name, texture: t)
            }
        }
    }
}

// MARK: - Default Screenshot Implementations

extension RenderBackend {
    public func takeScreenshot(path: String) {}
    public func captureScreen() -> ImageData? { nil }
}

// MARK: - Default Triangle Implementation

extension RenderBackend {
    public func drawTriangle(_ v1: Vector2, _ v2: Vector2, _ v3: Vector2, color: Color) {}
}

// MARK: - Default Batch Implementation

extension RenderBackend {
    /// Default implementation draws sprites one by one.
    /// Backends can override for optimized batching.
    public func drawSprites(_ sprites: [Sprite]) {
        for sprite in sprites {
            drawSprite(sprite)
        }
    }
}

// MARK: - Throwing Resource Loading

extension RenderBackend {
    /// Load a texture, throwing on failure instead of returning `.invalid`.
    public func loadTextureOrThrow(from path: String) throws -> TextureHandle {
        let handle = loadTexture(from: path)
        guard handle != .invalid else { throw ResourceError.textureLoadFailed(path: path) }
        return handle
    }

    /// Create a texture from image data, throwing on failure.
    public func loadTextureFromImageOrThrow(_ image: ImageData) throws -> TextureHandle {
        let handle = loadTextureFromImage(image)
        guard handle != .invalid else { throw ResourceError.textureFromImageFailed }
        return handle
    }

    /// Load a font, throwing on failure instead of returning `.invalid`.
    public func loadFontOrThrow(from path: String, size: Int) throws -> FontHandle {
        let handle = loadFont(from: path, size: size)
        guard handle != .invalid else { throw ResourceError.fontLoadFailed(path: path) }
        return handle
    }

    /// Compile a shader, throwing on failure instead of returning `.invalid`.
    public func loadShaderOrThrow(vertexSource: String?, fragmentSource: String) throws -> ShaderHandle {
        let handle = loadShader(vertexSource: vertexSource, fragmentSource: fragmentSource)
        guard handle != .invalid else { throw ResourceError.shaderCompilationFailed }
        return handle
    }
}
