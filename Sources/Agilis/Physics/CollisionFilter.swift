/// Check whether two colliders should be tested for collision based on layer/mask bitmasks.
///
/// Two entities collide only if each entity's layer overlaps with the other's mask.
/// This allows one-way filtering (A sees B but B doesn't see A).
///
/// - Parameters:
///   - layerA: The layer bitmask of entity A.
///   - maskA: The collision mask of entity A (which layers A can collide with).
///   - layerB: The layer bitmask of entity B.
///   - maskB: The collision mask of entity B (which layers B can collide with).
/// - Returns: `true` if the two entities should be tested for collision.
public func shouldCollide(
    layerA: UInt32, maskA: UInt32,
    layerB: UInt32, maskB: UInt32
) -> Bool {
    (layerA & maskB) != 0 && (layerB & maskA) != 0
}
