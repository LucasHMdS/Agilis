@testable import Agilis
@testable import AgilisFormats
import Foundation
import Testing

// MARK: - Aseprite Bridge Tests

@Suite("Aseprite Animation Bridge Tests")
struct AsepriteAnimationBridgeTests {

    /// Helper: create minimal Aseprite data with frames and optional tags.
    private func makeAsepriteData(
        frames: [(x: Int, y: Int, w: Int, h: Int, duration: Int)],
        // swiftlint:disable:next discouraged_optional_collection
        tags: [(name: String, from: Int, to: Int, direction: String)]? = nil
    ) -> AsepriteData {
        let json = makeAsepriteJSON(frames: frames, tags: tags)
        // swiftlint:disable:next force_try
        return try! AsepriteLoader().load(from: Data(json.utf8))
    }

    private func makeAsepriteJSON(
        frames: [(x: Int, y: Int, w: Int, h: Int, duration: Int)],
        // swiftlint:disable:next discouraged_optional_collection
        tags: [(name: String, from: Int, to: Int, direction: String)]?
    ) -> String {
        let framesJSON = frames
            .enumerated()
            .map { i, f in
                """
                {
                    "filename": "frame_\(i).png",
                    "frame": {"x": \(f.x), "y": \(f.y), "w": \(f.w), "h": \(f.h)},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": \(f.w), "h": \(f.h)},
                    "sourceSize": {"w": \(f.w), "h": \(f.h)},
                    "duration": \(f.duration)
                }
                """
            }
            .joined(separator: ",\n")

        var tagsJSON = ""
        if let tags = tags {
            let tagEntries = tags.map { tag in
                """
                {"name": "\(tag.name)", "from": \(tag.from), "to": \(tag.to), "direction": "\(tag.direction)"}
                """
            }
            .joined(separator: ",\n")
            tagsJSON = ", \"frameTags\": [\(tagEntries)]"
        }

        return """
        {
            "frames": [\(framesJSON)],
            "meta": {
                "image": "sheet.png",
                "size": {"w": 256, "h": 256}
                \(tagsJSON)
            }
        }
        """
    }

    @Test("fromAseprite creates clips from frame tags")
    func fromAsepriteWithTags() {
        let aseprite = makeAsepriteData(
            frames: [
                (x: 0, y: 0, w: 32, h: 32, duration: 100),
                (x: 32, y: 0, w: 32, h: 32, duration: 100),
                (x: 64, y: 0, w: 32, h: 32, duration: 150),
                (x: 96, y: 0, w: 32, h: 32, duration: 150),
                (x: 0, y: 32, w: 32, h: 32, duration: 200),
                (x: 32, y: 32, w: 32, h: 32, duration: 200)
            ],
            tags: [
                (name: "idle", from: 0, to: 1, direction: "forward"),
                (name: "walk", from: 2, to: 3, direction: "pingpong"),
                (name: "die", from: 4, to: 5, direction: "forward")
            ]
        )

        let clips = AnimationClip.fromAseprite(aseprite)

        #expect(clips.count == 3)

        // Idle clip
        #expect(clips[0].name == "idle")
        #expect(clips[0].frameCount == 2)
        #expect(clips[0].mode == .forward)
        #expect(clips[0].frames[0].sourceRect == Rect(x: 0, y: 0, width: 32, height: 32))
        #expect(clips[0].frames[1].sourceRect == Rect(x: 32, y: 0, width: 32, height: 32))
        // Duration: 100ms → 0.1s
        #expect(abs(clips[0].frames[0].duration - 0.1) < 0.001)

        // Walk clip
        #expect(clips[1].name == "walk")
        #expect(clips[1].mode == .pingPong)
        #expect(clips[1].frameCount == 2)

        // Die clip
        #expect(clips[2].name == "die")
        #expect(clips[2].frameCount == 2)
        #expect(clips[2].frames[0].sourceRect == Rect(x: 0, y: 32, width: 32, height: 32))
    }

    @Test("fromAseprite duration conversion ms to seconds")
    func durationConversion() {
        let aseprite = makeAsepriteData(
            frames: [
                (x: 0, y: 0, w: 16, h: 16, duration: 50),
                (x: 16, y: 0, w: 16, h: 16, duration: 250),
                (x: 32, y: 0, w: 16, h: 16, duration: 1_000)
            ],
            tags: [
                (name: "test", from: 0, to: 2, direction: "forward")
            ]
        )

        let clips = AnimationClip.fromAseprite(aseprite)
        #expect(clips.count == 1)
        #expect(abs(clips[0].frames[0].duration - 0.05) < 0.001)
        #expect(abs(clips[0].frames[1].duration - 0.25) < 0.001)
        #expect(abs(clips[0].frames[2].duration - 1.0) < 0.001)
    }

    @Test("fromAseprite maps direction to PlaybackMode")
    func directionMapping() {
        let aseprite = makeAsepriteData(
            frames: [
                (x: 0, y: 0, w: 16, h: 16, duration: 100),
                (x: 16, y: 0, w: 16, h: 16, duration: 100)
            ],
            tags: [
                (name: "fwd", from: 0, to: 1, direction: "forward"),
                (name: "rev", from: 0, to: 1, direction: "reverse"),
                (name: "pp", from: 0, to: 1, direction: "pingpong")
            ]
        )

        let clips = AnimationClip.fromAseprite(aseprite)
        #expect(clips[0].mode == .forward)
        #expect(clips[1].mode == .reverse)
        #expect(clips[2].mode == .pingPong)
    }

    @Test("fromAseprite returns empty array when no tags")
    func noTags() {
        let aseprite = makeAsepriteData(
            frames: [
                (x: 0, y: 0, w: 16, h: 16, duration: 100)
            ],
            tags: nil
        )

        let clips = AnimationClip.fromAseprite(aseprite)
        #expect(clips.isEmpty)
    }

    @Test("fromAsepriteAllFrames creates a single clip from all frames")
    func allFrames() {
        let aseprite = makeAsepriteData(
            frames: [
                (x: 0, y: 0, w: 32, h: 32, duration: 100),
                (x: 32, y: 0, w: 32, h: 32, duration: 200),
                (x: 64, y: 0, w: 32, h: 32, duration: 150)
            ]
        )

        let clip = AnimationClip.fromAsepriteAllFrames(aseprite, name: "all", mode: .pingPong)
        #expect(clip.name == "all")
        #expect(clip.frameCount == 3)
        #expect(clip.mode == .pingPong)
        #expect(abs(clip.frames[0].duration - 0.1) < 0.001)
        #expect(abs(clip.frames[1].duration - 0.2) < 0.001)
        #expect(abs(clip.frames[2].duration - 0.15) < 0.001)
    }

    @Test("fromAsepriteAllFrames default name and mode")
    func allFramesDefaults() {
        let aseprite = makeAsepriteData(
            frames: [
                (x: 0, y: 0, w: 16, h: 16, duration: 100)
            ]
        )

        let clip = AnimationClip.fromAsepriteAllFrames(aseprite)
        #expect(clip.name == "default")
        #expect(clip.mode == .forward)
    }
}

// MARK: - TextureAtlas Bridge Tests

@Suite("TextureAtlas Animation Bridge Tests")
struct TextureAtlasAnimationBridgeTests {

    /// Helper: create a TextureAtlasData with named frames.
    private func makeAtlas(
        frames: [(name: String, x: Int, y: Int, w: Int, h: Int)]
    ) -> TextureAtlasData {
        var framesJSON: [String] = []
        for frame in frames {
            framesJSON.append("""
            "\(frame.name)": {
                "frame": {"x": \(frame.x), "y": \(frame.y), "w": \(frame.w), "h": \(frame.h)},
                "rotated": false,
                "trimmed": false,
                "spriteSourceSize": {"x": 0, "y": 0, "w": \(frame.w), "h": \(frame.h)},
                "sourceSize": {"w": \(frame.w), "h": \(frame.h)}
            }
            """)
        }

        let json = """
        {
            "frames": {\(framesJSON.joined(separator: ",\n"))},
            "meta": {
                "image": "atlas.png",
                "size": {"w": 512, "h": 512}
            }
        }
        """
        // swiftlint:disable:next force_try
        return try! TextureAtlasLoader().load(from: Data(json.utf8))
    }

    @Test("fromTextureAtlas prefix matching selects correct frames")
    func prefixMatching() {
        let atlas = makeAtlas(frames: [
            (name: "walk_0000", x: 0, y: 0, w: 32, h: 32),
            (name: "walk_0001", x: 32, y: 0, w: 32, h: 32),
            (name: "walk_0002", x: 64, y: 0, w: 32, h: 32),
            (name: "idle_0000", x: 0, y: 32, w: 32, h: 32),
            (name: "idle_0001", x: 32, y: 32, w: 32, h: 32)
        ])

        let walkClip = AnimationClip.fromTextureAtlas(atlas, prefix: "walk_", frameDuration: 0.1)

        #expect(walkClip.name == "walk_")
        #expect(walkClip.frameCount == 3)
        #expect(walkClip.mode == .forward)

        // Verify frames are sorted alphabetically
        #expect(walkClip.frames[0].sourceRect == Rect(x: 0, y: 0, width: 32, height: 32))
        #expect(walkClip.frames[1].sourceRect == Rect(x: 32, y: 0, width: 32, height: 32))
        #expect(walkClip.frames[2].sourceRect == Rect(x: 64, y: 0, width: 32, height: 32))

        for frame in walkClip.frames {
            #expect(abs(frame.duration - 0.1) < 0.001)
        }
    }

    @Test("fromTextureAtlas prefix matching with custom mode")
    func prefixCustomMode() {
        let atlas = makeAtlas(frames: [
            (name: "run_0", x: 0, y: 0, w: 16, h: 16),
            (name: "run_1", x: 16, y: 0, w: 16, h: 16)
        ])

        let clip = AnimationClip.fromTextureAtlas(
            atlas, prefix: "run_", frameDuration: 0.08, mode: .pingPong
        )

        #expect(clip.mode == .pingPong)
        #expect(clip.frameCount == 2)
    }

    @Test("fromTextureAtlas prefix no matches returns empty clip")
    func prefixNoMatch() {
        let atlas = makeAtlas(frames: [
            (name: "walk_0", x: 0, y: 0, w: 16, h: 16)
        ])

        let clip = AnimationClip.fromTextureAtlas(atlas, prefix: "attack_", frameDuration: 0.1)
        #expect(clip.frameCount == 0)
    }

    @Test("fromTextureAtlas with explicit frame names")
    func explicitFrameNames() {
        let atlas = makeAtlas(frames: [
            (name: "hero_stand", x: 0, y: 0, w: 32, h: 48),
            (name: "hero_crouch", x: 32, y: 0, w: 32, h: 48),
            (name: "hero_jump", x: 64, y: 0, w: 32, h: 48),
            (name: "hero_fall", x: 96, y: 0, w: 32, h: 48)
        ])

        let clip = AnimationClip.fromTextureAtlas(
            atlas,
            name: "jump_sequence",
            frameNames: ["hero_crouch", "hero_jump", "hero_fall"],
            frameDuration: 0.15,
            mode: .oneShot
        )

        #expect(clip.name == "jump_sequence")
        #expect(clip.frameCount == 3)
        #expect(clip.mode == .oneShot)

        // Verify correct order: crouch, jump, fall
        #expect(clip.frames[0].sourceRect == Rect(x: 32, y: 0, width: 32, height: 48))
        #expect(clip.frames[1].sourceRect == Rect(x: 64, y: 0, width: 32, height: 48))
        #expect(clip.frames[2].sourceRect == Rect(x: 96, y: 0, width: 32, height: 48))
    }

    @Test("fromTextureAtlas explicit names skips missing frames")
    func explicitNamesMissing() {
        let atlas = makeAtlas(frames: [
            (name: "a", x: 0, y: 0, w: 16, h: 16),
            (name: "c", x: 32, y: 0, w: 16, h: 16)
        ])

        let clip = AnimationClip.fromTextureAtlas(
            atlas,
            name: "test",
            frameNames: ["a", "b", "c"], // "b" doesn't exist
            frameDuration: 0.1
        )

        #expect(clip.frameCount == 2) // "b" skipped
        #expect(clip.frames[0].sourceRect == Rect(x: 0, y: 0, width: 16, height: 16))
        #expect(clip.frames[1].sourceRect == Rect(x: 32, y: 0, width: 16, height: 16))
    }

    @Test("fromTextureAtlas frames are sorted alphabetically")
    func framesSorted() {
        // Insert frames in non-alphabetical order
        let atlas = makeAtlas(frames: [
            (name: "anim_03", x: 48, y: 0, w: 16, h: 16),
            (name: "anim_01", x: 16, y: 0, w: 16, h: 16),
            (name: "anim_00", x: 0, y: 0, w: 16, h: 16),
            (name: "anim_02", x: 32, y: 0, w: 16, h: 16)
        ])

        let clip = AnimationClip.fromTextureAtlas(atlas, prefix: "anim_", frameDuration: 0.1)

        #expect(clip.frameCount == 4)
        // Should be sorted: 00, 01, 02, 03
        #expect(clip.frames[0].sourceRect.x == 0)
        #expect(clip.frames[1].sourceRect.x == 16)
        #expect(clip.frames[2].sourceRect.x == 32)
        #expect(clip.frames[3].sourceRect.x == 48)
    }
}
