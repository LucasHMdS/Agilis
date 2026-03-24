/// A command buffer that queues deferred entity and component operations.
///
/// During system iteration, directly mutating the world (creating/destroying entities,
/// adding/removing components) can invalidate iteration state. The command buffer
/// collects these mutations and applies them in bulk after the system finishes.
///
/// Usage inside a system:
/// ```swift
/// func update(context: SystemContext) {
///     let bullet = context.commands.createEntity(in: context.world)
///     context.commands.addComponent(Position(x: 0, y: 0), to: bullet)
///     // Commands are flushed automatically after this system returns.
/// }
/// ```
public final class CommandBuffer: @unchecked Sendable {
    private enum Command {
        case createEntity(Entity)
        case destroyEntity(Entity)
        case addComponent(entity: Entity, apply: (World) -> Void)
        case removeComponent(entity: Entity, typeId: ObjectIdentifier)
    }

    private var commands: [Command] = []

    public init() {}

    /// Reserve an entity ID that will be finalized when the buffer is flushed.
    /// The entity can be used as a target for `addComponent` in the same buffer.
    @discardableResult
    public func createEntity(in world: World) -> Entity {
        let entity = world.reserveEntity()
        commands.append(.createEntity(entity))
        return entity
    }

    /// Queue an entity for destruction.
    public func destroyEntity(_ entity: Entity) {
        commands.append(.destroyEntity(entity))
    }

    /// Queue adding a component to an entity.
    public func addComponent<T: Component>(_ component: T, to entity: Entity) {
        commands.append(.addComponent(entity: entity, apply: { world in
            world.addComponent(component, to: entity)
        }))
    }

    /// Queue removing a component type from an entity.
    public func removeComponent<T: Component>(_: T.Type, from entity: Entity) {
        commands.append(.removeComponent(entity: entity, typeId: ObjectIdentifier(T.self)))
    }

    /// Apply all queued commands to the world, then clear the buffer.
    internal func flush(into world: World) {
        guard !commands.isEmpty else { return }

        for command in commands {
            switch command {
            case .createEntity(let entity):
                world.confirmEntity(entity)

            case .destroyEntity(let entity):
                world.destroyEntity(entity)

            case .addComponent(_, let apply):
                apply(world)

            case .removeComponent(let entity, let typeId):
                world.removeComponentByTypeId(typeId, from: entity)
            }
        }

        commands.removeAll(keepingCapacity: true)
    }
}
