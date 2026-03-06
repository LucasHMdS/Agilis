import Testing
import Foundation
@testable import Agilis

@Suite("ShaderComposer")
struct ShaderComposerTests {

    // MARK: - Single Effect

    @Test("Single effect produces valid shader")
    func singleEffect() {
        let composer = ShaderComposer()
        composer.addEffect("grayscale", body: "color.rgb = vec3(dot(color.rgb, vec3(0.3)));")
        let source = composer.build()

        #expect(source.contains("#version 300 es"))
        #expect(source.contains("void main()"))
        #expect(source.contains("sampleTexture(fragTexCoord)"))
        #expect(source.contains("finalColor = color;"))
        #expect(source.contains("vec3(dot(color.rgb, vec3(0.3)))"))
    }

    @Test("Single effect with uniforms declares them")
    func singleEffectUniforms() {
        let composer = ShaderComposer()
        composer.addEffect("tint",
            uniforms: ["tintColor": "vec3"],
            body: "color.rgb *= tintColor;")
        let source = composer.build()

        #expect(source.contains("uniform vec3 tintColor;"))
    }

    @Test("Single effect with includes injects library code")
    func singleEffectIncludes() {
        let composer = ShaderComposer()
        composer.addEffect("hueShift",
            includes: [.color],
            body: "color.rgb = hsv2rgb(rgb2hsv(color.rgb));")
        let source = composer.build()

        #expect(source.contains("rgb2hsv"))
        #expect(source.contains("hsv2rgb"))
    }

    // MARK: - Multiple Effects

    @Test("Multiple effects chained in order")
    func effectOrder() {
        let composer = ShaderComposer()
        composer.addEffect("first", body: "color.rgb *= 0.5;")
        composer.addEffect("second", body: "color.rgb += 0.1;")
        let source = composer.build()

        // Both effects present
        #expect(source.contains("color.rgb *= 0.5;"))
        #expect(source.contains("color.rgb += 0.1;"))

        // First effect appears before second
        let firstIndex = source.range(of: "color.rgb *= 0.5;")!.lowerBound
        let secondIndex = source.range(of: "color.rgb += 0.1;")!.lowerBound
        #expect(firstIndex < secondIndex)
    }

    @Test("Effect names appear as comments")
    func effectComments() {
        let composer = ShaderComposer()
        composer.addEffect("grayscale", body: "color.rgb = vec3(0.5);")
        composer.addEffect("bloom", body: "color.rgb *= 1.5;")
        let source = composer.build()

        #expect(source.contains("// --- grayscale ---"))
        #expect(source.contains("// --- bloom ---"))
    }

    // MARK: - Uniform Merging

    @Test("Uniforms from multiple effects are merged")
    func uniformsMerged() {
        let composer = ShaderComposer()
        composer.addEffect("a",
            uniforms: ["amount": "float"],
            body: "color.rgb *= amount;")
        composer.addEffect("b",
            uniforms: ["tint": "vec3"],
            body: "color.rgb *= tint;")
        let source = composer.build()

        #expect(source.contains("uniform float amount;"))
        #expect(source.contains("uniform vec3 tint;"))
    }

    @Test("Duplicate uniform name uses last-added type")
    func uniformDuplicates() {
        let composer = ShaderComposer()
        composer.addEffect("a",
            uniforms: ["value": "float"],
            body: "color.rgb *= value;")
        composer.addEffect("b",
            uniforms: ["value": "vec2"],
            body: "color.rg *= value;")
        let source = composer.build()

        // Last type wins — "vec2"
        #expect(source.contains("uniform vec2 value;"))
        // Should not have float declaration (overridden by vec2)
        #expect(!source.contains("uniform float value;"))
    }

    // MARK: - Include Deduplication

    @Test("Includes from multiple effects are deduplicated")
    func includesDeduplicated() {
        let composer = ShaderComposer()
        composer.addEffect("a",
            includes: [.color, .noise],
            body: "color.rgb = vec3(luminance(color.rgb));")
        composer.addEffect("b",
            includes: [.color, .math],
            body: "color.r = remap(color.r, 0.0, 1.0, 0.2, 0.8);")
        let source = composer.build()

        // Color library appears exactly once
        let colorCount = source.components(separatedBy: "// --- Color utilities ---").count - 1
        #expect(colorCount == 1)

        // All three libraries present
        #expect(source.contains("luminance"))
        #expect(source.contains("noise2D"))
        #expect(source.contains("remap"))
    }

    // MARK: - Post-Process Mode

    @Test("Post-process mode uses non-tinted sampleTexture")
    func postProcessMode() {
        let composer = ShaderComposer()
        composer.setPostProcess()
        composer.addEffect("pass", body: "// noop")
        let source = composer.build()

        #expect(source.contains("return texture(texture0, uv);"))
        #expect(!source.contains("return texture(texture0, uv) * fragColor;"))
    }

    @Test("Default mode uses tinted sampleTexture")
    func defaultMode() {
        let composer = ShaderComposer()
        composer.addEffect("pass", body: "// noop")
        let source = composer.build()

        #expect(source.contains("return texture(texture0, uv) * fragColor;"))
    }

    // MARK: - Effect Count

    @Test("effectCount tracks added effects")
    func effectCount() {
        let composer = ShaderComposer()
        #expect(composer.effectCount == 0)

        composer.addEffect("a", body: "")
        #expect(composer.effectCount == 1)

        composer.addEffect("b", body: "")
        composer.addEffect("c", body: "")
        #expect(composer.effectCount == 3)
    }

    // MARK: - Empty Composer

    @Test("Empty composer produces valid shader")
    func emptyComposer() {
        let composer = ShaderComposer()
        let source = composer.build()

        #expect(source.contains("#version 300 es"))
        #expect(source.contains("void main()"))
        #expect(source.contains("sampleTexture(fragTexCoord)"))
        #expect(source.contains("finalColor = color;"))
    }

    // MARK: - setPostProcess fluent API

    @Test("setPostProcess returns self for chaining")
    func setPostProcessFluent() {
        let composer = ShaderComposer()
        let returned = composer.setPostProcess(true)
        // Same instance returned
        #expect(returned === composer)
    }
}

@Suite("ComposableEffects")
struct ComposableEffectsTests {

    @Test("grayscale snippet has correct uniforms and includes")
    func grayscaleSnippet() {
        let (uniforms, includes, body) = ComposableEffects.grayscale()
        #expect(uniforms["grayscaleAmount"] == "float")
        #expect(includes.contains(.color))
        #expect(body.contains("luminance"))
    }

    @Test("flash snippet has correct uniforms")
    func flashSnippet() {
        let (uniforms, includes, body) = ComposableEffects.flash()
        #expect(uniforms["flashColor"] == "vec3")
        #expect(uniforms["flashAmount"] == "float")
        #expect(includes.isEmpty)
        #expect(body.contains("mix"))
    }

    @Test("hueShift snippet uses color include")
    func hueShiftSnippet() {
        let (uniforms, includes, body) = ComposableEffects.hueShift()
        #expect(uniforms["hueShift"] == "float")
        #expect(includes.contains(.color))
        #expect(body.contains("rgb2hsv"))
        #expect(body.contains("hsv2rgb"))
    }

    @Test("tint snippet has correct uniforms")
    func tintSnippet() {
        let (uniforms, _, body) = ComposableEffects.tint()
        #expect(uniforms["tintColor"] == "vec3")
        #expect(body.contains("tintColor"))
    }

    @Test("invertColors snippet has correct uniforms")
    func invertColorsSnippet() {
        let (uniforms, _, body) = ComposableEffects.invertColors()
        #expect(uniforms["invertAmount"] == "float")
        #expect(body.contains("1.0") && body.contains("inverted"))
    }

    @Test("brightnessContrast snippet has correct uniforms")
    func brightnessContrastSnippet() {
        let (uniforms, _, body) = ComposableEffects.brightnessContrast()
        #expect(uniforms["brightnessOffset"] == "float")
        #expect(uniforms["contrastScale"] == "float")
        #expect(body.contains("brightnessOffset"))
        #expect(body.contains("contrastScale"))
    }

    @Test("Composable effects integrate with ShaderComposer")
    func integrationTest() {
        let composer = ShaderComposer()

        let (u1, i1, b1) = ComposableEffects.grayscale()
        composer.addEffect("grayscale", uniforms: u1, includes: i1, body: b1)

        let (u2, i2, b2) = ComposableEffects.flash()
        composer.addEffect("flash", uniforms: u2, includes: i2, body: b2)

        let source = composer.build()

        // All uniforms present
        #expect(source.contains("uniform float grayscaleAmount;"))
        #expect(source.contains("uniform vec3 flashColor;"))
        #expect(source.contains("uniform float flashAmount;"))

        // Color include present (from grayscale)
        #expect(source.contains("luminance"))

        // Both effect bodies present
        #expect(source.contains("luminance(color.rgb)"))
        #expect(source.contains("mix(color.rgb, flashColor, flashAmount)"))

        // Correct order
        let grayIdx = source.range(of: "luminance(color.rgb)")!.lowerBound
        let flashIdx = source.range(of: "mix(color.rgb, flashColor, flashAmount)")!.lowerBound
        #expect(grayIdx < flashIdx)
    }

    @Test("Multiple effects with shared includes deduplicate")
    func sharedIncludes() {
        let composer = ShaderComposer()

        let (u1, i1, b1) = ComposableEffects.grayscale()
        composer.addEffect("grayscale", uniforms: u1, includes: i1, body: b1)

        let (u2, i2, b2) = ComposableEffects.hueShift()
        composer.addEffect("hueShift", uniforms: u2, includes: i2, body: b2)

        let source = composer.build()

        // Both need .color include — should only appear once
        let colorSections = source.components(separatedBy: "// --- Color utilities ---").count - 1
        #expect(colorSections == 1)
    }
}
