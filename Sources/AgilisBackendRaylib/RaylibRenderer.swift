import AgilisCore
import RaylibC

/// Raylib implementation of the RenderBackend protocol.
public final class RaylibRenderer: @unchecked Sendable, RenderBackend {
    private var textures: [UInt32: Texture2D] = [:]
    private var nextTextureId: UInt32 = 1
    private var fonts: [UInt32: RaylibC.Font] = [:]
    private var nextFontId: UInt32 = 1
    private var bgColor: AgilisCore.Color = .darkGray
    private var renderTargets: [UInt32: RenderTexture2D] = [:]
    private var nextRenderTargetId: UInt32 = 1
    private var renderTargetTextureIds: [UInt32: UInt32] = [:]
    private var shaders: [UInt32: RaylibC.Shader] = [:]
    private var nextShaderId: UInt32 = 1
    private var shaderLocations: [UInt32: [String: Int32]] = [:]

    public init() {}

    public func initialize(config: WindowConfig) throws {
        var flags: UInt32 = 0
        if config.vsync { flags |= UInt32(FLAG_VSYNC_HINT.rawValue) }
        if config.resizable { flags |= UInt32(FLAG_WINDOW_RESIZABLE.rawValue) }
        SetConfigFlags(flags)

        InitWindow(Int32(config.width), Int32(config.height), config.title)
        SetTargetFPS(Int32(config.targetFPS))
    }

    public func shutdown() {
        // Unload shaders first — they don't own other resources.
        for (_, shader) in shaders {
            UnloadShader(shader)
        }
        shaders.removeAll()
        shaderLocations.removeAll()

        // Unload render targets — UnloadRenderTexture frees the color texture,
        // so remove bridged entries from textures dict to avoid double-free.
        for (rtId, rt) in renderTargets {
            if let texId = renderTargetTextureIds[rtId] {
                textures.removeValue(forKey: texId)
            }
            UnloadRenderTexture(rt)
        }
        renderTargets.removeAll()
        renderTargetTextureIds.removeAll()

        for (_, tex) in textures {
            UnloadTexture(tex)
        }
        textures.removeAll()
        CloseWindow()
    }

    public func shouldClose() -> Bool {
        WindowShouldClose()
    }

    public func beginFrame() {
        BeginDrawing()
        ClearBackground(rlColor(bgColor))
    }

    public func endFrame() {
        EndDrawing()
    }

    public func setBackgroundColor(_ color: AgilisCore.Color) {
        bgColor = color
    }

    // MARK: - Textures

    public func loadTexture(from path: String) -> TextureHandle {
        let tex = LoadTexture(path)
        let handle = TextureHandle(id: nextTextureId)
        textures[nextTextureId] = tex
        nextTextureId += 1
        return handle
    }

    public func loadTextureFromImage(_ image: ImageData) -> TextureHandle {
        let count = image.width * image.height * 4
        guard count > 0, image.pixels.count >= count else { return .invalid }

        // Use C malloc so the pointer is compatible with raylib's free()
        guard let pixelsCopy = malloc(count) else { return .invalid }
        image.pixels.withUnsafeBufferPointer { buf in
            pixelsCopy.copyMemory(from: buf.baseAddress!, byteCount: count)
        }

        let rlImage = Image(
            data: pixelsCopy,
            width: Int32(image.width),
            height: Int32(image.height),
            mipmaps: 1,
            format: Int32(PIXELFORMAT_UNCOMPRESSED_R8G8B8A8.rawValue)
        )
        let tex = LoadTextureFromImage(rlImage)
        UnloadImage(rlImage)

        let handle = TextureHandle(id: nextTextureId)
        textures[nextTextureId] = tex
        nextTextureId += 1
        return handle
    }

    public func textureSize(_ handle: TextureHandle) -> AgilisCore.Size {
        guard let tex = textures[handle.id] else { return .zero }
        return AgilisCore.Size(width: Float(tex.width), height: Float(tex.height))
    }

    public func destroyTexture(_ handle: TextureHandle) {
        // Don't destroy textures owned by render targets — use destroyRenderTarget instead.
        if renderTargetTextureIds.values.contains(handle.id) { return }
        guard let tex = textures.removeValue(forKey: handle.id) else { return }
        UnloadTexture(tex)
    }

    // MARK: - Drawing

    public func drawSprite(_ sprite: Sprite) {
        guard let tex = textures[sprite.texture.id] else { return }

        // Determine effective blend mode (material override or sprite default)
        let effectiveBlend = sprite.material?.blendMode ?? sprite.blendMode
        let needsBlend = effectiveBlend != .alpha
        if needsBlend { RaylibC.BeginBlendMode(rlBlendMode(effectiveBlend)) }

        // Apply material shader if present
        let hasMaterial = sprite.material != nil && sprite.material!.shader != .invalid
        if hasMaterial {
            applyMaterial(sprite.material!)
            beginShader(sprite.material!.shader)
        }

        var sourceW = sprite.sourceRect.width == 0 ? Float(tex.width) : sprite.sourceRect.width
        var sourceH = sprite.sourceRect.height == 0 ? Float(tex.height) : sprite.sourceRect.height
        if sprite.flipX { sourceW = -sourceW }
        if sprite.flipY { sourceH = -sourceH }

        let source = RaylibC.Rectangle(
            x: sprite.sourceRect.x,
            y: sprite.sourceRect.y,
            width: sourceW,
            height: sourceH
        )

        let dest = RaylibC.Rectangle(
            x: sprite.position.x,
            y: sprite.position.y,
            width: abs(sourceW) * sprite.scale.x,
            height: abs(sourceH) * sprite.scale.y
        )

        let origin = RaylibC.Vector2(x: sprite.origin.x, y: sprite.origin.y)
        let rotation = radiansToDegrees(sprite.rotation)

        DrawTexturePro(tex, source, dest, origin, rotation, rlColor(sprite.tint))

        if hasMaterial { endShader() }
        if needsBlend { RaylibC.EndBlendMode() }
    }

    public func drawSprites(_ sprites: [Sprite]) {
        guard !sprites.isEmpty else { return }

        var currentTextureId: UInt32 = 0
        var currentTex: Texture2D?
        var currentBlend: AgilisCore.BlendMode = .alpha
        var currentShaderId: UInt32 = 0

        for sprite in sprites {
            // Track shader changes (material)
            let spriteShaderId = sprite.material?.shader.id ?? 0
            if spriteShaderId != currentShaderId {
                // End previous shader if active
                if currentShaderId != 0 { endShader() }
                // Begin new shader if needed
                if spriteShaderId != 0, let material = sprite.material {
                    applyMaterial(material)
                    beginShader(material.shader)
                }
                currentShaderId = spriteShaderId
            } else if spriteShaderId != 0, let material = sprite.material {
                // Same shader but potentially different uniforms — update them
                applyMaterial(material)
            }

            // Track blend mode changes (material override or sprite default)
            let effectiveBlend = sprite.material?.blendMode ?? sprite.blendMode
            if effectiveBlend != currentBlend {
                if currentBlend != .alpha { RaylibC.EndBlendMode() }
                if effectiveBlend != .alpha { RaylibC.BeginBlendMode(rlBlendMode(effectiveBlend)) }
                currentBlend = effectiveBlend
            }

            if sprite.texture.id != currentTextureId {
                currentTextureId = sprite.texture.id
                currentTex = textures[sprite.texture.id]
            }
            guard let tex = currentTex else { continue }

            var sourceW = sprite.sourceRect.width == 0 ? Float(tex.width) : sprite.sourceRect.width
            var sourceH = sprite.sourceRect.height == 0 ? Float(tex.height) : sprite.sourceRect.height
            if sprite.flipX { sourceW = -sourceW }
            if sprite.flipY { sourceH = -sourceH }

            let source = RaylibC.Rectangle(
                x: sprite.sourceRect.x,
                y: sprite.sourceRect.y,
                width: sourceW,
                height: sourceH
            )

            let dest = RaylibC.Rectangle(
                x: sprite.position.x,
                y: sprite.position.y,
                width: abs(sourceW) * sprite.scale.x,
                height: abs(sourceH) * sprite.scale.y
            )

            let origin = RaylibC.Vector2(x: sprite.origin.x, y: sprite.origin.y)
            let rotation = radiansToDegrees(sprite.rotation)

            DrawTexturePro(tex, source, dest, origin, rotation, rlColor(sprite.tint))
        }

        // Restore shader and blend mode
        if currentShaderId != 0 { endShader() }
        if currentBlend != .alpha { RaylibC.EndBlendMode() }
    }

    public func drawRect(_ rect: AgilisCore.Rect, color: AgilisCore.Color) {
        DrawRectangle(
            Int32(rect.x), Int32(rect.y),
            Int32(rect.width), Int32(rect.height),
            rlColor(color)
        )
    }

    public func drawRectOutline(_ rect: AgilisCore.Rect, color: AgilisCore.Color, thickness: Float) {
        let r = RaylibC.Rectangle(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        DrawRectangleLinesEx(r, thickness, rlColor(color))
    }

    public func drawLine(from start: AgilisCore.Vector2, to end: AgilisCore.Vector2, color: AgilisCore.Color, thickness: Float) {
        let s = RaylibC.Vector2(x: start.x, y: start.y)
        let e = RaylibC.Vector2(x: end.x, y: end.y)
        DrawLineEx(s, e, thickness, rlColor(color))
    }

    public func drawCircle(center: AgilisCore.Vector2, radius: Float, color: AgilisCore.Color) {
        DrawCircle(Int32(center.x), Int32(center.y), radius, rlColor(color))
    }

    public func drawCircleOutline(center: AgilisCore.Vector2, radius: Float, color: AgilisCore.Color, thickness: Float) {
        let c = RaylibC.Vector2(x: center.x, y: center.y)
        DrawRing(c, radius - thickness, radius, 0, 360, 60, rlColor(color))
    }

    // MARK: - Fonts & Text

    public func loadDefaultFont() -> FontHandle {
        let font = GetFontDefault()
        let handle = FontHandle(id: nextFontId)
        fonts[nextFontId] = font
        nextFontId += 1
        return handle
    }

    public func loadFont(from path: String, size: Int) -> FontHandle {
        let font = LoadFontEx(path, Int32(size), nil, 0)
        let handle = FontHandle(id: nextFontId)
        fonts[nextFontId] = font
        nextFontId += 1
        return handle
    }

    public func destroyFont(_ handle: FontHandle) {
        guard let font = fonts.removeValue(forKey: handle.id) else { return }
        UnloadFont(font)
    }

    public func drawText(_ text: String, position: AgilisCore.Vector2, font: FontHandle, size: Float, color: AgilisCore.Color) {
        guard let rlFont = fonts[font.id] else { return }
        let spacing = size / 10.0
        let pos = RaylibC.Vector2(x: position.x, y: position.y)
        DrawTextEx(rlFont, text, pos, size, spacing, rlColor(color))
    }

    public func measureText(_ text: String, font: FontHandle, size: Float) -> AgilisCore.Size {
        guard let rlFont = fonts[font.id] else { return .zero }
        let spacing = size / 10.0
        let v = MeasureTextEx(rlFont, text, size, spacing)
        return AgilisCore.Size(width: v.x, height: v.y)
    }

    // MARK: - Clipping

    public func beginClip(_ rect: AgilisCore.Rect) {
        BeginScissorMode(Int32(rect.x), Int32(rect.y), Int32(rect.width), Int32(rect.height))
    }

    public func endClip() {
        EndScissorMode()
    }

    // MARK: - Camera

    public func beginCamera(_ camera: AgilisCore.Camera2D) {
        let cam = RaylibC.Camera2D(
            offset: RaylibC.Vector2(x: camera.offset.x, y: camera.offset.y),
            target: RaylibC.Vector2(x: camera.target.x, y: camera.target.y),
            rotation: radiansToDegrees(camera.rotation),
            zoom: camera.zoom
        )
        BeginMode2D(cam)
    }

    public func endCamera() {
        EndMode2D()
    }

    // MARK: - Render Targets

    public func createRenderTarget(width: Int, height: Int) -> RenderTargetHandle {
        let rt = LoadRenderTexture(Int32(width), Int32(height))
        guard IsRenderTextureValid(rt) else { return .invalid }

        let rtId = nextRenderTargetId
        nextRenderTargetId += 1
        renderTargets[rtId] = rt

        // Bridge the color texture into the textures dictionary so drawSprite works.
        let texId = nextTextureId
        nextTextureId += 1
        textures[texId] = rt.texture
        renderTargetTextureIds[rtId] = texId

        return RenderTargetHandle(id: rtId)
    }

    public func beginRenderTarget(_ handle: RenderTargetHandle) {
        guard let rt = renderTargets[handle.id] else { return }
        BeginTextureMode(rt)
    }

    public func endRenderTarget() {
        EndTextureMode()
    }

    public func renderTargetTexture(_ handle: RenderTargetHandle) -> TextureHandle {
        guard let texId = renderTargetTextureIds[handle.id] else { return .invalid }
        return TextureHandle(id: texId)
    }

    public func renderTargetSize(_ handle: RenderTargetHandle) -> AgilisCore.Size {
        guard let rt = renderTargets[handle.id] else { return .zero }
        return AgilisCore.Size(width: Float(rt.texture.width), height: Float(rt.texture.height))
    }

    public func destroyRenderTarget(_ handle: RenderTargetHandle) {
        guard let rt = renderTargets.removeValue(forKey: handle.id) else { return }
        // Remove the bridged texture entry — don't call UnloadTexture,
        // UnloadRenderTexture handles freeing the GPU texture.
        if let texId = renderTargetTextureIds.removeValue(forKey: handle.id) {
            textures.removeValue(forKey: texId)
        }
        UnloadRenderTexture(rt)
    }

    // MARK: - Blend Mode

    public func beginBlendMode(_ mode: AgilisCore.BlendMode) {
        RaylibC.BeginBlendMode(rlBlendMode(mode))
    }

    public func endBlendMode() {
        RaylibC.EndBlendMode()
    }

    // MARK: - Shaders

    public func loadShader(vertexSource: String?, fragmentSource: String) -> ShaderHandle {
        let shader = LoadShaderFromMemory(vertexSource, fragmentSource)
        guard IsShaderValid(shader) else { return .invalid }
        let id = nextShaderId
        nextShaderId += 1
        shaders[id] = shader
        shaderLocations[id] = [:]
        return ShaderHandle(id: id)
    }

    public func beginShader(_ handle: ShaderHandle) {
        guard let shader = shaders[handle.id] else { return }
        // Reset to default first so raylib always detects the shader change
        // and properly sets currentShaderLocs. Without this, if SetShaderValue
        // (called by setShaderFloat/Vec2/etc.) already activated the same shader
        // via rlEnableShader, BeginShaderMode's rlSetShader check
        // (currentShaderId != id) would be false, skipping the locs assignment.
        // This causes the MVP matrix to be sent to the wrong uniform location.
        EndShaderMode()
        BeginShaderMode(shader)
    }

    public func endShader() {
        EndShaderMode()
    }

    public func setShaderFloat(_ handle: ShaderHandle, name: String, value: Float) {
        guard let shader = shaders[handle.id] else { return }
        let loc = cachedShaderLocation(shaderId: handle.id, shader: shader, name: name)
        var v = value
        SetShaderValue(shader, loc, &v, Int32(SHADER_UNIFORM_FLOAT.rawValue))
    }

    public func setShaderVec2(_ handle: ShaderHandle, name: String, value: AgilisCore.Vector2) {
        guard let shader = shaders[handle.id] else { return }
        let loc = cachedShaderLocation(shaderId: handle.id, shader: shader, name: name)
        var v: [Float] = [value.x, value.y]
        SetShaderValue(shader, loc, &v, Int32(SHADER_UNIFORM_VEC2.rawValue))
    }

    public func setShaderVec3(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float) {
        guard let shader = shaders[handle.id] else { return }
        let loc = cachedShaderLocation(shaderId: handle.id, shader: shader, name: name)
        var v: [Float] = [x, y, z]
        SetShaderValue(shader, loc, &v, Int32(SHADER_UNIFORM_VEC3.rawValue))
    }

    public func setShaderVec4(_ handle: ShaderHandle, name: String, x: Float, y: Float, z: Float, w: Float) {
        guard let shader = shaders[handle.id] else { return }
        let loc = cachedShaderLocation(shaderId: handle.id, shader: shader, name: name)
        var v: [Float] = [x, y, z, w]
        SetShaderValue(shader, loc, &v, Int32(SHADER_UNIFORM_VEC4.rawValue))
    }

    public func setShaderInt(_ handle: ShaderHandle, name: String, value: Int32) {
        guard let shader = shaders[handle.id] else { return }
        let loc = cachedShaderLocation(shaderId: handle.id, shader: shader, name: name)
        var v = value
        SetShaderValue(shader, loc, &v, Int32(SHADER_UNIFORM_INT.rawValue))
    }

    public func setShaderTexture(_ handle: ShaderHandle, name: String, texture: TextureHandle) {
        guard let shader = shaders[handle.id],
              let tex = textures[texture.id] else { return }
        let loc = cachedShaderLocation(shaderId: handle.id, shader: shader, name: name)
        SetShaderValueTexture(shader, loc, tex)
    }

    public func destroyShader(_ handle: ShaderHandle) {
        guard let shader = shaders.removeValue(forKey: handle.id) else { return }
        shaderLocations.removeValue(forKey: handle.id)
        UnloadShader(shader)
    }

    // MARK: - Drawing (Polygons)

    public func drawTriangle(_ v1: AgilisCore.Vector2, _ v2: AgilisCore.Vector2, _ v3: AgilisCore.Vector2, color: AgilisCore.Color) {
        let rv1 = RaylibC.Vector2(x: v1.x, y: v1.y)
        let rv2 = RaylibC.Vector2(x: v2.x, y: v2.y)
        let rv3 = RaylibC.Vector2(x: v3.x, y: v3.y)
        DrawTriangle(rv1, rv2, rv3, rlColor(color))
    }

    // MARK: - Screen

    public var screenSize: AgilisCore.Size {
        AgilisCore.Size(width: Float(GetScreenWidth()), height: Float(GetScreenHeight()))
    }

    // MARK: - Screenshots

    public func takeScreenshot(path: String) {
        TakeScreenshot(path)
    }

    public func captureScreen() -> ImageData? {
        var image = LoadImageFromScreen()
        defer { UnloadImage(image) }

        guard image.data != nil, image.width > 0, image.height > 0 else { return nil }

        // Ensure RGBA format (4 bytes per pixel)
        ImageFormat(&image, Int32(PIXELFORMAT_UNCOMPRESSED_R8G8B8A8.rawValue))

        let w = Int(image.width)
        let h = Int(image.height)
        let byteCount = w * h * 4
        let ptr = image.data!.assumingMemoryBound(to: UInt8.self)
        let pixels = [UInt8](UnsafeBufferPointer(start: ptr, count: byteCount))

        return ImageData(width: w, height: h, pixels: pixels)
    }

    // MARK: - Helpers

    private func rlColor(_ c: AgilisCore.Color) -> RaylibC.Color {
        RaylibC.Color(r: c.r, g: c.g, b: c.b, a: c.a)
    }

    private func rlBlendMode(_ mode: AgilisCore.BlendMode) -> Int32 {
        switch mode {
        case .alpha: return Int32(BLEND_ALPHA.rawValue)
        case .additive: return Int32(BLEND_ADDITIVE.rawValue)
        case .multiplied: return Int32(BLEND_MULTIPLIED.rawValue)
        case .premultiplied: return Int32(BLEND_ALPHA_PREMULTIPLY.rawValue)
        }
    }

    private func cachedShaderLocation(shaderId: UInt32, shader: RaylibC.Shader, name: String) -> Int32 {
        if let loc = shaderLocations[shaderId]?[name] {
            return loc
        }
        let loc = GetShaderLocation(shader, name)
        shaderLocations[shaderId]?[name] = loc
        return loc
    }
}
