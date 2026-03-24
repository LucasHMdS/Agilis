import AngleC
import PlatformC
import StbC
#if canImport(Foundation)
import Foundation
#endif

/// Concrete GLES3 renderer backed by ANGLE (EGL + OpenGL ES 3.0).
///
/// Handles window management via PlatformC, GPU resource lifecycle,
/// 2D sprite batching, shape drawing, text rendering, shaders,
/// render targets, and blend modes.
public final class Renderer: @unchecked Sendable {

    deinit {}

    private var bgColor = Color(r: 40, g: 40, b: 40)
    private var _screenSize: Size = .zero

    /// The platform window handle, available after `initialize(config:)`.
    internal private(set) var window: OpaquePointer?

    // EGL state (void* typedefs → UnsafeMutableRawPointer in Swift)
    private var eglDpy: UnsafeMutableRawPointer?   // EGLDisplay
    private var eglSfc: UnsafeMutableRawPointer?   // EGLSurface
    private var eglCtx: UnsafeMutableRawPointer?   // EGLContext
    private var isHeadless: Bool = false

    // MARK: - Internal GPU Types

    private struct GLTextureInfo {
        let glId: GLuint
        let width: Int
        let height: Int
        let isRenderTarget: Bool
    }

    private struct GLFontInfo {
        let textureGlId: GLuint
        let textureHandle: TextureHandle
        let atlasWidth: Int
        let atlasHeight: Int
        let fontSize: Float
        let ascent: Float  // pixels above baseline at baked size
        let bakedChars: UnsafeMutablePointer<stbtt_bakedchar>
    }

    private struct GLShaderInfo {
        let programId: GLuint
        var uniformCache: [String: GLint]
    }

    private struct GLRenderTargetInfo {
        let fbo: GLuint
        let textureHandle: TextureHandle
        let width: Int
        let height: Int
    }

    // MARK: - Resource Dictionaries

    private var textures: [UInt32: GLTextureInfo] = [:]
    private var nextTextureId: UInt32 = 1
    private var whitePixelTexture: TextureHandle = .invalid

    private var fonts: [UInt32: GLFontInfo] = [:]
    private var nextFontId: UInt32 = 1

    private var shaders: [UInt32: GLShaderInfo] = [:]
    private var nextShaderId: UInt32 = 1
    private var defaultShaderHandle: ShaderHandle = .invalid
    private var activeShaderHandle: ShaderHandle = .invalid

    private var renderTargets: [UInt32: GLRenderTargetInfo] = [:]
    private var nextRenderTargetId: UInt32 = 1
    private var activeRenderTarget: RenderTargetHandle = .invalid
    private var savedViewports: [(x: GLint, y: GLint, w: GLsizei, h: GLsizei)] = []

    // MARK: - Batch Renderer State

    private static let maxQuadsPerBatch = 8_192
    private static let floatsPerVertex = 8  // x, y, u, v, r, g, b, a
    private static let verticesPerQuad = 4
    private static let indicesPerQuad = 6

    private var batchVAO: GLuint = 0
    private var batchVBO: GLuint = 0
    private var batchIBO: GLuint = 0
    private var batchVertices: [Float] = []
    private var batchQuadCount: Int = 0
    private var batchCurrentTexture: GLuint = 0
    private var batchCurrentBlendMode: BlendMode = .alpha

    // MARK: - MVP Matrix

    private var projectionMatrix: [Float] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    private var mvpStack: [[Float]] = []
    private var mvpDirty: Bool = true

    // MARK: - State Stacks

    private var blendModeStack: [BlendMode] = []
    private var clipStack: [Rect] = []
    private var nextTextureUnit: Int32 = 1

    // MARK: - Default Shader Sources

    private static let defaultVertexShader = """
    #version 300 es
    precision highp float;

    layout(location = 0) in vec2 vertexPosition;
    layout(location = 1) in vec2 vertexTexCoord;
    layout(location = 2) in vec4 vertexColor;

    uniform mat4 mvp;

    out vec2 fragTexCoord;
    out vec4 fragColor;

    void main() {
        fragTexCoord = vertexTexCoord;
        fragColor = vertexColor;
        gl_Position = mvp * vec4(vertexPosition, 0.0, 1.0);
    }
    """

    private static let defaultFragmentShader = """
    #version 300 es
    precision mediump float;

    in vec2 fragTexCoord;
    in vec4 fragColor;

    uniform sampler2D texture0;

    out vec4 finalColor;

    void main() {
        finalColor = texture(texture0, fragTexCoord) * fragColor;
    }
    """

    // MARK: - Window / Frame

    public func initialize(config: WindowConfig) throws {
        // Create the platform window.
        var platformCfg = PlatformWindowConfig()
        let windowPtr: OpaquePointer? = config.title.withCString { titlePtr in
            platformCfg.title = titlePtr
            platformCfg.width = Int32(config.width)
            platformCfg.height = Int32(config.height)
            platformCfg.target_fps = Int32(config.targetFPS)
            platformCfg.resizable = config.resizable
            platformCfg.vsync = config.vsync
            return platform_create_window(&platformCfg)
        }

        guard let windowPtr else {
            throw RendererInitError.windowCreationFailed
        }
        self.window = windowPtr

        // Get native handles for EGL
        let nativeDisplay = platform_native_display(windowPtr)
        let nativeWindow = platform_native_window(windowPtr)

        // --- EGL initialization ---

        guard let display = angle_get_display(nativeDisplay) else {
            throw RendererInitError.eglFailed("eglGetDisplay returned EGL_NO_DISPLAY")
        }
        self.eglDpy = display

        var major: EGLint = 0
        var minor: EGLint = 0
        guard eglInitialize(display, &major, &minor) != 0 else {
            throw RendererInitError.eglFailed("eglInitialize failed")
        }

        // Choose an RGBA8 + depth24 config with ES 3.0 support
        var attribs: [EGLint] = [
            EGL_RED_SIZE, 8,
            EGL_GREEN_SIZE, 8,
            EGL_BLUE_SIZE, 8,
            EGL_ALPHA_SIZE, 8,
            EGL_DEPTH_SIZE, 24,
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_NONE
        ]

        var eglCfg: UnsafeMutableRawPointer?   // EGLConfig
        var numConfigs: EGLint = 0
        guard eglChooseConfig(display, &attribs, &eglCfg, 1, &numConfigs) != 0,
              numConfigs > 0,
              let chosenConfig = eglCfg else {
            throw RendererInitError.eglFailed("eglChooseConfig failed (no suitable config)")
        }

        // Create the window surface
        guard let surface = angle_create_window_surface(display, chosenConfig, nativeWindow, nil) else {
            throw RendererInitError.eglFailed("eglCreateWindowSurface failed")
        }
        self.eglSfc = surface

        // Create the ES 3.0 context
        var ctxAttribs: [EGLint] = [
            EGL_CONTEXT_MAJOR_VERSION, 3,
            EGL_CONTEXT_MINOR_VERSION, 0,
            EGL_NONE
        ]
        guard let context = eglCreateContext(display, chosenConfig, nil, &ctxAttribs) else {
            throw RendererInitError.eglFailed("eglCreateContext failed")
        }
        self.eglCtx = context

        // Make current
        guard eglMakeCurrent(display, surface, surface, context) != 0 else {
            throw RendererInitError.eglFailed("eglMakeCurrent failed")
        }

        // VSync
        eglSwapInterval(display, config.vsync ? 1 : 0)

        // Store screen size — use config dimensions when specified,
        // fall back to actual window dimensions (iOS passes 0×0 in config)
        let initWidth: Int
        let initHeight: Int
        if config.width > 0 && config.height > 0 {
            initWidth = config.width
            initHeight = config.height
        } else if let w = window {
            initWidth = Int(platform_window_width(w))
            initHeight = Int(platform_window_height(w))
        } else {
            initWidth = config.width
            initHeight = config.height
        }
        _screenSize = Size(width: Float(initWidth), height: Float(initHeight))

        // Initial GL state
        glViewport(0, 0, GLsizei(initWidth), GLsizei(initHeight))
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        applyClearColor()

        // --- GPU resource initialization ---
        try initGPU()
    }

    /// Initializes the renderer with an off-screen EGL pbuffer surface.
    /// No platform window is created — suitable for headless snapshot testing.
    public func initializeHeadless(width: Int, height: Int) throws {
        isHeadless = true

        // EGL initialization (no native display needed for pbuffer)
        guard let display = angle_get_display(nil) else {
            throw RendererInitError.eglFailed("eglGetDisplay returned EGL_NO_DISPLAY (headless)")
        }
        self.eglDpy = display

        var major: EGLint = 0
        var minor: EGLint = 0
        guard eglInitialize(display, &major, &minor) != 0 else {
            throw RendererInitError.eglFailed("eglInitialize failed (headless)")
        }

        // Choose config with EGL_PBUFFER_BIT surface type
        var attribs: [EGLint] = [
            EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
            EGL_RED_SIZE, 8,
            EGL_GREEN_SIZE, 8,
            EGL_BLUE_SIZE, 8,
            EGL_ALPHA_SIZE, 8,
            EGL_DEPTH_SIZE, 24,
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
            EGL_NONE
        ]

        var eglCfg: UnsafeMutableRawPointer?
        var numConfigs: EGLint = 0
        guard eglChooseConfig(display, &attribs, &eglCfg, 1, &numConfigs) != 0,
              numConfigs > 0,
              let chosenConfig = eglCfg else {
            throw RendererInitError.eglFailed("eglChooseConfig failed (headless)")
        }

        // Create pbuffer surface (no window needed)
        guard let surface = angle_create_pbuffer_surface(
            display, chosenConfig, EGLint(width), EGLint(height)
        ) else {
            throw RendererInitError.eglFailed("eglCreatePbufferSurface failed")
        }
        self.eglSfc = surface

        // Create ES 3.0 context
        var ctxAttribs: [EGLint] = [
            EGL_CONTEXT_MAJOR_VERSION, 3,
            EGL_CONTEXT_MINOR_VERSION, 0,
            EGL_NONE
        ]
        guard let context = eglCreateContext(display, chosenConfig, nil, &ctxAttribs) else {
            throw RendererInitError.eglFailed("eglCreateContext failed (headless)")
        }
        self.eglCtx = context

        guard eglMakeCurrent(display, surface, surface, context) != 0 else {
            throw RendererInitError.eglFailed("eglMakeCurrent failed (headless)")
        }

        _screenSize = Size(width: Float(width), height: Float(height))

        glViewport(0, 0, GLsizei(width), GLsizei(height))
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        applyClearColor()

        try initGPU()
    }

    public func shutdown() {
        shutdownGPU()

        if let display = eglDpy {
            eglMakeCurrent(display, nil, nil, nil)
            if let sfc = eglSfc { eglDestroySurface(display, sfc) }
            if let ctx = eglCtx { eglDestroyContext(display, ctx) }
            eglTerminate(display)
        }
        eglSfc = nil
        eglCtx = nil
        eglDpy = nil

        if !isHeadless, let window {
            platform_destroy_window(window)
        }
        window = nil
    }

    public func shouldClose() -> Bool {
        guard let window else { return true }
        return platform_should_close(window)
    }

    public func beginFrame() {
        if !isHeadless {
            guard let window else { return }

            // Poll platform events (keyboard, mouse, resize, close)
            platform_poll_events(window)

            // Handle resize
            if platform_window_resized(window) {
                let w = platform_window_width(window)
                let h = platform_window_height(window)
                _screenSize = Size(width: Float(w), height: Float(h))
                glViewport(0, 0, GLsizei(w), GLsizei(h))
                projectionMatrix = Self.ortho4x4(
                    left: 0, right: Float(w), bottom: Float(h), top: 0, near: -1, far: 1
                )
                mvpDirty = true
            }
        }

        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }

    public func endFrame() {
        flushBatch()
        if isHeadless {
            glFinish()
        } else {
            guard let display = eglDpy, let surface = eglSfc else { return }
            eglSwapBuffers(display, surface)
        }
    }

    public func setBackgroundColor(_ color: Color) {
        bgColor = color
        if eglDpy != nil {
            applyClearColor()
        }
    }

    public var screenSize: Size { _screenSize }

    // MARK: - GPU Init / Shutdown

    private func initGPU() throws {
        // 1. Compile default shader
        guard let programId = compileAndLinkProgram(
            vertexSource: Self.defaultVertexShader,
            fragmentSource: Self.defaultFragmentShader
        ) else {
            throw RendererInitError.eglFailed("Failed to compile default shader")
        }
        let shaderId = nextShaderId
        nextShaderId += 1
        shaders[shaderId] = GLShaderInfo(programId: programId, uniformCache: [:])
        defaultShaderHandle = ShaderHandle(id: shaderId)
        activeShaderHandle = defaultShaderHandle
        glUseProgram(programId)

        // 2. Create 1x1 white pixel texture
        whitePixelTexture = createWhitePixelTexture()

        // 3. Create batch renderer VAO/VBO/IBO
        initBatchRenderer()

        // 4. Set initial orthographic projection
        projectionMatrix = Self.ortho4x4(
            left: 0,
            right: _screenSize.width,
            bottom: _screenSize.height,
            top: 0,
            near: -1,
            far: 1
        )
        mvpDirty = true
        uploadMVP()

        // 5. Set texture0 uniform to texture unit 0
        let tex0Loc = getUniformLocation(shaderId: shaderId, name: "texture0")
        if tex0Loc >= 0 {
            glUniform1i(tex0Loc, 0)
        }
    }

    private func shutdownGPU() {
        flushBatch()

        // Destroy render targets
        for (_, rt) in renderTargets {
            var fbo = rt.fbo
            glDeleteFramebuffers(1, &fbo)
        }
        renderTargets.removeAll()

        // Destroy shaders
        for (_, shader) in shaders {
            glDeleteProgram(shader.programId)
        }
        shaders.removeAll()
        defaultShaderHandle = .invalid
        activeShaderHandle = .invalid

        // Destroy fonts
        for (_, font) in fonts {
            font.bakedChars.deallocate()
        }
        fonts.removeAll()

        // Destroy textures
        for (_, tex) in textures {
            var glId = tex.glId
            glDeleteTextures(1, &glId)
        }
        textures.removeAll()
        whitePixelTexture = .invalid

        // Destroy batch renderer objects
        if batchVAO != 0 { glDeleteVertexArrays(1, &batchVAO) }
        if batchVBO != 0 { glDeleteBuffers(1, &batchVBO) }
        if batchIBO != 0 { glDeleteBuffers(1, &batchIBO) }
        batchVAO = 0
        batchVBO = 0
        batchIBO = 0
        batchVertices.removeAll()
        batchQuadCount = 0
    }

    // MARK: - White Pixel Texture

    private func createWhitePixelTexture() -> TextureHandle {
        var glId: GLuint = 0
        glGenTextures(1, &glId)
        glBindTexture(GLenum(GL_TEXTURE_2D), glId)
        var pixel: [UInt8] = [255, 255, 255, 255]
        glTexImage2D(
            GLenum(GL_TEXTURE_2D),
            0,
            GL_RGBA,
            1,
            1,
            0,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            &pixel
        )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)

        let id = nextTextureId
        nextTextureId += 1
        textures[id] = GLTextureInfo(
            glId: glId,
            width: 1,
            height: 1,
            isRenderTarget: false
        )
        return TextureHandle(id: id)
    }

    // MARK: - Batch Renderer Init

    private func initBatchRenderer() {
        let maxVerts = Self.maxQuadsPerBatch * Self.verticesPerQuad
        let maxIndices = Self.maxQuadsPerBatch * Self.indicesPerQuad

        batchVertices = [Float](repeating: 0, count: maxVerts * Self.floatsPerVertex)

        glGenVertexArrays(1, &batchVAO)
        glBindVertexArray(batchVAO)

        // VBO (dynamic)
        glGenBuffers(1, &batchVBO)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), batchVBO)
        glBufferData(
            GLenum(GL_ARRAY_BUFFER),
            GLsizeiptr(maxVerts * Self.floatsPerVertex * MemoryLayout<Float>.size),
            nil,
            GLenum(GL_DYNAMIC_DRAW)
        )

        // IBO (static quad indices)
        var indices = [UInt16](repeating: 0, count: maxIndices)
        for i in 0..<Self.maxQuadsPerBatch {
            let vi = UInt16(i * 4)
            let ii = i * 6
            indices[ii + 0] = vi + 0
            indices[ii + 1] = vi + 1
            indices[ii + 2] = vi + 2
            indices[ii + 3] = vi + 2
            indices[ii + 4] = vi + 3
            indices[ii + 5] = vi + 0
        }
        glGenBuffers(1, &batchIBO)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), batchIBO)
        indices.withUnsafeBufferPointer { ptr in
            glBufferData(
                GLenum(GL_ELEMENT_ARRAY_BUFFER),
                GLsizeiptr(maxIndices * MemoryLayout<UInt16>.size),
                ptr.baseAddress,
                GLenum(GL_STATIC_DRAW)
            )
        }

        let stride = GLsizei(Self.floatsPerVertex * MemoryLayout<Float>.size)

        // Position: location 0, 2 floats, offset 0
        glEnableVertexAttribArray(0)
        glVertexAttribPointer(
            0,
            2,
            GLenum(GL_FLOAT),
            GLboolean(GL_FALSE),
            stride,
            UnsafeRawPointer(bitPattern: 0)
        )

        // TexCoord: location 1, 2 floats, offset 8
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(
            1,
            2,
            GLenum(GL_FLOAT),
            GLboolean(GL_FALSE),
            stride,
            UnsafeRawPointer(bitPattern: 2 * MemoryLayout<Float>.size)
        )

        // Color: location 2, 4 floats, offset 16
        glEnableVertexAttribArray(2)
        glVertexAttribPointer(
            2,
            4,
            GLenum(GL_FLOAT),
            GLboolean(GL_FALSE),
            stride,
            UnsafeRawPointer(bitPattern: 4 * MemoryLayout<Float>.size)
        )

        glBindVertexArray(0)
    }

    // MARK: - Batch Renderer Core

    // swiftlint:disable:next function_parameter_count
    private func addQuadToBatch(
        glTexId: GLuint,
        x0: Float, y0: Float, u0: Float, v0: Float,
        x1: Float, y1: Float, u1: Float, v1: Float,
        x2: Float, y2: Float, u2: Float, v2: Float,
        x3: Float, y3: Float, u3: Float, v3: Float,
        r: Float, g: Float, b: Float, a: Float,
        blendMode: BlendMode
    ) {
        if glTexId != batchCurrentTexture || blendMode != batchCurrentBlendMode ||
           batchQuadCount >= Self.maxQuadsPerBatch {
            flushBatch()
        }
        batchCurrentTexture = glTexId
        batchCurrentBlendMode = blendMode

        let offset = batchQuadCount * Self.verticesPerQuad * Self.floatsPerVertex

        batchVertices[offset + 0] = x0
        batchVertices[offset + 1] = y0
        batchVertices[offset + 2] = u0
        batchVertices[offset + 3] = v0
        batchVertices[offset + 4] = r
        batchVertices[offset + 5] = g
        batchVertices[offset + 6] = b
        batchVertices[offset + 7] = a

        batchVertices[offset + 8] = x1
        batchVertices[offset + 9] = y1
        batchVertices[offset + 10] = u1
        batchVertices[offset + 11] = v1
        batchVertices[offset + 12] = r
        batchVertices[offset + 13] = g
        batchVertices[offset + 14] = b
        batchVertices[offset + 15] = a

        batchVertices[offset + 16] = x2
        batchVertices[offset + 17] = y2
        batchVertices[offset + 18] = u2
        batchVertices[offset + 19] = v2
        batchVertices[offset + 20] = r
        batchVertices[offset + 21] = g
        batchVertices[offset + 22] = b
        batchVertices[offset + 23] = a

        batchVertices[offset + 24] = x3
        batchVertices[offset + 25] = y3
        batchVertices[offset + 26] = u3
        batchVertices[offset + 27] = v3
        batchVertices[offset + 28] = r
        batchVertices[offset + 29] = g
        batchVertices[offset + 30] = b
        batchVertices[offset + 31] = a

        batchQuadCount += 1
    }

    private func flushBatch() {
        guard batchQuadCount > 0 else { return }

        applyGLBlendFunc(batchCurrentBlendMode)

        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), batchCurrentTexture)

        if mvpDirty { uploadMVP() }

        glBindVertexArray(batchVAO)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), batchVBO)

        let byteCount = batchQuadCount * Self.verticesPerQuad * Self.floatsPerVertex * MemoryLayout<Float>.size
        batchVertices.withUnsafeBufferPointer { ptr in
            glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, GLsizeiptr(byteCount), ptr.baseAddress)
        }

        glDrawElements(
            GLenum(GL_TRIANGLES),
            GLsizei(batchQuadCount * Self.indicesPerQuad),
            GLenum(GL_UNSIGNED_SHORT),
            nil
        )

        glBindVertexArray(0)
        batchQuadCount = 0
    }

    // MARK: - Blend Mode Helpers

    private func applyGLBlendFunc(_ mode: BlendMode) {
        switch mode {
        case .alpha:
            glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

        case .additive:
            glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))

        case .multiplied:
            glBlendFunc(GLenum(GL_DST_COLOR), GLenum(GL_ONE_MINUS_SRC_ALPHA))

        case .premultiplied:
            glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        }
    }

    // MARK: - MVP Helpers

    private func uploadMVP() {
        let loc = getUniformLocation(shaderId: activeShaderHandle.id, name: "mvp")
        if loc >= 0 {
            projectionMatrix.withUnsafeBufferPointer { ptr in
                glUniformMatrix4fv(loc, 1, GLboolean(GL_FALSE), ptr.baseAddress)
            }
        }
        mvpDirty = false
    }

    private func getUniformLocation(shaderId: UInt32, name: String) -> GLint {
        if let cached = shaders[shaderId]?.uniformCache[name] {
            return cached
        }
        guard let shaderInfo = shaders[shaderId] else { return -1 }
        let loc = name.withCString { cstr in
            glGetUniformLocation(shaderInfo.programId, cstr)
        }
        shaders[shaderId]?.uniformCache[name] = loc
        return loc
    }

    // MARK: - Matrix Helpers

    private static func ortho4x4(
        left: Float, right: Float, bottom: Float, top: Float,
        near: Float, far: Float
    ) -> [Float] {
        let rl = right - left
        let tb = top - bottom
        let fn = far - near
        return [
            2.0 / rl, 0, 0, 0,
            0, 2.0 / tb, 0, 0,
            0, 0, -2.0 / fn, 0,
            -(right + left)/rl, -(top + bottom)/tb, -(far + near)/fn, 1
        ]
    }

    private static func mat4x4Identity() -> [Float] {
        [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    }

    private static func mat4x4Multiply(_ a: [Float], _ b: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: 16)
        for col in 0..<4 {
            for row in 0..<4 {
                var sum: Float = 0
                for k in 0..<4 {
                    sum += a[k * 4 + row] * b[col * 4 + k]
                }
                result[col * 4 + row] = sum
            }
        }
        return result
    }

    private static func mat4x4Translate(_ x: Float, _ y: Float) -> [Float] {
        [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, 0, 1]
    }

    private static func mat4x4Scale(_ sx: Float, _ sy: Float) -> [Float] {
        [sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    }

    private static func mat4x4Rotate(_ angle: Float) -> [Float] {
        let c = cosf(angle)
        let s = sinf(angle)
        return [c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    }

    // MARK: - Shader Compilation

    private func compileAndLinkProgram(vertexSource: String, fragmentSource: String) -> GLuint? {
        guard let vertShader = compileShader(type: GLenum(GL_VERTEX_SHADER), source: vertexSource) else {
            return nil
        }
        guard let fragShader = compileShader(type: GLenum(GL_FRAGMENT_SHADER), source: fragmentSource) else {
            glDeleteShader(vertShader)
            return nil
        }

        let program = glCreateProgram()
        glAttachShader(program, vertShader)
        glAttachShader(program, fragShader)
        glLinkProgram(program)

        glDeleteShader(vertShader)
        glDeleteShader(fragShader)

        var linkStatus: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &linkStatus)
        if linkStatus == 0 {
            var logLength: GLint = 0
            glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            if logLength > 0 {
                var logBuffer = [CChar](repeating: 0, count: Int(logLength))
                glGetProgramInfoLog(program, logLength, nil, &logBuffer)
                let message = logBuffer.withUnsafeBufferPointer { buf in
                    guard let base = buf.baseAddress else { return "" }
                    return String(cString: base)
                }
                Log.error("Renderer", "Shader link failed: \(message)")
            }
            glDeleteProgram(program)
            return nil
        }
        return program
    }

    private func compileShader(type: GLenum, source: String) -> GLuint? {
        let shader = glCreateShader(type)
        source.withCString { cstr in
            var ptr: UnsafePointer<GLchar>? = UnsafePointer(cstr)
            glShaderSource(shader, 1, &ptr, nil)
        }
        glCompileShader(shader)

        var compileStatus: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compileStatus)
        if compileStatus == 0 {
            var logLength: GLint = 0
            glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            if logLength > 0 {
                var logBuffer = [CChar](repeating: 0, count: Int(logLength))
                glGetShaderInfoLog(shader, logLength, nil, &logBuffer)
                let message = logBuffer.withUnsafeBufferPointer { buf in
                    guard let base = buf.baseAddress else { return "" }
                    return String(cString: base)
                }
                let typeStr = type == GLenum(GL_VERTEX_SHADER) ? "vertex" : "fragment"
                Log.error("Renderer", "Shader compile failed (\(typeStr)): \(message)")
            }
            glDeleteShader(shader)
            return nil
        }
        return shader
    }

    // MARK: - Clear Color

    private func applyClearColor() {
        glClearColor(
            GLfloat(bgColor.r) / 255.0,
            GLfloat(bgColor.g) / 255.0,
            GLfloat(bgColor.b) / 255.0,
            GLfloat(bgColor.a) / 255.0
        )
    }

    // MARK: - Textures

    public func loadTexture(from path: String) -> TextureHandle {
        var w: Int32 = 0
        var h: Int32 = 0
        var channels: Int32 = 0
        guard let pixels = stbi_load(path, &w, &h, &channels, 4) else {
            return .invalid
        }
        defer { stbi_image_free(pixels) }
        return uploadTexture(pixels: pixels, width: Int(w), height: Int(h))
    }

    public func loadTextureFromImage(_ image: ImageData) -> TextureHandle {
        guard !image.pixels.isEmpty else { return .invalid }
        return image.pixels.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return .invalid }
            return uploadTexture(pixels: base, width: image.width, height: image.height)
        }
    }

    private func uploadTexture(pixels: UnsafePointer<UInt8>, width: Int, height: Int) -> TextureHandle {
        var glId: GLuint = 0
        glGenTextures(1, &glId)
        glBindTexture(GLenum(GL_TEXTURE_2D), glId)
        glTexImage2D(
            GLenum(GL_TEXTURE_2D),
            0,
            GL_RGBA,
            GLsizei(width),
            GLsizei(height),
            0,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            pixels
        )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)

        let id = nextTextureId
        nextTextureId += 1
        textures[id] = GLTextureInfo(
            glId: glId,
            width: width,
            height: height,
            isRenderTarget: false
        )
        return TextureHandle(id: id)
    }

    public func textureSize(_ handle: TextureHandle) -> Size {
        guard let info = textures[handle.id] else { return .zero }
        return Size(width: Float(info.width), height: Float(info.height))
    }

    public func destroyTexture(_ handle: TextureHandle) {
        guard let info = textures[handle.id] else { return }
        if info.isRenderTarget { return }
        var glId = info.glId
        glDeleteTextures(1, &glId)
        textures.removeValue(forKey: handle.id)
    }

    // MARK: - Drawing

    public func drawSprite(_ sprite: Sprite) {
        guard let texInfo = textures[sprite.texture.id] else { return }

        let texW = Float(texInfo.width)
        let texH = Float(texInfo.height)

        var srcRect = sprite.sourceRect
        if srcRect.width <= 0 || srcRect.height <= 0 {
            srcRect = Rect(x: 0, y: 0, width: texW, height: texH)
        }

        var u0 = srcRect.x / texW
        var v0 = srcRect.y / texH
        var u1 = (srcRect.x + srcRect.width) / texW
        var v1 = (srcRect.y + srcRect.height) / texH

        if sprite.flipX { swap(&u0, &u1) }
        if sprite.flipY { swap(&v0, &v1) }

        let dw = srcRect.width * sprite.scale.x
        let dh = srcRect.height * sprite.scale.y
        let ox = sprite.origin.x * sprite.scale.x
        let oy = sprite.origin.y * sprite.scale.y

        var cx0 = -ox, cy0 = -oy
        var cx1 = dw - ox, cy1 = -oy
        var cx2 = dw - ox, cy2 = dh - oy
        var cx3 = -ox, cy3 = dh - oy

        if sprite.rotation != 0 {
            let c = cosf(sprite.rotation)
            let s = sinf(sprite.rotation)
            let rx0 = cx0 * c - cy0 * s, ry0 = cx0 * s + cy0 * c
            let rx1 = cx1 * c - cy1 * s, ry1 = cx1 * s + cy1 * c
            let rx2 = cx2 * c - cy2 * s, ry2 = cx2 * s + cy2 * c
            let rx3 = cx3 * c - cy3 * s, ry3 = cx3 * s + cy3 * c
            cx0 = rx0; cy0 = ry0; cx1 = rx1; cy1 = ry1
            cx2 = rx2; cy2 = ry2; cx3 = rx3; cy3 = ry3
        }

        let px = sprite.position.x
        let py = sprite.position.y
        cx0 += px; cy0 += py; cx1 += px; cy1 += py
        cx2 += px; cy2 += py; cx3 += px; cy3 += py

        let r = Float(sprite.tint.r) / 255.0
        let g = Float(sprite.tint.g) / 255.0
        let b = Float(sprite.tint.b) / 255.0
        let a = Float(sprite.tint.a) / 255.0

        let effectiveBlend = sprite.material?.blendMode ?? sprite.blendMode

        if let material = sprite.material, material.shader != .invalid {
            flushBatch()
            if let matShader = shaders[material.shader.id] {
                glUseProgram(matShader.programId)
                activeShaderHandle = material.shader
                mvpDirty = true
                uploadMVP()
                nextTextureUnit = 1

                let tex0Loc = getUniformLocation(shaderId: material.shader.id, name: "texture0")
                if tex0Loc >= 0 {
                    glActiveTexture(GLenum(GL_TEXTURE0))
                    glBindTexture(GLenum(GL_TEXTURE_2D), texInfo.glId)
                    glUniform1i(tex0Loc, 0)
                }
                applyMaterial(material)
            }

            addQuadToBatch(
                glTexId: texInfo.glId,
                x0: cx0,
                y0: cy0,
                u0: u0,
                v0: v0,
                x1: cx1,
                y1: cy1,
                u1: u1,
                v1: v0,
                x2: cx2,
                y2: cy2,
                u2: u1,
                v2: v1,
                x3: cx3,
                y3: cy3,
                u3: u0,
                v3: v1,
                r: r,
                g: g,
                b: b,
                a: a,
                blendMode: effectiveBlend
            )
            flushBatch()

            if let defShader = shaders[defaultShaderHandle.id] {
                glUseProgram(defShader.programId)
                activeShaderHandle = defaultShaderHandle
                mvpDirty = true
                nextTextureUnit = 1
            }
        } else {
            addQuadToBatch(
                glTexId: texInfo.glId,
                x0: cx0,
                y0: cy0,
                u0: u0,
                v0: v0,
                x1: cx1,
                y1: cy1,
                u1: u1,
                v1: v0,
                x2: cx2,
                y2: cy2,
                u2: u1,
                v2: v1,
                x3: cx3,
                y3: cy3,
                u3: u0,
                v3: v1,
                r: r,
                g: g,
                b: b,
                a: a,
                blendMode: effectiveBlend
            )
        }
    }

    public func drawSprites(_ sprites: [Sprite]) {
        for sprite in sprites {
            drawSprite(sprite)
        }
    }

    public func drawRect(_ rect: Rect, color: Color) {
        guard let wt = textures[whitePixelTexture.id] else { return }
        let r = Float(color.r) / 255.0
        let g = Float(color.g) / 255.0
        let b = Float(color.b) / 255.0
        let a = Float(color.a) / 255.0

        addQuadToBatch(
            glTexId: wt.glId,
            x0: rect.x,
            y0: rect.y,
            u0: 0,
            v0: 0,
            x1: rect.x + rect.width,
            y1: rect.y,
            u1: 1,
            v1: 0,
            x2: rect.x + rect.width,
            y2: rect.y + rect.height,
            u2: 1,
            v2: 1,
            x3: rect.x,
            y3: rect.y + rect.height,
            u3: 0,
            v3: 1,
            r: r,
            g: g,
            b: b,
            a: a,
            blendMode: batchCurrentBlendMode
        )
    }

    public func drawRectOutline(_ rect: Rect, color: Color, thickness: Float) {
        let t = thickness
        drawRect(Rect(x: rect.x, y: rect.y, width: rect.width, height: t), color: color)
        drawRect(Rect(x: rect.x, y: rect.y + rect.height - t, width: rect.width, height: t), color: color)
        drawRect(Rect(x: rect.x, y: rect.y + t, width: t, height: rect.height - 2 * t), color: color)
        drawRect(Rect(x: rect.x + rect.width - t, y: rect.y + t, width: t, height: rect.height - 2 * t), color: color)
    }

    public func drawLine(from start: Vector2, to end: Vector2, color: Color, thickness: Float) {
        guard let wt = textures[whitePixelTexture.id] else { return }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard len > 0 else { return }

        let nx = -dy / len * thickness * 0.5
        let ny = dx / len * thickness * 0.5

        let r = Float(color.r) / 255.0
        let g = Float(color.g) / 255.0
        let b = Float(color.b) / 255.0
        let a = Float(color.a) / 255.0

        addQuadToBatch(
            glTexId: wt.glId,
            x0: start.x + nx,
            y0: start.y + ny,
            u0: 0,
            v0: 0,
            x1: end.x + nx,
            y1: end.y + ny,
            u1: 1,
            v1: 0,
            x2: end.x - nx,
            y2: end.y - ny,
            u2: 1,
            v2: 1,
            x3: start.x - nx,
            y3: start.y - ny,
            u3: 0,
            v3: 1,
            r: r,
            g: g,
            b: b,
            a: a,
            blendMode: batchCurrentBlendMode
        )
    }

    public func drawCircle(center: Vector2, radius: Float, color: Color) {
        guard let wt = textures[whitePixelTexture.id] else { return }
        let segments = 32
        let r = Float(color.r) / 255.0
        let g = Float(color.g) / 255.0
        let b = Float(color.b) / 255.0
        let a = Float(color.a) / 255.0
        let angleStep = Float.pi * 2.0 / Float(segments)

        for i in 0..<segments {
            let a1 = Float(i) * angleStep
            let a2 = Float(i + 1) * angleStep
            let px1 = center.x + cosf(a1) * radius
            let py1 = center.y + sinf(a1) * radius
            let px2 = center.x + cosf(a2) * radius
            let py2 = center.y + sinf(a2) * radius

            addQuadToBatch(
                glTexId: wt.glId,
                x0: center.x,
                y0: center.y,
                u0: 0,
                v0: 0,
                x1: px1,
                y1: py1,
                u1: 0,
                v1: 0,
                x2: px2,
                y2: py2,
                u2: 0,
                v2: 0,
                x3: px2,
                y3: py2,
                u3: 0,
                v3: 0,
                r: r,
                g: g,
                b: b,
                a: a,
                blendMode: batchCurrentBlendMode
            )
        }
    }

    public func drawCircleOutline(center: Vector2, radius: Float, color: Color, thickness: Float) {
        let segments = 32
        let angleStep = Float.pi * 2.0 / Float(segments)
        for i in 0..<segments {
            let a1 = Float(i) * angleStep
            let a2 = Float(i + 1) * angleStep
            drawLine(
                from: Vector2(
                    x: center.x + cosf(a1) * radius,
                    y: center.y + sinf(a1) * radius
                ),
                to: Vector2(
                    x: center.x + cosf(a2) * radius,
                    y: center.y + sinf(a2) * radius
                ),
                color: color,
                thickness: thickness
            )
        }
    }

    public func drawTriangle(_ v1: Vector2, _ v2: Vector2, _ v3: Vector2, color: Color) {
        guard let wt = textures[whitePixelTexture.id] else { return }
        let r = Float(color.r) / 255.0
        let g = Float(color.g) / 255.0
        let b = Float(color.b) / 255.0
        let a = Float(color.a) / 255.0

        addQuadToBatch(
            glTexId: wt.glId,
            x0: v1.x,
            y0: v1.y,
            u0: 0,
            v0: 0,
            x1: v2.x,
            y1: v2.y,
            u1: 0,
            v1: 0,
            x2: v3.x,
            y2: v3.y,
            u2: 0,
            v2: 0,
            x3: v3.x,
            y3: v3.y,
            u3: 0,
            v3: 0,
            r: r,
            g: g,
            b: b,
            a: a,
            blendMode: batchCurrentBlendMode
        )
    }

    // MARK: - Fonts & Text

    public func loadDefaultFont() -> FontHandle {
        loadFontFromBytes(DefaultFontData.ttfBytes, pixelSize: 32.0)
    }

    public func loadFont(from path: String, size: Int) -> FontHandle {
        #if canImport(Foundation)
        guard let url = URL(string: "file://\(path)"),
              let data = try? Data(contentsOf: url) else {
            return .invalid
        }
        return data.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return FontHandle.invalid }
            let bytes = [UInt8](UnsafeBufferPointer(
                start: base.assumingMemoryBound(to: UInt8.self),
                count: rawBuf.count
            ))
            return loadFontFromBytes(bytes, pixelSize: Float(size))
        }
        #else
        guard let fp = fopen(path, "rb") else { return .invalid }
        fseek(fp, 0, SEEK_END)
        let fileSize = ftell(fp)
        fseek(fp, 0, SEEK_SET)
        guard fileSize > 0 else { fclose(fp); return .invalid }
        var bytes = [UInt8](repeating: 0, count: fileSize)
        fread(&bytes, 1, fileSize, fp)
        fclose(fp)
        return loadFontFromBytes(bytes, pixelSize: Float(size))
        #endif
    }

    private func loadFontFromBytes(_ bytes: [UInt8], pixelSize: Float) -> FontHandle {
        let numChars: Int32 = 95
        let atlasW: Int32 = 512
        let atlasH: Int32 = 512

        // Get font vertical metrics for ascent offset
        var fontAscent: Float = pixelSize
        bytes.withUnsafeBufferPointer { buf in
            var fontInfo = stbtt_fontinfo()
            if stbtt_InitFont(&fontInfo, buf.baseAddress, 0) != 0 {
                var ascent: Int32 = 0
                stbtt_GetFontVMetrics(&fontInfo, &ascent, nil, nil)
                let scale = stbtt_ScaleForPixelHeight(&fontInfo, pixelSize)
                fontAscent = Float(ascent) * scale
            }
        }

        let bakedChars = UnsafeMutablePointer<stbtt_bakedchar>.allocate(capacity: Int(numChars))
        bakedChars.initialize(repeating: stbtt_bakedchar(), count: Int(numChars))
        var bitmap = [UInt8](repeating: 0, count: Int(atlasW * atlasH))

        _ = bytes.withUnsafeBufferPointer { buf in
            stbtt_BakeFontBitmap(
                buf.baseAddress,
                0,
                pixelSize,
                &bitmap,
                atlasW,
                atlasH,
                32,
                numChars,
                bakedChars
            )
        }

        // Convert alpha bitmap to RGBA
        var rgba = [UInt8](repeating: 0, count: Int(atlasW * atlasH) * 4)
        for i in 0..<Int(atlasW * atlasH) {
            rgba[i * 4 + 0] = 255
            rgba[i * 4 + 1] = 255
            rgba[i * 4 + 2] = 255
            rgba[i * 4 + 3] = bitmap[i]
        }

        var glId: GLuint = 0
        glGenTextures(1, &glId)
        glBindTexture(GLenum(GL_TEXTURE_2D), glId)
        rgba.withUnsafeBufferPointer { ptr in
            glTexImage2D(
                GLenum(GL_TEXTURE_2D),
                0,
                GL_RGBA,
                GLsizei(atlasW),
                GLsizei(atlasH),
                0,
                GLenum(GL_RGBA),
                GLenum(GL_UNSIGNED_BYTE),
                ptr.baseAddress
            )
        }
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)

        let texId = nextTextureId
        nextTextureId += 1
        textures[texId] = GLTextureInfo(
            glId: glId,
            width: Int(atlasW),
            height: Int(atlasH),
            isRenderTarget: false
        )

        let fontId = nextFontId
        nextFontId += 1
        fonts[fontId] = GLFontInfo(
            textureGlId: glId,
            textureHandle: TextureHandle(id: texId),
            atlasWidth: Int(atlasW),
            atlasHeight: Int(atlasH),
            fontSize: pixelSize,
            ascent: fontAscent,
            bakedChars: bakedChars
        )
        return FontHandle(id: fontId)
    }

    public func destroyFont(_ handle: FontHandle) {
        guard let fontInfo = fonts[handle.id] else { return }
        fontInfo.bakedChars.deallocate()
        var glId = fontInfo.textureGlId
        glDeleteTextures(1, &glId)
        textures.removeValue(forKey: fontInfo.textureHandle.id)
        fonts.removeValue(forKey: handle.id)
    }

    public func drawText(_ text: String, position: Vector2, font: FontHandle, size: Float, color: Color) {
        guard let fontInfo = fonts[font.id] else { return }
        let scale = size / fontInfo.fontSize
        let r = Float(color.r) / 255.0
        let g = Float(color.g) / 255.0
        let b = Float(color.b) / 255.0
        let a = Float(color.a) / 255.0

        // stbtt_GetBakedQuad uses baseline coordinates (y=0 is baseline,
        // negative y is above). Offset by ascent so `position` is top-left.
        let ascentPx = fontInfo.ascent * scale

        var xpos: Float = 0
        var ypos: Float = 0

        for char in text.unicodeScalars {
            if char == "\n" {
                xpos = 0
                ypos += fontInfo.fontSize
                continue
            }

            let codepoint = Int(char.value)
            guard codepoint >= 32 && codepoint < 127 else { continue }

            var q = stbtt_aligned_quad()
            stbtt_GetBakedQuad(
                fontInfo.bakedChars,
                Int32(fontInfo.atlasWidth),
                Int32(fontInfo.atlasHeight),
                Int32(codepoint - 32),
                &xpos,
                &ypos,
                &q,
                1
            )

            let qx0 = position.x + q.x0 * scale
            let qy0 = position.y + ascentPx + q.y0 * scale
            let qx1 = position.x + q.x1 * scale
            let qy1 = position.y + ascentPx + q.y1 * scale

            addQuadToBatch(
                glTexId: fontInfo.textureGlId,
                x0: qx0,
                y0: qy0,
                u0: q.s0,
                v0: q.t0,
                x1: qx1,
                y1: qy0,
                u1: q.s1,
                v1: q.t0,
                x2: qx1,
                y2: qy1,
                u2: q.s1,
                v2: q.t1,
                x3: qx0,
                y3: qy1,
                u3: q.s0,
                v3: q.t1,
                r: r,
                g: g,
                b: b,
                a: a,
                blendMode: batchCurrentBlendMode
            )
        }
    }

    public func measureText(_ text: String, font: FontHandle, size: Float) -> Size {
        guard let fontInfo = fonts[font.id] else { return .zero }
        let scale = size / fontInfo.fontSize

        var xpos: Float = 0
        var ypos: Float = 0
        var maxWidth: Float = 0
        var lineCount: Int = 1

        for char in text.unicodeScalars {
            if char == "\n" {
                maxWidth = max(maxWidth, xpos)
                xpos = 0
                ypos = 0
                lineCount += 1
                continue
            }

            let codepoint = Int(char.value)
            guard codepoint >= 32 && codepoint < 127 else { continue }

            var q = stbtt_aligned_quad()
            stbtt_GetBakedQuad(
                fontInfo.bakedChars,
                Int32(fontInfo.atlasWidth),
                Int32(fontInfo.atlasHeight),
                Int32(codepoint - 32),
                &xpos,
                &ypos,
                &q,
                1
            )
        }
        maxWidth = max(maxWidth, xpos)

        return Size(
            width: maxWidth * scale,
            height: fontInfo.fontSize * scale * Float(lineCount)
        )
    }

    // MARK: - Clipping

    public func beginClip(_ rect: Rect) {
        flushBatch()
        clipStack.append(rect)
        glEnable(GLenum(GL_SCISSOR_TEST))
        applyScissor(rect)
    }

    public func endClip() {
        flushBatch()
        if !clipStack.isEmpty { clipStack.removeLast() }
        if clipStack.isEmpty {
            glDisable(GLenum(GL_SCISSOR_TEST))
        } else if let lastClip = clipStack.last {
            applyScissor(lastClip)
        }
    }

    private func applyScissor(_ rect: Rect) {
        let currentHeight: Float
        if let rtInfo = renderTargets[activeRenderTarget.id] {
            currentHeight = Float(rtInfo.height)
        } else {
            currentHeight = _screenSize.height
        }
        let glY = currentHeight - rect.y - rect.height
        glScissor(GLint(rect.x), GLint(glY), GLsizei(rect.width), GLsizei(rect.height))
    }

    // MARK: - Camera

    public func beginCamera(_ camera: Camera2D) {
        flushBatch()
        mvpStack.append(projectionMatrix)

        let ortho = Self.ortho4x4(
            left: 0,
            right: _screenSize.width,
            bottom: _screenSize.height,
            top: 0,
            near: -1,
            far: 1
        )

        let tOffset = Self.mat4x4Translate(camera.offset.x, camera.offset.y)
        let sZoom = Self.mat4x4Scale(camera.zoom, camera.zoom)
        let rRot = Self.mat4x4Rotate(-camera.rotation)
        let tTarget = Self.mat4x4Translate(-camera.target.x, -camera.target.y)

        let view = Self.mat4x4Multiply(tOffset,
                   Self.mat4x4Multiply(sZoom,
                   Self.mat4x4Multiply(rRot, tTarget)))

        projectionMatrix = Self.mat4x4Multiply(ortho, view)
        mvpDirty = true
    }

    public func endCamera() {
        flushBatch()
        if !mvpStack.isEmpty {
            projectionMatrix = mvpStack.removeLast()
        }
        mvpDirty = true
    }

    // MARK: - Render Targets

    public func createRenderTarget(width: Int, height: Int) -> RenderTargetHandle {
        var texGlId: GLuint = 0
        glGenTextures(1, &texGlId)
        glBindTexture(GLenum(GL_TEXTURE_2D), texGlId)
        glTexImage2D(
            GLenum(GL_TEXTURE_2D),
            0,
            GL_RGBA,
            GLsizei(width),
            GLsizei(height),
            0,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            nil
        )
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)

        var fbo: GLuint = 0
        glGenFramebuffers(1, &fbo)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo)
        glFramebufferTexture2D(
            GLenum(GL_FRAMEBUFFER),
            GLenum(GL_COLOR_ATTACHMENT0),
            GLenum(GL_TEXTURE_2D),
            texGlId,
            0
        )

        let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)

        if status != GLenum(GL_FRAMEBUFFER_COMPLETE) {
            var fboVar = fbo
            glDeleteFramebuffers(1, &fboVar)
            var texVar = texGlId
            glDeleteTextures(1, &texVar)
            return .invalid
        }

        let texId = nextTextureId
        nextTextureId += 1
        textures[texId] = GLTextureInfo(
            glId: texGlId,
            width: width,
            height: height,
            isRenderTarget: true
        )

        let rtId = nextRenderTargetId
        nextRenderTargetId += 1
        renderTargets[rtId] = GLRenderTargetInfo(
            fbo: fbo,
            textureHandle: TextureHandle(id: texId),
            width: width,
            height: height
        )
        return RenderTargetHandle(id: rtId)
    }

    public func beginRenderTarget(_ handle: RenderTargetHandle) {
        guard let rtInfo = renderTargets[handle.id] else { return }
        flushBatch()

        var viewport = [GLint](repeating: 0, count: 4)
        glGetIntegerv(GLenum(GL_VIEWPORT), &viewport)
        savedViewports.append((
            x: viewport[0],
            y: viewport[1],
            w: GLsizei(viewport[2]),
            h: GLsizei(viewport[3])
        ))

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), rtInfo.fbo)
        glViewport(0, 0, GLsizei(rtInfo.width), GLsizei(rtInfo.height))

        mvpStack.append(projectionMatrix)
        projectionMatrix = Self.ortho4x4(
            left: 0,
            right: Float(rtInfo.width),
            bottom: Float(rtInfo.height),
            top: 0,
            near: -1,
            far: 1
        )
        mvpDirty = true

        glClearColor(0, 0, 0, 0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        activeRenderTarget = handle
    }

    public func endRenderTarget() {
        flushBatch()
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        if let saved = savedViewports.popLast() {
            glViewport(saved.x, saved.y, saved.w, saved.h)
        }

        if !mvpStack.isEmpty {
            projectionMatrix = mvpStack.removeLast()
        }
        mvpDirty = true
        applyClearColor()
        activeRenderTarget = .invalid
    }

    public func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle {
        guard let rtInfo = renderTargets[handle.id] else { return .invalid }
        return rtInfo.textureHandle
    }

    public func renderTargetSize(_ handle: RenderTargetHandle) -> Size {
        guard let rtInfo = renderTargets[handle.id] else { return .zero }
        return Size(width: Float(rtInfo.width), height: Float(rtInfo.height))
    }

    public func destroyRenderTarget(_ handle: RenderTargetHandle) {
        guard let rtInfo = renderTargets[handle.id] else { return }
        var fbo = rtInfo.fbo
        glDeleteFramebuffers(1, &fbo)
        if let texInfo = textures[rtInfo.textureHandle.id] {
            var glId = texInfo.glId
            glDeleteTextures(1, &glId)
        }
        textures.removeValue(forKey: rtInfo.textureHandle.id)
        renderTargets.removeValue(forKey: handle.id)
    }

    // MARK: - Blend Modes

    public func beginBlendMode(_ mode: BlendMode) {
        flushBatch()
        blendModeStack.append(batchCurrentBlendMode)
        batchCurrentBlendMode = mode
        applyGLBlendFunc(mode)
    }

    public func endBlendMode() {
        flushBatch()
        if let prev = blendModeStack.popLast() {
            batchCurrentBlendMode = prev
            applyGLBlendFunc(prev)
        }
    }

    // MARK: - Shaders

    public func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle {
        let vs = vertexSource ?? Self.defaultVertexShader
        guard let programId = compileAndLinkProgram(vertexSource: vs, fragmentSource: fragmentSource) else {
            return .invalid
        }
        let id = nextShaderId
        nextShaderId += 1
        shaders[id] = GLShaderInfo(programId: programId, uniformCache: [:])
        return ShaderHandle(id: id)
    }

    public func beginShader(_ handle: ShaderHandle) {
        guard let shaderInfo = shaders[handle.id] else { return }
        flushBatch()
        glUseProgram(shaderInfo.programId)
        activeShaderHandle = handle
        mvpDirty = true
        nextTextureUnit = 1
        uploadMVP()
    }

    public func endShader() {
        flushBatch()
        if let defShader = shaders[defaultShaderHandle.id] {
            glUseProgram(defShader.programId)
        }
        activeShaderHandle = defaultShaderHandle
        mvpDirty = true
        nextTextureUnit = 1
    }

    public func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float) {
        let loc = getUniformLocation(shaderId: handle.id, name: name)
        guard loc >= 0 else { return }
        ensureShaderBound(handle)
        glUniform1f(loc, value)
    }

    public func setShaderVec2(_ handle: ShaderHandle, name: String, value: Vector2) {
        let loc = getUniformLocation(shaderId: handle.id, name: name)
        guard loc >= 0 else { return }
        ensureShaderBound(handle)
        glUniform2f(loc, value.x, value.y)
    }

    public func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float) {
        let loc = getUniformLocation(shaderId: handle.id, name: name)
        guard loc >= 0 else { return }
        ensureShaderBound(handle)
        glUniform3f(loc, x, y, z)
    }

    public func setShaderVec4(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float, w: Float) {
        let loc = getUniformLocation(shaderId: handle.id, name: name)
        guard loc >= 0 else { return }
        ensureShaderBound(handle)
        glUniform4f(loc, x, y, z, w)
    }

    public func setShaderInt(_ handle: ShaderHandle, name: String, value: Int32) {
        let loc = getUniformLocation(shaderId: handle.id, name: name)
        guard loc >= 0 else { return }
        ensureShaderBound(handle)
        glUniform1i(loc, GLint(value))
    }

    public func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle) {
        guard let texInfo = textures[texture.id] else { return }
        let loc = getUniformLocation(shaderId: handle.id, name: name)
        guard loc >= 0 else { return }
        ensureShaderBound(handle)
        let unit = nextTextureUnit
        glActiveTexture(GLenum(GL_TEXTURE0 + unit))
        glBindTexture(GLenum(GL_TEXTURE_2D), texInfo.glId)
        glUniform1i(loc, GLint(unit))
        nextTextureUnit += 1
    }

    private func ensureShaderBound(_ handle: ShaderHandle) {
        if activeShaderHandle != handle, let info = shaders[handle.id] {
            glUseProgram(info.programId)
        }
    }

    public func destroyShader(_ handle: ShaderHandle) {
        guard handle != defaultShaderHandle else { return }
        guard let shaderInfo = shaders[handle.id] else { return }
        glDeleteProgram(shaderInfo.programId)
        shaders.removeValue(forKey: handle.id)
    }

    // MARK: - Screenshots

    public func takeScreenshot(path: String) {
        guard let image = captureScreen() else { return }
        image.pixels.withUnsafeBufferPointer { ptr in
            _ = stbi_write_png(
                path,
                Int32(image.width),
                Int32(image.height),
                4,
                ptr.baseAddress,
                Int32(image.width * 4)
            )
        }
    }

    public func captureScreen() -> ImageData? {
        flushBatch()
        let w = Int(_screenSize.width)
        let h = Int(_screenSize.height)
        guard w > 0 && h > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        pixels.withUnsafeMutableBufferPointer { ptr in
            glReadPixels(
                0,
                0,
                GLsizei(w),
                GLsizei(h),
                GLenum(GL_RGBA),
                GLenum(GL_UNSIGNED_BYTE),
                ptr.baseAddress
            )
        }

        // Y-flip (GL reads bottom-to-top)
        let rowSize = w * 4
        var flipped = [UInt8](repeating: 0, count: w * h * 4)
        for row in 0..<h {
            let srcStart = (h - 1 - row) * rowSize
            let dstStart = row * rowSize
            flipped[dstStart..<(dstStart + rowSize)] = pixels[srcStart..<(srcStart + rowSize)]
        }

        return ImageData(width: w, height: h, pixels: flipped)
    }

    // MARK: - Material Support

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

    // MARK: - Throwing Resource Loading

    public func loadTextureOrThrow(from path: String) throws -> TextureHandle {
        let handle = loadTexture(from: path)
        guard handle != .invalid else { throw ResourceError.textureLoadFailed(path: path) }
        return handle
    }

    public func loadTextureFromImageOrThrow(_ image: ImageData) throws -> TextureHandle {
        let handle = loadTextureFromImage(image)
        guard handle != .invalid else { throw ResourceError.textureFromImageFailed }
        return handle
    }

    public func loadFontOrThrow(from path: String, size: Int) throws -> FontHandle {
        let handle = loadFont(from: path, size: size)
        guard handle != .invalid else { throw ResourceError.fontLoadFailed(path: path) }
        return handle
    }

    public func loadShaderOrThrow(vertexSource: String?, fragmentSource: String) throws -> ShaderHandle {
        let handle = loadShader(vertexSource: vertexSource, fragmentSource: fragmentSource)
        guard handle != .invalid else { throw ResourceError.shaderCompilationFailed }
        return handle
    }

}

// MARK: - Initialization Errors

public enum RendererInitError: Error, Sendable {
    case windowCreationFailed
    case eglFailed(String)
}
