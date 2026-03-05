import AgilisCore

/// Configuration for animation debug rendering.
public struct AnimationDebugRendererOptions: Sendable {
    /// Draw outlines around sprite source rectangles.
    public var drawSourceRects: Bool
    /// Show clip name, frame index, and play state near animated entities.
    public var drawAnimatorState: Bool
    /// Color for source rect outlines.
    public var sourceRectColor: Color
    /// Color for state text labels.
    public var stateTextColor: Color
    /// Font size for labels.
    public var fontSize: Float

    public init(
        drawSourceRects: Bool = true,
        drawAnimatorState: Bool = true,
        sourceRectColor: Color = .green,
        stateTextColor: Color = .white,
        fontSize: Float = 12
    ) {
        self.drawSourceRects = drawSourceRects
        self.drawAnimatorState = drawAnimatorState
        self.sourceRectColor = sourceRectColor
        self.stateTextColor = stateTextColor
        self.fontSize = fontSize
    }
}

extension RenderBackend {

    /// Draw debug overlays for all animated sprites.
    ///
    /// Shows source rect outlines and animator state labels. Call inside a camera
    /// block so overlays align with world-space sprite positions.
    ///
    /// - Parameters:
    ///   - world: The ECS world containing animated entities.
    ///   - font: Font for text labels.
    ///   - options: Rendering options.
    public func drawAnimationDebug(
        world: World,
        font: FontHandle,
        options: AnimationDebugRendererOptions = AnimationDebugRendererOptions()
    ) {
        world.forEach { (_: Entity, transform: inout Transform2D, animator: inout SpriteAnimator, sprite: inout Sprite) in
            let pos = transform.position

            if options.drawSourceRects {
                let sr = sprite.sourceRect
                // Draw source rect outline at entity position (simplified: shows rect dimensions)
                let displayRect = Rect(
                    x: pos.x - sr.width * 0.5,
                    y: pos.y - sr.height * 0.5,
                    width: sr.width,
                    height: sr.height
                )
                drawRectOutline(displayRect, color: options.sourceRectColor, thickness: 1)
            }

            if options.drawAnimatorState {
                let clipName = animator.clip.name
                let frameIndex = animator.currentFrameIndex
                let totalFrames = animator.clip.frames.count
                let status = animator.isPlaying ? ">" : "||"
                let text = "\(status) \(clipName) [\(frameIndex)/\(totalFrames)]"
                drawText(text,
                         position: Vector2(x: pos.x, y: pos.y - 20),
                         font: font, size: options.fontSize, color: options.stateTextColor)
            }
        }
    }
}
