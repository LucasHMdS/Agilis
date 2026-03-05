import AgilisCore

/// Debug information for a single active tween.
public struct TweenDebugInfo: Sendable {
    /// The entity being tweened.
    public let entity: Entity
    /// Description of what property is being animated.
    public let targetType: String
    /// Progress from 0.0 to 1.0.
    public let progress: Float
    /// Target position (only for position tweens).
    public let targetPosition: Vector2?

    public init(entity: Entity, targetType: String, progress: Float, targetPosition: Vector2?) {
        self.entity = entity
        self.targetType = targetType
        self.progress = progress
        self.targetPosition = targetPosition
    }
}

/// Configuration for tween debug rendering.
public struct TweenDebugRendererOptions: Sendable {
    /// Draw lines from current position to tween target (position tweens only).
    public var drawPaths: Bool
    /// Show tween type and progress near tweened entities.
    public var drawProgress: Bool
    /// Color for path lines.
    public var pathColor: Color
    /// Font size for labels.
    public var fontSize: Float

    public init(
        drawPaths: Bool = true,
        drawProgress: Bool = true,
        pathColor: Color = .magenta,
        fontSize: Float = 12
    ) {
        self.drawPaths = drawPaths
        self.drawProgress = drawProgress
        self.pathColor = pathColor
        self.fontSize = fontSize
    }
}

extension RenderBackend {

    /// Draw debug overlays for active tweens.
    ///
    /// Shows path lines for position tweens and progress labels. Call inside a camera
    /// block so overlays align with world-space positions.
    ///
    /// - Parameters:
    ///   - infos: Tween debug info from `TweenSystem.debugTweenInfo(world:)`.
    ///   - world: The ECS world (used to read current entity positions).
    ///   - font: Font for text labels.
    ///   - options: Rendering options.
    public func drawTweenDebug(
        infos: [TweenDebugInfo],
        world: World,
        font: FontHandle,
        options: TweenDebugRendererOptions = TweenDebugRendererOptions()
    ) {
        for info in infos {
            guard world.isAlive(info.entity) else { continue }

            guard let transform = world.getComponent(Transform2D.self, from: info.entity) else { continue }
            let pos = transform.position

            if options.drawPaths, let target = info.targetPosition {
                drawLine(from: pos, to: target, color: options.pathColor, thickness: 1)
                drawCircle(center: target, radius: 3, color: options.pathColor)
            }

            if options.drawProgress {
                let pct = Int(info.progress * 100)
                let text = "\(info.targetType) \(pct)%"
                drawText(text,
                         position: Vector2(x: pos.x, y: pos.y - 14),
                         font: font, size: options.fontSize, color: options.pathColor)
            }
        }
    }
}
