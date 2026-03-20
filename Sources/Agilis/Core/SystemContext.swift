/// Context provided to systems during their update tick.
///
/// Gives systems read/write access to the world (for queries and direct component access)
/// and a command buffer for deferred mutations (entity creation/destruction, component
/// add/remove) that are applied after the system finishes.
public struct SystemContext {
    /// The ECS world.
    public let world: World

    /// The fixed-timestep delta time for this tick.
    public let deltaTime: Double

    /// A command buffer for deferred mutations. Commands are flushed automatically
    /// after the system's `update(context:)` returns.
    public let commands: CommandBuffer
}
