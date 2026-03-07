@testable import Agilis
import Testing

// MARK: - Test Components

private struct PositionD: Component {
    var x: Float
    var y: Float
}

private struct VelocityD: Component {
    var dx: Float
    var dy: Float
}

// MARK: - Test System

private final class DebugCountingSystem: System, @unchecked Sendable {
    deinit {}

    var updateCallCount = 0

    func update(context _: SystemContext) {
        updateCallCount += 1
    }
}

private final class SlowSystem: System, @unchecked Sendable {
    deinit {}

    var priority: Int { 100 }

    func update(context _: SystemContext) {
        // Simulate some work
        var sum: Float = 0
        for i in 0..<1_000 {
            sum += Float(i) * 0.001
        }
        _ = sum
    }
}

// MARK: - Entity Count Tests

@Suite("World Debug Stats - Entity Count")
struct WorldEntityCountTests {

    @Test("Empty world has zero entity count")
    func emptyWorld() {
        let world = World()
        #expect(world.entityCount == 0)
    }

    @Test("Entity count tracks living entities")
    func tracksLiving() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        #expect(world.entityCount == 2)

        world.destroyEntity(e1)
        #expect(world.entityCount == 1)

        world.destroyEntity(e2)
        #expect(world.entityCount == 0)
    }
}

// MARK: - Component Store Count Tests

@Suite("World Debug Stats - Component Store Count")
struct WorldComponentStoreCountTests {

    @Test("Empty world has zero component stores")
    func emptyWorld() {
        let world = World()
        #expect(world.componentStoreCount == 0)
    }

    @Test("Adding components creates stores")
    func addsStores() {
        let world = World()
        let entity = world.createEntity()
        world.addComponent(PositionD(x: 0, y: 0), to: entity)
        #expect(world.componentStoreCount == 1)

        world.addComponent(VelocityD(dx: 1, dy: 2), to: entity)
        #expect(world.componentStoreCount == 2)
    }

    @Test("Multiple entities with same component type share store")
    func sharedStore() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        world.addComponent(PositionD(x: 0, y: 0), to: e1)
        world.addComponent(PositionD(x: 1, y: 1), to: e2)
        #expect(world.componentStoreCount == 1)
    }
}

// MARK: - System Count Tests

@Suite("World Debug Stats - System Count")
struct WorldSystemCountTests {

    @Test("Empty world has zero systems")
    func noSystems() {
        let world = World()
        #expect(world.systemCount == 0)
    }

    @Test("Adding systems increments count")
    func addsSystem() {
        let world = World()
        world.addSystem(DebugCountingSystem())
        #expect(world.systemCount == 1)

        world.addSystem(SlowSystem())
        #expect(world.systemCount == 2)
    }

    @Test("Removing system decrements count")
    func removesSystem() {
        let world = World()
        let system = DebugCountingSystem()
        world.addSystem(system)
        #expect(world.systemCount == 1)

        world.removeSystem(system)
        #expect(world.systemCount == 0)
    }
}

// MARK: - System Timings Tests

@Suite("World Debug Stats - System Timings")
struct WorldSystemTimingsTests {

    @Test("Timings are empty before first update")
    func emptyBeforeUpdate() {
        let world = World()
        #expect(world.systemTimings.isEmpty)
    }

    @Test("Timings are populated after update")
    func populatedAfterUpdate() {
        let world = World()
        world.addSystem(DebugCountingSystem())
        world.addSystem(SlowSystem())

        world.update(deltaTime: 1.0 / 60.0)

        #expect(world.systemTimings.count == 2)
    }

    @Test("Timings contain system names")
    func containsSystemNames() {
        let world = World()
        world.addSystem(DebugCountingSystem())

        world.update(deltaTime: 1.0 / 60.0)

        #expect(world.systemTimings.count == 1)
        #expect(world.systemTimings[0].name == "DebugCountingSystem")
    }

    @Test("Timings contain priority values")
    func containsPriority() {
        let world = World()
        world.addSystem(SlowSystem())

        world.update(deltaTime: 1.0 / 60.0)

        #expect(world.systemTimings[0].priority == 100)
    }

    @Test("Timings have non-negative durations")
    func nonNegativeDurations() {
        let world = World()
        world.addSystem(DebugCountingSystem())
        world.addSystem(SlowSystem())

        world.update(deltaTime: 1.0 / 60.0)

        for timing in world.systemTimings {
            #expect(timing.duration >= 0)
        }
    }

    @Test("Timings are refreshed each update")
    func refreshedEachUpdate() {
        let world = World()
        world.addSystem(DebugCountingSystem())

        world.update(deltaTime: 1.0 / 60.0)
        let firstTimings = world.systemTimings

        world.update(deltaTime: 1.0 / 60.0)
        let secondTimings = world.systemTimings

        #expect(firstTimings.count == 1)
        #expect(secondTimings.count == 1)
        // Both updates should produce timings (they may differ slightly)
        #expect(firstTimings[0].name == secondTimings[0].name)
    }
}
