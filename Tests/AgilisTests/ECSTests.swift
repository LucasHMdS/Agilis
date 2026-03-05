import Testing
@testable import Agilis

// MARK: - Test Components

struct Position: Component {
    var x: Float
    var y: Float
    init(x: Float, y: Float) { self.x = x; self.y = y }
}

struct Velocity: Component {
    var dx: Float
    var dy: Float
    init(dx: Float, dy: Float) { self.dx = dx; self.dy = dy }
}

struct Health: Component {
    var hp: Int
    init(hp: Int) { self.hp = hp }
}

/// A zero-size tag component for testing.
struct Frozen: Component {
    init() {}
}

// MARK: - Test Systems

final class MovementSystem: System {
    var updateCount = 0

    func update(context: SystemContext) {
        context.world.forEach { (entity: Entity, pos: inout Position, vel: inout Velocity) in
            pos.x += vel.dx * Float(context.deltaTime)
            pos.y += vel.dy * Float(context.deltaTime)
        }
        updateCount += 1
    }
}

final class CountingSystem: System {
    var setupCalled = false
    var updateCount = 0

    func setup(world: World) {
        setupCalled = true
    }

    func update(context: SystemContext) {
        updateCount += 1
    }
}

final class HighPrioritySystem: System {
    var priority: Int { -10 }
    var order: Int = 0
    var executionTracker: ExecutionTracker?

    func update(context: SystemContext) {
        order = executionTracker?.next() ?? 0
    }
}

final class LowPrioritySystem: System {
    var priority: Int { 10 }
    var order: Int = 0
    var executionTracker: ExecutionTracker?

    func update(context: SystemContext) {
        order = executionTracker?.next() ?? 0
    }
}

/// Helper for tracking system execution order.
final class ExecutionTracker {
    private var counter = 0
    func next() -> Int {
        counter += 1
        return counter
    }
}

// MARK: - Entity Tests

@Suite("Entity Tests")
struct EntityTests {
    @Test func uniqueIds() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        let e3 = world.createEntity()
        #expect(e1.index != e2.index || e1.generation != e2.generation)
        #expect(e2.index != e3.index || e2.generation != e3.generation)
    }

    @Test func entityHashable() {
        let e1 = Entity(index: 1, generation: 0)
        let e2 = Entity(index: 1, generation: 0)
        let e3 = Entity(index: 2, generation: 0)
        #expect(e1 == e2)
        #expect(e1 != e3)

        let set: Set<Entity> = [e1, e2, e3]
        #expect(set.count == 2)
    }

    @Test func entityNull() {
        let null = Entity.null
        #expect(null.index == .max)
        let world = World()
        #expect(!world.isAlive(null))
    }

    @Test func generationalIds() {
        let world = World()
        let e1 = world.createEntity()
        let originalIndex = e1.index
        let originalGeneration = e1.generation

        world.destroyEntity(e1)
        #expect(!world.isAlive(e1))

        // Create a new entity — should reuse the slot with incremented generation
        let e2 = world.createEntity()
        #expect(e2.index == originalIndex)
        #expect(e2.generation == originalGeneration &+ 1)

        // The old handle is still stale
        #expect(!world.isAlive(e1))
        #expect(world.isAlive(e2))
    }

    @Test func entityCount() {
        let world = World()
        #expect(world.entityCount == 0)

        let e1 = world.createEntity()
        let e2 = world.createEntity()
        #expect(world.entityCount == 2)

        world.destroyEntity(e1)
        #expect(world.entityCount == 1)

        world.destroyEntity(e2)
        #expect(world.entityCount == 0)
    }
}

// MARK: - World Tests

@Suite("World Tests")
struct WorldTests {
    @Test func createAndDestroyEntity() {
        let world = World()
        let entity = world.createEntity()
        #expect(world.isAlive(entity))
        #expect(world.entityCount == 1)

        world.destroyEntity(entity)
        #expect(!world.isAlive(entity))
        #expect(world.entityCount == 0)
    }

    @Test func destroyNonexistentEntity() {
        let world = World()
        let fake = Entity(index: 999, generation: 0)
        world.destroyEntity(fake) // should not crash
        #expect(!world.isAlive(fake))
    }

    @Test func addAndGetComponent() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 10, y: 20), to: entity)

        let retrieved = world.getComponent(Position.self, from: entity)
        #expect(retrieved?.x == 10)
        #expect(retrieved?.y == 20)
    }

    @Test func getComponentWrongType() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 0, y: 0), to: entity)

        let vel = world.getComponent(Velocity.self, from: entity)
        #expect(vel == nil)
    }

    @Test func getComponentFromDeadEntity() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 5, y: 5), to: entity)
        world.destroyEntity(entity)

        #expect(world.getComponent(Position.self, from: entity) == nil)
    }

    @Test func removeComponent() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 0, y: 0), to: entity)
        #expect(world.hasComponent(Position.self, on: entity))

        world.removeComponent(Position.self, from: entity)
        #expect(!world.hasComponent(Position.self, on: entity))
    }

    @Test func replaceComponent() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 1, y: 1), to: entity)
        world.addComponent(Position(x: 99, y: 99), to: entity)

        let pos = world.getComponent(Position.self, from: entity)
        #expect(pos?.x == 99)
    }

    @Test func multipleComponentTypes() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 1, y: 2), to: entity)
        world.addComponent(Velocity(dx: 3, dy: 4), to: entity)
        world.addComponent(Health(hp: 100), to: entity)

        #expect(world.hasComponent(Position.self, on: entity))
        #expect(world.hasComponent(Velocity.self, on: entity))
        #expect(world.hasComponent(Health.self, on: entity))
    }

    @Test func updateComponentInPlace() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Health(hp: 100), to: entity)

        let updated = world.updateComponent(Health.self, on: entity) { health in
            health.hp -= 25
        }

        #expect(updated)
        #expect(world.getComponent(Health.self, from: entity)?.hp == 75)
    }

    @Test func updateComponentOnDeadEntity() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Health(hp: 100), to: entity)
        world.destroyEntity(entity)

        let updated = world.updateComponent(Health.self, on: entity) { $0.hp = 0 }
        #expect(!updated)
    }

    @Test func allEntities() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        let e3 = world.createEntity()
        world.destroyEntity(e2)

        let all = world.allEntities
        #expect(all.count == 2)
        #expect(all.contains(e1))
        #expect(all.contains(e3))
        #expect(!all.contains(e2))
    }

    @Test func destroyEntityCleansUpComponents() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 1, y: 2), to: entity)
        world.addComponent(Health(hp: 50), to: entity)
        world.destroyEntity(entity)

        // Create a new entity that reuses the slot
        let newEntity = world.createEntity()
        #expect(newEntity.index == entity.index)

        // The new entity should NOT have the old entity's components
        #expect(!world.hasComponent(Position.self, on: newEntity))
        #expect(!world.hasComponent(Health.self, on: newEntity))
    }
}

// MARK: - Query Tests

@Suite("Query Tests")
struct QueryTests {
    @Test func forEachSingleComponent() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        world.addComponent(Position(x: 10, y: 20), to: e1)
        world.addComponent(Position(x: 30, y: 40), to: e2)

        var count = 0
        world.forEach { (entity: Entity, pos: inout Position) in
            pos.x += 1
            count += 1
        }

        #expect(count == 2)
        #expect(world.getComponent(Position.self, from: e1)?.x == 11)
        #expect(world.getComponent(Position.self, from: e2)?.x == 31)
    }

    @Test func forEachTwoComponents() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        let e3 = world.createEntity()

        world.addComponent(Position(x: 0, y: 0), to: e1)
        world.addComponent(Velocity(dx: 10, dy: 5), to: e1)

        world.addComponent(Position(x: 0, y: 0), to: e2)
        // e2 has no velocity

        world.addComponent(Position(x: 100, y: 100), to: e3)
        world.addComponent(Velocity(dx: -1, dy: -1), to: e3)

        world.forEach { (entity: Entity, pos: inout Position, vel: inout Velocity) in
            pos.x += vel.dx
            pos.y += vel.dy
        }

        #expect(world.getComponent(Position.self, from: e1)?.x == 10)
        #expect(world.getComponent(Position.self, from: e1)?.y == 5)
        #expect(world.getComponent(Position.self, from: e2)?.x == 0)  // untouched
        #expect(world.getComponent(Position.self, from: e3)?.x == 99)
    }

    @Test func forEachThreeComponents() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 0, y: 0), to: entity)
        world.addComponent(Velocity(dx: 5, dy: 10), to: entity)
        world.addComponent(Health(hp: 100), to: entity)

        var count = 0
        world.forEach { (e: Entity, pos: inout Position, vel: inout Velocity, hp: inout Health) in
            pos.x += vel.dx
            hp.hp -= 1
            count += 1
        }

        #expect(count == 1)
        #expect(world.getComponent(Position.self, from: entity)?.x == 5)
        #expect(world.getComponent(Health.self, from: entity)?.hp == 99)
    }

    @Test func forEachSkipsDeadEntities() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        world.addComponent(Position(x: 1, y: 1), to: e1)
        world.addComponent(Position(x: 2, y: 2), to: e2)

        world.destroyEntity(e1)

        var count = 0
        world.forEach { (entity: Entity, pos: inout Position) in
            count += 1
        }
        #expect(count == 1)
    }

    @Test func forEachEmptyWorld() {
        let world = World()
        var count = 0
        world.forEach { (entity: Entity, pos: inout Position) in
            count += 1
        }
        #expect(count == 0)
    }
}

// MARK: - System Tests

@Suite("System Tests")
struct SystemTests {
    @Test func systemSetupCalled() {
        let world = World()
        let system = CountingSystem()
        world.addSystem(system)
        #expect(system.setupCalled)
    }

    @Test func systemRunsOnUpdate() {
        let world = World()
        let system = MovementSystem()
        world.addSystem(system)

        let entity = world.createEntity()
        world.addComponent(Position(x: 0, y: 0), to: entity)
        world.addComponent(Velocity(dx: 100, dy: 50), to: entity)

        world.update(deltaTime: 1.0)

        let pos = world.getComponent(Position.self, from: entity)
        #expect(pos?.x == 100)
        #expect(pos?.y == 50)
        #expect(system.updateCount == 1)
    }

    @Test func removeSystem() {
        let world = World()
        let system = CountingSystem()
        world.addSystem(system)

        world.update(deltaTime: 1.0)
        #expect(system.updateCount == 1)

        world.removeSystem(system)
        world.update(deltaTime: 1.0)
        #expect(system.updateCount == 1) // not incremented after removal
    }

    @Test func multipleUpdates() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Position(x: 0, y: 0), to: entity)
        world.addComponent(Velocity(dx: 10, dy: 5), to: entity)
        world.addSystem(MovementSystem())

        world.update(deltaTime: 0.5)
        world.update(deltaTime: 0.5)
        world.update(deltaTime: 0.5)

        let pos = world.getComponent(Position.self, from: entity)
        #expect(abs((pos?.x ?? 0) - 15) < 0.001)
        #expect(abs((pos?.y ?? 0) - 7.5) < 0.001)
    }

    @Test func systemPriority() {
        let world = World()
        let tracker = ExecutionTracker()

        let high = HighPrioritySystem()
        high.executionTracker = tracker
        let low = LowPrioritySystem()
        low.executionTracker = tracker

        // Add low first, high second — priority should still make high run first
        world.addSystem(low)
        world.addSystem(high)

        world.update(deltaTime: 1.0)

        #expect(high.order == 1)
        #expect(low.order == 2)
    }
}

// MARK: - Command Buffer Tests

@Suite("Command Buffer Tests")
struct CommandBufferTests {
    @Test func deferredEntityCreation() {
        let world = World()
        let buffer = CommandBuffer()

        let entity = buffer.createEntity(in: world)
        // Entity is reserved but not yet confirmed
        #expect(!world.isAlive(entity))

        buffer.flush(into: world)
        #expect(world.isAlive(entity))
    }

    @Test func deferredEntityDestruction() {
        let world = World()
        let entity = world.createEntity()
        #expect(world.isAlive(entity))

        let buffer = CommandBuffer()
        buffer.destroyEntity(entity)
        #expect(world.isAlive(entity)) // still alive before flush

        buffer.flush(into: world)
        #expect(!world.isAlive(entity))
    }

    @Test func deferredComponentAddition() {
        let world = World()
        let entity = world.createEntity()

        let buffer = CommandBuffer()
        buffer.addComponent(Position(x: 42, y: 84), to: entity)
        #expect(world.getComponent(Position.self, from: entity) == nil)

        buffer.flush(into: world)
        let pos = world.getComponent(Position.self, from: entity)
        #expect(pos?.x == 42)
        #expect(pos?.y == 84)
    }

    @Test func deferredComponentRemoval() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(Health(hp: 100), to: entity)

        let buffer = CommandBuffer()
        buffer.removeComponent(Health.self, from: entity)
        #expect(world.hasComponent(Health.self, on: entity)) // still there

        buffer.flush(into: world)
        #expect(!world.hasComponent(Health.self, on: entity))
    }

    @Test func createEntityAndAddComponents() {
        let world = World()
        let buffer = CommandBuffer()

        let entity = buffer.createEntity(in: world)
        buffer.addComponent(Position(x: 1, y: 2), to: entity)
        buffer.addComponent(Velocity(dx: 3, dy: 4), to: entity)

        buffer.flush(into: world)

        #expect(world.isAlive(entity))
        #expect(world.getComponent(Position.self, from: entity)?.x == 1)
        #expect(world.getComponent(Velocity.self, from: entity)?.dx == 3)
    }
}

// MARK: - Hierarchy Tests

@Suite("Hierarchy Tests")
struct HierarchyTests {
    @Test func setAndGetParent() {
        let world = World()
        let parent = world.createEntity()
        let child = world.createEntity()

        world.setParent(parent, for: child)

        #expect(world.parent(of: child) == parent)
        let kids = world.children(of: parent)
        #expect(kids.count == 1)
        #expect(kids.first == child)
    }

    @Test func detachFromParent() {
        let world = World()
        let parent = world.createEntity()
        let child = world.createEntity()

        world.setParent(parent, for: child)
        world.setParent(nil, for: child)

        #expect(world.parent(of: child) == nil)
        #expect(world.children(of: parent).isEmpty)
    }

    @Test func reparent() {
        let world = World()
        let parent1 = world.createEntity()
        let parent2 = world.createEntity()
        let child = world.createEntity()

        world.setParent(parent1, for: child)
        world.setParent(parent2, for: child)

        #expect(world.parent(of: child) == parent2)
        #expect(world.children(of: parent1).isEmpty)
        #expect(world.children(of: parent2).count == 1)
    }

    @Test func destroyParentDestroysChildren() {
        let world = World()
        let parent = world.createEntity()
        let child1 = world.createEntity()
        let child2 = world.createEntity()

        world.setParent(parent, for: child1)
        world.setParent(parent, for: child2)

        world.destroyEntity(parent)

        #expect(!world.isAlive(parent))
        #expect(!world.isAlive(child1))
        #expect(!world.isAlive(child2))
    }

    @Test func destroyParentDestroysGrandchildren() {
        let world = World()
        let grandparent = world.createEntity()
        let parent = world.createEntity()
        let child = world.createEntity()

        world.setParent(grandparent, for: parent)
        world.setParent(parent, for: child)

        world.destroyEntity(grandparent)

        #expect(!world.isAlive(grandparent))
        #expect(!world.isAlive(parent))
        #expect(!world.isAlive(child))
    }

    @Test func multipleChildren() {
        let world = World()
        let parent = world.createEntity()
        var children: [Entity] = []
        for _ in 0..<5 {
            let child = world.createEntity()
            world.setParent(parent, for: child)
            children.append(child)
        }

        let kids = world.children(of: parent)
        #expect(kids.count == 5)
        for child in children {
            #expect(kids.contains(child))
        }
    }
}

// MARK: - Metadata Tests

@Suite("Metadata Tests")
struct MetadataTests {
    @Test func setAndGetName() {
        let world = World()
        let entity = world.createEntity()
        world.setName("Player", for: entity)

        #expect(world.name(of: entity) == "Player")
        #expect(world.entity(named: "Player") == entity)
    }

    @Test func nameUniqueness() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()

        world.setName("Hero", for: e1)
        world.setName("Hero", for: e2)

        // e2 now owns the name; e1 loses it
        #expect(world.entity(named: "Hero") == e2)
        #expect(world.name(of: e1) == nil)
    }

    @Test func entityNotFound() {
        let world = World()
        #expect(world.entity(named: "Ghost") == nil)
    }

    @Test func addAndQueryTags() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        let e3 = world.createEntity()

        world.addTag("enemy", to: e1)
        world.addTag("enemy", to: e2)
        world.addTag("friendly", to: e3)

        let enemies = world.entitiesWithTag("enemy")
        #expect(enemies.count == 2)
        #expect(enemies.contains(e1))
        #expect(enemies.contains(e2))

        #expect(world.hasTag("enemy", on: e1))
        #expect(!world.hasTag("friendly", on: e1))
    }

    @Test func removeTag() {
        let world = World()
        let entity = world.createEntity()
        world.addTag("target", to: entity)
        #expect(world.hasTag("target", on: entity))

        world.removeTag("target", from: entity)
        #expect(!world.hasTag("target", on: entity))
        #expect(world.entitiesWithTag("target").isEmpty)
    }

    @Test func destroyEntityCleansMetadata() {
        let world = World()
        let entity = world.createEntity()
        world.setName("Boss", for: entity)
        world.addTag("enemy", to: entity)

        world.destroyEntity(entity)

        #expect(world.entity(named: "Boss") == nil)
        #expect(world.entitiesWithTag("enemy").isEmpty)
    }
}

// MARK: - Component Event Tests

@Suite("Component Event Tests")
struct ComponentEventTests {
    @Test func onAddHandler() {
        let world = World()
        var addedEntities: [Entity] = []

        world.onComponentAdded(Position.self) { entity, _ in
            addedEntities.append(entity)
        }

        let e1 = world.createEntity()
        let e2 = world.createEntity()
        world.addComponent(Position(x: 0, y: 0), to: e1)
        world.addComponent(Position(x: 1, y: 1), to: e2)

        #expect(addedEntities.count == 2)
        #expect(addedEntities[0] == e1)
        #expect(addedEntities[1] == e2)
    }

    @Test func onRemoveHandler() {
        let world = World()
        var removedEntities: [Entity] = []

        world.onComponentRemoved(Health.self) { entity, _ in
            removedEntities.append(entity)
        }

        let entity = world.createEntity()
        world.addComponent(Health(hp: 100), to: entity)
        world.removeComponent(Health.self, from: entity)

        #expect(removedEntities.count == 1)
        #expect(removedEntities[0] == entity)
    }

    @Test func onRemoveHandlerFiresOnDestroy() {
        let world = World()
        var removedCount = 0

        world.onComponentRemoved(Position.self) { _, _ in
            removedCount += 1
        }

        let entity = world.createEntity()
        world.addComponent(Position(x: 0, y: 0), to: entity)
        world.destroyEntity(entity)

        #expect(removedCount == 1)
    }
}

// MARK: - Prefab Tests

@Suite("Prefab Tests")
struct PrefabTests {
    @Test func basicPrefab() {
        let world = World()

        var prefab = Prefab()
        prefab.add(Position(x: 10, y: 20))
        prefab.add(Health(hp: 50))

        let entity = prefab.instantiate(in: world)

        #expect(world.isAlive(entity))
        #expect(world.getComponent(Position.self, from: entity)?.x == 10)
        #expect(world.getComponent(Health.self, from: entity)?.hp == 50)
    }

    @Test func prefabWithNameAndTags() {
        let world = World()

        var prefab = Prefab()
        prefab.add(Health(hp: 100))
        prefab.withName("Player")
        prefab.withTag("friendly")
        prefab.withTag("controllable")

        let entity = prefab.instantiate(in: world)

        #expect(world.entity(named: "Player") == entity)
        #expect(world.hasTag("friendly", on: entity))
        #expect(world.hasTag("controllable", on: entity))
    }

    @Test func prefabWithChildren() {
        let world = World()

        var childPrefab = Prefab()
        childPrefab.add(Position(x: 5, y: 0))

        var parentPrefab = Prefab()
        parentPrefab.add(Position(x: 100, y: 200))
        parentPrefab.addChild(childPrefab)

        let parent = parentPrefab.instantiate(in: world)
        let children = world.children(of: parent)

        #expect(children.count == 1)
        #expect(world.parent(of: children[0]) == parent)
        #expect(world.getComponent(Position.self, from: children[0])?.x == 5)
    }

    @Test func multipleInstantiations() {
        let world = World()

        var prefab = Prefab()
        prefab.add(Health(hp: 10))
        prefab.withTag("clone")

        for _ in 0..<5 {
            prefab.instantiate(in: world)
        }

        #expect(world.entitiesWithTag("clone").count == 5)
    }
}

// MARK: - Sparse Set Tests

@Suite("SparseSet Tests")
struct SparseSetTests {
    @Test func insertAndGet() {
        var set = SparseSet<Int>()
        set.insert(key: 5, value: 42)
        #expect(set.get(key: 5) == 42)
        #expect(set.count == 1)
    }

    @Test func overwrite() {
        var set = SparseSet<Int>()
        set.insert(key: 3, value: 10)
        set.insert(key: 3, value: 20)
        #expect(set.get(key: 3) == 20)
        #expect(set.count == 1)
    }

    @Test func remove() {
        var set = SparseSet<Int>()
        set.insert(key: 1, value: 100)
        set.insert(key: 2, value: 200)
        set.insert(key: 3, value: 300)

        let removed = set.remove(key: 2)
        #expect(removed == 200)
        #expect(set.count == 2)
        #expect(set.get(key: 2) == nil)
        #expect(set.get(key: 1) == 100)
        #expect(set.get(key: 3) == 300)
    }

    @Test func contains() {
        var set = SparseSet<String>()
        set.insert(key: 7, value: "hello")
        #expect(set.contains(key: 7))
        #expect(!set.contains(key: 8))
    }

    @Test func removeAll() {
        var set = SparseSet<Int>()
        set.insert(key: 0, value: 1)
        set.insert(key: 1, value: 2)
        set.removeAll()
        #expect(set.isEmpty)
        #expect(set.count == 0)
    }

    @Test func withValue() {
        var set = SparseSet<Int>()
        set.insert(key: 10, value: 5)
        set.withValue(for: 10) { $0 += 10 }
        #expect(set.get(key: 10) == 15)
    }

    @Test func denseIteration() {
        var set = SparseSet<Int>()
        set.insert(key: 100, value: 1)
        set.insert(key: 200, value: 2)
        set.insert(key: 300, value: 3)

        #expect(set.dense.count == 3)
        #expect(set.values.count == 3)

        // All keys and values should be present (order may vary after removals)
        let pairs = zip(set.dense, set.values)
        let dict = Dictionary(uniqueKeysWithValues: pairs.map { (Int($0), $1) })
        #expect(dict[100] == 1)
        #expect(dict[200] == 2)
        #expect(dict[300] == 3)
    }
}
