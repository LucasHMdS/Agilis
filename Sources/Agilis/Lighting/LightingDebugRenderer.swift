import AgilisCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

extension RenderBackend {

    /// Draw debug overlays for the 2D lighting system.
    ///
    /// Shows light radii, spotlight direction arrows, and shadow caster outlines.
    /// Call at the end of `render()` after camera drawing so overlays appear on top.
    ///
    /// - Parameters:
    ///   - world: The ECS world containing Light2D and ShadowCaster2D components.
    ///   - options: Lighting options (uses debug colors and debugDraw flag).
    public func drawLightingDebug(
        world: World,
        options: LightingOptions = LightingOptions()
    ) {
        guard options.debugDraw else { return }

        let lightColor = options.debugLightColor
        let shadowColor = options.debugShadowColor

        // Draw light radii and direction arrows
        world.forEach { (_: Entity, transform: inout Transform2D, light: inout Light2D) in
            guard light.isEnabled else { return }
            let pos = transform.position

            // Draw radius circle
            drawCircleOutline(center: pos, radius: light.radius, color: lightColor, thickness: 1)

            // Draw center dot
            drawCircle(center: pos, radius: 3, color: lightColor)

            // Draw spotlight direction arrow
            if case .spot(let direction, let coneAngle) = light.lightType {
                let dir = Vector2(x: cosf(direction), y: sinf(direction))
                let arrowEnd = pos + dir * light.radius * 0.5

                // Direction line
                drawLine(from: pos, to: arrowEnd, color: lightColor, thickness: 2)

                // Cone edges
                let leftDir = Vector2(
                    x: cosf(direction - coneAngle),
                    y: sinf(direction - coneAngle)
                )
                let rightDir = Vector2(
                    x: cosf(direction + coneAngle),
                    y: sinf(direction + coneAngle)
                )
                let coneLen = light.radius * 0.4
                drawLine(from: pos, to: pos + leftDir * coneLen, color: lightColor, thickness: 1)
                drawLine(from: pos, to: pos + rightDir * coneLen, color: lightColor, thickness: 1)
            }
        }

        // Draw shadow caster outlines
        world.forEach { (_: Entity, transform: inout Transform2D, collider: inout Collider2D, caster: inout ShadowCaster2D) in
            guard caster.isEnabled else { return }
            let pos = transform.position + collider.offset

            switch collider.shape {
            case .aabb(let halfExtents):
                if transform.rotation == 0 {
                    let rect = Rect(
                        x: pos.x - halfExtents.x,
                        y: pos.y - halfExtents.y,
                        width: halfExtents.x * 2,
                        height: halfExtents.y * 2
                    )
                    drawRectOutline(rect, color: shadowColor, thickness: 1)
                } else {
                    let verts = ShadowGeometry.aabbVertices(halfExtents: halfExtents)
                    let worldVerts = ShadowGeometry.transformVertices(verts, position: pos, rotation: transform.rotation)
                    for i in 0..<worldVerts.count {
                        let j = (i + 1) % worldVerts.count
                        drawLine(from: worldVerts[i], to: worldVerts[j], color: shadowColor, thickness: 1)
                    }
                }

            case .circle(let radius):
                drawCircleOutline(center: pos, radius: radius, color: shadowColor, thickness: 1)

            case .polygon(let poly):
                let worldVerts = ShadowGeometry.transformVertices(poly.vertices, position: pos, rotation: transform.rotation)
                for i in 0..<worldVerts.count {
                    let j = (i + 1) % worldVerts.count
                    drawLine(from: worldVerts[i], to: worldVerts[j], color: shadowColor, thickness: 1)
                }
            }
        }
    }

    /// Draw debug overlays for the normal and specular buffers.
    ///
    /// When `options.debugNormalBuffer` is true, draws the normal buffer as a
    /// semi-transparent overlay in the top-left corner. When `options.debugSpecularBuffer`
    /// is true, draws the specular buffer next to it.
    ///
    /// - Parameters:
    ///   - lighting: The lighting system (provides render target handles).
    ///   - options: Lighting options (uses debug flags).
    public func drawNormalBufferDebug(
        lighting: LightingSystem,
        options: LightingOptions = LightingOptions()
    ) {
        let debugScale: Float = 0.25
        var xOffset: Float = 10

        if options.debugNormalBuffer, lighting.normalBufferHandle != .invalid {
            let texture = renderTargetTexture(lighting.normalBufferHandle)
            let rtSize = renderTargetSize(lighting.normalBufferHandle)
            guard texture != .invalid, rtSize.width > 0 else { return }

            let w = rtSize.width * debugScale
            let h = rtSize.height * debugScale

            drawSprite(Sprite(
                texture: texture,
                sourceRect: Rect(x: 0, y: 0, width: rtSize.width, height: rtSize.height),
                position: Vector2(x: xOffset, y: 10),
                scale: Vector2(x: debugScale, y: debugScale),
                tint: Color(r: 255, g: 255, b: 255, a: 200),
                flipY: true
            ))
            drawRectOutline(
                Rect(x: xOffset, y: 10, width: w, height: h),
                color: .green, thickness: 1
            )
            xOffset += w + 10
        }

        if options.debugSpecularBuffer, lighting.specularBufferHandle != .invalid {
            let texture = renderTargetTexture(lighting.specularBufferHandle)
            let rtSize = renderTargetSize(lighting.specularBufferHandle)
            guard texture != .invalid, rtSize.width > 0 else { return }

            let w = rtSize.width * debugScale
            let h = rtSize.height * debugScale

            drawSprite(Sprite(
                texture: texture,
                sourceRect: Rect(x: 0, y: 0, width: rtSize.width, height: rtSize.height),
                position: Vector2(x: xOffset, y: 10),
                scale: Vector2(x: debugScale, y: debugScale),
                tint: Color(r: 255, g: 255, b: 255, a: 200),
                flipY: true
            ))
            drawRectOutline(
                Rect(x: xOffset, y: 10, width: w, height: h),
                color: .cyan, thickness: 1
            )
            xOffset += w + 10
        }

        if options.debugShadowBuffer, lighting.shadowBufferHandle != .invalid {
            let texture = renderTargetTexture(lighting.shadowBufferHandle)
            let rtSize = renderTargetSize(lighting.shadowBufferHandle)
            guard texture != .invalid, rtSize.width > 0 else { return }

            let w = rtSize.width * debugScale
            let h = rtSize.height * debugScale

            drawSprite(Sprite(
                texture: texture,
                sourceRect: Rect(x: 0, y: 0, width: rtSize.width, height: rtSize.height),
                position: Vector2(x: xOffset, y: 10),
                scale: Vector2(x: debugScale, y: debugScale),
                tint: Color(r: 255, g: 255, b: 255, a: 200),
                flipY: true
            ))
            drawRectOutline(
                Rect(x: xOffset, y: 10, width: w, height: h),
                color: .magenta, thickness: 1
            )
        }
    }
}
