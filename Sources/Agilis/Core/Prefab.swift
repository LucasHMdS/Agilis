/// A reusable template for creating entities with predefined components, tags, and children.
///
/// Prefabs allow you to define an entity archetype once and instantiate it multiple times.
/// Each instantiation creates a fresh entity with copies of all defined components.
///
/// Usage:
/// ```swift
/// var enemyPrefab = Prefab()
/// enemyPrefab.add(Position(x: 0, y: 0))
/// enemyPrefab.add(Health(hp: 50))
/// enemyPrefab.withTag("enemy")
///
/// let enemy = enemyPrefab.instantiate(in: world)
/// ```
public struct Prefab {
    private var builders: [(Entity, World) -> Void] = []
    private var childPrefabs: [Prefab] = []
    private var entityName: String?
    private var entityTags: [String] = []

    public init() {}

    /// Add a component to the prefab template.
    /// When instantiated, the entity will receive a copy of this component.
    public mutating func add<T: Component>(_ component: T) {
        builders.append { entity, world in
            world.addComponent(component, to: entity)
        }
    }

    /// Set the name for entities created from this prefab.
    /// Since names are unique, instantiating multiple times will reassign the name.
    public mutating func withName(_ name: String) {
        entityName = name
    }

    /// Add a tag to entities created from this prefab.
    public mutating func withTag(_ tag: String) {
        entityTags.append(tag)
    }

    /// Add a child prefab. When this prefab is instantiated, the child prefab
    /// is also instantiated and parented to the main entity.
    public mutating func addChild(_ prefab: Prefab) {
        childPrefabs.append(prefab)
    }

    /// Instantiate this prefab in the given world.
    /// Creates a new entity with all defined components, tags, name, and children.
    @discardableResult
    public func instantiate(in world: World) -> Entity {
        let entity = world.createEntity()

        for builder in builders {
            builder(entity, world)
        }

        if let name = entityName {
            world.setName(name, for: entity)
        }

        for tag in entityTags {
            world.addTag(tag, to: entity)
        }

        for childPrefab in childPrefabs {
            let child = childPrefab.instantiate(in: world)
            world.setParent(entity, for: child)
        }

        return entity
    }
}
