/// Describes how a system accesses components, enabling the parallel scheduler
/// to determine which systems can run concurrently.
///
/// Systems declare which component types they read and write. The scheduler uses
/// this information to group non-conflicting systems into parallel stages.
///
/// Two systems can run in parallel if:
/// - Neither mutates entities (creates/destroys)
/// - Neither emits events
/// - Their write sets don't overlap each other's read or write sets
///
/// The default `componentAccess` (on `System`) is maximally conservative:
/// it declares entity mutation and event emission, forcing sequential execution.
/// Only systems that explicitly declare their access benefit from parallelism.
public struct ComponentAccess: @unchecked Sendable {
    /// Component types this system reads but does not write.
    public let reads: [any Component.Type]

    /// Component types this system writes (also implicitly reads).
    public let writes: [any Component.Type]

    /// Whether this system creates or destroys entities via the command buffer.
    public let mutatesEntities: Bool

    /// Whether this system emits events on the World event bus.
    public let emitsEvents: Bool

    public init(
        reads: [any Component.Type] = [],
        writes: [any Component.Type] = [],
        mutatesEntities: Bool = false,
        emitsEvents: Bool = false
    ) {
        self.reads = reads
        self.writes = writes
        self.mutatesEntities = mutatesEntities
        self.emitsEvents = emitsEvents
    }
}
