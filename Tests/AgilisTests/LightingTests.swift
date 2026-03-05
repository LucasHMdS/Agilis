import Testing
import Foundation
@testable import Agilis

// MARK: - ShaderHandle

@Suite("ShaderHandle")
struct ShaderHandleTests {

    @Test("Invalid handle has id 0")
    func invalidHandle() {
        let handle = ShaderHandle.invalid
        #expect(handle.id == 0)
    }

    @Test("Handle creation with custom id")
    func customId() {
        let handle = ShaderHandle(id: 42)
        #expect(handle.id == 42)
    }

    @Test("Handles with same id are equal")
    func equality() {
        let a = ShaderHandle(id: 5)
        let b = ShaderHandle(id: 5)
        #expect(a == b)
    }

    @Test("Handles with different ids are not equal")
    func inequality() {
        let a = ShaderHandle(id: 1)
        let b = ShaderHandle(id: 2)
        #expect(a != b)
    }

    @Test("Handle is Hashable (usable as dictionary key)")
    func hashable() {
        var dict: [ShaderHandle: String] = [:]
        dict[ShaderHandle(id: 1)] = "test"
        #expect(dict[ShaderHandle(id: 1)] == "test")
    }
}

// MARK: - Light2D Component

@Suite("Light2D")
struct Light2DTests {

    @Test("Default initialization")
    func defaults() {
        let light = Light2D()
        #expect(light.lightType == .point)
        #expect(light.color == .white)
        #expect(light.intensity == 1.0)
        #expect(light.radius == 200)
        #expect(light.castsShadows == false)
        #expect(light.falloff == 1.0)
        #expect(light.isEnabled == true)
        #expect(light.shadowLayerMask == 0xFFFF_FFFF)
        #expect(light.specularEnabled == false)
        #expect(light.specularStrength == 1.0)
        #expect(light.zHeight == 100.0)
        #expect(light.softShadowRadius == 0.0)
    }

    @Test("Custom initialization")
    func customInit() {
        let light = Light2D(
            lightType: .spot(direction: 1.5, coneAngle: 0.5),
            color: .red,
            intensity: 2.0,
            radius: 500,
            castsShadows: true,
            falloff: 2.0,
            isEnabled: false,
            shadowLayerMask: 0x0F
        )
        #expect(light.color == .red)
        #expect(light.intensity == 2.0)
        #expect(light.radius == 500)
        #expect(light.castsShadows == true)
        #expect(light.falloff == 2.0)
        #expect(light.isEnabled == false)
        #expect(light.shadowLayerMask == 0x0F)

        if case .spot(let dir, let cone) = light.lightType {
            #expect(abs(dir - 1.5) < 0.001)
            #expect(abs(cone - 0.5) < 0.001)
        } else {
            Issue.record("Expected spot light type")
        }
    }

    @Test("Property modification")
    func propertyModification() {
        var light = Light2D()
        light.intensity = 3.0
        light.radius = 100
        light.isEnabled = false
        #expect(light.intensity == 3.0)
        #expect(light.radius == 100)
        #expect(light.isEnabled == false)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let light = Light2D(
            lightType: .point,
            color: Color(r: 255, g: 128, b: 64),
            intensity: 1.5,
            radius: 300,
            castsShadows: true,
            falloff: 2.0,
            specularEnabled: true,
            specularStrength: 2.5,
            zHeight: 50.0,
            softShadowRadius: 8.0
        )
        let data = try JSONEncoder().encode(light)
        let decoded = try JSONDecoder().decode(Light2D.self, from: data)
        #expect(decoded.color == light.color)
        #expect(decoded.intensity == light.intensity)
        #expect(decoded.radius == light.radius)
        #expect(decoded.castsShadows == light.castsShadows)
        #expect(decoded.falloff == light.falloff)
        #expect(decoded.specularEnabled == true)
        #expect(decoded.specularStrength == 2.5)
        #expect(decoded.zHeight == 50.0)
        #expect(decoded.softShadowRadius == 8.0)
    }

    @Test("Codable backward compatibility - missing new fields use defaults")
    func codableBackwardCompatibility() throws {
        // Simulate old JSON without specular/zHeight/softShadowRadius fields
        let json = """
        {"lightType":{"point":{}},"color":{"r":255,"g":255,"b":255,"a":255},"intensity":1.0,"radius":200,"castsShadows":false,"falloff":1.0,"isEnabled":true,"shadowLayerMask":4294967295}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Light2D.self, from: data)
        #expect(decoded.specularEnabled == false)
        #expect(decoded.specularStrength == 1.0)
        #expect(decoded.zHeight == 100.0)
        #expect(decoded.softShadowRadius == 0.0)
    }

    @Test("Spotlight codable round-trip")
    func spotlightCodable() throws {
        let light = Light2D(lightType: .spot(direction: 1.0, coneAngle: 0.3))
        let data = try JSONEncoder().encode(light)
        let decoded = try JSONDecoder().decode(Light2D.self, from: data)
        if case .spot(let dir, let cone) = decoded.lightType {
            #expect(abs(dir - 1.0) < 0.001)
            #expect(abs(cone - 0.3) < 0.001)
        } else {
            Issue.record("Expected spot light type after decode")
        }
    }

    @Test("Can be used as ECS component")
    func ecsComponent() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Light2D(color: .yellow, intensity: 2.0), to: entity)

        var found = false
        world.forEach { (_: Entity, light: inout Light2D) in
            #expect(light.color == .yellow)
            #expect(light.intensity == 2.0)
            found = true
        }
        #expect(found)
    }
}

// MARK: - ShadowCaster2D Component

@Suite("ShadowCaster2D")
struct ShadowCaster2DTests {

    @Test("Default initialization")
    func defaults() {
        let caster = ShadowCaster2D()
        #expect(caster.layer == 1)
        #expect(caster.isEnabled == true)
    }

    @Test("Custom initialization")
    func customInit() {
        let caster = ShadowCaster2D(layer: 0x04, isEnabled: false)
        #expect(caster.layer == 0x04)
        #expect(caster.isEnabled == false)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let caster = ShadowCaster2D(layer: 0xFF, isEnabled: true)
        let data = try JSONEncoder().encode(caster)
        let decoded = try JSONDecoder().decode(ShadowCaster2D.self, from: data)
        #expect(decoded.layer == caster.layer)
        #expect(decoded.isEnabled == caster.isEnabled)
    }

    @Test("Can be used as ECS component")
    func ecsComponent() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(ShadowCaster2D(layer: 3), to: entity)

        var found = false
        world.forEach { (_: Entity, caster: inout ShadowCaster2D) in
            #expect(caster.layer == 3)
            found = true
        }
        #expect(found)
    }
}

// MARK: - LightingOptions

@Suite("LightingOptions")
struct LightingOptionsTests {

    @Test("Default initialization")
    func defaults() {
        let options = LightingOptions()
        #expect(options.ambientColor == Color(r: 30, g: 30, b: 40))
        #expect(options.lightMapScale == 1.0)
        #expect(options.shadowExtent == 0)
        #expect(options.debugDraw == false)
        #expect(options.normalMappingEnabled == false)
        #expect(options.specularEnabled == false)
        #expect(options.flipNormalY == false)
        #expect(options.debugNormalBuffer == false)
        #expect(options.debugSpecularBuffer == false)
        #expect(options.softShadows == false)
        #expect(options.softShadowRadius == 4.0)
        #expect(options.softShadowQuality == .medium)
        #expect(options.debugShadowBuffer == false)
    }

    @Test("Custom initialization")
    func customInit() {
        let options = LightingOptions(
            ambientColor: .black,
            lightMapScale: 0.5,
            shadowExtent: 2000,
            debugDraw: true
        )
        #expect(options.ambientColor == .black)
        #expect(options.lightMapScale == 0.5)
        #expect(options.shadowExtent == 2000)
        #expect(options.debugDraw == true)
    }

    @Test("Properties are mutable")
    func mutable() {
        var options = LightingOptions()
        options.ambientColor = .red
        options.debugDraw = true
        #expect(options.ambientColor == .red)
        #expect(options.debugDraw == true)
    }
}

// MARK: - LightType

@Suite("LightType")
struct LightTypeTests {

    @Test("Point lights are equal")
    func pointEquality() {
        #expect(LightType.point == LightType.point)
    }

    @Test("Spot lights with same params are equal")
    func spotEquality() {
        let a = LightType.spot(direction: 1.0, coneAngle: 0.5)
        let b = LightType.spot(direction: 1.0, coneAngle: 0.5)
        #expect(a == b)
    }

    @Test("Point and spot are not equal")
    func pointVsSpot() {
        #expect(LightType.point != LightType.spot(direction: 0, coneAngle: 0.5))
    }
}

// MARK: - Soft Shadows

@Suite("SoftShadowQuality")
struct SoftShadowQualityTests {

    @Test("Raw values")
    func rawValues() {
        #expect(SoftShadowQuality.low.rawValue == 1)
        #expect(SoftShadowQuality.medium.rawValue == 2)
        #expect(SoftShadowQuality.high.rawValue == 3)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let quality = SoftShadowQuality.high
        let data = try JSONEncoder().encode(quality)
        let decoded = try JSONDecoder().decode(SoftShadowQuality.self, from: data)
        #expect(decoded == quality)
    }
}

@Suite("Soft Shadows - LightingOptions")
struct SoftShadowOptionsTests {

    @Test("Custom soft shadow options")
    func customInit() {
        let options = LightingOptions(
            softShadows: true,
            softShadowRadius: 8.0,
            softShadowQuality: .high,
            debugShadowBuffer: true
        )
        #expect(options.softShadows == true)
        #expect(options.softShadowRadius == 8.0)
        #expect(options.softShadowQuality == .high)
        #expect(options.debugShadowBuffer == true)
    }

    @Test("Soft shadow properties are mutable")
    func mutable() {
        var options = LightingOptions()
        options.softShadows = true
        options.softShadowRadius = 12.0
        options.softShadowQuality = .low
        options.debugShadowBuffer = true
        #expect(options.softShadows == true)
        #expect(options.softShadowRadius == 12.0)
        #expect(options.softShadowQuality == .low)
        #expect(options.debugShadowBuffer == true)
    }
}

@Suite("Soft Shadows - Light2D")
struct SoftShadowLight2DTests {

    @Test("softShadowRadius default is 0")
    func defaultRadius() {
        let light = Light2D()
        #expect(light.softShadowRadius == 0.0)
    }

    @Test("Custom softShadowRadius")
    func customRadius() {
        let light = Light2D(softShadowRadius: 6.0)
        #expect(light.softShadowRadius == 6.0)
    }

    @Test("softShadowRadius codable round-trip")
    func codableRoundTrip() throws {
        let light = Light2D(castsShadows: true, softShadowRadius: 10.0)
        let data = try JSONEncoder().encode(light)
        let decoded = try JSONDecoder().decode(Light2D.self, from: data)
        #expect(decoded.softShadowRadius == 10.0)
    }
}

@Suite("Soft Shadows - LightingSystem")
struct SoftShadowSystemTests {

    @Test("Soft shadows disabled by default - no overhead")
    func disabledByDefault() {
        let options = LightingOptions()
        #expect(options.softShadows == false)

        let system = LightingSystem(options: options)
        #expect(system.isSoftShadowsInitialized == false)
    }

    @Test("LightingSystem with softShadows option")
    func softShadowsOption() {
        let options = LightingOptions(softShadows: true, softShadowRadius: 6.0, softShadowQuality: .high)
        let system = LightingSystem(options: options)
        #expect(system.options.softShadows == true)
        #expect(system.options.softShadowRadius == 6.0)
        #expect(system.options.softShadowQuality == .high)
        // Not initialized yet (no renderer call)
        #expect(system.isSoftShadowsInitialized == false)
    }

    @Test("Per-light blur radius resolution - light overrides global")
    func perLightBlurRadius() {
        let light = Light2D(softShadowRadius: 12.0)
        let globalRadius: Float = 4.0
        let effective = light.softShadowRadius > 0 ? light.softShadowRadius : globalRadius
        #expect(effective == 12.0)
    }

    @Test("Per-light blur radius resolution - zero uses global")
    func perLightBlurRadiusDefault() {
        let light = Light2D(softShadowRadius: 0.0)
        let globalRadius: Float = 4.0
        let effective = light.softShadowRadius > 0 ? light.softShadowRadius : globalRadius
        #expect(effective == 4.0)
    }
}
