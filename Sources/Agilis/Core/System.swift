/// A system processes entities with specific components each tick.
///
/// Systems define game logic that operates on entities via the world's query API.
/// They receive a `SystemContext` containing the world, delta time, and a command
/// buffer for deferred mutations.
///
/// The `priority` property controls execution order: lower values run first.
/// Systems with the same priority run in the order they were added.
public protocol System: AnyObject {
    /// Execution priority. Lower values run first. Default: 0.
    var priority: Int { get }

    /// Declares which component types this system reads and writes.
    /// Used by the parallel scheduler to determine which systems can run concurrently.
    ///
    /// The default is maximally conservative (assumes entity mutation + event emission),
    /// which forces sequential execution. Override this to enable parallel scheduling.
    var componentAccess: ComponentAccess { get }

    /// Called once when the system is added to the world.
    func setup(world: World)

    /// Called every fixed-timestep update with a context providing world access
    /// and a command buffer for deferred mutations.
    func update(context: SystemContext)

    /// Legacy update method. Override `update(context:)` instead for new systems.
    func update(world: World, deltaTime: Double)
}

public extension System {
    var priority: Int { 0 }

    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [], writes: [], mutatesEntities: true, emitsEvents: true)
    }

    func setup(world: World) {}

    /// Default implementation bridges the new `update(context:)` to the legacy
    /// `update(world:deltaTime:)` signature for backward compatibility.
    func update(context: SystemContext) {
        update(world: context.world, deltaTime: context.deltaTime)
    }

    func update(world: World, deltaTime: Double) {}
}
