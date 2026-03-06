import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

// MARK: - Sprite Helper

/// Creates a Sprite from an atlas rect, scaled to fill `destWidth x destHeight`,
/// centered at `pos`.
private func makeSprite(texture: TextureHandle, source: Rect,
                        pos: Vector2, destWidth: Float, destHeight: Float,
                        flipX: Bool = false, tint: Color = .white) -> Sprite {
    var sprite = Sprite(texture: texture)
    sprite.sourceRect = source
    sprite.position = Vector2(x: pos.x - destWidth / 2, y: pos.y - destHeight / 2)
    sprite.scale = Vector2(x: destWidth / source.width, y: destHeight / source.height)
    sprite.flipX = flipX
    sprite.tint = tint
    return sprite
}

// MARK: - Player Drawing

func drawPlayer(pos: Vector2, player: Player, gameTime: Float,
                atlas: MarioSprites.Atlas, renderer: any RenderBackend) {
    // Blink when invincible
    if player.isInvincible {
        let blink = Int(player.invincibleTimer * 10) % 2
        if blink == 0 { return }
    }

    let rectName: String
    if player.isDead {
        rectName = "player_dead"
    } else if !player.isGrounded {
        rectName = "player_jump"
    } else if player.walkAnimTimer > 0 {
        let frame = Int(player.walkAnimTimer * 6) % 2
        rectName = frame == 0 ? "player_walk1" : "player_walk2"
    } else {
        rectName = "player_idle"
    }

    let sprite = makeSprite(
        texture: atlas.texture, source: atlas.rect(rectName),
        pos: pos, destWidth: Mario.playerWidth, destHeight: Mario.playerHeight,
        flipX: !player.facingRight
    )
    renderer.drawSprite(sprite)
}

// MARK: - Tile Drawing

func drawTile(pos: Vector2, tile: Tile, atlas: MarioSprites.Atlas,
              renderer: any RenderBackend) {
    let s = Mario.tileSize

    switch tile.tileType {
    case .groundTop:
        let sprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("ground_top"),
            pos: pos, destWidth: s, destHeight: s
        )
        renderer.drawSprite(sprite)

    case .ground:
        let sprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("ground"),
            pos: pos, destWidth: s, destHeight: s
        )
        renderer.drawSprite(sprite)

    case .brick:
        let sprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("brick"),
            pos: pos, destWidth: s, destHeight: s
        )
        renderer.drawSprite(sprite)

    case .pipeTop:
        // Pipe top is wider: two 16x16 tiles side by side, scaled to fill wider area
        let topW = s + 8
        let halfW = topW / 2
        let leftSprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("pipe_top_left"),
            pos: Vector2(x: pos.x - halfW / 2, y: pos.y),
            destWidth: halfW, destHeight: s
        )
        let rightSprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("pipe_top_right"),
            pos: Vector2(x: pos.x + halfW / 2, y: pos.y),
            destWidth: halfW, destHeight: s
        )
        renderer.drawSprite(leftSprite)
        renderer.drawSprite(rightSprite)

    case .pipeBody:
        let leftSprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("pipe_body_left"),
            pos: Vector2(x: pos.x - s / 4, y: pos.y),
            destWidth: s / 2, destHeight: s
        )
        let rightSprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("pipe_body_right"),
            pos: Vector2(x: pos.x + s / 4, y: pos.y),
            destWidth: s / 2, destHeight: s
        )
        renderer.drawSprite(leftSprite)
        renderer.drawSprite(rightSprite)
    }
}

// MARK: - Question Block Drawing

func drawQuestionBlock(pos: Vector2, block: QuestionBlock,
                       atlas: MarioSprites.Atlas, renderer: any RenderBackend) {
    let s = Mario.tileSize
    let isActive = block.state == .active || block.state == .bouncing
    let rectName = isActive ? "qblock_active" : "qblock_used"

    let sprite = makeSprite(
        texture: atlas.texture, source: atlas.rect(rectName),
        pos: pos, destWidth: s, destHeight: s
    )
    renderer.drawSprite(sprite)
}

// MARK: - Enemy Drawing

func drawGoomba(pos: Vector2, enemy: Enemy, gameTime: Float,
                atlas: MarioSprites.Atlas, renderer: any RenderBackend) {
    if enemy.isDead {
        let sprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("goomba_squished"),
            pos: Vector2(x: pos.x, y: pos.y + Mario.goombaHeight / 2 - 4),
            destWidth: Mario.goombaWidth, destHeight: 8
        )
        renderer.drawSprite(sprite)
        return
    }

    let frame = Int(gameTime * 4) % 2
    let rectName = frame == 0 ? "goomba_walk1" : "goomba_walk2"

    let sprite = makeSprite(
        texture: atlas.texture, source: atlas.rect(rectName),
        pos: pos, destWidth: Mario.goombaWidth, destHeight: Mario.goombaHeight
    )
    renderer.drawSprite(sprite)
}

// MARK: - Coin Drawing

func drawCoin(pos: Vector2, time: Float, atlas: MarioSprites.Atlas,
              renderer: any RenderBackend) {
    let frame = Int(time * 6) % 4
    let rectName = "coin_\(frame)"
    let coinSize: Float = Mario.coinRadius * 2

    let sprite = makeSprite(
        texture: atlas.texture, source: atlas.rect(rectName),
        pos: pos, destWidth: coinSize, destHeight: coinSize
    )
    renderer.drawSprite(sprite)
}

// MARK: - Flagpole Drawing

func drawFlagpole(pos: Vector2, atlas: MarioSprites.Atlas,
                  renderer: any RenderBackend) {
    let baseY = Float(Mario.groundRow) * Mario.tileSize
    let topY = Float(Mario.groundRow - 8) * Mario.tileSize

    // Pole (still a line — looks fine for a thin pole)
    renderer.drawLine(
        from: Vector2(x: pos.x, y: topY),
        to: Vector2(x: pos.x, y: baseY),
        color: Mario.flagpoleColor, thickness: 4
    )

    // Ball on top
    renderer.drawCircle(center: Vector2(x: pos.x, y: topY), radius: 5,
                        color: Mario.coinColor)

    // Flag sprite
    let flagSprite = makeSprite(
        texture: atlas.texture, source: atlas.rect("flag"),
        pos: Vector2(x: pos.x + 14, y: topY + 12),
        destWidth: 24, destHeight: 20
    )
    renderer.drawSprite(flagSprite)
}

// MARK: - Background Drawing

func drawBackground(cameraTargetX: Float, screenSize: Size,
                    atlas: MarioSprites.Atlas, renderer: any RenderBackend) {
    // Parallax hills using sprites
    let parallaxX = cameraTargetX * 0.3
    for i in 0..<8 {
        let hillX = Float(i) * 300 - parallaxX
            .truncatingRemainder(dividingBy: 2400)
        let hillY = screenSize.height - 50
        let hillSprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("hill"),
            pos: Vector2(x: hillX, y: hillY),
            destWidth: 200, destHeight: 100
        )
        renderer.drawSprite(hillSprite)
    }

    // Clouds using sprites
    let cloudParallax = cameraTargetX * 0.1
    for i in 0..<6 {
        let cx = Float(i) * 350 + 100 - cloudParallax
            .truncatingRemainder(dividingBy: 2100)
        let cy: Float = 50 + Float(i % 3) * 25
        let cloudSprite = makeSprite(
            texture: atlas.texture, source: atlas.rect("cloud"),
            pos: Vector2(x: cx, y: cy),
            destWidth: 96, destHeight: 48
        )
        renderer.drawSprite(cloudSprite)
    }
}

// MARK: - HUD Drawing

func drawHUD(score: Int, lives: Int, coins: Int, font: FontHandle,
             renderer: any RenderBackend) {
    let y: Float = 8

    renderer.drawText("SCORE", position: Vector2(x: 16, y: y),
                      font: font, size: 16, color: .white)
    renderer.drawText("\(score)", position: Vector2(x: 16, y: y + 18),
                      font: font, size: 20, color: .white)

    renderer.drawText("COINS", position: Vector2(x: 200, y: y),
                      font: font, size: 16, color: .white)
    renderer.drawText("\(coins)", position: Vector2(x: 200, y: y + 18),
                      font: font, size: 20, color: Mario.coinColor)

    renderer.drawText("LIVES", position: Vector2(x: 400, y: y),
                      font: font, size: 16, color: .white)
    renderer.drawText("\(lives)", position: Vector2(x: 400, y: y + 18),
                      font: font, size: 20, color: .white)
}
