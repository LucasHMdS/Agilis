

extension Renderer {

    /// Draw all active particles from an emitter.
    ///
    /// Call this in your scene's `render()` method. For world-space emitters,
    /// particle positions are absolute. For local-space emitters, positions
    /// are offset by `emitterPosition`.
    ///
    /// ## Usage
    /// ```swift
    /// world.forEach { (_: Entity, emitter: inout ParticleEmitter, transform: inout Transform2D) in
    ///     app.renderer.drawParticles(emitter, at: transform.position)
    /// }
    /// ```
    public func drawParticles(_ emitter: ParticleEmitter, at emitterPosition: Vector2) {
        guard emitter.activeCount > 0 else { return }

        for i in 0..<emitter.activeCount {
            let particle = emitter.particles[i]
            let t = particle.normalizedAge

            let color = Color.lerp(emitter.startColor, emitter.endColor, t: t)
            let scale = lerp(particle.scale, emitter.endScale, t: t)

            let drawPos: Vector2
            if emitter.worldSpace {
                drawPos = particle.position
            } else {
                drawPos = emitterPosition + particle.position
            }

            switch emitter.renderShape {
            case .circle(let radius):
                drawCircle(center: drawPos, radius: radius * scale, color: color)

            case .rect(let width, let height):
                let w = width * scale
                let h = height * scale
                drawRect(
                    Rect(x: drawPos.x - w / 2, y: drawPos.y - h / 2, width: w, height: h),
                    color: color
                )

            case .sprite(let texture, let sourceRect):
                drawSprite(Sprite(
                    texture: texture,
                    sourceRect: sourceRect,
                    position: drawPos,
                    scale: Vector2(x: scale, y: scale),
                    rotation: particle.rotation,
                    origin: Vector2(x: sourceRect.width / 2, y: sourceRect.height / 2),
                    tint: color
                ))
            }
        }
    }
}
