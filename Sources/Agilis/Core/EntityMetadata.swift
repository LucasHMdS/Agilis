/// Stores optional metadata for entities: unique names, tags, and enabled state.
///
/// Names are unique — at most one entity can have a given name at a time.
/// Tags are many-to-many — an entity can have multiple tags, and multiple entities
/// can share the same tag. Both have reverse-indexed lookups for efficient querying.
internal struct EntityMetadataStore {
    /// Entity index -> name.
    private var names: [UInt32: String] = [:]

    /// Name -> entity index (reverse lookup).
    private var nameToEntity: [String: UInt32] = [:]

    /// Entity index -> set of tags.
    private var tags: [UInt32: Set<String>] = [:]

    /// Tag -> set of entity indices (reverse lookup).
    private var tagToEntities: [String: Set<UInt32>] = [:]

    // MARK: - Names

    /// Set a unique name for an entity. If another entity already has this name,
    /// the old entity loses the name.
    mutating func setName(_ name: String, for entity: UInt32) {
        // Remove old name from this entity
        if let oldName = names[entity] {
            nameToEntity.removeValue(forKey: oldName)
        }

        // If another entity has this name, remove it from that entity
        if let oldEntity = nameToEntity[name] {
            names.removeValue(forKey: oldEntity)
        }

        names[entity] = name
        nameToEntity[name] = entity
    }

    /// Look up an entity by name.
    func entity(named name: String) -> UInt32? {
        nameToEntity[name]
    }

    /// Get the name of an entity, or `nil` if unnamed.
    func name(of entity: UInt32) -> String? {
        names[entity]
    }

    // MARK: - Tags

    /// Add a tag to an entity.
    mutating func addTag(_ tag: String, to entity: UInt32) {
        tags[entity, default: []].insert(tag)
        tagToEntities[tag, default: []].insert(entity)
    }

    /// Remove a tag from an entity.
    mutating func removeTag(_ tag: String, from entity: UInt32) {
        tags[entity]?.remove(tag)
        if tags[entity]?.isEmpty == true {
            tags.removeValue(forKey: entity)
        }
        tagToEntities[tag]?.remove(entity)
        if tagToEntities[tag]?.isEmpty == true {
            tagToEntities.removeValue(forKey: tag)
        }
    }

    /// Get all tags for an entity, or an empty set if untagged.
    func tags(of entity: UInt32) -> Set<String> {
        tags[entity] ?? []
    }

    /// Check if an entity has a specific tag.
    func hasTag(_ tag: String, on entity: UInt32) -> Bool {
        tags[entity]?.contains(tag) ?? false
    }

    /// Get all entity indices with a given tag.
    func entitiesWithTag(_ tag: String) -> Set<UInt32> {
        tagToEntities[tag] ?? []
    }

    // MARK: - Cleanup

    /// Remove all metadata for a destroyed entity.
    mutating func removeEntity(_ entity: UInt32) {
        // Remove name
        if let name = names.removeValue(forKey: entity) {
            nameToEntity.removeValue(forKey: name)
        }

        // Remove tags
        if let entityTags = tags.removeValue(forKey: entity) {
            for tag in entityTags {
                tagToEntities[tag]?.remove(entity)
                if tagToEntities[tag]?.isEmpty == true {
                    tagToEntities.removeValue(forKey: tag)
                }
            }
        }
    }
}
