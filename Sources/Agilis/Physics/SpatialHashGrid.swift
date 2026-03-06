

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// A spatial hash grid for broad-phase collision detection.
///
/// Divides space into cells of uniform size. Entities are inserted by their
/// axis-aligned bounding rectangle, which may span multiple cells. After all
/// entities are inserted, `queryPairs()` returns all unique pairs of entities
/// that share at least one cell — these are candidates for narrow-phase testing.
///
/// The grid is rebuilt each physics step (cleared and re-populated).
public final class SpatialHashGrid: @unchecked Sendable {
    /// The size of each grid cell in world units.
    public let cellSize: Float

    /// Inverse cell size, precomputed for fast coordinate-to-cell conversion.
    private let inverseCellSize: Float

    /// Maps cell keys to the entities occupying that cell.
    private var cells: [CellKey: [Entity]] = [:]

    /// All entities currently in the grid (for pair generation).
    private var allEntities: [(entity: Entity, cellKeys: [CellKey])] = []

    /// Creates a spatial hash grid with the specified cell size.
    ///
    /// - Parameter cellSize: The size of each cell in world units. Larger cells
    ///   mean fewer cells but more potential pairs. A good default is slightly
    ///   larger than the largest expected entity. Default: 64.
    public init(cellSize: Float = 64) {
        precondition(cellSize > 0, "Cell size must be positive")
        self.cellSize = cellSize
        self.inverseCellSize = 1.0 / cellSize
    }

    /// Remove all entries. Called at the start of each physics step.
    public func clear() {
        cells.removeAll(keepingCapacity: true)
        allEntities.removeAll(keepingCapacity: true)
    }

    /// Insert an entity with its world-space AABB into the grid.
    ///
    /// The entity is placed into every cell that its bounding rectangle overlaps.
    public func insert(entity: Entity, bounds: Rect) {
        let minCellX = Int(floorf(bounds.minX * inverseCellSize))
        let maxCellX = Int(floorf(bounds.maxX * inverseCellSize))
        let minCellY = Int(floorf(bounds.minY * inverseCellSize))
        let maxCellY = Int(floorf(bounds.maxY * inverseCellSize))

        var keys: [CellKey] = []
        let cellCount = (maxCellX - minCellX + 1) * (maxCellY - minCellY + 1)
        keys.reserveCapacity(cellCount)
        for cx in minCellX...maxCellX {
            for cy in minCellY...maxCellY {
                let key = CellKey(x: cx, y: cy)
                keys.append(key)
                cells[key, default: []].append(entity)
            }
        }
        allEntities.append((entity: entity, cellKeys: keys))
    }

    /// Return all unique pairs of entities that share at least one grid cell.
    ///
    /// Each pair appears exactly once, using canonical ordering.
    /// Uses packed UInt64 keys for cheaper deduplication than hashing full CollisionPairs.
    public func queryPairs() -> [CollisionPair] {
        var seen = Set<UInt64>()
        var result: [CollisionPair] = []

        for (_, entities) in cells {
            guard entities.count > 1 else { continue }
            for i in 0..<entities.count {
                for j in (i + 1)..<entities.count {
                    let a = entities[i]
                    let b = entities[j]
                    // Pack canonical pair into UInt64 (smaller index in high bits)
                    let lo = min(a.index, b.index)
                    let hi = max(a.index, b.index)
                    let key = UInt64(lo) << 32 | UInt64(hi)
                    if seen.insert(key).inserted {
                        result.append(CollisionPair(a, b))
                    }
                }
            }
        }

        return result
    }
}

// MARK: - CellKey

/// A hashable key for a grid cell.
private struct CellKey: Hashable {
    let x: Int
    let y: Int
}
