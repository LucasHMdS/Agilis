#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Snapshot of a single light's state, captured during `update()` for use in rendering.
struct LightSnapshot {
    let position: Vector2
    let light: Light2D
}

/// Snapshot of an entity's normal map data for rendering into the normal/specular buffers.
struct NormalMapSnapshot {
    let position: Vector2
    let rotation: Float
    let scale: Vector2
    let origin: Vector2
    let sourceRect: Rect
    let flipX: Bool
    let flipY: Bool
    let normalMap: TextureHandle
    let specularMap: TextureHandle
    let specularIntensity: Float
}

/// Manages 2D lighting: light map creation, shadow computation, and compositing.
///
/// Add to the world as a system, then call `renderLightMap` and `compositeLightMap`
/// from your scene's `render()` method.
///
/// ## Usage
/// ```swift
/// // Setup (in Scene.didEnter)
/// let lighting = LightingSystem()
/// lighting.initialize(renderer: app.renderer)
/// world.addSystem(lighting)
///
/// // In Scene.render():
/// app.renderer.beginCamera(camera)
/// // ... draw scene sprites ...
/// app.renderer.endCamera()
///
/// // Render and composite lighting
/// lighting.renderNormalBuffer(renderer: app.renderer, camera: camera) // optional
/// lighting.renderLightMap(renderer: app.renderer, camera: camera)
/// lighting.compositeLightMap(renderer: app.renderer)
/// ```
public final class LightingSystem: System, @unchecked Sendable {

    public var priority: Int { _priority }
    private let _priority: Int

    /// Read-only: snapshots light/shadow data for GPU rendering.
    /// Runs at priority 300, after PhysicsWorld2D (100) and ParticleSystem (200).
    /// Can run in parallel with ParticleSystem (disjoint access).
    public var componentAccess: ComponentAccess {
        ComponentAccess(
            reads: [Transform2D.self, Light2D.self, Collider2D.self, ShadowCaster2D.self, Sprite.self]
        )
    }

    /// Lighting configuration.
    public var options: LightingOptions

    // MARK: - GPU Resources

    private var lightMapRT: RenderTargetHandle = .invalid
    private var pointLightShader: ShaderHandle = .invalid
    private var spotLightShader: ShaderHandle = .invalid
    private var lightMapWidth: Int = 0
    private var lightMapHeight: Int = 0

    // Normal mapping GPU resources
    private var normalBufferRT: RenderTargetHandle = .invalid
    private var specularBufferRT: RenderTargetHandle = .invalid
    private var normalLitPointShader: ShaderHandle = .invalid
    private var normalLitSpotShader: ShaderHandle = .invalid
    private var specularPointShader: ShaderHandle = .invalid
    private var specularSpotShader: ShaderHandle = .invalid
    private var normalPassShader: ShaderHandle = .invalid

    // Soft shadow GPU resources
    private var shadowBufferRT: RenderTargetHandle = .invalid
    private var shadowBlurRT: RenderTargetHandle = .invalid
    private var shadowBlurHShader: ShaderHandle = .invalid
    private var shadowBlurVShader: ShaderHandle = .invalid

    // 1x1 white texture for drawing full-screen shader quads with proper UV mapping.
    // drawRect uses vertex colors without proper 0-1 UV mapping across the quad.
    private var shaderQuadTexture: TextureHandle = .invalid

    // Pre-computed radial gradient texture for rendering point lights without shaders.
    // Used as a fallback when the full-screen shader quad approach has driver issues.
    private var lightGradientTexture: TextureHandle = .invalid
    private let lightGradientSize: Int = 256

    // Per-light temporary render target for proper shadow compositing.
    // Each light is rendered here, then additively blended onto the main light map.
    private var perLightRT: RenderTargetHandle = .invalid

    // Debug counters
    private var debugFrameCount: Int = 0
    private var debugTotalShadowVolumes: Int = 0
    private var debugTotalTriangles: Int = 0

    /// When true, stores shadow volumes for debug rendering via `drawShadowDebug`.
    public var debugShadowVolumes: Bool = false
    private var debugShadowData: [(lightPos: Vector2, volumes: [ShadowVolume])] = []

    // MARK: - Snapshot Data (from last update tick)

    private var lightSnapshots: [LightSnapshot] = []
    private var occluderSnapshots: [ShadowOccluder] = []
    private var normalMapSnapshots: [NormalMapSnapshot] = []

    /// Whether GPU resources have been initialized.
    public private(set) var isInitialized: Bool = false

    /// Whether normal mapping GPU resources have been initialized.
    public private(set) var isNormalMappingInitialized: Bool = false

    /// Whether soft shadow GPU resources have been initialized.
    public private(set) var isSoftShadowsInitialized: Bool = false

    // MARK: - Init

    /// Creates a lighting system.
    ///
    /// - Parameters:
    ///   - options: Lighting configuration.
    ///   - priority: Execution priority. Default 300 (after physics 100, particles 200).
    public init(
        options: LightingOptions = LightingOptions(),
        priority: Int = 300
    ) {
        self.options = options
        self._priority = priority
    }

    // MARK: - GPU Resource Management

    /// Tracks whether `shutdown(renderer:)` has been called.
    /// If GPU resources are allocated but not cleaned up, logs a warning on deinit.
    deinit {
        if isInitialized {
            Log.warn("LightingSystem", "LightingSystem deallocated without calling shutdown(renderer:). GPU resources may leak.")
        }
    }

    /// Initialize GPU resources (shaders, render targets). Call once after the
    /// renderer is initialized, typically in `Scene.didEnter`.
    public func initialize(renderer: any RenderBackend) {
        guard !isInitialized else { return }

        // Load base shaders
        pointLightShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: LightingShaders.pointLightFragment
        )
        spotLightShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: LightingShaders.spotLightFragment
        )

        // Create light map render target
        let screenSize = renderer.screenSize
        lightMapWidth = max(1, Int(screenSize.width * options.lightMapScale))
        lightMapHeight = max(1, Int(screenSize.height * options.lightMapScale))
        lightMapRT = renderer.createRenderTarget(width: lightMapWidth, height: lightMapHeight)

        // 1x1 white texture for shader quads - drawRect uses the white pixel
        // texture which does not produce 0-1 UVs needed by light shaders.
        shaderQuadTexture = renderer.loadTextureFromImage(
            ImageData(width: 1, height: 1, pixels: [255, 255, 255, 255])
        )

        // Generate radial gradient texture for light rendering.
        // White at center, transparent at edges, with smooth falloff.
        let gs = lightGradientSize
        var gradPixels = [UInt8](repeating: 0, count: gs * gs * 4)
        let center = Float(gs) / 2.0
        for py in 0..<gs {
            for px in 0..<gs {
                let dx = Float(px) - center + 0.5
                let dy = Float(py) - center + 0.5
                let dist = sqrtf(dx * dx + dy * dy) / center
                // Smooth radial falloff: 1 at center, 0 at edge
                let alpha: Float
                if dist >= 1.0 {
                    alpha = 0
                } else {
                    let att = 1.0 - dist * dist  // quadratic falloff
                    alpha = att * (1.0 - dist)    // extra edge softening
                }
                let a = UInt8(max(0, min(255, alpha * 255)))
                let idx = (py * gs + px) * 4
                gradPixels[idx] = 255
                gradPixels[idx + 1] = 255
                gradPixels[idx + 2] = 255
                gradPixels[idx + 3] = a
            }
        }
        lightGradientTexture = renderer.loadTextureFromImage(
            ImageData(width: gs, height: gs, pixels: gradPixels)
        )

        // Per-light temporary RT (same size as light map)
        perLightRT = renderer.createRenderTarget(width: lightMapWidth, height: lightMapHeight)

        isInitialized = true

        // Initialize normal mapping resources if enabled
        if options.normalMappingEnabled {
            initializeNormalMapping(renderer: renderer)
        }

        // Initialize soft shadow resources if enabled
        if options.softShadows {
            initializeSoftShadows(renderer: renderer)
        }
    }

    /// Initialize normal/specular mapping GPU resources.
    private func initializeNormalMapping(renderer: any RenderBackend) {
        guard !isNormalMappingInitialized else { return }

        // Load normal-lit light shaders
        normalLitPointShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: LightingShaders.normalLitPointFragment
        )
        normalLitSpotShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: LightingShaders.normalLitSpotFragment
        )

        // Load normal pass shader
        normalPassShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: LightingShaders.normalPassFragment
        )

        // Create normal buffer RT
        normalBufferRT = renderer.createRenderTarget(
            width: lightMapWidth,
            height: lightMapHeight
        )

        // Load specular shaders and RT if specular is enabled
        if options.specularEnabled {
            specularPointShader = renderer.loadShader(
                vertexSource: nil,
                fragmentSource: LightingShaders.specularPointFragment
            )
            specularSpotShader = renderer.loadShader(
                vertexSource: nil,
                fragmentSource: LightingShaders.specularSpotFragment
            )
            specularBufferRT = renderer.createRenderTarget(
                width: lightMapWidth,
                height: lightMapHeight
            )
        }

        isNormalMappingInitialized = true
    }

    /// Clean up normal mapping GPU resources.
    private func shutdownNormalMapping(renderer: any RenderBackend) {
        if normalLitPointShader != .invalid { renderer.destroyShader(normalLitPointShader) }
        if normalLitSpotShader != .invalid { renderer.destroyShader(normalLitSpotShader) }
        if specularPointShader != .invalid { renderer.destroyShader(specularPointShader) }
        if specularSpotShader != .invalid { renderer.destroyShader(specularSpotShader) }
        if normalPassShader != .invalid { renderer.destroyShader(normalPassShader) }
        if normalBufferRT != .invalid { renderer.destroyRenderTarget(normalBufferRT) }
        if specularBufferRT != .invalid { renderer.destroyRenderTarget(specularBufferRT) }
        normalLitPointShader = .invalid
        normalLitSpotShader = .invalid
        specularPointShader = .invalid
        specularSpotShader = .invalid
        normalPassShader = .invalid
        normalBufferRT = .invalid
        specularBufferRT = .invalid
        isNormalMappingInitialized = false
    }

    /// Initialize soft shadow GPU resources (blur shaders and render targets).
    private func initializeSoftShadows(renderer: any RenderBackend) {
        guard !isSoftShadowsInitialized else { return }

        shadowBlurHShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: LightingShaders.shadowBlurHorizontalFragment
        )
        shadowBlurVShader = renderer.loadShader(
            vertexSource: nil,
            fragmentSource: LightingShaders.shadowBlurVerticalFragment
        )

        shadowBufferRT = renderer.createRenderTarget(
            width: lightMapWidth,
            height: lightMapHeight
        )
        shadowBlurRT = renderer.createRenderTarget(
            width: lightMapWidth,
            height: lightMapHeight
        )

        isSoftShadowsInitialized = true
    }

    /// Clean up soft shadow GPU resources.
    private func shutdownSoftShadows(renderer: any RenderBackend) {
        if shadowBlurHShader != .invalid { renderer.destroyShader(shadowBlurHShader) }
        if shadowBlurVShader != .invalid { renderer.destroyShader(shadowBlurVShader) }
        if shadowBufferRT != .invalid { renderer.destroyRenderTarget(shadowBufferRT) }
        if shadowBlurRT != .invalid { renderer.destroyRenderTarget(shadowBlurRT) }
        shadowBlurHShader = .invalid
        shadowBlurVShader = .invalid
        shadowBufferRT = .invalid
        shadowBlurRT = .invalid
        isSoftShadowsInitialized = false
    }

    /// Clean up GPU resources. Call in `Scene.willExit`.
    public func shutdown(renderer: any RenderBackend) {
        shutdownNormalMapping(renderer: renderer)
        shutdownSoftShadows(renderer: renderer)
        if pointLightShader != .invalid { renderer.destroyShader(pointLightShader) }
        if spotLightShader != .invalid { renderer.destroyShader(spotLightShader) }
        if lightMapRT != .invalid { renderer.destroyRenderTarget(lightMapRT) }
        if shaderQuadTexture != .invalid { renderer.destroyTexture(shaderQuadTexture) }
        if lightGradientTexture != .invalid { renderer.destroyTexture(lightGradientTexture) }
        if perLightRT != .invalid { renderer.destroyRenderTarget(perLightRT) }
        pointLightShader = .invalid
        spotLightShader = .invalid
        lightMapRT = .invalid
        shaderQuadTexture = .invalid
        lightGradientTexture = .invalid
        perLightRT = .invalid
        isInitialized = false
    }

    // MARK: - System Update

    /// Snapshots light and shadow caster state from the ECS world.
    /// Called automatically each tick when the system is registered.
    public func update(context: SystemContext) {
        let world = context.world

        // Snapshot all enabled lights
        lightSnapshots.removeAll(keepingCapacity: true)
        world.forEach { (_: Entity, transform: inout Transform2D, light: inout Light2D) in
            if light.isEnabled {
                lightSnapshots.append(LightSnapshot(position: transform.position, light: light))
            }
        }

        // Snapshot all enabled shadow casters
        occluderSnapshots.removeAll(keepingCapacity: true)
        world.forEach { (_: Entity, transform: inout Transform2D, collider: inout Collider2D, caster: inout ShadowCaster2D) in
            if caster.isEnabled {
                occluderSnapshots.append(ShadowOccluder(
                    shape: collider.shape,
                    position: transform.position,
                    rotation: transform.rotation,
                    offset: collider.offset
                ))
            }
        }

        // Snapshot normal map entities (only when enabled)
        normalMapSnapshots.removeAll(keepingCapacity: true)
        if options.normalMappingEnabled {
            world.forEach { (_: Entity, transform: inout Transform2D, sprite: inout Sprite, normalData: inout NormalMapData) in
                normalMapSnapshots.append(NormalMapSnapshot(
                    position: transform.position,
                    rotation: transform.rotation,
                    scale: sprite.scale,
                    origin: sprite.origin,
                    sourceRect: sprite.sourceRect,
                    flipX: sprite.flipX,
                    flipY: sprite.flipY,
                    normalMap: normalData.normalMap,
                    specularMap: normalData.specularMap,
                    specularIntensity: normalData.specularIntensity
                ))
            }
        }
    }

    // MARK: - Normal Buffer Rendering

    /// Render normal maps into the normal buffer render target.
    ///
    /// Call this after drawing your scene but before `renderLightMap`. Each entity
    /// with a `NormalMapData` component has its normal map drawn at the same screen
    /// position as its sprite.
    ///
    /// When `options.specularEnabled` is also true, the specular buffer is populated
    /// in the same pass.
    ///
    /// - Parameters:
    ///   - renderer: The render backend.
    ///   - camera: The camera used to draw the scene, or `nil` for no camera transform.
    public func renderNormalBuffer(renderer: any RenderBackend, camera: Camera2D? = nil) {
        guard isInitialized, options.normalMappingEnabled else { return }

        // Lazy-initialize normal mapping resources if not yet done
        if !isNormalMappingInitialized {
            initializeNormalMapping(renderer: renderer)
        }
        guard normalBufferRT != .invalid, normalPassShader != .invalid else { return }

        // Render normal buffer
        renderer.beginRenderTarget(normalBufferRT)

        // Clear with default flat normal (128, 128, 255) = pointing straight up
        renderer.drawRect(
            Rect(x: 0, y: 0, width: Float(lightMapWidth), height: Float(lightMapHeight)),
            color: Color(r: 128, g: 128, b: 255)
        )

        // Draw each entity's normal map at its sprite position
        for snapshot in normalMapSnapshots {
            guard snapshot.normalMap != .invalid else { continue }
            let screenPos = worldToScreen(snapshot.position, camera: camera)
            let zoom = camera?.zoom ?? 1.0

            renderer.beginShader(normalPassShader)
            renderer.drawSprite(Sprite(
                texture: snapshot.normalMap,
                sourceRect: snapshot.sourceRect,
                position: screenPos,
                scale: snapshot.scale * zoom,
                rotation: snapshot.rotation,
                origin: snapshot.origin,
                tint: .white,
                flipX: snapshot.flipX,
                flipY: snapshot.flipY
            ))
            renderer.endShader()
        }

        renderer.endRenderTarget()

        // Render specular buffer if enabled
        if options.specularEnabled, specularBufferRT != .invalid {
            renderer.beginRenderTarget(specularBufferRT)

            // Clear with zero specular
            renderer.drawRect(
                Rect(x: 0, y: 0, width: Float(lightMapWidth), height: Float(lightMapHeight)),
                color: Color(r: 0, g: 0, b: 0)
            )

            for snapshot in normalMapSnapshots {
                let screenPos = worldToScreen(snapshot.position, camera: camera)
                let zoom = camera?.zoom ?? 1.0

                if snapshot.specularMap != .invalid {
                    // Use the specular map texture
                    renderer.drawSprite(Sprite(
                        texture: snapshot.specularMap,
                        sourceRect: snapshot.sourceRect,
                        position: screenPos,
                        scale: snapshot.scale * zoom,
                        rotation: snapshot.rotation,
                        origin: snapshot.origin,
                        tint: .white,
                        flipX: snapshot.flipX,
                        flipY: snapshot.flipY
                    ))
                } else {
                    // Use uniform specular intensity as a solid color
                    let intensity = UInt8(min(max(snapshot.specularIntensity * 255.0, 0), 255))
                    let w = snapshot.sourceRect.width * snapshot.scale.x * zoom
                    let h = snapshot.sourceRect.height * snapshot.scale.y * zoom
                    renderer.drawRect(
                        Rect(
                            x: screenPos.x - snapshot.origin.x * zoom,
                            y: screenPos.y - snapshot.origin.y * zoom,
                            width: w,
                            height: h
                        ),
                        color: Color(r: intensity, g: intensity, b: intensity)
                    )
                }
            }

            renderer.endRenderTarget()
        }
    }

    // MARK: - Light Map Rendering

    /// Render all lights into the light map render target.
    ///
    /// Call this after drawing your scene (and optionally `renderNormalBuffer`)
    /// but before `compositeLightMap`.
    /// The camera parameter is used to convert light world positions to screen positions.
    ///
    /// - Parameters:
    ///   - renderer: The render backend.
    ///   - camera: The camera used to draw the scene, or `nil` for no camera transform.
    public func renderLightMap(renderer: any RenderBackend, camera: Camera2D? = nil) {
        guard isInitialized, lightMapRT != .invalid, perLightRT != .invalid else { return }
        debugFrameCount += 1
        debugTotalShadowVolumes = 0
        debugTotalTriangles = 0
        if debugShadowVolumes { debugShadowData = [] }

        let screenSize = renderer.screenSize
        let resolution = Vector2(
            x: Float(lightMapWidth),
            y: Float(lightMapHeight)
        )
        let clearRect = Rect(x: 0, y: 0, width: Float(lightMapWidth), height: Float(lightMapHeight))

        // Check if normal-mapped rendering is available
        let useNormalMapping = options.normalMappingEnabled && isNormalMappingInitialized
            && normalBufferRT != .invalid
        let useSpecular = useNormalMapping && options.specularEnabled
            && specularBufferRT != .invalid

        // Get normal/specular buffer textures if available
        let normalBufferTexture = useNormalMapping
            ? renderer.renderTargetTexture(normalBufferRT) : .invalid
        let specularBufferTexture = useSpecular
            ? renderer.renderTargetTexture(specularBufferRT) : .invalid

        // Compute default shadow extent (world-space visible diagonal)
        let zoom = camera?.zoom ?? 1.0
        let defaultShadowExtent: Float
        if options.shadowExtent > 0 {
            defaultShadowExtent = options.shadowExtent
        } else {
            // Use world-space visible diagonal so shadows cover the screen but don't over-extend
            let worldW = screenSize.width / zoom
            let worldH = screenSize.height / zoom
            defaultShadowExtent = sqrtf(worldW * worldW + worldH * worldH)
        }

        // Clear light map with ambient color
        renderer.beginRenderTarget(lightMapRT)
        renderer.drawRect(clearRect, color: options.ambientColor)
        renderer.endRenderTarget()

        let flipNormalYInt: Int32 = options.flipNormalY ? 1 : 0
        let perLightTexture = renderer.renderTargetTexture(perLightRT)
        let perLightSize = renderer.renderTargetSize(perLightRT)

        // Draw each light into a per-light buffer, then composite onto the light map.
        // This isolates each light's shadows so they don't erase other lights or ambient.
        for snapshot in lightSnapshots {
            let light = snapshot.light

            // Convert world position to screen position
            let screenPos = worldToScreen(snapshot.position, camera: camera)

            // Scale radius by camera zoom
            let scaledRadius = light.radius * zoom

            // Camera-cull: skip lights fully off-screen
            if screenPos.x + scaledRadius < 0 || screenPos.x - scaledRadius > Float(lightMapWidth) ||
               screenPos.y + scaledRadius < 0 || screenPos.y - scaledRadius > Float(lightMapHeight) {
                continue
            }

            // Compute shadow volumes for this light if needed
            var shadowVolumes: [ShadowVolume] = []
            if light.castsShadows && !occluderSnapshots.isEmpty {
                shadowVolumes = ShadowGeometry.computeShadows(
                    lightPosition: snapshot.position,
                    lightRadius: light.radius,
                    occluders: occluderSnapshots,
                    shadowExtent: min(light.radius * 2, defaultShadowExtent),
                    shadowBloat: options.shadowBloat
                )
            }

            if debugShadowVolumes && !shadowVolumes.isEmpty {
                debugShadowData.append((lightPos: snapshot.position, volumes: shadowVolumes))
            }

            // --- Render this light into the per-light buffer ---
            renderer.beginRenderTarget(perLightRT)

            // Clear to opaque black (shadow areas will stay black = zero contribution)
            renderer.drawRect(clearRect, color: .black)

            // Draw light gradient (additive onto black → produces the light color)
            let diameter = scaledRadius * 2
            let tintR = UInt8(min(255, Float(light.color.r) * light.intensity))
            let tintG = UInt8(min(255, Float(light.color.g) * light.intensity))
            let tintB = UInt8(min(255, Float(light.color.b) * light.intensity))
            let lightTint = Color(r: tintR, g: tintG, b: tintB)
            let gs = Float(lightGradientSize)

            renderer.beginBlendMode(.additive)
            renderer.drawSprite(Sprite(
                texture: lightGradientTexture,
                sourceRect: Rect(x: 0, y: 0, width: gs, height: gs),
                position: Vector2(x: screenPos.x - scaledRadius, y: screenPos.y - scaledRadius),
                scale: Vector2(x: diameter / gs, y: diameter / gs),
                tint: lightTint
            ))
            renderer.endBlendMode()

            // Draw shadow volumes as black triangles.
            // IMPORTANT: Explicitly set alpha blend mode to flush the render batch
            // and ensure we're NOT still in additive mode. With additive blending,
            // black (0,0,0) adds nothing and shadows would be invisible.
            renderer.beginBlendMode(.alpha)
            debugTotalShadowVolumes += shadowVolumes.count
            for shadow in shadowVolumes {
                drawShadowVolume(shadow, renderer: renderer, camera: camera)
            }
            renderer.endBlendMode()

            renderer.endRenderTarget()

            // --- Composite per-light buffer onto the main light map (additive) ---
            if perLightTexture != .invalid {
                renderer.beginRenderTarget(lightMapRT)
                renderer.beginBlendMode(.additive)
                renderer.drawSprite(Sprite(
                    texture: perLightTexture,
                    sourceRect: Rect(x: 0, y: 0, width: perLightSize.width, height: perLightSize.height),
                    position: .zero,
                    tint: .white,
                    flipY: true
                ))
                renderer.endBlendMode()
                renderer.endRenderTarget()
            }

            // Specular pass (additive, after diffuse + shadows)
            // Only runs when normal mapping is enabled and the light has specular.
            if useSpecular && light.specularEnabled {
                let specShader: ShaderHandle
                switch light.lightType {
                case .point:
                    specShader = specularPointShader

                case .spot(let direction, let coneAngle):
                    specShader = specularSpotShader
                    renderer.setShaderVec2(
                        specShader,
                        name: "lightDirection",
                        value: Vector2(x: cosf(direction), y: sinf(direction))
                    )
                    renderer.setShaderFloat(specShader, name: "lightConeAngle", value: coneAngle)
                }

                renderer.setShaderVec2(specShader, name: "lightPos", value: screenPos)
                renderer.setShaderVec3(
                    specShader,
                    name: "lightColor",
                    x: Float(light.color.r) / 255.0,
                    y: Float(light.color.g) / 255.0,
                    z: Float(light.color.b) / 255.0
                )
                renderer.setShaderFloat(specShader, name: "lightRadius", value: scaledRadius)
                renderer.setShaderFloat(specShader, name: "lightIntensity", value: light.intensity)
                renderer.setShaderFloat(specShader, name: "lightFalloff", value: light.falloff)
                renderer.setShaderVec2(specShader, name: "resolution", value: resolution)
                renderer.setShaderTexture(specShader, name: "normalBuffer", texture: normalBufferTexture)
                renderer.setShaderTexture(specShader, name: "specularBuffer", texture: specularBufferTexture)
                renderer.setShaderFloat(specShader, name: "lightZ", value: light.zHeight)
                renderer.setShaderInt(specShader, name: "flipNormalY", value: flipNormalYInt)
                renderer.setShaderFloat(specShader, name: "specularStrength", value: light.specularStrength)
                renderer.setShaderFloat(specShader, name: "shininess", value: 32.0)
                renderer.setShaderInt(specShader, name: "useShadowBuffer", value: 0)

                renderer.beginRenderTarget(lightMapRT)
                renderer.beginBlendMode(.additive)
                renderer.beginShader(specShader)
                drawShaderQuad(renderer: renderer)
                renderer.endShader()
                renderer.endBlendMode()
                renderer.endRenderTarget()
            }
        }
    }

    /// Composite the light map onto the scene using multiply blending.
    ///
    /// Call this after `renderLightMap`. The light map is drawn as a full-screen
    /// overlay using `BlendMode.multiplied`, which darkens unlit areas and preserves
    /// lit areas.
    ///
    /// - Parameter renderer: The render backend.
    public func compositeLightMap(renderer: any RenderBackend) {
        guard isInitialized, lightMapRT != .invalid else { return }

        let texture = renderer.renderTargetTexture(lightMapRT)
        guard texture != .invalid else { return }

        let screenSize = renderer.screenSize
        let rtSize = renderer.renderTargetSize(lightMapRT)
        guard rtSize.width > 0 && rtSize.height > 0 else { return }

        renderer.beginBlendMode(.multiplied)
        renderer.drawSprite(Sprite(
            texture: texture,
            sourceRect: Rect(x: 0, y: 0, width: rtSize.width, height: rtSize.height),
            position: .zero,
            scale: Vector2(
                x: screenSize.width / rtSize.width,
                y: screenSize.height / rtSize.height
            ),
            tint: .white,
            flipY: true
        ))
        renderer.endBlendMode()
    }

    // MARK: - Debug

    /// The normal buffer render target, for debug rendering.
    /// Returns `.invalid` if normal mapping is not initialized.
    var normalBufferHandle: RenderTargetHandle { normalBufferRT }

    /// The specular buffer render target, for debug rendering.
    /// Returns `.invalid` if specular is not initialized.
    var specularBufferHandle: RenderTargetHandle { specularBufferRT }

    /// The shadow buffer render target, for debug rendering.
    /// Returns `.invalid` if soft shadows are not initialized.
    var shadowBufferHandle: RenderTargetHandle { shadowBufferRT }

    /// Number of light snapshots from the last update tick.
    public var debugLightCount: Int { lightSnapshots.count }

    /// Number of occluder snapshots from the last update tick.
    public var debugOccluderCount: Int { occluderSnapshots.count }

    /// Light snapshot positions (world-space) for debug display.
    public var debugLightPositions: [(position: Vector2, radius: Float, color: Color)] {
        lightSnapshots.map { ($0.position, $0.light.radius, $0.light.color) }
    }

    /// The light map render target handle, for debug thumbnail.
    public var debugLightMapHandle: RenderTargetHandle { lightMapRT }

    /// The per-light render target handle, for debug thumbnail.
    public var debugPerLightHandle: RenderTargetHandle { perLightRT }

    /// Draw debug overlays: light map thumbnail, per-light thumbnail, stats text.
    ///
    /// Call after `compositeLightMap` in screen space.
    public func drawDebugOverlay(renderer: any RenderBackend, font: FontHandle, camera: Camera2D?) {
        let screenSize = renderer.screenSize

        // Thumbnail size (25% of screen)
        let thumbW = screenSize.width * 0.25
        let thumbH = screenSize.height * 0.25
        let padding: Float = 4
        let textSize: Float = 11

        // --- Light map thumbnail (top-left) ---
        let lmTex = renderer.renderTargetTexture(lightMapRT)
        if lmTex != .invalid {
            let rtSize = renderer.renderTargetSize(lightMapRT)
            let x: Float = padding
            let y: Float = padding + 14

            // Label
            renderer.drawText(
                "Light Map (\(lightMapWidth)x\(lightMapHeight))",
                position: Vector2(x: x, y: y - 13),
                font: font,
                size: textSize,
                color: .white
            )

            // Border
            renderer.drawRectOutline(
                Rect(x: x - 1, y: y - 1, width: thumbW + 2, height: thumbH + 2),
                color: .white,
                thickness: 1
            )

            // Thumbnail (no multiply blend — show raw light map colors)
            renderer.drawSprite(Sprite(
                texture: lmTex,
                sourceRect: Rect(x: 0, y: 0, width: rtSize.width, height: rtSize.height),
                position: Vector2(x: x, y: y),
                scale: Vector2(x: thumbW / rtSize.width, y: thumbH / rtSize.height),
                tint: .white,
                flipY: true
            ))
        }

        // --- Per-light buffer thumbnail (below light map) ---
        let plTex = renderer.renderTargetTexture(perLightRT)
        if plTex != .invalid {
            let rtSize = renderer.renderTargetSize(perLightRT)
            let x: Float = padding
            let y: Float = padding + 14 + thumbH + 20 + 14

            renderer.drawText(
                "Per-Light Buffer (last)",
                position: Vector2(x: x, y: y - 13),
                font: font,
                size: textSize,
                color: .white
            )

            renderer.drawRectOutline(
                Rect(x: x - 1, y: y - 1, width: thumbW + 2, height: thumbH + 2),
                color: .yellow,
                thickness: 1
            )

            renderer.drawSprite(Sprite(
                texture: plTex,
                sourceRect: Rect(x: 0, y: 0, width: rtSize.width, height: rtSize.height),
                position: Vector2(x: x, y: y),
                scale: Vector2(x: thumbW / rtSize.width, y: thumbH / rtSize.height),
                tint: .white,
                flipY: true
            ))
        }

        // --- Stats text (right side) ---
        let statsX = screenSize.width - 220
        var statsY: Float = padding

        let gray = Color(r: 180, g: 180, b: 180)
        let okColor = Color(r: 100, g: 255, b: 100)
        let missingColor = Color(r: 255, g: 80, b: 80)
        let ambientR = options.ambientColor.r
        let ambientG = options.ambientColor.g
        let ambientB = options.ambientColor.b
        let gradientOk = lightGradientTexture != .invalid
        let perLightOk = perLightRT != .invalid
        let lightMapOk = lightMapRT != .invalid
        let lines: [(String, Color)] = [
            ("-- Lighting Debug --", .white),
            ("Lights: \(lightSnapshots.count)", .yellow),
            ("Occluders: \(occluderSnapshots.count)", .yellow),
            ("LightMap: \(lightMapWidth)x\(lightMapHeight)", gray),
            ("Ambient: (\(ambientR),\(ambientG),\(ambientB))", gray),
            (
                "Gradient tex: \(gradientOk ? "OK" : "MISSING")",
                gradientOk ? okColor : missingColor
            ),
            (
                "PerLight RT: \(perLightOk ? "OK" : "MISSING")",
                perLightOk ? okColor : missingColor
            ),
            (
                "LightMap RT: \(lightMapOk ? "OK" : "MISSING")",
                lightMapOk ? okColor : missingColor
            )
        ]

        for (text, color) in lines {
            renderer.drawText(
                text,
                position: Vector2(x: statsX, y: statsY),
                font: font,
                size: textSize,
                color: color
            )
            statsY += 14
        }

        // Per-light details
        statsY += 4
        for (i, snapshot) in lightSnapshots.enumerated() {
            let light = snapshot.light
            let screenPos = worldToScreen(snapshot.position, camera: camera)
            let typeStr: String
            switch light.lightType {
            case .point: typeStr = "pt"

            case .spot: typeStr = "sp"
            }
            let posX = Int(snapshot.position.x)
            let posY = Int(snapshot.position.y)
            let scrX = Int(screenPos.x)
            let scrY = Int(screenPos.y)
            let intensityStr = String(format: "%.1f", light.intensity)
            let text = "L\(i) \(typeStr) pos=(\(posX),\(posY))"
                + " scr=(\(scrX),\(scrY))"
                + " r=\(Int(light.radius)) i=\(intensityStr)"
            let detailColor = Color(r: 200, g: 200, b: 200)
            renderer.drawText(
                text,
                position: Vector2(x: statsX, y: statsY),
                font: font,
                size: 9,
                color: detailColor
            )
            statsY += 12
        }

        // Shadow caster count per type
        statsY += 4
        var aabbCount = 0, circleCount = 0, polyCount = 0
        for occ in occluderSnapshots {
            switch occ.shape {
            case .aabb: aabbCount += 1

            case .circle: circleCount += 1

            case .polygon: polyCount += 1
            }
        }
        renderer.drawText(
            "Occluders: \(aabbCount) aabb, \(circleCount) circle, \(polyCount) poly",
            position: Vector2(x: statsX, y: statsY),
            font: font,
            size: 9,
            color: Color(r: 200, g: 200, b: 200)
        )
    }

    // MARK: - Helpers

    /// Convert a world-space position to screen-space position using the camera.
    private func worldToScreen(_ worldPos: Vector2, camera: Camera2D?) -> Vector2 {
        guard let camera = camera else { return worldPos }
        let zoom = camera.zoom
        return Vector2(
            x: (worldPos.x - camera.target.x) * zoom + camera.offset.x,
            y: (worldPos.y - camera.target.y) * zoom + camera.offset.y
        )
    }

    /// Draw a full-screen textured quad for shader passes.
    /// Uses a 1x1 white texture so fragTexCoord maps 0-1 across the quad,
    /// which drawRect cannot provide (white pixel texture has wrong UVs).
    private func drawShaderQuad(renderer: any RenderBackend) {
        renderer.drawSprite(Sprite(
            texture: shaderQuadTexture,
            sourceRect: Rect(x: 0, y: 0, width: 1, height: 1),
            scale: Vector2(x: Float(lightMapWidth), y: Float(lightMapHeight)),
            tint: .white
        ))
    }

    /// Draw a shadow volume as filled black triangles to subtract light.
    ///
    /// Shadow polygon structure from ShadowGeometry:
    ///   [projA, wallA, wallV1, ..., wallB, projB]
    /// where wall vertices (indices 1..count-2) are on the occluder's back face
    /// and projA/projB are the far projected silhouette vertices.
    ///
    /// Uses triangle fan from projA (vertex 0). The shadow polygon is always
    /// star-shaped from projA because it is at the extremity of the shadow,
    /// with all other vertices visible from it.
    private func drawShadowVolume(_ shadow: ShadowVolume, renderer: any RenderBackend, camera: Camera2D?) {
        let verts = shadow.vertices
        let count = verts.count
        guard count >= 4 else { return } // minimum: projA, wallA, wallB, projB

        let screenVerts = verts.map { worldToScreen($0, camera: camera) }

        // Fan from projA (vertex 0) to all other edges
        let anchor = screenVerts[0]
        for i in 1..<(count - 1) {
            drawTriCCW(anchor, screenVerts[i], screenVerts[i + 1], renderer: renderer)
        }
    }

    /// Draw a triangle with automatic CCW winding (GL_CULL_FACE may be enabled).
    private func drawTriCCW(_ a: Vector2, _ b: Vector2, _ c: Vector2, renderer: any RenderBackend) {
        let cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        if cross > 0 {
            debugTotalTriangles += 1
            renderer.drawTriangle(a, b, c, color: .black)
        } else if cross < 0 {
            debugTotalTriangles += 1
            renderer.drawTriangle(a, c, b, color: .black)
        }
    }

    /// Debug info string for HUD display.
    public var debugShadowInfo: String {
        "ShadowVols: \(debugTotalShadowVolumes)  Tris: \(debugTotalTriangles)"
    }

    /// Draw shadow volume outlines and occluder outlines for visual debugging.
    ///
    /// Call AFTER `compositeLightMap`, inside `beginCamera`/`endCamera`.
    /// Requires `debugShadowVolumes = true` to be set before rendering.
    ///
    /// Colors:
    /// - Magenta outlines: shadow caster colliders (occluders)
    /// - Yellow dot: light position
    /// - Green outlines: shadow volume polygons (what actually blocks light)
    /// - Red dots: shadow polygon vertices
    /// - Cyan outlines: corner shadow casters (small ones)
    public func drawShadowDebug(renderer: any RenderBackend) {
        guard debugShadowVolumes else { return }

        // Draw occluder outlines
        for occluder in occluderSnapshots {
            let pos = occluder.position + occluder.offset
            switch occluder.shape {
            case .aabb(let he):
                let size = Vector2(x: he.x * 2, y: he.y * 2)
                let isTiny = he.x < 10 || he.y < 10  // corner shadow casters
                let color = isTiny ? Color(r: 0, g: 255, b: 255) : Color(r: 255, g: 0, b: 255)
                renderer.drawRectOutline(
                    Rect(x: pos.x - he.x, y: pos.y - he.y, width: size.x, height: size.y),
                    color: color,
                    thickness: isTiny ? 1 : 2
                )

            case .circle(let r):
                renderer.drawCircleOutline(
                    center: pos,
                    radius: r,
                    color: Color(r: 255, g: 0, b: 255),
                    thickness: 2
                )

            case .polygon(let poly):
                let worldVerts = ShadowGeometry.transformVertices(
                    poly.vertices,
                    position: pos,
                    rotation: occluder.rotation
                )
                let magenta = Color(r: 255, g: 0, b: 255)
                for i in 0..<worldVerts.count {
                    let j = (i + 1) % worldVerts.count
                    renderer.drawLine(
                        from: worldVerts[i],
                        to: worldVerts[j],
                        color: magenta,
                        thickness: 2
                    )
                }
            }
        }

        // Draw shadow volume outlines per light
        let colors: [Color] = [
            Color(r: 0, g: 255, b: 0),      // green
            Color(r: 0, g: 200, b: 255),     // light blue
            Color(r: 255, g: 255, b: 0),     // yellow
            Color(r: 255, g: 128, b: 0)     // orange
        ]

        for (lightIdx, entry) in debugShadowData.enumerated() {
            // Light position marker
            renderer.drawCircle(center: entry.lightPos, radius: 4, color: Color(r: 255, g: 255, b: 0))

            let color = colors[lightIdx % colors.count]

            for shadow in entry.volumes {
                let verts = shadow.vertices
                guard verts.count >= 3 else { continue }

                // Draw shadow polygon outline
                for i in 0..<verts.count {
                    let j = (i + 1) % verts.count
                    renderer.drawLine(from: verts[i], to: verts[j], color: color, thickness: 1)
                }

                // Mark vertices - wall vertices in red, proj vertices in white
                for (i, v) in verts.enumerated() {
                    let isProj = i == 0 || i == verts.count - 1
                    let dotColor = isProj ? Color(r: 255, g: 255, b: 255) : Color(r: 255, g: 0, b: 0)
                    renderer.drawCircle(center: v, radius: isProj ? 3 : 2, color: dotColor)
                }
            }
        }
    }
}
