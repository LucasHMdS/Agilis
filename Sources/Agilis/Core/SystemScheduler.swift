/// Schedules systems for execution, grouping compatible systems into parallel stages.
///
/// Two systems can run in parallel if:
/// 1. Neither declares `mutatesEntities: true`
/// 2. Neither declares `emitsEvents: true`
/// 3. System A's writes don't overlap System B's reads or writes
/// 4. System A's reads don't overlap System B's writes
///
/// Systems with the default (conservative) `componentAccess` are always placed
/// in their own sequential stage.
internal final class SystemScheduler: @unchecked Sendable {

    deinit {}

    /// Build an execution plan from a priority-sorted system list.
    ///
    /// Returns an array of stages. Each stage contains systems that can run
    /// in parallel. Stages themselves execute sequentially.
    func buildExecutionPlan(systems: [SystemEntry]) -> [[SystemEntry]] {
        guard !systems.isEmpty else { return [] }

        var stages: [[SystemEntry]] = []
        var currentStage: [SystemEntry] = []
        var currentAccessSets: [(reads: ComponentBitset, writes: ComponentBitset, serial: Bool)] = []

        for entry in systems {
            let access = entry.system.componentAccess
            let isSerial = access.mutatesEntities || access.emitsEvents

            let registry = ComponentRegistry.shared
            let reads = registry.bitset(for: access.reads)
            let writes = registry.bitset(for: access.writes)

            if isSerial {
                // This system must run alone — flush current stage first
                if !currentStage.isEmpty {
                    stages.append(currentStage)
                    currentStage = []
                    currentAccessSets = []
                }
                stages.append([entry])
                continue
            }

            // Check if this system conflicts with any system in the current stage
            var conflicts = false
            for existing in currentAccessSets {
                if existing.serial {
                    conflicts = true
                    break
                }
                // Write-write conflict
                if writes.intersects(existing.writes) {
                    conflicts = true
                    break
                }
                // New system's writes vs existing reads
                if writes.intersects(existing.reads) {
                    conflicts = true
                    break
                }
                // New system's reads vs existing writes
                if reads.intersects(existing.writes) {
                    conflicts = true
                    break
                }
            }

            if conflicts {
                // Start a new stage
                if !currentStage.isEmpty {
                    stages.append(currentStage)
                }
                currentStage = [entry]
                currentAccessSets = [(reads: reads, writes: writes, serial: false)]
            } else {
                // Add to current stage
                currentStage.append(entry)
                currentAccessSets.append((reads: reads, writes: writes, serial: false))
            }
        }

        // Don't forget the last stage
        if !currentStage.isEmpty {
            stages.append(currentStage)
        }

        return stages
    }
}
