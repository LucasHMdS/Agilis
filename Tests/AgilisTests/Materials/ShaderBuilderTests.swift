@testable import Agilis
import Foundation
import Testing

@Suite("ShaderBuilder")
struct ShaderBuilderTests {

    // MARK: - createFragment

    @Test("createFragment includes version header")
    func fragmentVersion() {
        let source = ShaderBuilder.createFragment(body: "finalColor = vec4(1.0);")
        #expect(source.contains("#version 300 es"))
    }

    @Test("createFragment includes standard inputs")
    func fragmentInputs() {
        let source = ShaderBuilder.createFragment(body: "finalColor = vec4(1.0);")
        #expect(source.contains("in vec2 fragTexCoord;"))
        #expect(source.contains("in vec4 fragColor;"))
        #expect(source.contains("uniform sampler2D texture0;"))
    }

    @Test("createFragment includes auto-inject uniforms")
    func fragmentAutoUniforms() {
        let source = ShaderBuilder.createFragment(body: "finalColor = vec4(1.0);")
        #expect(source.contains("uniform float _time;"))
        #expect(source.contains("uniform vec2 _resolution;"))
        #expect(source.contains("uniform float _deltaTime;"))
    }

    @Test("createFragment includes user uniforms")
    func fragmentUserUniforms() {
        let source = ShaderBuilder.createFragment(
            uniforms: ["amount": "float", "tintColor": "vec4"],
            body: "finalColor = vec4(1.0);"
        )
        #expect(source.contains("uniform float amount;"))
        #expect(source.contains("uniform vec4 tintColor;"))
    }

    @Test("createFragment includes body in main function")
    func fragmentBody() {
        let source = ShaderBuilder.createFragment(
            body: "finalColor = sampleTexture(fragTexCoord);"
        )
        #expect(source.contains("void main() {"))
        #expect(source.contains("finalColor = sampleTexture(fragTexCoord);"))
    }

    @Test("createFragment sampleTexture multiplies fragColor")
    func fragmentSampleTint() {
        let source = ShaderBuilder.createFragment(body: "finalColor = vec4(1.0);")
        #expect(source.contains("return texture(texture0, uv) * fragColor;"))
    }

    @Test("createFragment includes requested libraries")
    func fragmentIncludes() {
        let source = ShaderBuilder.createFragment(
            includes: [.noise, .color],
            body: "finalColor = vec4(1.0);"
        )
        #expect(source.contains("hash21"))
        #expect(source.contains("noise2D"))
        #expect(source.contains("rgb2hsv"))
        #expect(source.contains("hsv2rgb"))
    }

    @Test("createFragment with no includes does not add library code")
    func fragmentNoIncludes() {
        let source = ShaderBuilder.createFragment(body: "finalColor = vec4(1.0);")
        #expect(!source.contains("hash21"))
        #expect(!source.contains("rgb2hsv"))
        #expect(!source.contains("easeQuadIn"))
    }

    @Test("createFragment output has finalColor declaration")
    func fragmentOutput() {
        let source = ShaderBuilder.createFragment(body: "finalColor = vec4(1.0);")
        #expect(source.contains("out vec4 finalColor;"))
    }

    // MARK: - createPostProcess

    @Test("createPostProcess sampleTexture does NOT multiply fragColor")
    func postProcessSampleNoTint() {
        let source = ShaderBuilder.createPostProcess(body: "finalColor = vec4(1.0);")
        #expect(source.contains("return texture(texture0, uv);"))
        #expect(!source.contains("return texture(texture0, uv) * fragColor;"))
    }

    @Test("createPostProcess has same structure as createFragment")
    func postProcessStructure() {
        let source = ShaderBuilder.createPostProcess(
            uniforms: ["strength": "float"],
            includes: [.math],
            body: "finalColor = vec4(1.0);"
        )
        #expect(source.contains("#version 300 es"))
        #expect(source.contains("uniform float strength;"))
        #expect(source.contains("remap"))
        #expect(source.contains("void main() {"))
    }

    // MARK: - Deterministic Output

    @Test("Uniforms are sorted alphabetically")
    func uniformsSorted() {
        let source = ShaderBuilder.createFragment(
            uniforms: ["zeta": "float", "alpha": "int", "mid": "vec2"],
            body: "finalColor = vec4(1.0);"
        )
        // swiftlint:disable:next force_unwrapping
        let alphaIndex = source.range(of: "uniform int alpha;")!.lowerBound
        // swiftlint:disable:next force_unwrapping
        let midIndex = source.range(of: "uniform vec2 mid;")!.lowerBound
        // swiftlint:disable:next force_unwrapping
        let zetaIndex = source.range(of: "uniform float zeta;")!.lowerBound
        #expect(alphaIndex < midIndex)
        #expect(midIndex < zetaIndex)
    }

    @Test("Includes are sorted by name")
    func includesSorted() {
        let source = ShaderBuilder.createFragment(
            includes: [.uv, .easing, .math],
            body: "finalColor = vec4(1.0);"
        )
        // easing < math < uv alphabetically
        // swiftlint:disable:next force_unwrapping
        let easingIndex = source.range(of: "easeQuadIn")!.lowerBound
        // swiftlint:disable:next force_unwrapping
        let mathIndex = source.range(of: "remap")!.lowerBound
        // swiftlint:disable:next force_unwrapping
        let uvIndex = source.range(of: "rotateUV")!.lowerBound
        #expect(easingIndex < mathIndex)
        #expect(mathIndex < uvIndex)
    }
}

@Suite("ShaderInclude")
struct ShaderIncludeTests {

    @Test("All include cases have non-empty GLSL source")
    func allCasesHaveSource() {
        for include in ShaderInclude.allCases {
            #expect(!include.glslSource.isEmpty, "\(include.rawValue) should have GLSL source")
        }
    }

    @Test("Noise include has hash, noise2D, and fbm")
    func noiseInclude() {
        let source = ShaderInclude.noise.glslSource
        #expect(source.contains("hash21"))
        #expect(source.contains("noise2D"))
        #expect(source.contains("fbm"))
    }

    @Test("Easing include has standard easing functions")
    func easingInclude() {
        let source = ShaderInclude.easing.glslSource
        #expect(source.contains("easeQuadIn"))
        #expect(source.contains("easeQuadOut"))
        #expect(source.contains("easeCubicIn"))
        #expect(source.contains("easeCubicOut"))
        #expect(source.contains("easeSineIn"))
        #expect(source.contains("easeSineOut"))
        #expect(source.contains("easeSmoothstep"))
    }

    @Test("UV include has rotation, scroll, and tile")
    func uvInclude() {
        let source = ShaderInclude.uv.glslSource
        #expect(source.contains("rotateUV"))
        #expect(source.contains("scrollUV"))
        #expect(source.contains("tileUV"))
    }

    @Test("Color include has HSV conversion and luminance")
    func colorInclude() {
        let source = ShaderInclude.color.glslSource
        #expect(source.contains("rgb2hsv"))
        #expect(source.contains("hsv2rgb"))
        #expect(source.contains("luminance"))
    }

    @Test("Math include has remap, smootherStep, inverseLerp")
    func mathInclude() {
        let source = ShaderInclude.math.glslSource
        #expect(source.contains("remap"))
        #expect(source.contains("smootherStep"))
        #expect(source.contains("inverseLerp"))
    }

    @Test("ShaderInclude has 6 cases")
    func caseCount() {
        #expect(ShaderInclude.allCases.count == 6)
    }
}
