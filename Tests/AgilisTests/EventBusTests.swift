import Testing
@testable import Agilis

// MARK: - Test Events

private struct PlayerDied: Event {
    let entityIndex: UInt32
    let killedBy: UInt32?
}

private struct ScoreChanged: Event {
    let oldScore: Int
    let newScore: Int
}

private struct EmptyEvent: Event {}

// MARK: - Event Bus Tests

@Suite("Event Bus Tests")
struct EventBusTests {

    @Test("Emit with no handlers does not crash")
    func emitNoHandlers() {
        let world = World()
        // Should be a no-op, not a crash
        world.emit(PlayerDied(entityIndex: 0, killedBy: nil))
    }

    @Test("Single handler receives event")
    func singleHandler() {
        let world = World()
        var received: PlayerDied?
        world.on(PlayerDied.self) { event in
            received = event
        }
        world.emit(PlayerDied(entityIndex: 5, killedBy: 3))
        #expect(received?.entityIndex == 5)
        #expect(received?.killedBy == 3)
    }

    @Test("Multiple handlers all fire")
    func multipleHandlers() {
        let world = World()
        var count = 0
        world.on(EmptyEvent.self) { _ in count += 1 }
        world.on(EmptyEvent.self) { _ in count += 1 }
        world.on(EmptyEvent.self) { _ in count += 1 }
        world.emit(EmptyEvent())
        #expect(count == 3)
    }

    @Test("Handlers fire in registration order")
    func handlerOrder() {
        let world = World()
        var order: [Int] = []
        world.on(EmptyEvent.self) { _ in order.append(1) }
        world.on(EmptyEvent.self) { _ in order.append(2) }
        world.on(EmptyEvent.self) { _ in order.append(3) }
        world.emit(EmptyEvent())
        #expect(order == [1, 2, 3])
    }

    @Test("Different event types are independent")
    func independentTypes() {
        let world = World()
        var playerDiedCount = 0
        var scoreChangedCount = 0
        world.on(PlayerDied.self) { _ in playerDiedCount += 1 }
        world.on(ScoreChanged.self) { _ in scoreChangedCount += 1 }

        world.emit(PlayerDied(entityIndex: 0, killedBy: nil))
        #expect(playerDiedCount == 1)
        #expect(scoreChangedCount == 0)

        world.emit(ScoreChanged(oldScore: 0, newScore: 10))
        #expect(playerDiedCount == 1)
        #expect(scoreChangedCount == 1)
    }

    @Test("removeHandlers stops delivery for that type")
    func removeHandlersForType() {
        let world = World()
        var count = 0
        world.on(EmptyEvent.self) { _ in count += 1 }
        world.emit(EmptyEvent())
        #expect(count == 1)

        world.removeHandlers(for: EmptyEvent.self)
        world.emit(EmptyEvent())
        #expect(count == 1) // no change
    }

    @Test("removeAllEventHandlers clears everything")
    func removeAll() {
        let world = World()
        var playerCount = 0
        var scoreCount = 0
        world.on(PlayerDied.self) { _ in playerCount += 1 }
        world.on(ScoreChanged.self) { _ in scoreCount += 1 }

        world.removeAllEventHandlers()
        world.emit(PlayerDied(entityIndex: 0, killedBy: nil))
        world.emit(ScoreChanged(oldScore: 0, newScore: 1))
        #expect(playerCount == 0)
        #expect(scoreCount == 0)
    }

    @Test("Re-entrant emit works correctly")
    func reentrantEmit() {
        let world = World()
        var outerFired = false
        var innerFired = false

        world.on(PlayerDied.self) { _ in
            outerFired = true
            // Emit a different event from inside a handler
            world.emit(ScoreChanged(oldScore: 0, newScore: 100))
        }
        world.on(ScoreChanged.self) { _ in
            innerFired = true
        }

        world.emit(PlayerDied(entityIndex: 0, killedBy: nil))
        #expect(outerFired)
        #expect(innerFired)
    }

    @Test("Event data is carried correctly")
    func eventDataCarried() {
        let world = World()
        var captured: ScoreChanged?
        world.on(ScoreChanged.self) { event in
            captured = event
        }
        world.emit(ScoreChanged(oldScore: 42, newScore: 99))
        #expect(captured?.oldScore == 42)
        #expect(captured?.newScore == 99)
    }

    @Test("Multiple emissions accumulate")
    func multipleEmissions() {
        let world = World()
        var scores: [Int] = []
        world.on(ScoreChanged.self) { event in
            scores.append(event.newScore)
        }
        world.emit(ScoreChanged(oldScore: 0, newScore: 10))
        world.emit(ScoreChanged(oldScore: 10, newScore: 20))
        world.emit(ScoreChanged(oldScore: 20, newScore: 30))
        #expect(scores == [10, 20, 30])
    }

    @Test("Handler added during emit does not fire for that emit")
    func handlerAddedDuringEmit() {
        let world = World()
        var lateHandlerFired = false

        world.on(EmptyEvent.self) { _ in
            // Register a new handler during emission
            world.on(EmptyEvent.self) { _ in
                lateHandlerFired = true
            }
        }

        world.emit(EmptyEvent())
        // The late handler should NOT have fired for the first emit
        #expect(!lateHandlerFired)

        // But it should fire for subsequent emits
        world.emit(EmptyEvent())
        #expect(lateHandlerFired)
    }

    @Test("Emit from system during update")
    func emitFromSystem() {
        let world = World()
        var received = false

        world.on(ScoreChanged.self) { event in
            received = true
            #expect(event.newScore == 50)
        }

        // Create a simple system that emits an event
        let emitterSystem = EventEmitterSystem()
        world.addSystem(emitterSystem)

        world.update(deltaTime: 1.0 / 60.0)
        #expect(received)
    }
}

// MARK: - Helper System

private final class EventEmitterSystem: System {
    func update(context: SystemContext) {
        context.world.emit(ScoreChanged(oldScore: 0, newScore: 50))
    }
}
