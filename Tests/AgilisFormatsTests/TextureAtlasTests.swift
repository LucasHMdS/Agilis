@testable import AgilisFormats
import Foundation
import Testing

@Suite("TextureAtlas Parser Tests")
struct TextureAtlasTests {
    @Test func parseSingleFrame() throws {
        let json = """
        {
            "frames": {
                "player_idle_0.png": {
                    "frame": {"x": 0, "y": 0, "w": 32, "h": 32},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 32, "h": 32},
                    "sourceSize": {"w": 32, "h": 32}
                }
            },
            "meta": {
                "image": "spritesheet.png",
                "size": {"w": 256, "h": 256}
            }
        }
        """
        let atlas = try TextureAtlasLoader().load(from: Data(json.utf8))

        #expect(atlas.frames.count == 1)
        #expect(atlas.meta.image == "spritesheet.png")
        #expect(atlas.meta.size.w == 256)
        #expect(atlas.meta.size.h == 256)

        // swiftlint:disable:next force_unwrapping
        let frame = atlas.frames["player_idle_0.png"]!
        #expect(frame.frame.x == 0)
        #expect(frame.frame.y == 0)
        #expect(frame.frame.w == 32)
        #expect(frame.frame.h == 32)
        #expect(!frame.rotated)
        #expect(!frame.trimmed)
    }

    @Test func parseMultipleFrames() throws {
        let json = """
        {
            "frames": {
                "frame_0.png": {
                    "frame": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "sourceSize": {"w": 16, "h": 16}
                },
                "frame_1.png": {
                    "frame": {"x": 16, "y": 0, "w": 16, "h": 16},
                    "rotated": false,
                    "trimmed": true,
                    "spriteSourceSize": {"x": 2, "y": 2, "w": 12, "h": 12},
                    "sourceSize": {"w": 16, "h": 16}
                }
            },
            "meta": {
                "image": "atlas.png",
                "size": {"w": 64, "h": 64},
                "scale": "1"
            }
        }
        """
        let atlas = try TextureAtlasLoader().load(from: Data(json.utf8))

        #expect(atlas.frames.count == 2)
        #expect(atlas.meta.scale == "1")

        // swiftlint:disable:next force_unwrapping
        let f1 = atlas.frames["frame_1.png"]!
        #expect(f1.trimmed)
        #expect(f1.spriteSourceSize.x == 2)
        #expect(f1.spriteSourceSize.w == 12)
        #expect(f1.frame.x == 16)
    }

    @Test func parseRotatedFrame() throws {
        let json = """
        {
            "frames": {
                "tall.png": {
                    "frame": {"x": 0, "y": 0, "w": 64, "h": 32},
                    "rotated": true,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 32, "h": 64},
                    "sourceSize": {"w": 32, "h": 64}
                }
            },
            "meta": {
                "image": "atlas.png",
                "size": {"w": 128, "h": 128}
            }
        }
        """
        let atlas = try TextureAtlasLoader().load(from: Data(json.utf8))
        // swiftlint:disable:next force_unwrapping
        let frame = atlas.frames["tall.png"]!
        #expect(frame.rotated)
        #expect(frame.sourceSize.w == 32)
        #expect(frame.sourceSize.h == 64)
    }

    @Test func loadFromBytes() throws {
        let json = """
        {"frames":{},"meta":{"image":"test.png","size":{"w":32,"h":32}}}
        """
        let atlas = try TextureAtlasLoader().load(from: Array(json.utf8))
        #expect(atlas.frames.isEmpty)
        #expect(atlas.meta.image == "test.png")
    }
}
