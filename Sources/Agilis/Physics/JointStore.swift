#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Manages the lifecycle and storage of physics joints.
///
/// Handles creation, destruction, and entity-to-joint lookups.
/// Used internally by `PhysicsWorld2D`.
internal final class JointStore: @unchecked Sendable {

    deinit {}

    /// All active joints, keyed by handle ID.
    private var joints: [UInt32: Joint2D] = [:]

    /// Next handle ID to assign (0 is reserved for `.invalid`).
    private var nextId: UInt32 = 1

    /// Reverse map from entity index to the set of joint handle IDs it participates in.
    private var entityToJoints: [UInt32: Set<UInt32>] = [:]

    /// Sorted keys for deterministic iteration order.
    /// Sequential impulse is order-dependent; consistent ordering aids reproducibility.
    private var sortedKeys: [UInt32] = []

    // MARK: - Creation

    /// Create a joint and return its handle.
    ///
    /// Resolves local anchors from world-space anchors using current body transforms.
    /// Computes reference angles and rest lengths from initial body state.
    ///
    /// - Parameters:
    ///   - definition: The joint configuration.
    ///   - world: The ECS world containing the bodies.
    /// - Returns: A handle to the created joint, or `.invalid` if creation failed.
    func create(definition: JointDefinition, world: World) -> JointHandle {
        var id = nextId
        nextId &+= 1
        if nextId == 0 { nextId = 1 } // skip invalid sentinel

        // If ID collides with an active joint, scan forward for a free slot
        var attempts = 0
        while joints[id] != nil && attempts < 100 {
            id &+= 1
            if id == 0 { id = 1 }
            attempts += 1
        }
        guard joints[id] == nil else { return .invalid }

        let handle = JointHandle(id: id)

        let joint: Joint2D
        switch definition {
        case .revolute(let def):
            joint = createRevolute(handle: handle, def: def, world: world)

        case .distance(let def):
            joint = createDistance(handle: handle, def: def, world: world)

        case .weld(let def):
            joint = createWeld(handle: handle, def: def, world: world)

        case .prismatic(let def):
            joint = createPrismatic(handle: handle, def: def, world: world)

        case .rope(let def):
            joint = createRope(handle: handle, def: def, world: world)

        case .motor(let def):
            joint = createMotor(handle: handle, def: def, world: world)
        }

        joints[id] = joint
        let pos = sortedKeys.firstIndex(where: { $0 > id }) ?? sortedKeys.endIndex
        sortedKeys.insert(id, at: pos)

        // Register entity-to-joint mapping
        entityToJoints[joint.entityA.index, default: []].insert(id)
        entityToJoints[joint.entityB.index, default: []].insert(id)

        return handle
    }

    // MARK: - Destruction

    /// Destroy a joint by handle. No-op if the handle is invalid or already destroyed.
    func destroy(handle: JointHandle) {
        guard let joint = joints.removeValue(forKey: handle.id) else { return }
        if let idx = sortedKeys.firstIndex(of: handle.id) {
            sortedKeys.remove(at: idx)
        }
        entityToJoints[joint.entityA.index]?.remove(handle.id)
        entityToJoints[joint.entityB.index]?.remove(handle.id)
        // Clean up empty sets
        if entityToJoints[joint.entityA.index]?.isEmpty == true {
            entityToJoints.removeValue(forKey: joint.entityA.index)
        }
        if entityToJoints[joint.entityB.index]?.isEmpty == true {
            entityToJoints.removeValue(forKey: joint.entityB.index)
        }
    }

    /// Remove all joints involving a specific entity.
    ///
    /// Returns the removed joints for event generation.
    func removeJoints(for entityIndex: UInt32) -> [Joint2D] {
        guard let jointIds = entityToJoints.removeValue(forKey: entityIndex) else {
            return []
        }
        var removed: [Joint2D] = []
        for id in jointIds {
            if let joint = joints.removeValue(forKey: id) {
                removed.append(joint)
                if let idx = sortedKeys.firstIndex(of: id) {
                    sortedKeys.remove(at: idx)
                }
                // Also remove from the other entity's mapping
                let otherIndex = joint.entityA.index == entityIndex
                    ? joint.entityB.index : joint.entityA.index
                entityToJoints[otherIndex]?.remove(id)
                if entityToJoints[otherIndex]?.isEmpty == true {
                    entityToJoints.removeValue(forKey: otherIndex)
                }
            }
        }
        return removed
    }

    // MARK: - Access

    /// Get a joint by handle for read access.
    func joint(for handle: JointHandle) -> Joint2D? {
        joints[handle.id]
    }

    /// Total number of active joints.
    var count: Int { joints.count }

    /// Iterate all joints mutably in deterministic order.
    func forEachJoint(_ body: (inout Joint2D) -> Void) {
        for key in sortedKeys {
            if var joint = joints[key] {
                body(&joint)
                joints[key] = joint
            }
        }
    }

    /// Remove joints marked for destruction and return events for them.
    func flushDestroyedJoints() -> [JointEvent] {
        var events: [JointEvent] = []
        var toRemove: [UInt32] = []

        for key in sortedKeys {
            if let joint = joints[key], joint.isMarkedForDestruction {
                events.append(JointEvent(
                    handle: joint.handle,
                    entityA: joint.entityA,
                    entityB: joint.entityB,
                    type: .broken
                ))
                toRemove.append(key)
            }
        }

        for id in toRemove {
            destroy(handle: JointHandle(id: id))
        }

        return events
    }

    /// Clear all joints.
    func clear() {
        joints.removeAll()
        sortedKeys.removeAll()
        entityToJoints.removeAll()
    }

    // MARK: - Debug

    /// Get debug info for all active joints.
    func debugInfo(world: World) -> [JointDebugInfo] {
        var result: [JointDebugInfo] = []
        for key in sortedKeys {
            guard let joint = joints[key] else { continue }
            let tA = world.getComponent(Transform2D.self, from: joint.entityA)
            let tB = world.getComponent(Transform2D.self, from: joint.entityB)

            let worldAnchorA = computeWorldAnchor(
                localAnchor: joint.localAnchorA,
                position: tA?.position ?? .zero,
                rotation: tA?.rotation ?? 0
            )
            let worldAnchorB = computeWorldAnchor(
                localAnchor: joint.localAnchorB,
                position: tB?.position ?? .zero,
                rotation: tB?.rotation ?? 0
            )

            let jointType: String
            var worldAxis: Vector2?
            switch joint.definition {
            case .revolute: jointType = "revolute"
            case .distance: jointType = "distance"
            case .weld: jointType = "weld"

            case .prismatic:
                jointType = "prismatic"
                let rotA = tA?.rotation ?? 0
                worldAxis = rotateVector(joint.localAxisA, angle: rotA)

            case .rope: jointType = "rope"
            case .motor: jointType = "motor"
            }

            result.append(JointDebugInfo(
                entityA: joint.entityA,
                entityB: joint.entityB,
                worldAnchorA: worldAnchorA,
                worldAnchorB: worldAnchorB,
                jointType: jointType,
                axis: worldAxis
            ))
        }
        return result
    }

    // MARK: - Private Helpers

    private func createRevolute(handle: JointHandle, def: RevoluteJointDef, world: World) -> Joint2D {
        let tA = world.getComponent(Transform2D.self, from: def.entityA)
        let tB = world.getComponent(Transform2D.self, from: def.entityB)
        let posA = tA?.position ?? .zero
        let posB = tB?.position ?? .zero
        let rotA = tA?.rotation ?? 0
        let rotB = tB?.rotation ?? 0

        let localA = def.localAnchorA ?? worldToLocal(worldPoint: def.anchor, bodyPos: posA, bodyRot: rotA)
        let localB = def.localAnchorB ?? worldToLocal(worldPoint: def.anchor, bodyPos: posB, bodyRot: rotB)

        var joint = Joint2D(
            handle: handle,
            definition: .revolute(def),
            entityA: def.entityA,
            entityB: def.entityB,
            localAnchorA: localA,
            localAnchorB: localB
        )
        joint.referenceAngle = rotB - rotA
        return joint
    }

    private func createDistance(handle: JointHandle, def: DistanceJointDef, world: World) -> Joint2D {
        let tA = world.getComponent(Transform2D.self, from: def.entityA)
        let tB = world.getComponent(Transform2D.self, from: def.entityB)
        let posA = tA?.position ?? .zero
        let posB = tB?.position ?? .zero
        let rotA = tA?.rotation ?? 0
        let rotB = tB?.rotation ?? 0

        let localA = def.localAnchorA ?? worldToLocal(worldPoint: def.anchorA, bodyPos: posA, bodyRot: rotA)
        let localB = def.localAnchorB ?? worldToLocal(worldPoint: def.anchorB, bodyPos: posB, bodyRot: rotB)

        var joint = Joint2D(
            handle: handle,
            definition: .distance(def),
            entityA: def.entityA,
            entityB: def.entityB,
            localAnchorA: localA,
            localAnchorB: localB
        )

        // Compute rest length if not specified
        if def.length <= 0 {
            let worldA = computeWorldAnchor(localAnchor: localA, position: posA, rotation: rotA)
            let worldB = computeWorldAnchor(localAnchor: localB, position: posB, rotation: rotB)
            let diff = worldB - worldA
            let len = sqrtf(diff.x * diff.x + diff.y * diff.y)
            // Store length in the accumulated scalar as a workaround — the solver reads it from definition
            // Actually, we need to modify the definition. Let's store the computed length.
            // Since definitions are value types, we create a modified one.
            var modDef = def
            modDef.length = max(len, 0.005) // minimum length to avoid singularity
            joint = Joint2D(
                handle: handle,
                definition: .distance(modDef),
                entityA: def.entityA,
                entityB: def.entityB,
                localAnchorA: localA,
                localAnchorB: localB
            )
        }

        return joint
    }

    private func createWeld(handle: JointHandle, def: WeldJointDef, world: World) -> Joint2D {
        let tA = world.getComponent(Transform2D.self, from: def.entityA)
        let tB = world.getComponent(Transform2D.self, from: def.entityB)
        let posA = tA?.position ?? .zero
        let posB = tB?.position ?? .zero
        let rotA = tA?.rotation ?? 0
        let rotB = tB?.rotation ?? 0

        let localA = def.localAnchorA ?? worldToLocal(worldPoint: def.anchor, bodyPos: posA, bodyRot: rotA)
        let localB = def.localAnchorB ?? worldToLocal(worldPoint: def.anchor, bodyPos: posB, bodyRot: rotB)

        var joint = Joint2D(
            handle: handle,
            definition: .weld(def),
            entityA: def.entityA,
            entityB: def.entityB,
            localAnchorA: localA,
            localAnchorB: localB
        )
        joint.referenceAngle = def.referenceAngle ?? (rotB - rotA)
        return joint
    }

    private func createPrismatic(handle: JointHandle, def: PrismaticJointDef, world: World) -> Joint2D {
        let tA = world.getComponent(Transform2D.self, from: def.entityA)
        let tB = world.getComponent(Transform2D.self, from: def.entityB)
        let posA = tA?.position ?? .zero
        let posB = tB?.position ?? .zero
        let rotA = tA?.rotation ?? 0
        let rotB = tB?.rotation ?? 0

        let localA = def.localAnchorA ?? worldToLocal(worldPoint: def.anchor, bodyPos: posA, bodyRot: rotA)
        let localB = def.localAnchorB ?? worldToLocal(worldPoint: def.anchor, bodyPos: posB, bodyRot: rotB)

        // Normalize the world-space axis, then inverse-rotate into body A's local frame
        let axisLen = sqrtf(def.axis.x * def.axis.x + def.axis.y * def.axis.y)
        let normAxis: Vector2
        if axisLen > PhysicsConstants.Tolerance.vectorLength {
            normAxis = Vector2(x: def.axis.x / axisLen, y: def.axis.y / axisLen)
        } else {
            normAxis = Vector2(x: 1, y: 0) // default to horizontal
        }
        let computedLocalAxisA = def.localAxisA ?? worldToLocal(
            worldPoint: normAxis + posA, bodyPos: posA, bodyRot: rotA
        )
        // Normalize the local axis
        let localAxisLen = sqrtf(computedLocalAxisA.x * computedLocalAxisA.x + computedLocalAxisA.y * computedLocalAxisA.y)
        let finalLocalAxis: Vector2
        if localAxisLen > PhysicsConstants.Tolerance.vectorLength {
            finalLocalAxis = Vector2(x: computedLocalAxisA.x / localAxisLen, y: computedLocalAxisA.y / localAxisLen)
        } else {
            finalLocalAxis = Vector2(x: 1, y: 0)
        }

        var joint = Joint2D(
            handle: handle,
            definition: .prismatic(def),
            entityA: def.entityA,
            entityB: def.entityB,
            localAnchorA: localA,
            localAnchorB: localB
        )
        joint.localAxisA = finalLocalAxis
        joint.referenceAngle = def.referenceAngle ?? (rotB - rotA)
        return joint
    }

    private func createRope(handle: JointHandle, def: RopeJointDef, world: World) -> Joint2D {
        let tA = world.getComponent(Transform2D.self, from: def.entityA)
        let tB = world.getComponent(Transform2D.self, from: def.entityB)
        let posA = tA?.position ?? .zero
        let posB = tB?.position ?? .zero
        let rotA = tA?.rotation ?? 0
        let rotB = tB?.rotation ?? 0

        let localA = def.localAnchorA ?? worldToLocal(worldPoint: def.anchorA, bodyPos: posA, bodyRot: rotA)
        let localB = def.localAnchorB ?? worldToLocal(worldPoint: def.anchorB, bodyPos: posB, bodyRot: rotB)

        // Auto-compute maxLength if not specified
        var modDef = def
        if modDef.maxLength <= 0 {
            let worldA = computeWorldAnchor(localAnchor: localA, position: posA, rotation: rotA)
            let worldB = computeWorldAnchor(localAnchor: localB, position: posB, rotation: rotB)
            let diff = worldB - worldA
            let len = sqrtf(diff.x * diff.x + diff.y * diff.y)
            modDef.maxLength = max(len, 0.005)
        }

        return Joint2D(
            handle: handle,
            definition: .rope(modDef),
            entityA: def.entityA,
            entityB: def.entityB,
            localAnchorA: localA,
            localAnchorB: localB
        )
    }

    private func createMotor(handle: JointHandle, def: MotorJointDef, world _: World) -> Joint2D {
        // Motor joint acts at body centers — no anchors needed
        Joint2D(
            handle: handle,
            definition: .motor(def),
            entityA: def.entityA,
            entityB: def.entityB,
            localAnchorA: .zero,
            localAnchorB: .zero
        )
    }

    /// Transform a world-space point to a body's local space.
    private func worldToLocal(worldPoint: Vector2, bodyPos: Vector2, bodyRot: Float) -> Vector2 {
        let dx = worldPoint.x - bodyPos.x
        let dy = worldPoint.y - bodyPos.y
        let c = cosf(bodyRot)
        let s = sinf(bodyRot)
        // Inverse rotation: transpose of rotation matrix
        return Vector2(x: dx * c + dy * s, y: -dx * s + dy * c)
    }

    /// Transform a local-space anchor to world space.
    private func computeWorldAnchor(localAnchor: Vector2, position: Vector2, rotation: Float) -> Vector2 {
        let c = cosf(rotation)
        let s = sinf(rotation)
        return Vector2(
            x: localAnchor.x * c - localAnchor.y * s + position.x,
            y: localAnchor.x * s + localAnchor.y * c + position.y
        )
    }
}
