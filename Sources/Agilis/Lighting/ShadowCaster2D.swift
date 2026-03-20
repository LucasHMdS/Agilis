/// Marks an entity as a shadow caster for the 2D lighting system.
///
/// The entity must also have a `Transform2D` and a `Collider2D` whose shape
/// defines the shadow-casting geometry. Without a `Collider2D`, this component
/// has no effect.
///
/// ## Usage
/// ```swift
/// let wall = world.createEntity()
/// world.addComponent(Transform2D(position: Vector2(x: 200, y: 150)), to: wall)
/// world.addComponent(Collider2D(shape: .aabb(halfExtents: Vector2(x: 50, y: 10))), to: wall)
/// world.addComponent(ShadowCaster2D(), to: wall)
/// ```
public struct ShadowCaster2D: Component, Sendable, Codable, SerializableComponent {
    public static let componentName = "ShadowCaster2D"

    /// Collision layer bitmask for this shadow caster. Lights only cast shadows
    /// from casters whose layer matches the light's `shadowLayerMask`.
    public var layer: UInt32

    /// Whether this shadow caster is currently active.
    public var isEnabled: Bool

    public init(layer: UInt32 = 1, isEnabled: Bool = true) {
        self.layer = layer
        self.isEnabled = isEnabled
    }
}
