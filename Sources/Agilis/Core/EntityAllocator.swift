/// Manages entity slot allocation, recycling, and generational indexing.
///
/// Extracted from `World` to separate entity lifecycle management from
/// component storage and system orchestration. World delegates all slot
/// operations to this type.
internal final class EntityAllocator: @unchecked Sendable {

    /// Per-slot state for generational entity allocation.
    private struct EntitySlot {
        var generation: UInt32 = 0
        var alive: Bool = false
    }

    private var slots: [EntitySlot] = []
    private var freeList: [UInt32] = []
    private var livingCount: Int = 0

    // MARK: - Creation

    /// Create a new entity, reusing a recycled slot if available.
    func createEntity() -> Entity {
        if let recycled = freeList.popLast() {
            slots[Int(recycled)].generation &+= 1
            slots[Int(recycled)].alive = true
            livingCount += 1
            return Entity(index: recycled, generation: slots[Int(recycled)].generation)
        } else {
            let index = UInt32(slots.count)
            slots.append(EntitySlot(generation: 0, alive: true))
            livingCount += 1
            return Entity(index: index, generation: 0)
        }
    }

    /// Reserve an entity slot (for command buffer use). The slot is allocated but
    /// not yet marked alive — call `confirmEntity` to finalize.
    func reserveEntity() -> Entity {
        if let recycled = freeList.popLast() {
            slots[Int(recycled)].generation &+= 1
            return Entity(index: recycled, generation: slots[Int(recycled)].generation)
        } else {
            let index = UInt32(slots.count)
            slots.append(EntitySlot(generation: 0, alive: false))
            return Entity(index: index, generation: 0)
        }
    }

    /// Finalize a reserved entity, marking it alive.
    func confirmEntity(_ entity: Entity) {
        let i = Int(entity.index)
        guard i < slots.count, slots[i].generation == entity.generation else { return }
        if !slots[i].alive {
            slots[i].alive = true
            livingCount += 1
        }
    }

    // MARK: - Destruction

    /// Mark an entity's slot as dead and recycle it. Does not clean up components
    /// or hierarchy — the caller (World) handles that.
    func markDead(_ entity: Entity) {
        slots[Int(entity.index)].alive = false
        livingCount -= 1
        freeList.append(entity.index)
    }

    // MARK: - Queries

    /// Check if an entity handle is still valid (alive and generation matches).
    func isAlive(_ entity: Entity) -> Bool {
        let i = Int(entity.index)
        guard i < slots.count else { return false }
        return slots[i].alive && slots[i].generation == entity.generation
    }

    /// The number of living entities.
    var entityCount: Int { livingCount }

    /// All currently living entities.
    var allEntities: [Entity] {
        var result: [Entity] = []
        result.reserveCapacity(livingCount)
        for i in 0..<slots.count {
            if slots[i].alive {
                result.append(Entity(index: UInt32(i), generation: slots[i].generation))
            }
        }
        return result
    }

    /// Iterate all living entities without allocating an array.
    func forEachEntity(_ body: (Entity) -> Void) {
        for i in 0..<slots.count {
            if slots[i].alive {
                body(Entity(index: UInt32(i), generation: slots[i].generation))
            }
        }
    }

    // MARK: - Slot Access (used by Query.swift)

    /// Total number of entity slots (including dead ones).
    var slotCount: Int { slots.count }

    /// Check if a slot index is alive (no generation check — internal use only).
    func isSlotAlive(_ slot: Int) -> Bool {
        guard slot < slots.count else { return false }
        return slots[slot].alive
    }

    /// Reconstruct an `Entity` handle from a slot index.
    func entityFromSlot(_ slot: Int) -> Entity {
        Entity(index: UInt32(slot), generation: slots[slot].generation)
    }

    /// Check if a child slot is alive and return its Entity handle.
    func entityFromSlotIfAlive(_ slot: Int) -> Entity? {
        guard slot < slots.count, slots[slot].alive else { return nil }
        return Entity(index: UInt32(slot), generation: slots[slot].generation)
    }
}
