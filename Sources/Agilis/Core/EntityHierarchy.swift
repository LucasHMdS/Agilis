/// Manages parent-child relationships between entities.
///
/// When a parent entity is destroyed, the `World` recursively destroys all children.
/// An entity can have at most one parent but any number of children.
internal struct EntityHierarchy {
    /// Maps child entity index -> parent entity index.
    private var parents: [UInt32: UInt32] = [:]

    /// Maps parent entity index -> set of child entity indices.
    private var childrenMap: [UInt32: Set<UInt32>] = [:]

    /// Set the parent of a child entity. If the child already had a parent, it is
    /// detached from the old parent first.
    mutating func setParent(_ parent: UInt32, for child: UInt32) {
        // Detach from old parent if any
        if let oldParent = parents[child] {
            childrenMap[oldParent]?.remove(child)
            if childrenMap[oldParent]?.isEmpty == true {
                childrenMap.removeValue(forKey: oldParent)
            }
        }

        parents[child] = parent
        childrenMap[parent, default: []].insert(child)
    }

    /// Remove the parent link for a child (detach from parent).
    mutating func removeParent(for child: UInt32) {
        if let oldParent = parents.removeValue(forKey: child) {
            childrenMap[oldParent]?.remove(child)
            if childrenMap[oldParent]?.isEmpty == true {
                childrenMap.removeValue(forKey: oldParent)
            }
        }
    }

    /// Get the parent index of an entity, or `nil` if it has no parent.
    func parent(of entity: UInt32) -> UInt32? {
        parents[entity]
    }

    /// Get the child indices of an entity.
    func children(of entity: UInt32) -> [UInt32] {
        Array(childrenMap[entity] ?? [])
    }

    /// Clean up all hierarchy data for a destroyed entity.
    /// Removes it as a child from its parent, and removes its children set.
    /// (The World handles recursive child destruction before calling this.)
    mutating func removeEntity(_ entity: UInt32) {
        // Detach from parent
        if let oldParent = parents.removeValue(forKey: entity) {
            childrenMap[oldParent]?.remove(entity)
            if childrenMap[oldParent]?.isEmpty == true {
                childrenMap.removeValue(forKey: oldParent)
            }
        }

        // Remove children set (children themselves are destroyed by World)
        childrenMap.removeValue(forKey: entity)
    }
}
