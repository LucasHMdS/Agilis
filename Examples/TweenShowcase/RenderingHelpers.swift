import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Generate a procedural nine-patch texture for panel backgrounds.
/// Returns the texture handle and the source rect for the full texture.
func generateNinePatchTexture(renderer: any RenderBackend) -> (TextureHandle, Rect) {
    let size = 48
    let border = 12
    var pixels = [UInt8](repeating: 0, count: size * size * 4)

    for y in 0..<size {
        for x in 0..<size {
            let idx = (y * size + x) * 4
            let isEdge = x < 1 || x >= size - 1 || y < 1 || y >= size - 1
            let isBorder = x < border || x >= size - border || y < border || y >= size - border
            let isCorner = (x < 3 && y < 3) || (x >= size - 3 && y < 3)
                        || (x < 3 && y >= size - 3) || (x >= size - 3 && y >= size - 3)

            if isCorner {
                // Transparent corners for rounded look
                pixels[idx] = 0; pixels[idx+1] = 0; pixels[idx+2] = 0; pixels[idx+3] = 0
            } else if isEdge {
                // Bright border edge
                pixels[idx] = 80; pixels[idx+1] = 80; pixels[idx+2] = 110; pixels[idx+3] = 255
            } else if isBorder {
                // Border zone
                pixels[idx] = 55; pixels[idx+1] = 55; pixels[idx+2] = 75; pixels[idx+3] = 240
            } else {
                // Inner fill
                pixels[idx] = 40; pixels[idx+1] = 40; pixels[idx+2] = 55; pixels[idx+3] = 230
            }
        }
    }

    let image = ImageData(width: size, height: size, pixels: pixels)
    let texture = renderer.loadTextureFromImage(image)
    let sourceRect = Rect(x: 0, y: 0, width: Float(size), height: Float(size))
    return (texture, sourceRect)
}

/// Draw an easing curve as a series of connected line segments.
func drawEasingCurve(
    easing: EasingFunction,
    rect: Rect,
    resolution: Int = 40,
    color: Color,
    renderer: any RenderBackend
) {
    let step = 1.0 / Float(resolution)
    for i in 0..<resolution {
        let t0 = Float(i) * step
        let t1 = Float(i + 1) * step
        let v0 = easing.apply(t0)
        let v1 = easing.apply(t1)

        let x0 = rect.x + t0 * rect.width
        let y0 = rect.y + rect.height - v0 * rect.height
        let x1 = rect.x + t1 * rect.width
        let y1 = rect.y + rect.height - v1 * rect.height

        renderer.drawLine(
            from: Vector2(x: x0, y: y0),
            to: Vector2(x: x1, y: y1),
            color: color,
            thickness: 1.5
        )
    }
}

/// Draw a horizontal track line.
func drawTrack(startX: Float, endX: Float, y: Float, color: Color, renderer: any RenderBackend) {
    renderer.drawLine(
        from: Vector2(x: startX, y: y),
        to: Vector2(x: endX, y: y),
        color: color,
        thickness: 1
    )
}
