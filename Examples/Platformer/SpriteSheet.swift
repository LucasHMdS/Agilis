import Agilis

/// Generates a pixel-art sprite sheet at runtime — no external asset files.
enum MarioSprites {

    /// Sprite atlas entry: maps a name to a region in the sheet.
    struct Atlas {
        let texture: TextureHandle
        private let rects: [String: Rect]

        init(texture: TextureHandle, rects: [String: Rect]) {
            self.texture = texture
            self.rects = rects
        }

        func rect(_ name: String) -> Rect {
            guard let r = rects[name] else {
                Log.warn("MarioSprites", "Missing sprite: \(name)")
                return Rect()
            }
            return r
        }
    }

    // Sheet layout: 256 wide, rows packed top-to-bottom
    static let sheetWidth = 256
    static let sheetHeight = 256

    static func buildAtlas(renderer: any RenderBackend) -> Atlas {
        var pixels = [UInt8](repeating: 0, count: sheetWidth * sheetHeight * 4)
        var rects: [String: Rect] = [:]

        // Row 0 (y=0): Player sprites — each 16x32
        drawPlayerIdle(&pixels, x: 0, y: 0)
        rects["player_idle"] = Rect(x: 0, y: 0, width: 16, height: 32)

        drawPlayerWalk1(&pixels, x: 16, y: 0)
        rects["player_walk1"] = Rect(x: 16, y: 0, width: 16, height: 32)

        drawPlayerWalk2(&pixels, x: 32, y: 0)
        rects["player_walk2"] = Rect(x: 32, y: 0, width: 16, height: 32)

        drawPlayerJump(&pixels, x: 48, y: 0)
        rects["player_jump"] = Rect(x: 48, y: 0, width: 16, height: 32)

        drawPlayerDead(&pixels, x: 64, y: 0)
        rects["player_dead"] = Rect(x: 64, y: 0, width: 16, height: 32)

        // Row 1 (y=32): Tiles — each 16x16
        drawGroundTop(&pixels, x: 0, y: 32)
        rects["ground_top"] = Rect(x: 0, y: 32, width: 16, height: 16)

        drawGround(&pixels, x: 16, y: 32)
        rects["ground"] = Rect(x: 16, y: 32, width: 16, height: 16)

        drawBrick(&pixels, x: 32, y: 32)
        rects["brick"] = Rect(x: 32, y: 32, width: 16, height: 16)

        drawQuestionBlockActive(&pixels, x: 48, y: 32)
        rects["qblock_active"] = Rect(x: 48, y: 32, width: 16, height: 16)

        drawQuestionBlockUsed(&pixels, x: 64, y: 32)
        rects["qblock_used"] = Rect(x: 64, y: 32, width: 16, height: 16)

        // Row 1 continued: Pipe tiles
        drawPipeTopLeft(&pixels, x: 80, y: 32)
        rects["pipe_top_left"] = Rect(x: 80, y: 32, width: 16, height: 16)

        drawPipeTopRight(&pixels, x: 96, y: 32)
        rects["pipe_top_right"] = Rect(x: 96, y: 32, width: 16, height: 16)

        drawPipeBodyLeft(&pixels, x: 112, y: 32)
        rects["pipe_body_left"] = Rect(x: 112, y: 32, width: 16, height: 16)

        drawPipeBodyRight(&pixels, x: 128, y: 32)
        rects["pipe_body_right"] = Rect(x: 128, y: 32, width: 16, height: 16)

        // Row 2 (y=48): Enemies — 16x16
        drawGoombaWalk1(&pixels, x: 0, y: 48)
        rects["goomba_walk1"] = Rect(x: 0, y: 48, width: 16, height: 16)

        drawGoombaWalk2(&pixels, x: 16, y: 48)
        rects["goomba_walk2"] = Rect(x: 16, y: 48, width: 16, height: 16)

        drawGoombaSquished(&pixels, x: 32, y: 48)
        rects["goomba_squished"] = Rect(x: 32, y: 48, width: 16, height: 8)

        // Row 2 continued: Coins — 8x16
        drawCoinFrame(&pixels, x: 48, y: 48, widthPx: 8)
        rects["coin_0"] = Rect(x: 48, y: 48, width: 8, height: 16)

        drawCoinFrame(&pixels, x: 56, y: 48, widthPx: 6)
        rects["coin_1"] = Rect(x: 56, y: 48, width: 8, height: 16)

        drawCoinFrame(&pixels, x: 64, y: 48, widthPx: 2)
        rects["coin_2"] = Rect(x: 64, y: 48, width: 8, height: 16)

        drawCoinFrame(&pixels, x: 72, y: 48, widthPx: 6)
        rects["coin_3"] = Rect(x: 72, y: 48, width: 8, height: 16)

        // Row 3 (y=64): Decorations
        drawFlag(&pixels, x: 0, y: 64)
        rects["flag"] = Rect(x: 0, y: 64, width: 16, height: 16)

        drawCloud(&pixels, x: 16, y: 64)
        rects["cloud"] = Rect(x: 16, y: 64, width: 32, height: 16)

        drawHill(&pixels, x: 48, y: 64)
        rects["hill"] = Rect(x: 48, y: 64, width: 32, height: 16)

        let image = ImageData(width: sheetWidth, height: sheetHeight, pixels: pixels)
        let texture = renderer.loadTextureFromImage(image)
        return Atlas(texture: texture, rects: rects)
    }

    // MARK: - Pixel Helpers

    private static let W = sheetWidth

    private static func set(_ pixels: inout [UInt8], _ px: Int, _ py: Int,
                            _ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        guard px >= 0, py >= 0, px < sheetWidth, py < sheetHeight else { return }
        let i = (py * W + px) * 4
        pixels[i] = r; pixels[i+1] = g; pixels[i+2] = b; pixels[i+3] = a
    }

    private static func fillRect(_ pixels: inout [UInt8], _ x: Int, _ y: Int,
                                  _ w: Int, _ h: Int,
                                  _ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        for dy in 0..<h {
            for dx in 0..<w {
                set(&pixels, x + dx, y + dy, r, g, b, a)
            }
        }
    }

    // MARK: - Player Sprites (16x32 each)

    private static func drawPlayerBase(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        // Hat (red) — rows 0-4
        fillRect(&pixels, ox+3, oy+0, 10, 2, 255, 0, 0)    // hat top
        fillRect(&pixels, ox+2, oy+2, 12, 3, 255, 0, 0)    // hat brim

        // Face (skin) — rows 5-10
        fillRect(&pixels, ox+3, oy+5, 10, 6, 255, 200, 150) // face
        set(&pixels, ox+5, oy+7, 0, 0, 0)                   // left eye
        set(&pixels, ox+9, oy+7, 0, 0, 0)                   // right eye
        fillRect(&pixels, ox+6, oy+9, 4, 1, 180, 120, 80)   // mustache

        // Body (red shirt) — rows 11-17
        fillRect(&pixels, ox+3, oy+11, 10, 3, 255, 0, 0)    // shirt top
        fillRect(&pixels, ox+2, oy+14, 12, 4, 255, 0, 0)    // shirt body

        // Overalls (blue) — rows 18-25
        fillRect(&pixels, ox+3, oy+18, 10, 4, 0, 0, 200)    // overalls top
        fillRect(&pixels, ox+2, oy+22, 5, 2, 0, 0, 200)     // left strap
        fillRect(&pixels, ox+9, oy+22, 5, 2, 0, 0, 200)     // right strap
        // Buttons
        set(&pixels, ox+6, oy+19, 255, 215, 0)
        set(&pixels, ox+9, oy+19, 255, 215, 0)

        // Shoes (brown) — rows 26-29
        fillRect(&pixels, ox+2, oy+26, 5, 4, 139, 69, 19)   // left shoe
        fillRect(&pixels, ox+9, oy+26, 5, 4, 139, 69, 19)   // right shoe
    }

    private static func drawPlayerIdle(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        drawPlayerBase(&pixels, x: ox, y: oy)
        // Arms at sides
        fillRect(&pixels, ox+0, oy+13, 3, 5, 255, 200, 150) // left arm
        fillRect(&pixels, ox+13, oy+13, 3, 5, 255, 200, 150) // right arm
    }

    private static func drawPlayerWalk1(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        drawPlayerBase(&pixels, x: ox, y: oy)
        // Arms swinging
        fillRect(&pixels, ox+0, oy+12, 3, 5, 255, 200, 150) // left arm forward
        fillRect(&pixels, ox+13, oy+15, 3, 5, 255, 200, 150) // right arm back
        // Left foot forward
        fillRect(&pixels, ox+1, oy+28, 5, 4, 139, 69, 19)
        fillRect(&pixels, ox+9, oy+26, 5, 4, 0, 0, 0, 0)    // clear right shoe default
        fillRect(&pixels, ox+10, oy+28, 5, 4, 139, 69, 19)
    }

    private static func drawPlayerWalk2(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        drawPlayerBase(&pixels, x: ox, y: oy)
        // Arms swinging opposite
        fillRect(&pixels, ox+0, oy+15, 3, 5, 255, 200, 150) // left arm back
        fillRect(&pixels, ox+13, oy+12, 3, 5, 255, 200, 150) // right arm forward
        // Right foot forward
        fillRect(&pixels, ox+2, oy+26, 5, 4, 0, 0, 0, 0)    // clear left shoe default
        fillRect(&pixels, ox+1, oy+28, 5, 4, 139, 69, 19)
        fillRect(&pixels, ox+10, oy+28, 5, 4, 139, 69, 19)
    }

    private static func drawPlayerJump(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        drawPlayerBase(&pixels, x: ox, y: oy)
        // Arms up
        fillRect(&pixels, ox+0, oy+9, 3, 5, 255, 200, 150)  // left arm up
        fillRect(&pixels, ox+13, oy+9, 3, 5, 255, 200, 150)  // right arm up
        // Legs together
        fillRect(&pixels, ox+4, oy+26, 8, 4, 139, 69, 19)
    }

    private static func drawPlayerDead(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        // Simplified dead: body + X eyes
        fillRect(&pixels, ox+3, oy+0, 10, 2, 255, 0, 0)     // hat
        fillRect(&pixels, ox+2, oy+2, 12, 3, 255, 0, 0)
        fillRect(&pixels, ox+3, oy+5, 10, 6, 255, 200, 150)  // face
        // X eyes
        set(&pixels, ox+4, oy+6, 0, 0, 0); set(&pixels, ox+6, oy+8, 0, 0, 0)
        set(&pixels, ox+6, oy+6, 0, 0, 0); set(&pixels, ox+4, oy+8, 0, 0, 0)
        set(&pixels, ox+9, oy+6, 0, 0, 0); set(&pixels, ox+11, oy+8, 0, 0, 0)
        set(&pixels, ox+11, oy+6, 0, 0, 0); set(&pixels, ox+9, oy+8, 0, 0, 0)
        // Body
        fillRect(&pixels, ox+3, oy+11, 10, 7, 255, 0, 0)
        fillRect(&pixels, ox+3, oy+18, 10, 8, 0, 0, 200)
        fillRect(&pixels, ox+3, oy+26, 10, 4, 139, 69, 19)
    }

    // MARK: - Tile Sprites (16x16 each)

    private static func drawGroundTop(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        // Green grass top (3 rows)
        fillRect(&pixels, ox, oy, 16, 3, 34, 139, 34)
        // Grass detail
        set(&pixels, ox+3, oy+3, 34, 139, 34)
        set(&pixels, ox+8, oy+3, 34, 139, 34)
        set(&pixels, ox+12, oy+3, 34, 139, 34)
        // Brown dirt
        fillRect(&pixels, ox, oy+3, 16, 13, 139, 90, 43)
        // Dirt texture dots
        set(&pixels, ox+2, oy+6, 120, 75, 35)
        set(&pixels, ox+9, oy+8, 120, 75, 35)
        set(&pixels, ox+5, oy+11, 120, 75, 35)
        set(&pixels, ox+13, oy+13, 120, 75, 35)
    }

    private static func drawGround(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox, oy, 16, 16, 139, 90, 43)
        // Texture dots
        set(&pixels, ox+3, oy+3, 120, 75, 35)
        set(&pixels, ox+10, oy+5, 120, 75, 35)
        set(&pixels, ox+6, oy+9, 120, 75, 35)
        set(&pixels, ox+1, oy+12, 120, 75, 35)
        set(&pixels, ox+12, oy+13, 120, 75, 35)
    }

    private static func drawBrick(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox, oy, 16, 16, 180, 100, 50)
        // Horizontal mortar lines
        fillRect(&pixels, ox, oy+4, 16, 1, 140, 75, 35)
        fillRect(&pixels, ox, oy+8, 16, 1, 140, 75, 35)
        fillRect(&pixels, ox, oy+12, 16, 1, 140, 75, 35)
        // Vertical mortar lines (offset per row)
        fillRect(&pixels, ox+7, oy, 1, 4, 140, 75, 35)
        fillRect(&pixels, ox+3, oy+5, 1, 3, 140, 75, 35)
        fillRect(&pixels, ox+11, oy+5, 1, 3, 140, 75, 35)
        fillRect(&pixels, ox+7, oy+9, 1, 3, 140, 75, 35)
        fillRect(&pixels, ox+3, oy+13, 1, 3, 140, 75, 35)
        fillRect(&pixels, ox+11, oy+13, 1, 3, 140, 75, 35)
    }

    private static func drawQuestionBlockActive(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        // Yellow body
        fillRect(&pixels, ox, oy, 16, 16, 255, 200, 50)
        // Border
        fillRect(&pixels, ox, oy, 16, 1, 180, 140, 30)      // top
        fillRect(&pixels, ox, oy+15, 16, 1, 180, 140, 30)    // bottom
        fillRect(&pixels, ox, oy, 1, 16, 180, 140, 30)       // left
        fillRect(&pixels, ox+15, oy, 1, 16, 180, 140, 30)    // right
        // "?" mark
        fillRect(&pixels, ox+5, oy+3, 6, 2, 255, 255, 255)   // ? top
        fillRect(&pixels, ox+9, oy+5, 3, 2, 255, 255, 255)   // ? right
        fillRect(&pixels, ox+6, oy+7, 4, 2, 255, 255, 255)   // ? middle
        fillRect(&pixels, ox+5, oy+9, 3, 2, 255, 255, 255)   // ? bottom
        fillRect(&pixels, ox+6, oy+12, 3, 2, 255, 255, 255)  // ? dot
    }

    private static func drawQuestionBlockUsed(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox, oy, 16, 16, 120, 80, 30)
        // Border
        fillRect(&pixels, ox, oy, 16, 1, 90, 60, 20)
        fillRect(&pixels, ox, oy+15, 16, 1, 90, 60, 20)
        fillRect(&pixels, ox, oy, 1, 16, 90, 60, 20)
        fillRect(&pixels, ox+15, oy, 1, 16, 90, 60, 20)
    }

    // MARK: - Pipe Sprites (16x16 each, 2x2 arrangement)

    private static func drawPipeTopLeft(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox, oy, 16, 16, 0, 160, 0)
        // Highlight on left
        fillRect(&pixels, ox+1, oy+1, 3, 14, 100, 220, 100)
        // Dark border left + top
        fillRect(&pixels, ox, oy, 1, 16, 0, 120, 0)
        fillRect(&pixels, ox, oy, 16, 1, 0, 120, 0)
        // Lip at top
        fillRect(&pixels, ox, oy, 16, 4, 0, 170, 0)
        fillRect(&pixels, ox, oy, 16, 1, 0, 120, 0)
        fillRect(&pixels, ox+1, oy+1, 3, 2, 120, 230, 120)
    }

    private static func drawPipeTopRight(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox, oy, 16, 16, 0, 160, 0)
        // Dark border right + top
        fillRect(&pixels, ox+15, oy, 1, 16, 0, 120, 0)
        fillRect(&pixels, ox, oy, 16, 1, 0, 120, 0)
        // Lip
        fillRect(&pixels, ox, oy, 16, 4, 0, 170, 0)
        fillRect(&pixels, ox, oy, 16, 1, 0, 120, 0)
        fillRect(&pixels, ox+15, oy, 1, 4, 0, 120, 0)
    }

    private static func drawPipeBodyLeft(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox, oy, 16, 16, 0, 160, 0)
        fillRect(&pixels, ox+1, oy, 3, 16, 100, 220, 100) // highlight
        fillRect(&pixels, ox, oy, 1, 16, 0, 120, 0)       // dark border
    }

    private static func drawPipeBodyRight(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox, oy, 16, 16, 0, 160, 0)
        fillRect(&pixels, ox+15, oy, 1, 16, 0, 120, 0) // dark border right
    }

    // MARK: - Enemy Sprites

    private static func drawGoombaWalk1(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        // Brown mushroom body
        fillRect(&pixels, ox+2, oy+0, 12, 4, 160, 100, 50)   // cap top
        fillRect(&pixels, ox+1, oy+4, 14, 4, 160, 100, 50)   // cap mid
        fillRect(&pixels, ox+0, oy+8, 16, 2, 160, 100, 50)   // cap bottom
        // Face
        fillRect(&pixels, ox+2, oy+6, 12, 4, 255, 220, 180)  // skin
        // Eyes
        set(&pixels, ox+4, oy+7, 0, 0, 0)
        set(&pixels, ox+5, oy+7, 0, 0, 0)
        set(&pixels, ox+10, oy+7, 0, 0, 0)
        set(&pixels, ox+11, oy+7, 0, 0, 0)
        // Angry brows
        set(&pixels, ox+3, oy+6, 0, 0, 0)
        set(&pixels, ox+12, oy+6, 0, 0, 0)
        // Body/stem
        fillRect(&pixels, ox+4, oy+10, 8, 2, 200, 150, 80)
        // Feet — walk frame 1 (spread)
        fillRect(&pixels, ox+1, oy+12, 5, 4, 80, 50, 25)     // left foot
        fillRect(&pixels, ox+10, oy+12, 5, 4, 80, 50, 25)    // right foot
    }

    private static func drawGoombaWalk2(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        // Same as walk1 but feet together
        fillRect(&pixels, ox+2, oy+0, 12, 4, 160, 100, 50)
        fillRect(&pixels, ox+1, oy+4, 14, 4, 160, 100, 50)
        fillRect(&pixels, ox+0, oy+8, 16, 2, 160, 100, 50)
        fillRect(&pixels, ox+2, oy+6, 12, 4, 255, 220, 180)
        set(&pixels, ox+4, oy+7, 0, 0, 0)
        set(&pixels, ox+5, oy+7, 0, 0, 0)
        set(&pixels, ox+10, oy+7, 0, 0, 0)
        set(&pixels, ox+11, oy+7, 0, 0, 0)
        set(&pixels, ox+3, oy+6, 0, 0, 0)
        set(&pixels, ox+12, oy+6, 0, 0, 0)
        fillRect(&pixels, ox+4, oy+10, 8, 2, 200, 150, 80)
        // Feet together
        fillRect(&pixels, ox+2, oy+12, 5, 4, 80, 50, 25)
        fillRect(&pixels, ox+9, oy+12, 5, 4, 80, 50, 25)
    }

    private static func drawGoombaSquished(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        fillRect(&pixels, ox+0, oy+0, 16, 4, 160, 100, 50)
        fillRect(&pixels, ox+1, oy+4, 14, 4, 160, 100, 50)
        // Squished eyes
        set(&pixels, ox+4, oy+2, 0, 0, 0); set(&pixels, ox+5, oy+2, 0, 0, 0)
        set(&pixels, ox+10, oy+2, 0, 0, 0); set(&pixels, ox+11, oy+2, 0, 0, 0)
    }

    // MARK: - Coin Sprites (8x16 each)

    private static func drawCoinFrame(_ pixels: inout [UInt8], x ox: Int, y oy: Int,
                                       widthPx: Int) {
        let coinR: UInt8 = 255, coinG: UInt8 = 215, coinB: UInt8 = 0
        let darkR: UInt8 = 200, darkG: UInt8 = 170, darkB: UInt8 = 0

        let margin = (8 - widthPx) / 2
        // Outer
        fillRect(&pixels, ox + margin, oy+1, widthPx, 14, coinR, coinG, coinB)
        // Top/bottom caps
        if widthPx >= 4 {
            fillRect(&pixels, ox + margin + 1, oy, widthPx - 2, 1, coinR, coinG, coinB)
            fillRect(&pixels, ox + margin + 1, oy+15, widthPx - 2, 1, coinR, coinG, coinB)
        }
        // Dark edge for depth
        if widthPx >= 3 {
            fillRect(&pixels, ox + margin + widthPx - 1, oy+2, 1, 12, darkR, darkG, darkB)
        }
    }

    // MARK: - Decoration Sprites

    private static func drawFlag(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        // Green triangular flag
        for row in 0..<10 {
            let w = 10 - row
            fillRect(&pixels, ox+1, oy + row, w, 1, 0, 200, 0)
        }
        // Pole line on left
        fillRect(&pixels, ox, oy, 1, 16, 80, 80, 80)
    }

    private static func drawCloud(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        let cr: UInt8 = 255, cg: UInt8 = 255, cb: UInt8 = 255, ca: UInt8 = 200

        // Three overlapping bumps
        fillRect(&pixels, ox+4, oy+4, 24, 8, cr, cg, cb, ca)   // main body
        fillRect(&pixels, ox+8, oy+2, 8, 4, cr, cg, cb, ca)    // top bump center
        fillRect(&pixels, ox+18, oy+2, 8, 4, cr, cg, cb, ca)   // top bump right
        fillRect(&pixels, ox+2, oy+6, 4, 4, cr, cg, cb, ca)    // left extension
        fillRect(&pixels, ox+26, oy+6, 4, 4, cr, cg, cb, ca)   // right extension
    }

    private static func drawHill(_ pixels: inout [UInt8], x ox: Int, y oy: Int) {
        let hr: UInt8 = 50, hg: UInt8 = 160, hb: UInt8 = 50, ha: UInt8 = 180

        // Triangular hill shape
        for row in 0..<16 {
            let w = (16 - row) * 2
            let startX = ox + 16 - (16 - row)
            fillRect(&pixels, startX, oy + row, w, 1, hr, hg, hb, ha)
        }
    }
}
