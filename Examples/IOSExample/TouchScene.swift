import Agilis

/// A simple scene that demonstrates touch input on iOS.
///
/// - Tap to place a colored circle
/// - Drag to move a circle in real-time
/// - Circles fade out over time
final class TouchScene: Scene {
    private var circles: [(position: Vector2, color: Color, age: Double)] = []
    private let maxAge: Double = 3.0
    private var hue: Float = 0

    func didEnter(app: Application) {
        app.renderer.setBackgroundColor(Color(r: 30, g: 30, b: 40))
    }

    func update(app: Application, deltaTime: Double) {
        // Spawn circles from touches
        for touch in app.input.touches {
            if touch.phase == .began || touch.phase == .moved {
                let color = colorFromHue(hue)
                circles.append((position: touch.position, color: color, age: 0))
                hue += 5
                if hue >= 360 { hue -= 360 }
            }
        }

        // Age and remove old circles
        circles = circles.compactMap { circle in
            let newAge = circle.age + deltaTime
            if newAge >= maxAge { return nil }
            return (circle.position, circle.color, newAge)
        }
    }

    func render(app: Application, interpolation: Double) {
        let renderer = app.renderer

        for circle in circles {
            let alpha = UInt8(255.0 * (1.0 - circle.age / maxAge))
            let radius = Float(20 + 30 * (circle.age / maxAge))
            let color = Color(r: circle.color.r, g: circle.color.g, b: circle.color.b, a: alpha)
            renderer.drawCircle(center: circle.position, radius: radius, color: color)
        }

        // Draw active touch points
        for touch in app.input.touches {
            if touch.phase == .began || touch.phase == .moved {
                renderer.drawCircle(center: touch.position, radius: 15, color: .white)
                renderer.drawCircleOutline(center: touch.position, radius: 20, color: .white, thickness: 2)
            }
        }

        // HUD
        let screenSize = renderer.screenSize
        let font = app.renderer.loadDefaultFont()
        renderer.drawText(
            "Touch the screen!",
            position: Vector2(x: screenSize.width / 2 - 80, y: 40),
            font: font,
            size: 24,
            color: Color(r: 200, g: 200, b: 200)
        )
        renderer.drawText(
            "FPS: \(app.fps)",
            position: Vector2(x: 10, y: 10),
            font: font,
            size: 16,
            color: Color(r: 150, g: 150, b: 150)
        )
    }

    // MARK: - Helpers

    private func colorFromHue(_ h: Float) -> Color {
        let s: Float = 0.8
        let v: Float = 1.0
        let c = v * s
        let x = c * (1 - abs(((h / 60).truncatingRemainder(dividingBy: 2)) - 1))
        let m = v - c

        let r1, g1, b1: Float
        switch h {
        case 0..<60:   r1 = c; g1 = x; b1 = 0
        case 60..<120:  r1 = x; g1 = c; b1 = 0
        case 120..<180: r1 = 0; g1 = c; b1 = x
        case 180..<240: r1 = 0; g1 = x; b1 = c
        case 240..<300: r1 = x; g1 = 0; b1 = c
        default:        r1 = c; g1 = 0; b1 = x
        }

        return Color(
            r: UInt8((r1 + m) * 255),
            g: UInt8((g1 + m) * 255),
            b: UInt8((b1 + m) * 255)
        )
    }
}
