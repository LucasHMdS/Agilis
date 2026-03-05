import Testing
@testable import Agilis

@Suite("Spatial Hash Grid Tests")
struct SpatialHashGridTests {

    @Test("Two entities in same cell form a pair")
    func sameCellPair() {
        let grid = SpatialHashGrid(cellSize: 64)
        let eA = Entity(index: 0, generation: 0)
        let eB = Entity(index: 1, generation: 0)

        grid.insert(entity: eA, bounds: Rect(x: 0, y: 0, width: 10, height: 10))
        grid.insert(entity: eB, bounds: Rect(x: 5, y: 5, width: 10, height: 10))

        let pairs = grid.queryPairs()
        #expect(pairs.count == 1)
        #expect(pairs[0] == CollisionPair(eA, eB))
    }

    @Test("Entities in different cells: no pairs")
    func differentCells() {
        let grid = SpatialHashGrid(cellSize: 64)
        let eA = Entity(index: 0, generation: 0)
        let eB = Entity(index: 1, generation: 0)

        grid.insert(entity: eA, bounds: Rect(x: 0, y: 0, width: 10, height: 10))
        grid.insert(entity: eB, bounds: Rect(x: 200, y: 200, width: 10, height: 10))

        let pairs = grid.queryPairs()
        #expect(pairs.isEmpty)
    }

    @Test("Entity spanning multiple cells pairs with neighbor")
    func spanningMultipleCells() {
        let grid = SpatialHashGrid(cellSize: 32)
        let eA = Entity(index: 0, generation: 0)
        let eB = Entity(index: 1, generation: 0)

        // eA spans cells: occupies cells at (0,0) and (1,0)
        grid.insert(entity: eA, bounds: Rect(x: 20, y: 0, width: 30, height: 10))
        // eB is in cell (1,0)
        grid.insert(entity: eB, bounds: Rect(x: 35, y: 0, width: 10, height: 10))

        let pairs = grid.queryPairs()
        #expect(pairs.count == 1)
    }

    @Test("Clear removes all entries")
    func clearGrid() {
        let grid = SpatialHashGrid(cellSize: 64)
        let eA = Entity(index: 0, generation: 0)
        let eB = Entity(index: 1, generation: 0)

        grid.insert(entity: eA, bounds: Rect(x: 0, y: 0, width: 10, height: 10))
        grid.insert(entity: eB, bounds: Rect(x: 5, y: 5, width: 10, height: 10))

        grid.clear()
        let pairs = grid.queryPairs()
        #expect(pairs.isEmpty)
    }

    @Test("Single entity: no pairs")
    func singleEntity() {
        let grid = SpatialHashGrid(cellSize: 64)
        let e = Entity(index: 0, generation: 0)

        grid.insert(entity: e, bounds: Rect(x: 0, y: 0, width: 10, height: 10))

        let pairs = grid.queryPairs()
        #expect(pairs.isEmpty)
    }

    @Test("Three entities in same cell: three pairs")
    func threeEntities() {
        let grid = SpatialHashGrid(cellSize: 64)
        let eA = Entity(index: 0, generation: 0)
        let eB = Entity(index: 1, generation: 0)
        let eC = Entity(index: 2, generation: 0)

        grid.insert(entity: eA, bounds: Rect(x: 0, y: 0, width: 10, height: 10))
        grid.insert(entity: eB, bounds: Rect(x: 5, y: 5, width: 10, height: 10))
        grid.insert(entity: eC, bounds: Rect(x: 10, y: 10, width: 10, height: 10))

        let pairs = grid.queryPairs()
        #expect(pairs.count == 3) // AB, AC, BC
    }

    @Test("Duplicate pairs from multiple shared cells are deduplicated")
    func deduplication() {
        let grid = SpatialHashGrid(cellSize: 32)
        let eA = Entity(index: 0, generation: 0)
        let eB = Entity(index: 1, generation: 0)

        // Both entities span the same two cells
        grid.insert(entity: eA, bounds: Rect(x: 20, y: 0, width: 30, height: 10))
        grid.insert(entity: eB, bounds: Rect(x: 25, y: 0, width: 30, height: 10))

        let pairs = grid.queryPairs()
        #expect(pairs.count == 1) // Should only appear once
    }

    @Test("Negative coordinate entities work correctly")
    func negativeCoordinates() {
        let grid = SpatialHashGrid(cellSize: 64)
        let eA = Entity(index: 0, generation: 0)
        let eB = Entity(index: 1, generation: 0)

        grid.insert(entity: eA, bounds: Rect(x: -20, y: -20, width: 10, height: 10))
        grid.insert(entity: eB, bounds: Rect(x: -15, y: -15, width: 10, height: 10))

        let pairs = grid.queryPairs()
        #expect(pairs.count == 1)
    }
}
