import Agilis

// MARK: - Rendering Helpers

/// Seven-segment digit renderer. Draws digits 0-9 using rectangles.
///
/// Segment layout:
///  aaa
/// f   b
///  ggg
/// e   c
///  ddd
func drawDigit(_ digit: Int, at origin: Vector2, scale: Float, color: Color, renderer: any RenderBackend) {
    //                  abcdefg
    let segments: [UInt8] = [
        0b0111111,  // 0
        0b0000110,  // 1
        0b1011011,  // 2
        0b1001111,  // 3
        0b1100110,  // 4
        0b1101101,  // 5
        0b1111101,  // 6
        0b0000111,  // 7
        0b1111111,  // 8
        0b1101111  // 9
    ]

    let clamped = max(0, min(digit, 9))
    let mask = segments[clamped]
    let t = Pong.digitThickness * scale
    let w = Pong.digitWidth * scale
    let h = Pong.digitHeight * scale
    let x = origin.x
    let y = origin.y

    // a - top horizontal
    if mask & 0b0000001 != 0 {
        renderer.drawRect(Rect(x: x + t, y: y, width: w - 2 * t, height: t), color: color)
    }
    // b - top-right vertical
    if mask & 0b0000010 != 0 {
        renderer.drawRect(Rect(x: x + w - t, y: y + t, width: t, height: h - 2 * t), color: color)
    }
    // c - bottom-right vertical
    if mask & 0b0000100 != 0 {
        renderer.drawRect(Rect(x: x + w - t, y: y + h + t, width: t, height: h - 2 * t), color: color)
    }
    // d - bottom horizontal
    if mask & 0b0001000 != 0 {
        renderer.drawRect(Rect(x: x + t, y: y + 2 * h - t, width: w - 2 * t, height: t), color: color)
    }
    // e - bottom-left vertical
    if mask & 0b0010000 != 0 {
        renderer.drawRect(Rect(x: x, y: y + h + t, width: t, height: h - 2 * t), color: color)
    }
    // f - top-left vertical
    if mask & 0b0100000 != 0 {
        renderer.drawRect(Rect(x: x, y: y + t, width: t, height: h - 2 * t), color: color)
    }
    // g - middle horizontal
    if mask & 0b1000000 != 0 {
        renderer.drawRect(Rect(x: x + t, y: y + h - t / 2, width: w - 2 * t, height: t), color: color)
    }
}

func drawScore(_ score: Int, centerX: Float, y: Float, scale: Float, color: Color, renderer: any RenderBackend) {
    let digitW = Pong.digitWidth * scale
    let gap: Float = 4 * scale
    let digits = score < 10 ? [score] : [score / 10, score % 10]
    let totalWidth = Float(digits.count) * digitW + Float(digits.count - 1) * gap
    var x = centerX - totalWidth / 2

    for digit in digits {
        drawDigit(digit, at: Vector2(x: x, y: y), scale: scale, color: color, renderer: renderer)
        x += digitW + gap
    }
}

func drawCourtDashes(renderer: any RenderBackend, screenHeight: Float, centerX: Float) {
    var y: Float = 0
    let dashW = Pong.lineThickness
    let dashColor = Color(r: 80, g: 80, b: 80)
    while y < screenHeight {
        renderer.drawRect(
            Rect(x: centerX - dashW / 2, y: y, width: dashW, height: Pong.dashLength),
            color: dashColor
        )
        y += Pong.dashLength + Pong.dashGap
    }
}

func drawPongTitle(centerX: Float, y: Float, renderer: any RenderBackend) {
    let color = Color.white
    let t: Float = 5
    let lw: Float = 25
    let lh: Float = 40
    let gap: Float = 12
    let totalW = 4 * lw + 3 * gap
    var x = centerX - totalW / 2

    // P
    renderer.drawRect(Rect(x: x, y: y, width: t, height: lh), color: color)
    renderer.drawRect(Rect(x: x, y: y, width: lw, height: t), color: color)
    renderer.drawRect(Rect(x: x + lw - t, y: y, width: t, height: lh / 2), color: color)
    renderer.drawRect(Rect(x: x, y: y + lh / 2 - t / 2, width: lw, height: t), color: color)
    x += lw + gap

    // O
    renderer.drawRect(Rect(x: x, y: y, width: t, height: lh), color: color)
    renderer.drawRect(Rect(x: x + lw - t, y: y, width: t, height: lh), color: color)
    renderer.drawRect(Rect(x: x, y: y, width: lw, height: t), color: color)
    renderer.drawRect(Rect(x: x, y: y + lh - t, width: lw, height: t), color: color)
    x += lw + gap

    // N
    renderer.drawRect(Rect(x: x, y: y, width: t, height: lh), color: color)
    renderer.drawRect(Rect(x: x + lw - t, y: y, width: t, height: lh), color: color)
    renderer.drawLine(
        from: Vector2(x: x + t / 2, y: y),
        to: Vector2(x: x + lw - t / 2, y: y + lh),
        color: color,
        thickness: t
    )
    x += lw + gap

    // G
    renderer.drawRect(Rect(x: x, y: y, width: t, height: lh), color: color)
    renderer.drawRect(Rect(x: x, y: y, width: lw, height: t), color: color)
    renderer.drawRect(Rect(x: x, y: y + lh - t, width: lw, height: t), color: color)
    renderer.drawRect(Rect(x: x + lw - t, y: y + lh / 2, width: t, height: lh / 2), color: color)
    renderer.drawRect(Rect(x: x + lw / 2, y: y + lh / 2 - t / 2, width: lw / 2, height: t), color: color)
}
