/// Type-safe query extensions on `World`.
///
/// These `forEach` overloads iterate over all entities that have the required
/// component types, providing direct `inout` access to each component.
/// The overloads cover 1–8 component types, which is sufficient for the vast
/// majority of system queries in a 2D game framework.
///
/// Usage:
/// ```swift
/// world.forEach { (entity: Entity, pos: inout Position, vel: Velocity) in
///     pos.x += vel.dx * Float(deltaTime)
/// }
/// ```
///
/// The 3–8 component overloads share a common iteration helper
/// (`iterateSmallest`) to eliminate repeated smallest-store selection and
/// entity validation boilerplate. The 1- and 2-component overloads use
/// direct dense-array iteration for maximum cache efficiency.
///
/// Swift parameter packs cannot fully replace these overloads due to `inout`
/// limitations. If a future Swift version lifts that restriction, these
/// overloads can collapse into a single generic implementation.
extension World {

    // MARK: - Shared Iteration Helper

    /// Iterate alive entities present in all given stores, using the smallest
    /// store as the iteration driver for efficiency.
    ///
    /// The body receives the validated `Entity` and its `entityIndex` (for
    /// dense-index lookup in individual stores). Used by 3–8 component
    /// `forEach` / `forEachReadOnly` overloads.
    private func iterateSmallest(
        _ stores: [AnyComponentStorage],
        body: (Entity, UInt32) -> Void
    ) {
        guard let lead = stores.min(by: { $0.count < $1.count }) else { return }
        for entityIndex in lead.entityIndices {
            let slot = Int(entityIndex)
            guard slot < allEntitySlotCount, isSlotAlive(slot) else { continue }
            body(entityFromSlot(slot), entityIndex)
        }
    }

    // MARK: - 1 Component

    /// Iterate all entities with component `A`.
    public func forEach<A: Component>(
        _ body: (Entity, inout A) -> Void
    ) {
        let storeA = getStore(for: A.self)
        for i in 0..<storeA.sparseSet.dense.count {
            let entityIndex = storeA.sparseSet.dense[i]
            let slot = Int(entityIndex)
            guard slot < allEntitySlotCount, isSlotAlive(slot) else { continue }
            let entity = entityFromSlot(slot)
            body(entity, &storeA.sparseSet.values[i])
        }
    }

    // MARK: - 2 Components

    /// Iterate all entities with components `A` and `B`.
    public func forEach<A: Component, B: Component>(
        _ body: (Entity, inout A, inout B) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)

        if storeA.count <= storeB.count {
            for i in 0..<storeA.sparseSet.dense.count {
                let entityIndex = storeA.sparseSet.dense[i]
                guard let bi = storeB.denseIndex(for: entityIndex) else { continue }
                let slot = Int(entityIndex)
                guard slot < allEntitySlotCount, isSlotAlive(slot) else { continue }
                let entity = entityFromSlot(slot)
                body(entity, &storeA.sparseSet.values[i], &storeB.sparseSet.values[bi])
            }
        } else {
            for i in 0..<storeB.sparseSet.dense.count {
                let entityIndex = storeB.sparseSet.dense[i]
                guard let ai = storeA.denseIndex(for: entityIndex) else { continue }
                let slot = Int(entityIndex)
                guard slot < allEntitySlotCount, isSlotAlive(slot) else { continue }
                let entity = entityFromSlot(slot)
                body(entity, &storeA.sparseSet.values[ai], &storeB.sparseSet.values[i])
            }
        }
    }

    // MARK: - 3 Components

    /// Iterate all entities with components `A`, `B`, and `C`.
    public func forEach<A: Component, B: Component, C: Component>(
        _ body: (Entity, inout A, inout B, inout C) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        iterateSmallest([storeA, storeB, storeC]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex) else { return }
            body(entity,
                 &storeA.sparseSet.values[ai],
                 &storeB.sparseSet.values[bi],
                 &storeC.sparseSet.values[ci])
        }
    }

    // MARK: - 4 Components

    /// Iterate all entities with components `A`, `B`, `C`, and `D`.
    public func forEach<A: Component, B: Component, C: Component, D: Component>(
        _ body: (Entity, inout A, inout B, inout C, inout D) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        iterateSmallest([storeA, storeB, storeC, storeD]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex) else { return }
            body(entity,
                 &storeA.sparseSet.values[ai],
                 &storeB.sparseSet.values[bi],
                 &storeC.sparseSet.values[ci],
                 &storeD.sparseSet.values[di])
        }
    }

    // MARK: - 5 Components

    /// Iterate all entities with components `A`, `B`, `C`, `D`, and `E`.
    public func forEach<A: Component, B: Component, C: Component, D: Component, E: Component>(
        _ body: (Entity, inout A, inout B, inout C, inout D, inout E) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex) else { return }
            body(entity,
                 &storeA.sparseSet.values[ai],
                 &storeB.sparseSet.values[bi],
                 &storeC.sparseSet.values[ci],
                 &storeD.sparseSet.values[di],
                 &storeE.sparseSet.values[ei])
        }
    }

    // MARK: - 6 Components

    /// Iterate all entities with components `A` through `F`.
    public func forEach<A: Component, B: Component, C: Component, D: Component, E: Component, F: Component>(
        _ body: (Entity, inout A, inout B, inout C, inout D, inout E, inout F) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        let storeF = getStore(for: F.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE, storeF]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex),
                  let fi = storeF.denseIndex(for: entityIndex) else { return }
            body(entity,
                 &storeA.sparseSet.values[ai],
                 &storeB.sparseSet.values[bi],
                 &storeC.sparseSet.values[ci],
                 &storeD.sparseSet.values[di],
                 &storeE.sparseSet.values[ei],
                 &storeF.sparseSet.values[fi])
        }
    }

    // MARK: - 7 Components

    /// Iterate all entities with components `A` through `G`.
    public func forEach<A: Component, B: Component, C: Component, D: Component, E: Component, F: Component, G: Component>(
        _ body: (Entity, inout A, inout B, inout C, inout D, inout E, inout F, inout G) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        let storeF = getStore(for: F.self)
        let storeG = getStore(for: G.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE, storeF, storeG]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex),
                  let fi = storeF.denseIndex(for: entityIndex),
                  let gi = storeG.denseIndex(for: entityIndex) else { return }
            body(entity,
                 &storeA.sparseSet.values[ai],
                 &storeB.sparseSet.values[bi],
                 &storeC.sparseSet.values[ci],
                 &storeD.sparseSet.values[di],
                 &storeE.sparseSet.values[ei],
                 &storeF.sparseSet.values[fi],
                 &storeG.sparseSet.values[gi])
        }
    }

    // MARK: - 8 Components

    /// Iterate all entities with components `A` through `H`.
    public func forEach<A: Component, B: Component, C: Component, D: Component, E: Component, F: Component, G: Component, H: Component>(
        _ body: (Entity, inout A, inout B, inout C, inout D, inout E, inout F, inout G, inout H) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        let storeF = getStore(for: F.self)
        let storeG = getStore(for: G.self)
        let storeH = getStore(for: H.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE, storeF, storeG, storeH]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex),
                  let fi = storeF.denseIndex(for: entityIndex),
                  let gi = storeG.denseIndex(for: entityIndex),
                  let hi = storeH.denseIndex(for: entityIndex) else { return }
            body(entity,
                 &storeA.sparseSet.values[ai],
                 &storeB.sparseSet.values[bi],
                 &storeC.sparseSet.values[ci],
                 &storeD.sparseSet.values[di],
                 &storeE.sparseSet.values[ei],
                 &storeF.sparseSet.values[fi],
                 &storeG.sparseSet.values[gi],
                 &storeH.sparseSet.values[hi])
        }
    }

    // MARK: - Read-Only Queries

    /// Iterate all entities with component `A` (read-only access).
    public func forEachReadOnly<A: Component>(
        _ body: (Entity, A) -> Void
    ) {
        let storeA = getStore(for: A.self)
        for i in 0..<storeA.sparseSet.dense.count {
            let entityIndex = storeA.sparseSet.dense[i]
            let slot = Int(entityIndex)
            guard slot < allEntitySlotCount, isSlotAlive(slot) else { continue }
            let entity = entityFromSlot(slot)
            body(entity, storeA.sparseSet.values[i])
        }
    }

    /// Iterate all entities with components `A` and `B` (read-only access).
    public func forEachReadOnly<A: Component, B: Component>(
        _ body: (Entity, A, B) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)

        if storeA.count <= storeB.count {
            for i in 0..<storeA.sparseSet.dense.count {
                let entityIndex = storeA.sparseSet.dense[i]
                guard let bi = storeB.denseIndex(for: entityIndex) else { continue }
                let slot = Int(entityIndex)
                guard slot < allEntitySlotCount, isSlotAlive(slot) else { continue }
                let entity = entityFromSlot(slot)
                body(entity, storeA.sparseSet.values[i], storeB.sparseSet.values[bi])
            }
        } else {
            for i in 0..<storeB.sparseSet.dense.count {
                let entityIndex = storeB.sparseSet.dense[i]
                guard let ai = storeA.denseIndex(for: entityIndex) else { continue }
                let slot = Int(entityIndex)
                guard slot < allEntitySlotCount, isSlotAlive(slot) else { continue }
                let entity = entityFromSlot(slot)
                body(entity, storeA.sparseSet.values[ai], storeB.sparseSet.values[i])
            }
        }
    }

    /// Iterate all entities with components `A`, `B`, and `C` (read-only access).
    public func forEachReadOnly<A: Component, B: Component, C: Component>(
        _ body: (Entity, A, B, C) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        iterateSmallest([storeA, storeB, storeC]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex) else { return }
            body(entity,
                 storeA.sparseSet.values[ai],
                 storeB.sparseSet.values[bi],
                 storeC.sparseSet.values[ci])
        }
    }

    /// Iterate all entities with components `A`, `B`, `C`, and `D` (read-only access).
    public func forEachReadOnly<A: Component, B: Component, C: Component, D: Component>(
        _ body: (Entity, A, B, C, D) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        iterateSmallest([storeA, storeB, storeC, storeD]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex) else { return }
            body(entity,
                 storeA.sparseSet.values[ai],
                 storeB.sparseSet.values[bi],
                 storeC.sparseSet.values[ci],
                 storeD.sparseSet.values[di])
        }
    }

    /// Iterate all entities with components `A` through `E` (read-only access).
    public func forEachReadOnly<A: Component, B: Component, C: Component, D: Component, E: Component>(
        _ body: (Entity, A, B, C, D, E) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex) else { return }
            body(entity,
                 storeA.sparseSet.values[ai],
                 storeB.sparseSet.values[bi],
                 storeC.sparseSet.values[ci],
                 storeD.sparseSet.values[di],
                 storeE.sparseSet.values[ei])
        }
    }

    /// Iterate all entities with components `A` through `F` (read-only access).
    public func forEachReadOnly<A: Component, B: Component, C: Component, D: Component, E: Component, F: Component>(
        _ body: (Entity, A, B, C, D, E, F) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        let storeF = getStore(for: F.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE, storeF]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex),
                  let fi = storeF.denseIndex(for: entityIndex) else { return }
            body(entity,
                 storeA.sparseSet.values[ai],
                 storeB.sparseSet.values[bi],
                 storeC.sparseSet.values[ci],
                 storeD.sparseSet.values[di],
                 storeE.sparseSet.values[ei],
                 storeF.sparseSet.values[fi])
        }
    }

    /// Iterate all entities with components `A` through `G` (read-only access).
    public func forEachReadOnly<A: Component, B: Component, C: Component, D: Component, E: Component, F: Component, G: Component>(
        _ body: (Entity, A, B, C, D, E, F, G) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        let storeF = getStore(for: F.self)
        let storeG = getStore(for: G.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE, storeF, storeG]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex),
                  let fi = storeF.denseIndex(for: entityIndex),
                  let gi = storeG.denseIndex(for: entityIndex) else { return }
            body(entity,
                 storeA.sparseSet.values[ai],
                 storeB.sparseSet.values[bi],
                 storeC.sparseSet.values[ci],
                 storeD.sparseSet.values[di],
                 storeE.sparseSet.values[ei],
                 storeF.sparseSet.values[fi],
                 storeG.sparseSet.values[gi])
        }
    }

    /// Iterate all entities with components `A` through `H` (read-only access).
    public func forEachReadOnly<A: Component, B: Component, C: Component, D: Component, E: Component, F: Component, G: Component, H: Component>(
        _ body: (Entity, A, B, C, D, E, F, G, H) -> Void
    ) {
        let storeA = getStore(for: A.self)
        let storeB = getStore(for: B.self)
        let storeC = getStore(for: C.self)
        let storeD = getStore(for: D.self)
        let storeE = getStore(for: E.self)
        let storeF = getStore(for: F.self)
        let storeG = getStore(for: G.self)
        let storeH = getStore(for: H.self)
        iterateSmallest([storeA, storeB, storeC, storeD, storeE, storeF, storeG, storeH]) { entity, entityIndex in
            guard let ai = storeA.denseIndex(for: entityIndex),
                  let bi = storeB.denseIndex(for: entityIndex),
                  let ci = storeC.denseIndex(for: entityIndex),
                  let di = storeD.denseIndex(for: entityIndex),
                  let ei = storeE.denseIndex(for: entityIndex),
                  let fi = storeF.denseIndex(for: entityIndex),
                  let gi = storeG.denseIndex(for: entityIndex),
                  let hi = storeH.denseIndex(for: entityIndex) else { return }
            body(entity,
                 storeA.sparseSet.values[ai],
                 storeB.sparseSet.values[bi],
                 storeC.sparseSet.values[ci],
                 storeD.sparseSet.values[di],
                 storeE.sparseSet.values[ei],
                 storeF.sparseSet.values[fi],
                 storeG.sparseSet.values[gi],
                 storeH.sparseSet.values[hi])
        }
    }
}
