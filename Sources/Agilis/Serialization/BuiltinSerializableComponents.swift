// MARK: - Retroactive SerializableComponent Conformance

// Sprite is defined in the Graphics module and has retroactive Component conformance
// in SpriteComponentConformance.swift. We add SerializableComponent here
// since SerializableComponent requires Component (which lives in Agilis).

extension Sprite: SerializableComponent {
    public static let componentName = "Sprite"
}
