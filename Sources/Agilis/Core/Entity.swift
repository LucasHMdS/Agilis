/// A lightweight handle to an entity in the ECS world.
///
/// Uses generational indexing: when an entity is destroyed and its slot recycled,
/// the generation increments. Any stale `Entity` handle still holding the old
/// generation will fail `isAlive` checks, preventing use-after-destroy bugs.
public struct Entity: Sendable, Hashable {
    /// The slot index in the entity allocator.
    public let index: UInt32

    /// The generation of this slot when the entity was created.
    public let generation: UInt32

    public init(index: UInt32, generation: UInt32) {
        self.index = index
        self.generation = generation
    }

    /// A sentinel value representing no entity.
    public static let null = Entity(index: .max, generation: 0)

    /// Backward-compatible accessor. Prefer `index` for new code.
    @available(*, deprecated, renamed: "index")
    public var id: UInt64 { UInt64(index) }
}
