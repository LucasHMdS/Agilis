import AgilisCore

// Sprite is defined in AgilisCore (no dependency on ECS),
// but Component is defined in Agilis. This retroactive conformance
// lets the AnimationSystem query for (SpriteAnimator, Sprite) pairs.
extension Sprite: Component {}
