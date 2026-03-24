/// The ECS world: manages entities, components, systems, hierarchy, metadata, and lifecycle events.
///
/// Entities use generational indexing for safe handle reuse. Components are stored
/// in sparse sets for cache-friendly iteration. Systems run each fixed-timestep tick
/// with a command buffer for deferred mutations.
///
/// Internally delegates to `EntityAllocator`, `SystemManager`, and `EventBus` for
/// entity lifecycle, system orchestration, and event dispatch respectively.
public final class World: @unchecked Sendable {

    // MARK: - Internal Managers

    private let entities = EntityAllocator()
    private let systemManager = SystemManager()
    private let eventBus = EventBus()

    // MARK: - Component Storage

    /// Maps component type -> type-erased sparse-set storage.
    private var storage: [ObjectIdentifier: AnyComponentStorage] = [:]

    // MARK: - Entity Management

    internal var hierarchy = EntityHierarchy()
    internal var metadata = EntityMetadataStore()

    // MARK: - Component Lifecycle Events

    private var addHandlers: [ObjectIdentifier: [(Entity, World) -> Void]] = [:]
    private var removeHandlers: [ObjectIdentifier: [(Entity, World) -> Void]] = [:]

    // MARK: - Debug Stats

    /// Per-system timing info from the most recent `update()` call.
    public var systemTimings: [(name: String, priority: Int, duration: Double)] {
        systemManager.systemTimings
    }

    public init() {}

    // MARK: - Debug Properties

    /// Number of distinct component types that have been registered (have storage).
    public var componentStoreCount: Int { storage.count }

    /// Number of systems currently registered.
    public var systemCount: Int { systemManager.systems.count }

    // MARK: - Entities

    /// Create a new entity, reusing a recycled slot if available.
    @discardableResult
    public func createEntity() -> Entity {
        entities.createEntity()
    }

    /// Reserve an entity slot (for command buffer use). The slot is allocated but
    /// not yet marked alive — call `confirmEntity` to finalize.
    internal func reserveEntity() -> Entity {
        entities.reserveEntity()
    }

    /// Finalize a reserved entity, marking it alive.
    internal func confirmEntity(_ entity: Entity) {
        entities.confirmEntity(entity)
    }

    /// Destroy an entity and remove all its components, hierarchy links, and metadata.
    /// Also recursively destroys all children.
    public func destroyEntity(_ entity: Entity) {
        guard isAlive(entity) else { return }

        // Recursively destroy children first
        let children = hierarchy.children(of: entity.index)
        for childIndex in children {
            if let child = entities.entityFromSlotIfAlive(Int(childIndex)) {
                destroyEntity(child)
            }
        }

        // Fire remove handlers and remove components
        for (typeId, store) in storage where store.has(entity: entity.index) {
            if let handlers = removeHandlers[typeId] {
                for handler in handlers {
                    handler(entity, self)
                }
            }
            store.removeIfPresent(entity: entity.index)
        }

        // Clean up hierarchy and metadata
        hierarchy.removeEntity(entity.index)
        metadata.removeEntity(entity.index)

        // Mark slot as dead and recycle
        entities.markDead(entity)
    }

    /// Check if an entity handle is still valid (alive and generation matches).
    public func isAlive(_ entity: Entity) -> Bool {
        entities.isAlive(entity)
    }

    /// The number of living entities.
    public var entityCount: Int { entities.entityCount }

    /// All currently living entities.
    public var allEntities: [Entity] { entities.allEntities }

    // MARK: - Components

    /// Get or create the typed storage for a component type.
    internal func getStore<T: Component>(for _: T.Type) -> ComponentStore<T> {
        let key = ObjectIdentifier(T.self)
        if let existing = storage[key] as? ComponentStore<T> {
            return existing
        }
        let store = ComponentStore<T>()
        storage[key] = store
        return store
    }

    /// Add (or replace) a component on an entity.
    public func addComponent<T: Component>(_ component: T, to entity: Entity) {
        guard isAlive(entity) else { return }
        let store = getStore(for: T.self)
        store.set(entity: entity.index, value: component)

        // Fire add handlers
        let key = ObjectIdentifier(T.self)
        if let handlers = addHandlers[key] {
            for handler in handlers {
                handler(entity, self)
            }
        }
    }

    /// Get a component from an entity, or `nil` if not present or entity is dead.
    public func getComponent<T: Component>(_: T.Type, from entity: Entity) -> T? {
        guard isAlive(entity) else { return nil }
        let store = getStore(for: T.self)
        return store.get(entity: entity.index)
    }

    /// Mutate a component on an entity in-place. Returns `true` if the component existed.
    @discardableResult
    public func updateComponent<T: Component>(_: T.Type, on entity: Entity, _ body: (inout T) -> Void) -> Bool {
        guard isAlive(entity) else { return false }
        let store = getStore(for: T.self)
        return store.withValue(for: entity.index, body)
    }

    /// Remove a component from an entity.
    public func removeComponent<T: Component>(_: T.Type, from entity: Entity) {
        guard isAlive(entity) else { return }
        let key = ObjectIdentifier(T.self)
        if let store = storage[key] {
            if store.has(entity: entity.index) {
                if let handlers = removeHandlers[key] {
                    for handler in handlers {
                        handler(entity, self)
                    }
                }
                store.removeIfPresent(entity: entity.index)
            }
        }
    }

    /// Check if an entity has a specific component type.
    public func hasComponent<T: Component>(_: T.Type, on entity: Entity) -> Bool {
        guard isAlive(entity) else { return false }
        let key = ObjectIdentifier(T.self)
        guard let store = storage[key] else { return false }
        return store.has(entity: entity.index)
    }

    /// Remove a component by its type identifier (for command buffer use).
    internal func removeComponentByTypeId(_ typeId: ObjectIdentifier, from entity: Entity) {
        guard isAlive(entity) else { return }
        if let store = storage[typeId] {
            if store.has(entity: entity.index) {
                if let handlers = removeHandlers[typeId] {
                    for handler in handlers {
                        handler(entity, self)
                    }
                }
                store.removeIfPresent(entity: entity.index)
            }
        }
    }

    // MARK: - Queries (Legacy)

    /// Get all entities that have all of the specified component types.
    @available(*, deprecated, message: "Use forEach or query API instead")
    public func entitiesWith(_ types: [Component.Type]) -> [Entity] {
        let allAlive = allEntities
        return allAlive.filter { entity in
            types.allSatisfy { type in
                let key = ObjectIdentifier(type)
                guard let store = storage[key] else { return false }
                return store.has(entity: entity.index)
            }
        }
    }

    // MARK: - Systems

    /// Add a system to the world with an optional priority (lower runs first, default 0).
    /// Calls the system's `setup(world:)` immediately.
    public func addSystem(_ system: System, priority: Int? = nil) {
        systemManager.addSystem(system, priority: priority, world: self)
    }

    /// Remove a system from the world.
    public func removeSystem(_ system: System) {
        systemManager.removeSystem(system)
    }

    // MARK: - Parallel Scheduling

    /// Whether parallel system scheduling is enabled. When `true` and systems
    /// declare their `componentAccess`, compatible systems run concurrently
    /// in a `TaskGroup`. Default: `false`.
    public var parallelSchedulingEnabled: Bool {
        get { systemManager.parallelSchedulingEnabled }
        set { systemManager.parallelSchedulingEnabled = newValue }
    }

    /// Run all systems in priority order. Called by the game loop each fixed-timestep tick.
    public func update(deltaTime: Double) {
        systemManager.update(deltaTime: deltaTime, world: self)
    }

    /// Async variant that runs compatible systems in parallel using `TaskGroup`.
    internal func updateParallel(deltaTime: Double) async {
        await systemManager.updateParallel(deltaTime: deltaTime, world: self)
    }

    // MARK: - Hierarchy

    /// Set the parent of an entity. Pass `nil` to detach from any parent.
    public func setParent(_ parent: Entity?, for child: Entity) {
        guard isAlive(child) else { return }
        if let parent = parent {
            guard isAlive(parent) else { return }
            hierarchy.setParent(parent.index, for: child.index)
        } else {
            hierarchy.removeParent(for: child.index)
        }
    }

    /// Get the children of an entity.
    public func children(of entity: Entity) -> [Entity] {
        guard isAlive(entity) else { return [] }
        return hierarchy.children(of: entity.index).compactMap { childIndex in
            entities.entityFromSlotIfAlive(Int(childIndex))
        }
    }

    /// Get the parent of an entity, or `nil` if it has no parent.
    public func parent(of entity: Entity) -> Entity? {
        guard isAlive(entity) else { return nil }
        guard let parentIndex = hierarchy.parent(of: entity.index) else { return nil }
        return entities.entityFromSlotIfAlive(Int(parentIndex))
    }

    // MARK: - Metadata

    /// Assign a unique name to an entity. Only one entity can have a given name.
    public func setName(_ name: String, for entity: Entity) {
        guard isAlive(entity) else { return }
        metadata.setName(name, for: entity.index)
    }

    /// Look up an entity by name, or `nil` if not found.
    public func entity(named name: String) -> Entity? {
        guard let index = metadata.entity(named: name) else { return nil }
        return entities.entityFromSlotIfAlive(Int(index))
    }

    /// Add a tag to an entity.
    public func addTag(_ tag: String, to entity: Entity) {
        guard isAlive(entity) else { return }
        metadata.addTag(tag, to: entity.index)
    }

    /// Remove a tag from an entity.
    public func removeTag(_ tag: String, from entity: Entity) {
        guard isAlive(entity) else { return }
        metadata.removeTag(tag, from: entity.index)
    }

    /// Check if an entity has a specific tag.
    public func hasTag(_ tag: String, on entity: Entity) -> Bool {
        guard isAlive(entity) else { return false }
        return metadata.hasTag(tag, on: entity.index)
    }

    /// Get all entities with a given tag.
    public func entitiesWithTag(_ tag: String) -> [Entity] {
        metadata.entitiesWithTag(tag).compactMap { index in
            entities.entityFromSlotIfAlive(Int(index))
        }
    }

    /// Get all tags for an entity, or an empty set if untagged.
    public func tags(of entity: Entity) -> Set<String> {
        guard isAlive(entity) else { return [] }
        return metadata.tags(of: entity.index)
    }

    /// Get the name of an entity, or `nil` if unnamed.
    public func name(of entity: Entity) -> String? {
        guard isAlive(entity) else { return nil }
        return metadata.name(of: entity.index)
    }

    // MARK: - Component Lifecycle Events

    /// Register a handler called whenever a component of the given type is added to an entity.
    public func onComponentAdded<T: Component>(_: T.Type, handler: @escaping (Entity, World) -> Void) {
        let key = ObjectIdentifier(T.self)
        addHandlers[key, default: []].append(handler)
    }

    /// Register a handler called whenever a component of the given type is removed from an entity.
    public func onComponentRemoved<T: Component>(_: T.Type, handler: @escaping (Entity, World) -> Void) {
        let key = ObjectIdentifier(T.self)
        removeHandlers[key, default: []].append(handler)
    }

    // MARK: - Event Bus

    /// Subscribe to events of a given type. Returns an opaque subscription for removal.
    @discardableResult
    public func on<T: Event>(_ type: T.Type, handler: @escaping (T) -> Void) -> EventSubscription {
        eventBus.on(type, handler: handler)
    }

    /// Emit an event, calling all registered handlers for that event type synchronously.
    public func emit<T: Event>(_ event: T) {
        eventBus.emit(event)
    }

    /// Remove a single event handler by its subscription.
    public func removeSubscription(_ subscription: EventSubscription) {
        eventBus.removeSubscription(subscription)
    }

    /// Remove all handlers for a specific event type.
    public func removeHandlers<T: Event>(for type: T.Type) {
        eventBus.removeHandlers(for: type)
    }

    /// Remove all event handlers for all event types.
    public func removeAllEventHandlers() {
        eventBus.removeAll()
    }

    /// Compact event handler arrays to reclaim memory from removed subscriptions.
    ///
    /// Call during scene transitions or other natural breakpoints. Invalidates
    /// any outstanding `EventSubscription` tokens.
    public func compactEventHandlers() {
        eventBus.compact()
    }

    // MARK: - Internal Helpers (used by Query.swift)

    /// Total number of entity slots (including dead ones).
    internal var allEntitySlotCount: Int { entities.slotCount }

    /// Check if a slot index is alive (no generation check — internal use only).
    internal func isSlotAlive(_ slot: Int) -> Bool {
        entities.isSlotAlive(slot)
    }

    /// Reconstruct an `Entity` handle from a slot index.
    internal func entityFromSlot(_ slot: Int) -> Entity {
        entities.entityFromSlot(slot)
    }
}
