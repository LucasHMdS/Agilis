@testable import AgilisFormats
import Foundation
import Testing

@Suite("Aseprite Parser Tests")
struct AsepriteTests {
    @Test func parseArrayFrames() throws {
        let json = """
        {
            "frames": [
                {
                    "filename": "sprite_0.png",
                    "frame": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "sourceSize": {"w": 16, "h": 16},
                    "duration": 100
                },
                {
                    "filename": "sprite_1.png",
                    "frame": {"x": 16, "y": 0, "w": 16, "h": 16},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "sourceSize": {"w": 16, "h": 16},
                    "duration": 200
                }
            ],
            "meta": {
                "image": "sprite.png",
                "size": {"w": 32, "h": 16}
            }
        }
        """
        let data = try AsepriteLoader().load(from: Data(json.utf8))

        #expect(data.frames.count == 2)
        #expect(data.frames[0].filename == "sprite_0.png")
        #expect(data.frames[0].duration == 100)
        #expect(data.frames[0].frame.x == 0)
        #expect(data.frames[0].frame.w == 16)
        #expect(data.frames[1].filename == "sprite_1.png")
        #expect(data.frames[1].duration == 200)
        #expect(data.frames[1].frame.x == 16)
        #expect(data.meta.image == "sprite.png")
        #expect(data.meta.size.w == 32)
        #expect(data.meta.size.h == 16)
    }

    @Test func parseDictionaryFrames() throws {
        let json = """
        {
            "frames": {
                "walk_0.png": {
                    "frame": {"x": 0, "y": 0, "w": 24, "h": 32},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 24, "h": 32},
                    "sourceSize": {"w": 24, "h": 32},
                    "duration": 150
                },
                "walk_1.png": {
                    "frame": {"x": 24, "y": 0, "w": 24, "h": 32},
                    "rotated": false,
                    "trimmed": true,
                    "spriteSourceSize": {"x": 2, "y": 0, "w": 20, "h": 32},
                    "sourceSize": {"w": 24, "h": 32},
                    "duration": 150
                }
            },
            "meta": {
                "image": "walk.png",
                "size": {"w": 48, "h": 32}
            }
        }
        """
        let data = try AsepriteLoader().load(from: Data(json.utf8))

        #expect(data.frames.count == 2)
        // Dictionary frames are sorted by key — walk_0 before walk_1
        #expect(data.frames[0].filename == "walk_0.png")
        #expect(data.frames[1].filename == "walk_1.png")
        #expect(data.frames[1].trimmed)
        #expect(data.frames[1].spriteSourceSize.x == 2)
        #expect(data.frames[1].spriteSourceSize.w == 20)
    }

    @Test func parseFrameTags() throws {
        let json = """
        {
            "frames": [
                {
                    "filename": "char_0.png",
                    "frame": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "sourceSize": {"w": 16, "h": 16},
                    "duration": 100
                },
                {
                    "filename": "char_1.png",
                    "frame": {"x": 16, "y": 0, "w": 16, "h": 16},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "sourceSize": {"w": 16, "h": 16},
                    "duration": 100
                },
                {
                    "filename": "char_2.png",
                    "frame": {"x": 32, "y": 0, "w": 16, "h": 16},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": 16, "h": 16},
                    "sourceSize": {"w": 16, "h": 16},
                    "duration": 100
                }
            ],
            "meta": {
                "app": "http://www.aseprite.org/",
                "version": "1.3",
                "image": "char.png",
                "size": {"w": 48, "h": 16},
                "scale": "1",
                "frameTags": [
                    {"name": "idle", "from": 0, "to": 0, "direction": "forward"},
                    {"name": "walk", "from": 1, "to": 2, "direction": "pingpong"}
                ]
            }
        }
        """
        let data = try AsepriteLoader().load(from: Data(json.utf8))

        #expect(data.frames.count == 3)
        #expect(data.meta.app == "http://www.aseprite.org/")
        #expect(data.meta.version == "1.3")
        #expect(data.meta.scale == "1")

        // swiftlint:disable:next force_unwrapping
        let tags = data.meta.frameTags!
        #expect(tags.count == 2)
        #expect(tags[0].name == "idle")
        #expect(tags[0].from == 0)
        #expect(tags[0].to == 0)
        #expect(tags[0].direction == "forward")
        #expect(tags[1].name == "walk")
        #expect(tags[1].from == 1)
        #expect(tags[1].to == 2)
        #expect(tags[1].direction == "pingpong")
    }

    @Test func parseMinimalMeta() throws {
        let json = """
        {
            "frames": [],
            "meta": {
                "image": "empty.png",
                "size": {"w": 0, "h": 0}
            }
        }
        """
        let data = try AsepriteLoader().load(from: Data(json.utf8))
        #expect(data.frames.isEmpty)
        #expect(data.meta.image == "empty.png")
        #expect(data.meta.app == nil)
        #expect(data.meta.version == nil)
        #expect(data.meta.scale == nil)
        #expect(data.meta.frameTags == nil)
    }

    @Test func loadFromBytes() throws {
        let json = """
        {"frames":[],"meta":{"image":"test.png","size":{"w":16,"h":16}}}
        """
        let data = try AsepriteLoader().load(from: Array(json.utf8))
        #expect(data.frames.isEmpty)
        #expect(data.meta.image == "test.png")
    }
}
