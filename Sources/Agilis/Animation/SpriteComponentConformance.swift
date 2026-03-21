// Sprite is defined in the Graphics module (no dependency on ECS),
// but Component is defined in Agilis. This retroactive conformance
// lets the AnimationSystem query for (SpriteAnimator, Sprite) pairs.
extension Sprite: Component {}
