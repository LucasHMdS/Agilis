/// Type-erased protocol for component storage, allowing the World to hold
/// heterogeneous `ComponentStore<T>` instances in a single dictionary.
internal protocol AnyComponentStorage: AnyObject {
    /// Whether this storage contains a value for the given entity index.
    func has(entity: UInt32) -> Bool

    /// Remove the component for the given entity index, if present.
    func removeIfPresent(entity: UInt32)

    /// The number of components stored.
    var count: Int { get }

    /// All entity indices that have a component in this storage.
    var entityIndices: [UInt32] { get }
}

/// Concrete typed storage for a specific component type, backed by a `SparseSet`.
internal final class ComponentStore<T: Component>: AnyComponentStorage {
    deinit {}

    var sparseSet = SparseSet<T>()

    var count: Int { sparseSet.count }

    var entityIndices: [UInt32] { sparseSet.dense }

    func get(entity: UInt32) -> T? {
        sparseSet.get(key: entity)
    }

    func set(entity: UInt32, value: T) {
        sparseSet.insert(key: entity, value: value)
    }

    func has(entity: UInt32) -> Bool {
        sparseSet.contains(key: entity)
    }

    func removeIfPresent(entity: UInt32) {
        sparseSet.remove(key: entity)
    }

    /// Mutate a component value in-place. Returns `true` if the entity had this component.
    @discardableResult
    func withValue(for entity: UInt32, _ body: (inout T) -> Void) -> Bool {
        sparseSet.withValue(for: entity, body)
    }

    /// Access the dense index for an entity, allowing direct array access to the values.
    func denseIndex(for entity: UInt32) -> Int? {
        sparseSet.denseIndex(for: entity)
    }
}
