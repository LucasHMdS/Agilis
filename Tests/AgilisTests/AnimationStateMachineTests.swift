@testable import Agilis
import Foundation
import Testing
private final class CallTracker: @unchecked Sendable {
    deinit {}

    var called = false
    var callCount = 0
    func call() { called = true; callCount += 1 }
}

/// Thread-safe value tracker for @Sendable closure testing.
private final class ValueTracker<T>: @unchecked Sendable {
    deinit {}

    var value: T
    init(_ initial: T) { self.value = initial }
}

private func makeClip(
    _ name: String,
    frameCount: Int = 4,
    frameDuration: Float = 0.1,
    mode: PlaybackMode = .forward
) -> AnimationClip {
    AnimationClip.fromSpriteSheet(
        name: name,
        startX: 0,
        y: 0,
        frameWidth: 32,
        frameHeight: 32,
        count: frameCount,
        frameDuration: frameDuration,
        mode: mode
    )
}

private func makeWorld() -> (World, AnimationStateMachineSystem, AnimationSystem) {
    let world = World()
    let smSystem = AnimationStateMachineSystem()
    let animSystem = AnimationSystem()
    world.addSystem(smSystem)
    world.addSystem(animSystem)
    return (world, smSystem, animSystem)
}

private func tick(_ world: World, times: Int = 1, dt: Double = 1.0 / 60.0) {
    for _ in 0..<times {
        world.update(deltaTime: dt)
    }
}

/// Creates an entity with Sprite, SpriteAnimator (using the default state's clip), and the state machine.
private func makeEntity(_ world: World, sm: AnimationStateMachine) -> Entity {
    let entity = world.createEntity()
    let defaultClip = sm.states[sm.defaultStateName]?.clip ?? makeClip("empty", frameCount: 1)
    world.addComponent(Sprite(texture: TextureHandle(id: 1)), to: entity)
    world.addComponent(SpriteAnimator(clip: defaultClip), to: entity)
    world.addComponent(sm, to: entity)
    return entity
}

// MARK: - AnimationState Tests

@Suite("AnimationState Tests")
struct AnimationStateTests {

    @Test("Create state with defaults")
    func createWithDefaults() {
        let clip = makeClip("idle")
        let state = AnimationState(name: "idle", clip: clip)
        #expect(state.name == "idle")
        #expect(state.clip.name == "idle")
        #expect(state.speed == 1.0)
    }

    @Test("Create state with custom speed")
    func createWithCustomSpeed() {
        let clip = makeClip("attack")
        let state = AnimationState(name: "attack", clip: clip, speed: 1.5)
        #expect(state.speed == 1.5)
    }

    @Test("States are equatable")
    func statesEquatable() {
        let clip = makeClip("idle")
        let a = AnimationState(name: "idle", clip: clip, speed: 1.0)
        let b = AnimationState(name: "idle", clip: clip, speed: 1.0)
        #expect(a == b)
    }
}

// MARK: - TransitionCondition Tests

@Suite("TransitionCondition Tests")
struct TransitionConditionTests {

    @Test("Bool equals condition")
    func boolEquals() {
        let c = TransitionCondition.boolEquals("isRunning", true)
        #expect(c == .boolEquals("isRunning", true))
        #expect(c != .boolEquals("isRunning", false))
    }

    @Test("Float greater condition")
    func floatGreater() {
        let c = TransitionCondition.floatGreater("speed", 5.0)
        #expect(c == .floatGreater("speed", 5.0))
    }

    @Test("Float less condition")
    func floatLess() {
        let c = TransitionCondition.floatLess("speed", 0.1)
        #expect(c == .floatLess("speed", 0.1))
    }

    @Test("Int equals condition")
    func intEquals() {
        let c = TransitionCondition.intEquals("direction", 1)
        #expect(c == .intEquals("direction", 1))
    }

    @Test("Trigger condition")
    func trigger() {
        let c = TransitionCondition.trigger("attack")
        #expect(c == .trigger("attack"))
    }

    @Test("Animation finished condition")
    func animFinished() {
        #expect(TransitionCondition.animationFinished == .animationFinished)
    }

    @Test("Animation looped condition")
    func animLooped() {
        #expect(TransitionCondition.animationLooped == .animationLooped)
    }

    @Test("After time condition")
    func afterTime() {
        let c = TransitionCondition.afterTime(2.0)
        #expect(c == .afterTime(2.0))
    }
}

// MARK: - Component Configuration Tests

@Suite("AnimationStateMachine Component Config Tests")
struct ComponentConfigTests {

    @Test("Init sets default state")
    func initDefaultState() {
        let sm = AnimationStateMachine(defaultState: "idle")
        #expect(sm.defaultStateName == "idle")
        #expect(sm.currentStateName == "idle")
        #expect(sm.timeInState == 0)
        #expect(sm.previousStateName == nil)
        #expect(sm.needsInitialization == true)
    }

    @Test("Add states")
    func addStates() {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"), speed: 1.2)
        #expect(sm.states.count == 2)
        #expect(sm.states["idle"]?.speed == 1.0)
        #expect(sm.states["walk"]?.speed == 1.2)
    }

    @Test("Add transitions")
    func addTransitions() {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("isMoving", true)])
        sm.addTransition(from: "walk", to: "idle", conditions: [.boolEquals("isMoving", false)])
        #expect(sm.transitions.count == 2)
        #expect(sm.transitions[0].from == "idle")
        #expect(sm.transitions[0].to == "walk")
    }

    @Test("Add any-state transitions")
    func addAnyStateTransitions() {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addAnyStateTransition(to: "death", conditions: [.boolEquals("isDead", true)])
        #expect(sm.anyStateTransitions.count == 1)
        #expect(sm.anyStateTransitions[0].from.isEmpty)
        #expect(sm.anyStateTransitions[0].to == "death")
    }

    @Test("Bool parameters")
    func boolParams() {
        var sm = AnimationStateMachine(defaultState: "idle")
        #expect(sm.getBool("isRunning") == false)
        sm.setBool("isRunning", true)
        #expect(sm.getBool("isRunning") == true)
        sm.setBool("isRunning", false)
        #expect(sm.getBool("isRunning") == false)
    }

    @Test("Float parameters")
    func floatParams() {
        var sm = AnimationStateMachine(defaultState: "idle")
        #expect(sm.getFloat("speed") == 0)
        sm.setFloat("speed", 3.5)
        #expect(sm.getFloat("speed") == 3.5)
    }

    @Test("Int parameters")
    func intParams() {
        var sm = AnimationStateMachine(defaultState: "idle")
        #expect(sm.getInt("direction") == 0)
        sm.setInt("direction", 2)
        #expect(sm.getInt("direction") == 2)
    }

    @Test("Trigger parameters")
    func triggerParams() {
        var sm = AnimationStateMachine(defaultState: "idle")
        #expect(sm.isTriggerSet("attack") == false)
        sm.setTrigger("attack")
        #expect(sm.isTriggerSet("attack") == true)
        sm.consumeTrigger("attack")
        #expect(sm.isTriggerSet("attack") == false)
    }
}

// MARK: - Initialization Tests

@Suite("Initialization Tests")
struct InitializationTests {

    @Test("Auto-initialization sets default state clip")
    func autoInit() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))

        let entity = world.createEntity()
        world.addComponent(Sprite(texture: TextureHandle(id: 1)), to: entity)
        // Start with a wrong clip
        world.addComponent(SpriteAnimator(clip: makeClip("wrong")), to: entity)
        world.addComponent(sm, to: entity)

        tick(world)

        let animator = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animator.clip.name == "idle")
    }

    @Test("Initialization clears needsInitialization flag")
    func clearsFlag() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        let entity = makeEntity(world, sm: sm)

        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.needsInitialization == false)
    }

    @Test("Missing default state gracefully handled")
    func missingDefaultState() throws {
        let (world, _, _) = makeWorld()
        let sm = AnimationStateMachine(defaultState: "nonexistent")
        // No states added — should not crash

        let entity = world.createEntity()
        world.addComponent(Sprite(texture: TextureHandle(id: 1)), to: entity)
        world.addComponent(SpriteAnimator(clip: makeClip("fallback")), to: entity)
        world.addComponent(sm, to: entity)

        tick(world)
        // Should not crash; animator keeps its current clip
        let animator = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animator.clip.name == "fallback")
    }

    @Test("Speed override applied on initialization")
    func speedOverride() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "fast")
        sm.addState("fast", clip: makeClip("fast"), speed: 2.0)
        let entity = makeEntity(world, sm: sm)

        tick(world)

        let animator = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animator.speed == 2.0)
    }
}

// MARK: - Basic Transition Tests

@Suite("Basic Transition Tests")
struct BasicTransitionTests {

    @Test("Single transition fires when condition met")
    func singleTransition() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("isMoving", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // initialization tick

        // Set parameter
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isMoving", true)
        }
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "walk")
        let animator = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animator.clip.name == "walk")
    }

    @Test("Bidirectional transitions")
    func bidirectional() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("isMoving", true)])
        sm.addTransition(from: "walk", to: "idle", conditions: [.boolEquals("isMoving", false)])

        let entity = makeEntity(world, sm: sm)
        tick(world)

        // Go to walk
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isMoving", true)
        }
        tick(world)
        let walkSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(walkSm.currentStateName == "walk")

        // Go back to idle
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isMoving", false)
        }
        tick(world)
        let idleSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(idleSm.currentStateName == "idle")
    }

    @Test("No matching transition stays in current state")
    func noMatch() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("isMoving", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init
        tick(world)  // no condition met

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
    }

    @Test("Exit time gate prevents early transition")
    func exitTimeGate() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "attack")
        // 4 frames * 0.1s = 0.4s total
        sm.addState("attack", clip: makeClip("attack", frameCount: 4, frameDuration: 0.1))
        sm.addState("idle", clip: makeClip("idle"))
        sm.addTransition(
            from: "attack",
            to: "idle",
            conditions: [.boolEquals("done", true)],
            exitTime: 0.9
        )
        sm.setBool("done", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Progress is 0 — exit time not reached
        tick(world)
        let attackSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(attackSm.currentStateName == "attack")

        // Advance animation to near end (progress ~ 1.0)
        // 4 frames, 0.1s each. At 60fps, each tick is ~0.0167s
        // Need about 24 ticks to get through 0.4s
        tick(world, times: 25)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
    }

    @Test("Empty conditions means immediate transition")
    func emptyConditions() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "a")
        sm.addState("a", clip: makeClip("a"))
        sm.addState("b", clip: makeClip("b"))
        sm.addTransition(from: "a", to: "b", conditions: [])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init + immediate transition

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "b")
    }

    @Test("First matching transition wins")
    func firstMatchWins() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addState("run", clip: makeClip("run"))
        // Both conditions will be true, but walk transition is listed first
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])
        sm.addTransition(from: "idle", to: "run", conditions: [.boolEquals("go", true)])
        sm.setBool("go", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "walk")
    }

    @Test("Previous state name tracked")
    func previousStateTracked() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])
        sm.setBool("go", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.previousStateName == "idle")
        #expect(updatedSm.currentStateName == "walk")
    }
}

// MARK: - Any State Transition Tests

@Suite("Any State Transition Tests")
struct AnyStateTransitionTests {

    @Test("Any-state transition fires from any current state")
    func fromAnyState() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addState("death", clip: makeClip("death"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("isMoving", true)])
        sm.addAnyStateTransition(to: "death", conditions: [.boolEquals("isDead", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Move to walk state
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isMoving", true)
        }
        tick(world)
        let walkSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(walkSm.currentStateName == "walk")

        // Die from walk state
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isDead", true)
        }
        tick(world)
        let deathSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(deathSm.currentStateName == "death")
    }

    @Test("Any-state has priority over per-state transitions")
    func anyStatePriority() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addState("death", clip: makeClip("death"))
        // Both should match, but any-state is checked first
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])
        sm.addAnyStateTransition(to: "death", conditions: [.boolEquals("go", true)])
        sm.setBool("go", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "death")
    }

    @Test("Any-state skips self-transition")
    func anyStateSkipsSelf() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        // Any-state to idle would be self-transition — should be skipped
        sm.addAnyStateTransition(to: "idle", conditions: [.boolEquals("reset", true)])
        sm.setBool("reset", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init
        tick(world)  // should NOT self-transition

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
        #expect(updatedSm.previousStateName == nil)  // no transition occurred
    }

    @Test("Multiple any-state transitions, first wins")
    func multipleAnyStateFirstWins() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("hurt", clip: makeClip("hurt"))
        sm.addState("death", clip: makeClip("death"))
        sm.addAnyStateTransition(to: "hurt", conditions: [.boolEquals("hit", true)])
        sm.addAnyStateTransition(to: "death", conditions: [.boolEquals("hit", true)])
        sm.setBool("hit", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "hurt")
    }

    @Test("Any-state transition from non-idle state")
    func anyStateFromNonIdle() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "walk")
        sm.addState("walk", clip: makeClip("walk"))
        sm.addState("death", clip: makeClip("death"))
        sm.addAnyStateTransition(to: "death", conditions: [.boolEquals("isDead", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isDead", true)
        }
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "death")
    }
}

// MARK: - Parameter-Driven Transition Tests

@Suite("Parameter-Driven Transition Tests")
struct ParameterTransitionTests {

    @Test("Bool parameter drives transition")
    func boolDriven() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("isMoving", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)

        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isMoving", true)
        }
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "walk")
    }

    @Test("Float greater drives transition")
    func floatGreater() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("run", clip: makeClip("run"))
        sm.addTransition(from: "idle", to: "run", conditions: [.floatGreater("speed", 5.0)])

        let entity = makeEntity(world, sm: sm)
        tick(world)

        // Speed 3.0 — not enough
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setFloat("speed", 3.0)
        }
        tick(world)
        let idleSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(idleSm.currentStateName == "idle")

        // Speed 6.0 — fires
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setFloat("speed", 6.0)
        }
        tick(world)
        let runSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(runSm.currentStateName == "run")
    }

    @Test("Float less drives transition")
    func floatLess() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "run")
        sm.addState("run", clip: makeClip("run"))
        sm.addState("idle", clip: makeClip("idle"))
        sm.addTransition(from: "run", to: "idle", conditions: [.floatLess("speed", 0.1)])
        sm.setFloat("speed", 5.0)

        let entity = makeEntity(world, sm: sm)
        tick(world)

        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setFloat("speed", 0.05)
        }
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
    }

    @Test("Int parameter drives transition")
    func intDriven() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "neutral")
        sm.addState("neutral", clip: makeClip("neutral"))
        sm.addState("happy", clip: makeClip("happy"))
        sm.addTransition(from: "neutral", to: "happy", conditions: [.intEquals("mood", 1)])

        let entity = makeEntity(world, sm: sm)
        tick(world)

        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setInt("mood", 1)
        }
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "happy")
    }

    @Test("Trigger consumed after transition")
    func triggerConsumed() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("attack", clip: makeClip("attack"))
        sm.addTransition(from: "idle", to: "attack", conditions: [.trigger("attack")])
        sm.addTransition(from: "attack", to: "idle", conditions: [.boolEquals("done", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Set trigger
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setTrigger("attack")
        }
        tick(world)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "attack")
        #expect(updatedSm.isTriggerSet("attack") == false)  // consumed
    }

    @Test("Multiple conditions AND logic")
    func multipleConditionsAND() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("sprint", clip: makeClip("sprint"))
        sm.addTransition(from: "idle", to: "sprint", conditions: [
            .boolEquals("isMoving", true),
            .floatGreater("speed", 5.0)
        ])

        let entity = makeEntity(world, sm: sm)
        tick(world)

        // Only one condition met
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("isMoving", true)
            sm.setFloat("speed", 3.0)
        }
        tick(world)
        let idleSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(idleSm.currentStateName == "idle")

        // Both conditions met
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setFloat("speed", 6.0)
        }
        tick(world)
        let sprintSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(sprintSm.currentStateName == "sprint")
    }

    @Test("OR logic via multiple transitions")
    func orLogicMultipleTransitions() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("alert", clip: makeClip("alert"))
        // Two transitions to same destination with different conditions = OR
        sm.addTransition(from: "idle", to: "alert", conditions: [.boolEquals("enemyNear", true)])
        sm.addTransition(from: "idle", to: "alert", conditions: [.boolEquals("alarmOn", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)

        // Second condition fires (OR)
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("alarmOn", true)
        }
        tick(world)
        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "alert")
    }

    @Test("Trigger not consumed when other condition fails")
    func triggerPreservedOnFailure() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("special", clip: makeClip("special"))
        sm.addTransition(from: "idle", to: "special", conditions: [
            .trigger("activate"),
            .boolEquals("ready", true)
        ])

        let entity = makeEntity(world, sm: sm)
        tick(world)

        // Set trigger but not ready
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setTrigger("activate")
        }
        tick(world)

        // Trigger should be preserved (other condition failed)
        let smAfter = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(smAfter.currentStateName == "idle")
        #expect(smAfter.isTriggerSet("activate") == true)  // NOT consumed

        // Now set ready — trigger + ready should fire
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("ready", true)
        }
        tick(world)
        let specialSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(specialSm.currentStateName == "special")
    }
}

// MARK: - Animation Event Transition Tests

@Suite("Animation Event Transition Tests")
struct AnimationEventTransitionTests {

    @Test("Animation finished triggers transition")
    func animationFinished() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "attack")
        // oneShot clip: 4 frames * 0.1s = 0.4s
        sm.addState("attack", clip: makeClip("attack", frameCount: 4, frameDuration: 0.1, mode: .oneShot))
        sm.addState("idle", clip: makeClip("idle"))
        sm.addTransition(from: "attack", to: "idle", conditions: [.animationFinished])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Advance past the full animation (0.4s at 60fps = 24 ticks)
        tick(world, times: 30)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
    }

    @Test("Animation looped triggers transition")
    func animationLooped() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "patrol")
        // Forward clip: 4 frames * 0.1s = 0.4s per loop
        sm.addState("patrol", clip: makeClip("patrol", frameCount: 4, frameDuration: 0.1))
        sm.addState("idle", clip: makeClip("idle"))
        sm.addTransition(from: "patrol", to: "idle", conditions: [
            .animationLooped,
            .boolEquals("shouldStop", true)
        ])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Set shouldStop but animation hasn't looped yet
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("shouldStop", true)
        }

        // Advance past one full loop (0.4s)
        tick(world, times: 30)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
    }

    @Test("After time triggers transition")
    func afterTime() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("bored", clip: makeClip("bored"))
        sm.addTransition(from: "idle", to: "bored", conditions: [.afterTime(0.5)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Not enough time
        tick(world, times: 10)  // ~0.167s
        let idleSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(idleSm.currentStateName == "idle")

        // Enough time (total ~0.5s at 60fps = 30 ticks)
        tick(world, times: 25)
        let boredSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(boredSm.currentStateName == "bored")
    }

    @Test("Combined animation event and parameter")
    func combinedEventAndParam() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "attack")
        sm.addState("attack", clip: makeClip("attack", frameCount: 4, frameDuration: 0.1, mode: .oneShot))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addState("idle", clip: makeClip("idle"))
        // Go to walk if moving when attack finishes, else idle
        sm.addTransition(from: "attack", to: "walk", conditions: [
            .animationFinished,
            .boolEquals("isMoving", true)
        ])
        sm.addTransition(from: "attack", to: "idle", conditions: [.animationFinished])
        sm.setBool("isMoving", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Play through attack animation
        tick(world, times: 30)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "walk")
    }

    @Test("After time resets on state change")
    func afterTimeResetsOnStateChange() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "a")
        sm.addState("a", clip: makeClip("a"))
        sm.addState("b", clip: makeClip("b"))
        sm.addState("c", clip: makeClip("c"))
        sm.addTransition(from: "a", to: "b", conditions: [.trigger("go")])
        sm.addTransition(from: "b", to: "c", conditions: [.afterTime(0.3)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Spend some time in state a
        tick(world, times: 30)  // ~0.5s

        // Transition to b
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setTrigger("go")
        }
        tick(world)
        let bSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(bSm.currentStateName == "b")

        // timeInState should be reset — need 0.3s more
        tick(world, times: 10)  // ~0.167s — not enough
        let stillBSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(stillBSm.currentStateName == "b")

        tick(world, times: 15)  // total ~0.42s — enough
        let cSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(cSm.currentStateName == "c")
    }
}

// MARK: - Self Transition Tests

@Suite("Self Transition Tests")
struct SelfTransitionTests {

    @Test("Per-state self-transition restarts clip")
    func selfTransitionRestartsClip() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "attack")
        sm.addState("attack", clip: makeClip("attack", frameCount: 4, frameDuration: 0.1, mode: .oneShot))
        sm.addTransition(from: "attack", to: "attack", conditions: [.trigger("attackAgain")])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        // Advance a few frames
        tick(world, times: 10)
        let animBefore = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animBefore.currentFrameIndex > 0)

        // Trigger self-transition
        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setTrigger("attackAgain")
        }
        tick(world)

        // Animation should restart (forceSetClip resets to frame 0)
        let animAfter = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animAfter.currentFrameIndex == 0)
        #expect(animAfter.isPlaying == true)
    }

    @Test("Trigger-driven self-transition fires once")
    func triggerSelfTransitionOnce() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addTransition(from: "idle", to: "idle", conditions: [.trigger("reset")])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setTrigger("reset")
        }
        tick(world)  // trigger consumed

        // Trigger consumed — should not self-transition again
        let smAfter = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(smAfter.isTriggerSet("reset") == false)
    }

    @Test("Self-transition updates previousStateName")
    func selfTransitionPreviousState() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "attack")
        sm.addState("attack", clip: makeClip("attack"))
        sm.addTransition(from: "attack", to: "attack", conditions: [.trigger("again")])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setTrigger("again")
        }
        tick(world)

        let smAfter = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(smAfter.currentStateName == "attack")
        #expect(smAfter.previousStateName == "attack")
    }
}

// MARK: - Events & Callbacks Tests

@Suite("Events & Callbacks Tests")
struct EventsAndCallbacksTests {

    @Test("AnimationStateChanged event emitted")
    func eventEmitted() {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])
        sm.setBool("go", true)

        let tracker = ValueTracker<String>("")
        world.on(AnimationStateChanged.self) { event in
            tracker.value = "\(event.from)->\(event.to)"
        }

        _ = makeEntity(world, sm: sm)
        tick(world)

        #expect(tracker.value == "idle->walk")
    }

    @Test("onStateChanged callback fires")
    func callbackFires() {
        let (world, smSystem, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])
        sm.setBool("go", true)

        let tracker = CallTracker()
        smSystem.onStateChanged = { _, _, _ in
            tracker.call()
        }

        _ = makeEntity(world, sm: sm)
        tick(world)

        #expect(tracker.called)
    }

    @Test("Correct from and to in callback")
    func correctFromTo() {
        let (world, smSystem, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "a")
        sm.addState("a", clip: makeClip("a"))
        sm.addState("b", clip: makeClip("b"))
        sm.addTransition(from: "a", to: "b", conditions: [.trigger("go")])
        sm.setTrigger("go")

        let fromTracker = ValueTracker<String>("")
        let toTracker = ValueTracker<String>("")
        smSystem.onStateChanged = { _, from, to in
            fromTracker.value = from
            toTracker.value = to
        }

        _ = makeEntity(world, sm: sm)
        tick(world)

        #expect(fromTracker.value == "a")
        #expect(toTracker.value == "b")
    }

    @Test("No event when no transition occurs")
    func noEventWhenNoTransition() {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        // No transitions defined

        let tracker = CallTracker()
        world.on(AnimationStateChanged.self) { _ in
            tracker.call()
        }

        _ = makeEntity(world, sm: sm)
        tick(world, times: 5)

        #expect(tracker.called == false)
    }
}

// MARK: - Serialization Tests

@Suite("Serialization Tests")
struct SerializationTests {

    @Test("Round-trip encode/decode")
    func roundTrip() throws {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addState("walk", clip: makeClip("walk"))
        sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])
        sm.currentStateName = "walk"
        sm.timeInState = 1.5
        sm.previousStateName = "idle"
        sm.needsInitialization = false

        let encoder = JSONEncoder()
        let data = try encoder.encode(sm)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnimationStateMachine.self, from: data)

        #expect(decoded.defaultStateName == "idle")
        #expect(decoded.currentStateName == "walk")
        #expect(decoded.timeInState == 1.5)
        #expect(decoded.previousStateName == "idle")
        #expect(decoded.states.count == 2)
        #expect(decoded.transitions.count == 1)
        #expect(decoded.needsInitialization == false)
    }

    @Test("Parameters preserved after serialization")
    func parametersPreserved() throws {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.setBool("isMoving", true)
        sm.setFloat("speed", 3.14)
        sm.setInt("level", 42)
        sm.setTrigger("fire")
        sm.needsInitialization = false

        let encoder = JSONEncoder()
        let data = try encoder.encode(sm)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnimationStateMachine.self, from: data)

        #expect(decoded.getBool("isMoving") == true)
        #expect(decoded.getFloat("speed") == 3.14)
        #expect(decoded.getInt("level") == 42)
        #expect(decoded.isTriggerSet("fire") == true)
    }

    @Test("needsInitialization is false after decode")
    func needsInitFalseAfterDecode() throws {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        // Even though it was true before encoding
        sm.needsInitialization = true

        let encoder = JSONEncoder()
        let data = try encoder.encode(sm)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnimationStateMachine.self, from: data)

        // needsInitialization is NOT encoded, so decoder sets it to false
        #expect(decoded.needsInitialization == false)
    }

    @Test("Transition conditions survive serialization")
    func conditionsSerialize() throws {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        sm.addTransition(from: "idle", to: "idle", conditions: [
            .boolEquals("a", true),
            .floatGreater("b", 1.0),
            .floatLess("c", 2.0),
            .intEquals("d", 3),
            .trigger("e"),
            .animationFinished,
            .animationLooped,
            .afterTime(0.5)
        ], exitTime: 0.8)

        let encoder = JSONEncoder()
        let data = try encoder.encode(sm)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnimationStateMachine.self, from: data)

        #expect(decoded.transitions[0].conditions.count == 8)
        #expect(decoded.transitions[0].exitTime == 0.8)
        #expect(decoded.transitions[0].conditions[0] == .boolEquals("a", true))
        #expect(decoded.transitions[0].conditions[5] == .animationFinished)
    }
}

// MARK: - Edge Case Tests

@Suite("Animation State Machine Edge Case Tests")
struct AnimStateMachineEdgeCaseTests {

    @Test("No states defined — no crash")
    func noStates() throws {
        let (world, _, _) = makeWorld()
        let sm = AnimationStateMachine(defaultState: "none")

        let entity = world.createEntity()
        world.addComponent(Sprite(texture: TextureHandle(id: 1)), to: entity)
        world.addComponent(SpriteAnimator(clip: makeClip("placeholder")), to: entity)
        world.addComponent(sm, to: entity)

        tick(world, times: 5)
        // Should not crash
        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "none")
    }

    @Test("No transitions defined — stays in state")
    func noTransitions() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))

        let entity = makeEntity(world, sm: sm)
        tick(world, times: 10)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
    }

    @Test("Multiple entities with independent state machines")
    func multipleEntities() throws {
        let (world, _, _) = makeWorld()

        // Entity A: idle -> walk
        var smA = AnimationStateMachine(defaultState: "idle")
        smA.addState("idle", clip: makeClip("idle"))
        smA.addState("walk", clip: makeClip("walk"))
        smA.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])

        // Entity B: stand -> sit
        var smB = AnimationStateMachine(defaultState: "stand")
        smB.addState("stand", clip: makeClip("stand"))
        smB.addState("sit", clip: makeClip("sit"))
        smB.addTransition(from: "stand", to: "sit", conditions: [.boolEquals("tired", true)])

        let entityA = makeEntity(world, sm: smA)
        let entityB = makeEntity(world, sm: smB)
        tick(world)

        // Only trigger A
        world.updateComponent(AnimationStateMachine.self, on: entityA) { sm in
            sm.setBool("go", true)
        }
        tick(world)

        let smAResult = try #require(world.getComponent(AnimationStateMachine.self, from: entityA))
        #expect(smAResult.currentStateName == "walk")
        let smBResult = try #require(world.getComponent(AnimationStateMachine.self, from: entityB))
        #expect(smBResult.currentStateName == "stand")

        // Now trigger B
        world.updateComponent(AnimationStateMachine.self, on: entityB) { sm in
            sm.setBool("tired", true)
        }
        tick(world)

        let smAFinal = try #require(world.getComponent(AnimationStateMachine.self, from: entityA))
        #expect(smAFinal.currentStateName == "walk")
        let smBFinal = try #require(world.getComponent(AnimationStateMachine.self, from: entityB))
        #expect(smBFinal.currentStateName == "sit")
    }

    @Test("Transition to nonexistent state — no crash")
    func transitionToNonexistentState() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))
        // "ghost" state not added
        sm.addTransition(from: "idle", to: "ghost", conditions: [.boolEquals("go", true)])
        sm.setBool("go", true)

        let entity = makeEntity(world, sm: sm)
        tick(world)

        // Transition is blocked because destination state doesn't exist
        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        #expect(updatedSm.currentStateName == "idle")
        // Animator keeps its current clip since transition was rejected
        let animator = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animator.clip.name == "idle")
    }

    @Test("Time in state advances correctly")
    func timeInStateAdvances() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"))

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init (timeInState gets one dt added)

        // Tick 10 more times at 1/60
        tick(world, times: 10)

        let updatedSm = try #require(world.getComponent(AnimationStateMachine.self, from: entity))
        // 11 ticks total * 1/60 ~ 0.183s
        #expect(updatedSm.timeInState > 0.15)
        #expect(updatedSm.timeInState < 0.25)
    }
}

// MARK: - Current State Accessor Tests

@Suite("Current State Accessor Tests")
struct CurrentStateAccessorTests {

    @Test("currentState returns correct state")
    func currentStateReturns() {
        var sm = AnimationStateMachine(defaultState: "idle")
        sm.addState("idle", clip: makeClip("idle"), speed: 1.5)
        #expect(sm.currentState?.name == "idle")
        #expect(sm.currentState?.speed == 1.5)
    }

    @Test("currentState returns nil for missing state")
    func currentStateNil() {
        let sm = AnimationStateMachine(defaultState: "ghost")
        #expect(sm.currentState == nil)
    }
}

// MARK: - Discardable Result Tests

@Suite("Discardable Result Tests")
struct DiscardableResultTests {

    @Test("addState returns self for discardable result")
    func addStateDiscardable() {
        var sm = AnimationStateMachine(defaultState: "idle")
        _ = sm.addState("idle", clip: makeClip("idle"))
        _ = sm.addState("walk", clip: makeClip("walk"))
        _ = sm.addTransition(from: "idle", to: "walk", conditions: [.boolEquals("go", true)])
        _ = sm.addAnyStateTransition(to: "walk", conditions: [.trigger("sprint")])

        #expect(sm.states.count == 2)
        #expect(sm.transitions.count == 1)
        #expect(sm.anyStateTransitions.count == 1)
    }
}

// MARK: - Speed Override Tests

@Suite("Speed Override Tests")
struct SpeedOverrideTests {

    @Test("Transition applies speed from destination state")
    func transitionAppliesSpeed() throws {
        let (world, _, _) = makeWorld()
        var sm = AnimationStateMachine(defaultState: "walk")
        sm.addState("walk", clip: makeClip("walk"), speed: 1.0)
        sm.addState("run", clip: makeClip("run"), speed: 2.0)
        sm.addTransition(from: "walk", to: "run", conditions: [.boolEquals("fast", true)])

        let entity = makeEntity(world, sm: sm)
        tick(world)  // init

        world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
            sm.setBool("fast", true)
        }
        tick(world)

        let animator = try #require(world.getComponent(SpriteAnimator.self, from: entity))
        #expect(animator.speed == 2.0)
    }
}
