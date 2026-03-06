import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Procedurally generates a dungeon tilemap and wall entities.
enum DungeonBuilder {

    struct DungeonData {
        var tileMap: TileMap
        var wallEntities: [Entity]
        var roomCenters: [Vector2]
        var tileTexture: TextureHandle
    }

    /// Room definition during generation.
    private struct Room {
        var x: Int, y: Int, w: Int, h: Int
        var centerX: Int { x + w / 2 }
        var centerY: Int { y + h / 2 }

        func overlaps(_ other: Room, margin: Int = 2) -> Bool {
            return x - margin < other.x + other.w &&
                   x + w + margin > other.x &&
                   y - margin < other.y + other.h &&
                   y + h + margin > other.y
        }
    }

    static func generate(renderer: Renderer, world: World) -> DungeonData {
        let cols = Dungeon.mapCols
        let rows = Dungeon.mapRows
        let ts = Dungeon.tileSize

        // Start with all walls
        var grid = [[Int]](repeating: [Int](repeating: 1, count: cols), count: rows)

        // Carve rooms
        var rooms: [Room] = []
        var seed: UInt32 = 42
        for _ in 0..<30 { // attempts
            guard rooms.count < 7 else { break }
            seed = seed &* 1664525 &+ 1013904223
            let rw = 4 + Int(seed % 5)
            seed = seed &* 1664525 &+ 1013904223
            let rh = 4 + Int(seed % 4)
            seed = seed &* 1664525 &+ 1013904223
            let rx = 1 + Int(seed % UInt32(cols - rw - 2))
            seed = seed &* 1664525 &+ 1013904223
            let ry = 1 + Int(seed % UInt32(rows - rh - 2))

            let room = Room(x: rx, y: ry, w: rw, h: rh)
            if rooms.allSatisfy({ !$0.overlaps(room) }) {
                rooms.append(room)
                for row in ry..<(ry + rh) {
                    for col in rx..<(rx + rw) {
                        grid[row][col] = 0
                    }
                }
            }
        }

        // Connect rooms with L-shaped corridors
        for i in 1..<rooms.count {
            let prev = rooms[i - 1]
            let curr = rooms[i]
            let cx1 = prev.centerX, cy1 = prev.centerY
            let cx2 = curr.centerX, cy2 = curr.centerY

            // Horizontal then vertical
            let startX = min(cx1, cx2)
            let endX = max(cx1, cx2)
            for col in startX...endX { grid[cy1][col] = 0 }
            let startY = min(cy1, cy2)
            let endY = max(cy1, cy2)
            for row in startY...endY { grid[row][cx2] = 0 }
        }

        // Create tileset texture (2 tiles: floor + wall)
        let texW = 64
        let texH = 32
        var pixels = [UInt8](repeating: 0, count: texW * texH * 4)
        // Tile 0 (floor) at (0,0)
        for py in 0..<ts {
            for px in 0..<ts {
                let idx = (py * texW + px) * 4
                pixels[idx] = Dungeon.floorColor.r
                pixels[idx + 1] = Dungeon.floorColor.g
                pixels[idx + 2] = Dungeon.floorColor.b
                pixels[idx + 3] = 255
            }
        }
        // Tile 1 (wall) at (32,0)
        for py in 0..<ts {
            for px in 0..<ts {
                let idx = (py * texW + (px + ts)) * 4
                pixels[idx] = Dungeon.wallColor.r
                pixels[idx + 1] = Dungeon.wallColor.g
                pixels[idx + 2] = Dungeon.wallColor.b
                pixels[idx + 3] = 255
            }
        }
        let image = ImageData(width: texW, height: texH, pixels: pixels)
        let tileTexture = renderer.loadTextureFromImage(image)

        let tileset = Tileset(
            texture: tileTexture,
            tileWidth: ts,
            tileHeight: ts,
            columns: 2,
            firstGid: 1,
            tileCount: 2
        )

        // Build tile layer (id 1=floor, 2=wall to match firstGid=1)
        var tiles: [Tile] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let tileId = grid[row][col] == 0 ? 1 : 2  // floor=1, wall=2
                tiles.append(Tile(id: tileId))
            }
        }
        let layer = TileLayer(name: "ground", width: cols, height: rows, tiles: tiles)
        let tileMap = TileMap(layers: [layer], tilesets: [tileset],
                              tileWidth: ts, tileHeight: ts, width: cols, height: rows)

        // Create wall entities with colliders + shadow casters
        // Merge horizontally adjacent shadow-casting walls into runs to eliminate shadow seams
        var wallEntities: [Entity] = []

        // First pass: identify which walls are adjacent to floor (need shadow casting)
        var shadowGrid = [[Bool]](repeating: [Bool](repeating: false, count: cols), count: rows)
        for row in 0..<rows {
            for col in 0..<cols {
                guard grid[row][col] == 1 else { continue }
                let adjacentToFloor =
                    (row > 0 && grid[row - 1][col] == 0) ||
                    (row < rows - 1 && grid[row + 1][col] == 0) ||
                    (col > 0 && grid[row][col - 1] == 0) ||
                    (col < cols - 1 && grid[row][col + 1] == 0) ||
                    // Diagonal adjacency — prevents light leaking through corners
                    (row > 0 && col > 0 && grid[row - 1][col - 1] == 0) ||
                    (row > 0 && col < cols - 1 && grid[row - 1][col + 1] == 0) ||
                    (row < rows - 1 && col > 0 && grid[row + 1][col - 1] == 0) ||
                    (row < rows - 1 && col < cols - 1 && grid[row + 1][col + 1] == 0)
                shadowGrid[row][col] = adjacentToFloor
            }
        }

        // Interior walls (not adjacent to floor) — individual entities, no shadow caster
        for row in 0..<rows {
            for col in 0..<cols {
                guard grid[row][col] == 1 && !shadowGrid[row][col] else { continue }
                let entity = world.createEntity()
                let pos = Vector2(
                    x: Float(col * ts) + Float(ts) / 2,
                    y: Float(row * ts) + Float(ts) / 2
                )
                world.addComponent(Transform2D(position: pos), to: entity)
                world.addComponent(RigidBody2D(mass: 0, bodyType: .static), to: entity)
                world.addComponent(Collider2D(
                    shape: .aabb(halfExtents: Vector2(x: Float(ts) / 2, y: Float(ts) / 2)),
                    layer: Dungeon.layerWall,
                    mask: Dungeon.layerPlayer | Dungeon.layerEnemy
                ), to: entity)
                wallEntities.append(entity)
            }
        }

        // Shadow-casting walls — merge into rectangular runs to eliminate shadow seams
        // Use a greedy rectangle merge: mark cells as consumed, scan for largest runs
        var consumed = [[Bool]](repeating: [Bool](repeating: false, count: cols), count: rows)

        // First pass: merge horizontal runs
        for row in 0..<rows {
            var col = 0
            while col < cols {
                guard shadowGrid[row][col] && !consumed[row][col] else { col += 1; continue }
                let startCol = col
                while col < cols && shadowGrid[row][col] && !consumed[row][col] { col += 1 }
                let runLength = col - startCol

                // Try to extend this run downward (merge vertical)
                var endRow = row + 1
                while endRow < rows {
                    var canExtend = true
                    for c in startCol..<(startCol + runLength) {
                        if !shadowGrid[endRow][c] || consumed[endRow][c] {
                            canExtend = false
                            break
                        }
                    }
                    if !canExtend { break }
                    endRow += 1
                }
                let runHeight = endRow - row

                // Mark consumed
                for r in row..<endRow {
                    for c in startCol..<(startCol + runLength) {
                        consumed[r][c] = true
                    }
                }

                let entity = world.createEntity()
                let centerX = Float(startCol * ts) + Float(runLength * ts) / 2
                let centerY = Float(row * ts) + Float(runHeight * ts) / 2
                world.addComponent(Transform2D(position: Vector2(x: centerX, y: centerY)), to: entity)
                world.addComponent(RigidBody2D(mass: 0, bodyType: .static), to: entity)
                world.addComponent(Collider2D(
                    shape: .aabb(halfExtents: Vector2(x: Float(runLength * ts) / 2, y: Float(runHeight * ts) / 2)),
                    layer: Dungeon.layerWall,
                    mask: Dungeon.layerPlayer | Dungeon.layerEnemy
                ), to: entity)
                world.addComponent(ShadowCaster2D(), to: entity)
                wallEntities.append(entity)
            }
        }

        // Room centers for light placement
        let roomCenters = rooms.map { room in
            Vector2(x: Float(room.centerX * ts) + Float(ts) / 2,
                    y: Float(room.centerY * ts) + Float(ts) / 2)
        }

        return DungeonData(
            tileMap: tileMap,
            wallEntities: wallEntities,
            roomCenters: roomCenters,
            tileTexture: tileTexture
        )
    }
}
