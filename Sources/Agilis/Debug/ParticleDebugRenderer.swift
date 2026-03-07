#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Configuration for particle debug rendering.
public struct ParticleDebugRendererOptions: Sendable {
    /// Draw emission shape outlines.
    public var drawEmissionShape: Bool
    /// Show particle count labels.
    public var drawParticleCount: Bool
    /// Color for emission shape outlines.
    public var emissionShapeColor: Color
    /// Font size for labels.
    public var fontSize: Float

    public init(
        drawEmissionShape: Bool = true,
        drawParticleCount: Bool = true,
        emissionShapeColor: Color = .yellow,
        fontSize: Float = 12
    ) {
        self.drawEmissionShape = drawEmissionShape
        self.drawParticleCount = drawParticleCount
        self.emissionShapeColor = emissionShapeColor
        self.fontSize = fontSize
    }
}

extension RenderBackend {

    /// Draw debug overlays for all particle emitters.
    ///
    /// Shows emission shape outlines and particle count labels. Call inside a camera
    /// block so overlays align with world-space emitter positions.
    ///
    /// - Parameters:
    ///   - world: The ECS world containing particle emitter entities.
    ///   - font: Font for text labels.
    ///   - options: Rendering options.
    public func drawParticleDebug(
        world: World,
        font: FontHandle,
        options: ParticleDebugRendererOptions = ParticleDebugRendererOptions()
    ) {
        world.forEach { (_: Entity, transform: inout Transform2D, emitter: inout ParticleEmitter) in
            let pos = transform.position
            let color = options.emissionShapeColor

            if options.drawEmissionShape {
                switch emitter.emissionShape {
                case .point:
                    // Crosshair
                    let size: Float = 6
                    drawLine(
                        from: Vector2(x: pos.x - size, y: pos.y),
                        to: Vector2(x: pos.x + size, y: pos.y),
                        color: color,
                        thickness: 1
                    )
                    drawLine(
                        from: Vector2(x: pos.x, y: pos.y - size),
                        to: Vector2(x: pos.x, y: pos.y + size),
                        color: color,
                        thickness: 1
                    )

                case .circle(let radius):
                    drawCircleOutline(center: pos, radius: radius, color: color, thickness: 1)

                case .ring(let radius):
                    drawCircleOutline(center: pos, radius: radius, color: color, thickness: 1)
                    // Inner dot to distinguish from circle
                    drawCircle(center: pos, radius: 2, color: color)

                case .rect(let width, let height):
                    let rect = Rect(
                        x: pos.x - width * 0.5,
                        y: pos.y - height * 0.5,
                        width: width,
                        height: height
                    )
                    drawRectOutline(rect, color: color, thickness: 1)
                }
            }

            if options.drawParticleCount {
                let active = emitter.particles.count
                let max = emitter.maxParticles
                let status = emitter.isEmitting ? "ON" : "OFF"
                let text = "\(active)/\(max) [\(status)]"
                drawText(
                    text,
                    position: Vector2(x: pos.x + 8, y: pos.y - 8),
                    font: font,
                    size: options.fontSize,
                    color: color
                )
            }
        }
    }
}
