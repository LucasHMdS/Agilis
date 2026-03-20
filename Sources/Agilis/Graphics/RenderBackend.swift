/// Protocol for 2D rendering backends.
///
/// Abstracts the rendering API so that test mocks can stand in for the
/// concrete ``Renderer`` without requiring GPU resources.
public protocol RenderBackend: AnyObject, Sendable {

    // MARK: - Window / Frame Lifecycle

    func initialize(config: WindowConfig) throws
    func shutdown()
    func shouldClose() -> Bool
    func beginFrame()
    func endFrame()
    func setBackgroundColor(_ color: Color)

    var screenSize: Size { get }

    // MARK: - Textures

    func loadTexture(from path: String) -> TextureHandle
    func loadTextureFromImage(_ image: ImageData) -> TextureHandle
    func textureSize(_ handle: TextureHandle) -> Size
    func destroyTexture(_ handle: TextureHandle)

    // MARK: - Drawing

    func drawSprite(_ sprite: Sprite)
    func drawSprites(_ sprites: [Sprite])
    func drawRect(_ rect: Rect, color: Color)
    func drawRectOutline(_ rect: Rect, color: Color, thickness: Float)
    func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float)
    func drawCircle(center: Vector2, radius: Float, color: Color)
    func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float)
    func drawTriangle(_ v1: Vector2, _ v2: Vector2, _ v3: Vector2, color: Color)

    // MARK: - Text

    func loadDefaultFont() -> FontHandle
    func loadFont(from path: String, size: Int) -> FontHandle
    func destroyFont(_ handle: FontHandle)
    func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color)
    func measureText(_ text: String, font: FontHandle, size: Float) -> Size

    // MARK: - Clipping

    func beginClip(_ rect: Rect)
    func endClip()

    // MARK: - Camera

    func beginCamera(_ camera: Camera2D)
    func endCamera()

    // MARK: - Blend Modes

    func beginBlendMode(_ mode: BlendMode)
    func endBlendMode()

    // MARK: - Shaders

    func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle
    func beginShader(_ handle: ShaderHandle)
    func endShader()
    func destroyShader(_ handle: ShaderHandle)
    func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float)
    func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2)
    func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float)
    func setShaderVec4(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float, w: Float)
    func setShaderInt(_ handle: ShaderHandle, name: String, value: Int32)
    func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle)

    // MARK: - Render Targets

    func createRenderTarget(width: Int, height: Int) -> RenderTargetHandle
    func beginRenderTarget(_ handle: RenderTargetHandle)
    func endRenderTarget()
    func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle
    func renderTargetSize(_ handle: RenderTargetHandle) -> Size
    func destroyRenderTarget(_ handle: RenderTargetHandle)

    // MARK: - Screenshots

    func takeScreenshot(path: String)
    func captureScreen() -> ImageData?

    // MARK: - Materials

    func applyMaterial(_ material: Material2D)
}

// MARK: - Default Implementations

extension RenderBackend {
    public func drawSprites(_ sprites: [Sprite]) {
        for sprite in sprites { drawSprite(sprite) }
    }
    public func loadTextureFromImage(_: ImageData) -> TextureHandle { .invalid }
    public func beginBlendMode(_: BlendMode) {}
    public func endBlendMode() {}
    public func loadShader(vertexSource _: String?, fragmentSource _: String) -> ShaderHandle { .invalid }
    public func beginShader(_: ShaderHandle) {}
    public func endShader() {}
    public func destroyShader(_: ShaderHandle) {}
    public func setShaderFloat(_: ShaderHandle, name _: String, value _: Float) {}
    public func setShaderVec2(_: ShaderHandle, name _: String, value _: Vector2) {}
    public func setShaderVec3(_: ShaderHandle, name _: String, x _: Float, y _: Float, z _: Float) {}
    public func setShaderVec4(_: ShaderHandle, name _: String, x _: Float, y _: Float, z _: Float, w _: Float) {}
    public func setShaderInt(_: ShaderHandle, name _: String, value _: Int32) {}
    public func setShaderTexture(_: ShaderHandle, name _: String, texture _: TextureHandle) {}
    public func createRenderTarget(width _: Int, height _: Int) -> RenderTargetHandle { .invalid }
    public func beginRenderTarget(_: RenderTargetHandle) {}
    public func endRenderTarget() {}
    public func renderTargetTexture(_: RenderTargetHandle) -> TextureHandle { .invalid }
    public func renderTargetSize(_: RenderTargetHandle) -> Size { .zero }
    public func destroyRenderTarget(_: RenderTargetHandle) {}
    public func drawTriangle(_: Vector2, _: Vector2, _: Vector2, color _: Color) {}
    public func takeScreenshot(path _: String) {}
    public func captureScreen() -> ImageData? { nil }
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
                setShaderVec4(
                    material.shader,
                    name: name,
                    x: Float(c.r) / 255.0,
                    y: Float(c.g) / 255.0,
                    z: Float(c.b) / 255.0,
                    w: Float(c.a) / 255.0
                )

            case .texture(let t):
                setShaderTexture(material.shader, name: name, texture: t)
            }
        }
    }
}

// MARK: - Renderer Conformance

extension Renderer: RenderBackend {}
