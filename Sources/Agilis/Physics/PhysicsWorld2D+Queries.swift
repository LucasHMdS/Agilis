import AgilisCore

// MARK: - Spatial Queries

extension PhysicsWorld2D {

    /// Cast a ray and return the closest hit, if any.
    ///
    /// Iterates all entities with `Transform2D` and `Collider2D` components,
    /// tests each against the ray, and returns the nearest intersection.
    ///
    /// ## Usage
    /// ```swift
    /// if let hit = physics.raycast(world: app.world,
    ///                              origin: gunTip,
    ///                              direction: Vector2(x: 1, y: 0)) {
    ///     print("Hit \(hit.entity) at \(hit.point), distance \(hit.distance)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - world: The ECS world to query.
    ///   - origin: Ray start point in world space.
    ///   - direction: Ray direction (will be normalized internally).
    ///   - maxDistance: Maximum ray length. Default: unlimited.
    ///   - layerMask: Only test entities whose `collider.layer & layerMask != 0`.
    ///     Default: all layers (0xFFFF_FFFF).
    /// - Returns: The closest `RaycastHit`, or `nil` if nothing was hit.
    public func raycast(
        world: World,
        origin: Vector2,
        direction: Vector2,
        maxDistance: Float = .greatestFiniteMagnitude,
        layerMask: UInt32 = 0xFFFF_FFFF
    ) -> RaycastHit? {
        let dir = direction.normalized
        guard dir.lengthSquared > PhysicsConstants.Tolerance.vectorLength else { return nil }

        var closestHit: RaycastHit? = nil
        var closestDist = maxDistance

        world.forEach { (entity: Entity, transform: inout Transform2D, collider: inout Collider2D) in
            guard collider.layer & layerMask != 0 else { return }

            let worldPos = transform.position + collider.offset

            guard let hit = SpatialQuery.raycast(
                origin: origin, direction: dir, tMax: closestDist,
                shape: collider.shape, shapePos: worldPos, shapeRot: transform.rotation
            ) else { return }

            if hit.distance < closestDist {
                closestDist = hit.distance
                closestHit = RaycastHit(
                    entity: entity, point: hit.point,
                    normal: hit.normal, distance: hit.distance
                )
            }
        }

        return closestHit
    }

    /// Cast a ray and return all hits, sorted by distance (closest first).
    ///
    /// Unlike `raycast()`, this does not stop at the first hit and returns
    /// every entity the ray intersects within `maxDistance`.
    ///
    /// - Parameters:
    ///   - world: The ECS world to query.
    ///   - origin: Ray start point in world space.
    ///   - direction: Ray direction (will be normalized internally).
    ///   - maxDistance: Maximum ray length. Default: unlimited.
    ///   - layerMask: Only test entities whose `collider.layer & layerMask != 0`.
    ///     Default: all layers (0xFFFF_FFFF).
    /// - Returns: All `RaycastHit` results, sorted by distance ascending.
    public func raycastAll(
        world: World,
        origin: Vector2,
        direction: Vector2,
        maxDistance: Float = .greatestFiniteMagnitude,
        layerMask: UInt32 = 0xFFFF_FFFF
    ) -> [RaycastHit] {
        let dir = direction.normalized
        guard dir.lengthSquared > PhysicsConstants.Tolerance.vectorLength else { return [] }

        var hits: [RaycastHit] = []

        world.forEach { (entity: Entity, transform: inout Transform2D, collider: inout Collider2D) in
            guard collider.layer & layerMask != 0 else { return }

            let worldPos = transform.position + collider.offset

            guard let hit = SpatialQuery.raycast(
                origin: origin, direction: dir, tMax: maxDistance,
                shape: collider.shape, shapePos: worldPos, shapeRot: transform.rotation
            ) else { return }

            hits.append(RaycastHit(
                entity: entity, point: hit.point,
                normal: hit.normal, distance: hit.distance
            ))
        }

        return hits.sorted { $0.distance < $1.distance }
    }

    /// Find all entities whose colliders contain a point.
    ///
    /// Useful for mouse picking, sensor checks, and overlap queries at a
    /// single position.
    ///
    /// ## Usage
    /// ```swift
    /// let results = physics.pointQuery(world: app.world,
    ///                                  point: mouseWorldPos)
    /// for result in results {
    ///     print("Mouse is over \(result.entity)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - world: The ECS world to query.
    ///   - point: The query point in world space.
    ///   - layerMask: Only test entities whose `collider.layer & layerMask != 0`.
    ///     Default: all layers (0xFFFF_FFFF).
    /// - Returns: All entities whose colliders contain the point.
    public func pointQuery(
        world: World,
        point: Vector2,
        layerMask: UInt32 = 0xFFFF_FFFF
    ) -> [PointQueryResult] {
        var results: [PointQueryResult] = []

        world.forEach { (entity: Entity, transform: inout Transform2D, collider: inout Collider2D) in
            guard collider.layer & layerMask != 0 else { return }

            let worldPos = transform.position + collider.offset

            if SpatialQuery.pointTest(
                point: point,
                shape: collider.shape, shapePos: worldPos, shapeRot: transform.rotation
            ) {
                results.append(PointQueryResult(entity: entity))
            }
        }

        return results
    }

    /// Find all entities whose colliders overlap a rectangle.
    ///
    /// Useful for explosion radius checks, spawn zone queries, and
    /// selecting entities within a screen region.
    ///
    /// ## Usage
    /// ```swift
    /// let explosionArea = Rect(x: 90, y: 90, width: 20, height: 20)
    /// let results = physics.areaQuery(world: app.world, rect: explosionArea)
    /// for result in results {
    ///     // Apply damage to result.entity
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - world: The ECS world to query.
    ///   - rect: The query rectangle in world space.
    ///   - layerMask: Only test entities whose `collider.layer & layerMask != 0`.
    ///     Default: all layers (0xFFFF_FFFF).
    /// - Returns: All entities whose colliders overlap the rectangle.
    public func areaQuery(
        world: World,
        rect: Rect,
        layerMask: UInt32 = 0xFFFF_FFFF
    ) -> [AreaQueryResult] {
        var results: [AreaQueryResult] = []

        world.forEach { (entity: Entity, transform: inout Transform2D, collider: inout Collider2D) in
            guard collider.layer & layerMask != 0 else { return }

            let worldPos = transform.position + collider.offset

            if SpatialQuery.areaTest(
                rect: rect,
                shape: collider.shape, shapePos: worldPos, shapeRot: transform.rotation
            ) {
                results.append(AreaQueryResult(entity: entity))
            }
        }

        return results
    }
}
