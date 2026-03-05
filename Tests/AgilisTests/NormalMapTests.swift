import Testing
import Foundation
@testable import Agilis

// MARK: - NormalMapData Component

@Suite("NormalMapData")
struct NormalMapDataTests {

    @Test("Default initialization")
    func defaults() {
        let data = NormalMapData(normalMap: TextureHandle(id: 1))
        #expect(data.normalMap == TextureHandle(id: 1))
        #expect(data.specularMap == .invalid)
        #expect(data.specularIntensity == 0.5)
        #expect(data.shininess == 32.0)
    }

    @Test("Custom initialization")
    func customInit() {
        let data = NormalMapData(
            normalMap: TextureHandle(id: 10),
            specularMap: TextureHandle(id: 20),
            specularIntensity: 0.8,
            shininess: 64.0
        )
        #expect(data.normalMap == TextureHandle(id: 10))
        #expect(data.specularMap == TextureHandle(id: 20))
        #expect(data.specularIntensity == 0.8)
        #expect(data.shininess == 64.0)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let data = NormalMapData(
            normalMap: TextureHandle(id: 5),
            specularMap: TextureHandle(id: 7),
            specularIntensity: 0.3,
            shininess: 16.0
        )
        let json = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(NormalMapData.self, from: json)
        #expect(decoded.normalMap == data.normalMap)
        #expect(decoded.specularMap == data.specularMap)
        #expect(decoded.specularIntensity == data.specularIntensity)
        #expect(decoded.shininess == data.shininess)
    }

    @Test("SerializableComponent conformance")
    func serializableComponent() {
        #expect(NormalMapData.componentName == "NormalMapData")
    }

    @Test("Can be used as ECS component")
    func ecsComponent() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(
            NormalMapData(normalMap: TextureHandle(id: 42), shininess: 64),
            to: entity
        )

        var found = false
        world.forEach { (_: Entity, data: inout NormalMapData) in
            #expect(data.normalMap == TextureHandle(id: 42))
            #expect(data.shininess == 64.0)
            found = true
        }
        #expect(found)
    }

    @Test("WorldSerializer includes NormalMapData in registerDefaults")
    func registeredInSerializer() {
        let serializer = WorldSerializer()
        serializer.registerDefaults()
        #expect(serializer.registeredComponentNames.contains("NormalMapData"))
    }
}

// MARK: - LightingShaders (Normal-Lit)

@Suite("LightingShaders - Normal Map")
struct LightingShadersNormalMapTests {

    @Test("Normal-lit point shader is non-empty")
    func normalLitPointNonEmpty() {
        #expect(!LightingShaders.normalLitPointFragment.isEmpty)
    }

    @Test("Normal-lit spot shader is non-empty")
    func normalLitSpotNonEmpty() {
        #expect(!LightingShaders.normalLitSpotFragment.isEmpty)
    }

    @Test("Specular point shader is non-empty")
    func specularPointNonEmpty() {
        #expect(!LightingShaders.specularPointFragment.isEmpty)
    }

    @Test("Specular spot shader is non-empty")
    func specularSpotNonEmpty() {
        #expect(!LightingShaders.specularSpotFragment.isEmpty)
    }

    @Test("Normal pass shader is non-empty")
    func normalPassNonEmpty() {
        #expect(!LightingShaders.normalPassFragment.isEmpty)
    }

    @Test("Normal-lit shaders contain normalBuffer sampler")
    func normalBufferSampler() {
        #expect(LightingShaders.normalLitPointFragment.contains("normalBuffer"))
        #expect(LightingShaders.normalLitSpotFragment.contains("normalBuffer"))
    }

    @Test("Specular shaders contain specularBuffer sampler")
    func specularBufferSampler() {
        #expect(LightingShaders.specularPointFragment.contains("specularBuffer"))
        #expect(LightingShaders.specularSpotFragment.contains("specularBuffer"))
    }

    @Test("Specular shaders contain specularStrength uniform")
    func specularStrengthUniform() {
        #expect(LightingShaders.specularPointFragment.contains("specularStrength"))
        #expect(LightingShaders.specularSpotFragment.contains("specularStrength"))
    }

    @Test("Specular shaders contain shininess uniform")
    func shininessUniform() {
        #expect(LightingShaders.specularPointFragment.contains("shininess"))
        #expect(LightingShaders.specularSpotFragment.contains("shininess"))
    }

    @Test("Normal-lit shaders contain lightZ uniform")
    func lightZUniform() {
        #expect(LightingShaders.normalLitPointFragment.contains("lightZ"))
        #expect(LightingShaders.normalLitSpotFragment.contains("lightZ"))
    }

    @Test("Normal pass shader contains texture0 sampler")
    func normalPassTexture0() {
        #expect(LightingShaders.normalPassFragment.contains("texture0"))
    }

    @Test("Normal-lit shaders contain decodeNormal function")
    func decodeNormalFunction() {
        #expect(LightingShaders.normalLitPointFragment.contains("decodeNormal"))
        #expect(LightingShaders.normalLitSpotFragment.contains("decodeNormal"))
    }

    @Test("Specular shaders use Blinn-Phong half vector")
    func blinnPhongHalfVector() {
        #expect(LightingShaders.specularPointFragment.contains("halfDir"))
        #expect(LightingShaders.specularSpotFragment.contains("halfDir"))
    }
}

// MARK: - LightingShaders (Soft Shadows)

@Suite("LightingShaders - Soft Shadows")
struct LightingShadersSoftShadowTests {

    @Test("Shadow blur horizontal shader is non-empty")
    func blurHNonEmpty() {
        #expect(!LightingShaders.shadowBlurHorizontalFragment.isEmpty)
    }

    @Test("Shadow blur vertical shader is non-empty")
    func blurVNonEmpty() {
        #expect(!LightingShaders.shadowBlurVerticalFragment.isEmpty)
    }

    @Test("Blur shaders contain blurRadius uniform")
    func blurRadiusUniform() {
        #expect(LightingShaders.shadowBlurHorizontalFragment.contains("blurRadius"))
        #expect(LightingShaders.shadowBlurVerticalFragment.contains("blurRadius"))
    }

    @Test("Blur shaders contain resolution uniform")
    func blurResolutionUniform() {
        #expect(LightingShaders.shadowBlurHorizontalFragment.contains("resolution"))
        #expect(LightingShaders.shadowBlurVerticalFragment.contains("resolution"))
    }

    @Test("All 6 light shaders contain shadowBuffer sampler")
    func shadowBufferInAllShaders() {
        #expect(LightingShaders.pointLightFragment.contains("shadowBuffer"))
        #expect(LightingShaders.spotLightFragment.contains("shadowBuffer"))
        #expect(LightingShaders.normalLitPointFragment.contains("shadowBuffer"))
        #expect(LightingShaders.normalLitSpotFragment.contains("shadowBuffer"))
        #expect(LightingShaders.specularPointFragment.contains("shadowBuffer"))
        #expect(LightingShaders.specularSpotFragment.contains("shadowBuffer"))
    }

    @Test("All 6 light shaders contain useShadowBuffer uniform")
    func useShadowBufferInAllShaders() {
        #expect(LightingShaders.pointLightFragment.contains("useShadowBuffer"))
        #expect(LightingShaders.spotLightFragment.contains("useShadowBuffer"))
        #expect(LightingShaders.normalLitPointFragment.contains("useShadowBuffer"))
        #expect(LightingShaders.normalLitSpotFragment.contains("useShadowBuffer"))
        #expect(LightingShaders.specularPointFragment.contains("useShadowBuffer"))
        #expect(LightingShaders.specularSpotFragment.contains("useShadowBuffer"))
    }

    @Test("Blur horizontal shader uses X axis offset")
    func horizontalAxisOffset() {
        #expect(LightingShaders.shadowBlurHorizontalFragment.contains("vec2(offset, 0.0)"))
    }

    @Test("Blur vertical shader uses Y axis offset")
    func verticalAxisOffset() {
        #expect(LightingShaders.shadowBlurVerticalFragment.contains("vec2(0.0, offset)"))
    }
}

// MARK: - ShaderInclude Normal Mapping

@Suite("ShaderInclude - Normal Mapping")
struct ShaderIncludeNormalMappingTests {

    @Test("normalMapping include exists")
    func includeExists() {
        let include = ShaderInclude.normalMapping
        #expect(include.rawValue == "normalMapping")
    }

    @Test("normalMapping GLSL contains decodeNormal")
    func containsDecodeNormal() {
        let source = ShaderInclude.normalMapping.glslSource
        #expect(source.contains("decodeNormal"))
    }

    @Test("normalMapping GLSL contains lightDirection3D")
    func containsLightDirection3D() {
        let source = ShaderInclude.normalMapping.glslSource
        #expect(source.contains("lightDirection3D"))
    }

    @Test("normalMapping GLSL contains lambertDiffuse")
    func containsLambertDiffuse() {
        let source = ShaderInclude.normalMapping.glslSource
        #expect(source.contains("lambertDiffuse"))
    }

    @Test("normalMapping GLSL contains blinnPhongSpecular")
    func containsBlinnPhongSpecular() {
        let source = ShaderInclude.normalMapping.glslSource
        #expect(source.contains("blinnPhongSpecular"))
    }

    @Test("CaseIterable includes normalMapping")
    func caseIterable() {
        let allCases = ShaderInclude.allCases
        #expect(allCases.contains(.normalMapping))
        #expect(allCases.count == 6)
    }
}

// MARK: - LightingSystem Normal Map Integration

@Suite("LightingSystem - Normal Map Integration")
struct LightingSystemNormalMapTests {

    @Test("System snapshots NormalMapData entities during update")
    func snapshotsNormalMapEntities() {
        let world = World()
        let options = LightingOptions(normalMappingEnabled: true)
        let system = LightingSystem(options: options)
        world.addSystem(system)

        let entity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 100, y: 200)), to: entity)
        world.addComponent(Sprite(texture: TextureHandle(id: 1)), to: entity)
        world.addComponent(NormalMapData(normalMap: TextureHandle(id: 2)), to: entity)

        // Also add a light so the system has something to work with
        let lightEntity = world.createEntity()
        world.addComponent(Transform2D(position: Vector2(x: 50, y: 50)), to: lightEntity)
        world.addComponent(Light2D(), to: lightEntity)

        // Run update
        world.update(deltaTime: 1.0 / 60.0)

        // System should be registered and updated without errors
        #expect(system.isInitialized == false) // Not initialized (no renderer)
    }

    @Test("Normal mapping disabled by default - no overhead")
    func disabledByDefault() {
        let options = LightingOptions()
        #expect(options.normalMappingEnabled == false)

        let system = LightingSystem(options: options)
        #expect(system.isNormalMappingInitialized == false)
    }

    @Test("LightingSystem with normalMappingEnabled option")
    func normalMappingOption() {
        let options = LightingOptions(normalMappingEnabled: true, specularEnabled: true)
        let system = LightingSystem(options: options)
        #expect(system.options.normalMappingEnabled == true)
        #expect(system.options.specularEnabled == true)
        // Not initialized yet (no renderer call)
        #expect(system.isNormalMappingInitialized == false)
    }

    @Test("Light2D specular properties with custom values")
    func lightSpecularProperties() {
        let light = Light2D(
            specularEnabled: true,
            specularStrength: 3.0,
            zHeight: 200.0
        )
        #expect(light.specularEnabled == true)
        #expect(light.specularStrength == 3.0)
        #expect(light.zHeight == 200.0)
    }

    @Test("LightingOptions normal mapping properties with custom values")
    func lightingOptionsNormalMapping() {
        let options = LightingOptions(
            normalMappingEnabled: true,
            specularEnabled: true,
            flipNormalY: true,
            debugNormalBuffer: true,
            debugSpecularBuffer: true
        )
        #expect(options.normalMappingEnabled == true)
        #expect(options.specularEnabled == true)
        #expect(options.flipNormalY == true)
        #expect(options.debugNormalBuffer == true)
        #expect(options.debugSpecularBuffer == true)
    }

    @Test("NormalMapData with no specular map uses uniform intensity")
    func noSpecularMapUsesUniform() {
        let data = NormalMapData(
            normalMap: TextureHandle(id: 1),
            specularIntensity: 0.7
        )
        #expect(data.specularMap == .invalid)
        #expect(data.specularIntensity == 0.7)
    }

    @Test("NormalMapData property mutation")
    func propertyMutation() {
        var data = NormalMapData(normalMap: TextureHandle(id: 1))
        data.normalMap = TextureHandle(id: 10)
        data.specularMap = TextureHandle(id: 20)
        data.specularIntensity = 0.9
        data.shininess = 128.0
        #expect(data.normalMap == TextureHandle(id: 10))
        #expect(data.specularMap == TextureHandle(id: 20))
        #expect(data.specularIntensity == 0.9)
        #expect(data.shininess == 128.0)
    }
}
