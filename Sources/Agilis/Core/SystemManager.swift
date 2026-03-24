/// Manages system registration, priority ordering, and execution.
///
/// Extracted from `World` to separate system orchestration from entity and
/// component management. World delegates system operations to this type.
internal final class SystemManager: @unchecked Sendable {

    var systems: [SystemEntry] = []

    /// Per-system timing info from the most recent `update()` call.
    var systemTimings: [(name: String, priority: Int, duration: Double)] = []

    /// Whether parallel system scheduling is enabled.
    var parallelSchedulingEnabled: Bool = false

    let scheduler = SystemScheduler()

    // MARK: - Registration

    /// Add a system with an optional priority (lower runs first, default 0).
    func addSystem(_ system: System, priority: Int?, world: World) {
        let p = priority ?? system.priority
        let entry = SystemEntry(system: system, priority: p)

        // Insert in sorted order (stable: append at end of equal-priority group)
        if let insertIndex = systems.firstIndex(where: { $0.priority > p }) {
            systems.insert(entry, at: insertIndex)
        } else {
            systems.append(entry)
        }

        system.setup(world: world)
    }

    /// Remove a system from the world.
    func removeSystem(_ system: System) {
        systems.removeAll(where: { $0.system === system })
    }

    // MARK: - Sequential Execution

    /// Run all systems in priority order with timing instrumentation.
    func update(deltaTime: Double, world: World) {
        let buffer = CommandBuffer()
        let context = SystemContext(world: world, deltaTime: deltaTime, commands: buffer)

        var timings: [(name: String, priority: Int, duration: Double)] = []
        timings.reserveCapacity(systems.count)
        let timingClock = Clock()

        for entry in systems {
            _ = timingClock.elapsed()
            entry.system.update(context: context)
            let duration = timingClock.elapsed()
            buffer.flush(into: world)

            let name = entry.name
            timings.append((name: name, priority: entry.priority, duration: duration))
        }

        systemTimings = timings
    }

    // MARK: - Parallel Execution

    /// Async variant that runs compatible systems in parallel using `TaskGroup`.
    func updateParallel(deltaTime: Double, world: World) async {
        let plan = scheduler.buildExecutionPlan(systems: systems)

        var timings: [(name: String, priority: Int, duration: Double)] = []
        timings.reserveCapacity(systems.count)
        let timingClock = Clock()

        for stage in plan {
            if stage.count == 1 {
                let buffer = CommandBuffer()
                let context = SystemContext(world: world, deltaTime: deltaTime, commands: buffer)
                _ = timingClock.elapsed()
                stage[0].system.update(context: context)
                let duration = timingClock.elapsed()
                buffer.flush(into: world)

                let name = stage[0].name
                timings.append((name: name, priority: stage[0].priority, duration: duration))
            } else {
                let buffers = stage.map { _ in CommandBuffer() }

                _ = timingClock.elapsed()

                #if DEBUG
                for i in 0..<stage.count {
                    let aWrites = ComponentRegistry.shared.bitset(for: stage[i].system.componentAccess.writes)
                    for j in (i + 1)..<stage.count {
                        let bWrites = ComponentRegistry.shared.bitset(for: stage[j].system.componentAccess.writes)
                        let bReads = ComponentRegistry.shared.bitset(for: stage[j].system.componentAccess.reads)
                        assert(
                            !aWrites.intersects(bWrites),
                            "Parallel stage has write-write conflict between \(type(of: stage[i].system)) and \(type(of: stage[j].system))"
                        )
                        assert(
                            !aWrites.intersects(bReads),
                            "Parallel stage has write-read conflict between \(type(of: stage[i].system)) and \(type(of: stage[j].system))"
                        )
                    }
                }
                #endif
                await withTaskGroup(of: Void.self) { group in
                    for (i, entry) in stage.enumerated() {
                        let ref = UnsafeSystemRef(entry.system)
                        let buf = UnsafeBufferRef(buffers[i])
                        let w = world
                        let dt = deltaTime
                        group.addTask {
                            let context = SystemContext(
                                world: w,
                                deltaTime: dt,
                                commands: buf.value
                            )
                            ref.value.update(context: context)
                        }
                    }
                }

                let stageDuration = timingClock.elapsed()
                let perSystem = stageDuration / Double(stage.count)

                for (i, buffer) in buffers.enumerated() {
                    buffer.flush(into: world)
                    let name = stage[i].name
                    timings.append((name: name, priority: stage[i].priority, duration: perSystem))
                }
            }
        }

        systemTimings = timings
    }
}

// MARK: - System Entry

/// A system paired with its assigned execution priority.
/// Used by `SystemManager` and `SystemScheduler`.
internal struct SystemEntry {
    let system: System
    let priority: Int
    /// Cached system type name to avoid per-frame `String(describing:)` allocation.
    let name: String

    init(system: System, priority: Int) {
        self.system = system
        self.priority = priority
        self.name = String(describing: type(of: system))
    }
}

// MARK: - Sendable Wrappers for Parallel Scheduling

/// Wraps a non-Sendable `System` reference for use in TaskGroup.addTask.
/// Safety: the SystemScheduler guarantees that systems in the same parallel stage
/// access disjoint component stores, so no data races occur.
private struct UnsafeSystemRef: @unchecked Sendable {
    let value: System
    init(_ system: System) { self.value = system }
}

/// Wraps a `CommandBuffer` reference for use in TaskGroup.addTask.
/// Safety: each parallel system receives its own CommandBuffer instance.
private struct UnsafeBufferRef: @unchecked Sendable {
    let value: CommandBuffer
    init(_ buffer: CommandBuffer) { self.value = buffer }
}
