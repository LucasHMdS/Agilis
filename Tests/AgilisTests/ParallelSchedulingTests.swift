import Testing
@testable import Agilis
import AgilisCore

// MARK: - Test Components (unique to this file to avoid collisions)

private struct PosA: Component { var x: Float = 0 }
private struct VelA: Component { var dx: Float = 0 }
private struct SpriteData: Component { var frame: Int = 0 }
private struct ParticleData: Component { var count: Int = 0 }
private struct LightData: Component { var intensity: Float = 0 }

// MARK: - Test Systems

private final class SystemA: System, @unchecked Sendable {
    var priority: Int { 10 }
    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [], writes: [PosA.self])
    }
    var updateCount = 0
    func update(context: SystemContext) { updateCount += 1 }
}

private final class SystemB: System, @unchecked Sendable {
    var priority: Int { 20 }
    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [], writes: [VelA.self])
    }
    var updateCount = 0
    func update(context: SystemContext) { updateCount += 1 }
}

private final class SystemC: System, @unchecked Sendable {
    var priority: Int { 30 }
    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [PosA.self], writes: [SpriteData.self])
    }
    var updateCount = 0
    func update(context: SystemContext) { updateCount += 1 }
}

private final class ReadOnlySystem: System, @unchecked Sendable {
    var priority: Int { 40 }
    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [PosA.self, VelA.self])
    }
    var updateCount = 0
    func update(context: SystemContext) { updateCount += 1 }
}

private final class EntityMutatingSystem: System, @unchecked Sendable {
    var priority: Int { 50 }
    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [], writes: [], mutatesEntities: true)
    }
    var updateCount = 0
    func update(context: SystemContext) { updateCount += 1 }
}

private final class EventEmittingSystem: System, @unchecked Sendable {
    var priority: Int { 60 }
    var componentAccess: ComponentAccess {
        ComponentAccess(reads: [], writes: [LightData.self], emitsEvents: true)
    }
    var updateCount = 0
    func update(context: SystemContext) { updateCount += 1 }
}

private final class DefaultAccessSystem: System, @unchecked Sendable {
    var priority: Int { 70 }
    // Uses default componentAccess (maximally conservative)
    var updateCount = 0
    func update(context: SystemContext) { updateCount += 1 }
}

// MARK: - ComponentAccess Tests

@Suite("ComponentAccess Tests")
struct ComponentAccessTests {

    @Test func defaultAccessIsConservative() {
        let access = ComponentAccess()
        #expect(access.reads.isEmpty)
        #expect(access.writes.isEmpty)
        #expect(access.mutatesEntities == false)
        #expect(access.emitsEvents == false)
    }

    @Test func systemDefaultAccessIsMaximallyConservative() {
        let system = DefaultAccessSystem()
        let access = system.componentAccess
        #expect(access.mutatesEntities == true)
        #expect(access.emitsEvents == true)
    }

    @Test func customAccessPreservesTypes() {
        let access = ComponentAccess(
            reads: [PosA.self, VelA.self],
            writes: [SpriteData.self],
            mutatesEntities: false,
            emitsEvents: true
        )
        #expect(access.reads.count == 2)
        #expect(access.writes.count == 1)
        #expect(access.mutatesEntities == false)
        #expect(access.emitsEvents == true)
    }
}

// MARK: - ComponentBitset Tests

@Suite("ComponentBitset Tests")
struct ComponentBitsetTests {

    @Test func emptyBitset() {
        let bits = ComponentBitset()
        #expect(bits.isEmpty)
        #expect(bits.count == 0)
    }

    @Test func setBit() {
        var bits = ComponentBitset()
        bits.set(0)
        #expect(!bits.isEmpty)
        #expect(bits.test(0))
        #expect(!bits.test(1))
        #expect(bits.count == 1)
    }

    @Test func setBitsAcrossWords() {
        var bits = ComponentBitset()
        bits.set(0)    // word 0
        bits.set(63)   // word 0 high bit
        bits.set(64)   // word 1
        bits.set(128)  // word 2
        bits.set(192)  // word 3
        #expect(bits.count == 5)
        #expect(bits.test(0))
        #expect(bits.test(63))
        #expect(bits.test(64))
        #expect(bits.test(128))
        #expect(bits.test(192))
        #expect(!bits.test(1))
        #expect(!bits.test(65))
    }

    @Test func outOfRangeIgnored() {
        var bits = ComponentBitset()
        bits.set(256)  // Out of range — ignored
        bits.set(-1)   // Negative — ignored
        #expect(bits.isEmpty)
        #expect(!bits.test(256))
        #expect(!bits.test(-1))
    }

    @Test func intersectsOverlapping() {
        var a = ComponentBitset()
        var b = ComponentBitset()
        a.set(5)
        a.set(10)
        b.set(10)
        b.set(20)
        #expect(a.intersects(b))
        #expect(b.intersects(a))
    }

    @Test func doesNotIntersectDisjoint() {
        var a = ComponentBitset()
        var b = ComponentBitset()
        a.set(0)
        a.set(1)
        b.set(2)
        b.set(3)
        #expect(!a.intersects(b))
        #expect(!b.intersects(a))
    }

    @Test func intersectsAcrossWords() {
        var a = ComponentBitset()
        var b = ComponentBitset()
        a.set(130)   // word 2
        b.set(130)   // same bit
        #expect(a.intersects(b))
    }

    @Test func equality() {
        var a = ComponentBitset()
        var b = ComponentBitset()
        a.set(5)
        a.set(100)
        b.set(5)
        b.set(100)
        #expect(a == b)
    }

    @Test func maxBitIndex() {
        var bits = ComponentBitset()
        bits.set(255)
        #expect(bits.test(255))
        #expect(bits.count == 1)
    }
}

// MARK: - ComponentRegistry Tests

@Suite("ComponentRegistry Tests")
struct ComponentRegistryTests {

    @Test func assignsStableIndices() {
        let registry = ComponentRegistry.shared
        let idx1 = registry.index(for: PosA.self)
        let idx2 = registry.index(for: VelA.self)
        let idx1Again = registry.index(for: PosA.self)
        #expect(idx1 != idx2)
        #expect(idx1 == idx1Again)
    }

    @Test func bitsetFromTypes() {
        let registry = ComponentRegistry.shared
        let bits = registry.bitset(for: [PosA.self, VelA.self])
        let posIdx = registry.index(for: PosA.self)
        let velIdx = registry.index(for: VelA.self)
        #expect(bits.test(posIdx))
        #expect(bits.test(velIdx))
        #expect(bits.count == 2)
    }
}

// MARK: - SystemScheduler Tests

@Suite("SystemScheduler Tests")
struct SystemSchedulerTests {

    @Test func emptySystemList() {
        let scheduler = SystemScheduler()
        let plan = scheduler.buildExecutionPlan(systems: [])
        #expect(plan.isEmpty)
    }

    @Test func singleSystemInOwnStage() {
        let scheduler = SystemScheduler()
        let system = SystemA()
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: system, priority: 10)
        ])
        #expect(plan.count == 1)
        #expect(plan[0].count == 1)
    }

    @Test func disjointWritesGroupTogether() {
        let scheduler = SystemScheduler()
        let a = SystemA()  // writes PosA
        let b = SystemB()  // writes VelA
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: a, priority: 10),
            SystemEntry(system: b, priority: 20),
        ])
        // Disjoint writes → should be in same stage
        #expect(plan.count == 1)
        #expect(plan[0].count == 2)
    }

    @Test func writeReadConflictSeparatesStages() {
        let scheduler = SystemScheduler()
        let a = SystemA()  // writes PosA
        let c = SystemC()  // reads PosA, writes SpriteData
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: a, priority: 10),
            SystemEntry(system: c, priority: 30),
        ])
        // C reads PosA which A writes → different stages
        #expect(plan.count == 2)
    }

    @Test func entityMutatingSystemAlwaysAlone() {
        let scheduler = SystemScheduler()
        let a = SystemA()
        let m = EntityMutatingSystem()
        let b = SystemB()
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: a, priority: 10),
            SystemEntry(system: m, priority: 50),
            SystemEntry(system: b, priority: 60),
        ])
        // a alone (or grouped), m alone, b alone (or grouped)
        #expect(plan.count == 3)
        // m must be alone
        let mutatingStage = plan[1]
        #expect(mutatingStage.count == 1)
    }

    @Test func eventEmittingSystemAlwaysAlone() {
        let scheduler = SystemScheduler()
        let b = SystemB()
        let e = EventEmittingSystem()
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: b, priority: 20),
            SystemEntry(system: e, priority: 60),
        ])
        #expect(plan.count == 2)
    }

    @Test func defaultAccessSystemAlwaysAlone() {
        let scheduler = SystemScheduler()
        let a = SystemA()
        let d = DefaultAccessSystem()
        let b = SystemB()
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: a, priority: 10),
            SystemEntry(system: d, priority: 70),
            SystemEntry(system: b, priority: 80),
        ])
        // Default system is serial (mutatesEntities + emitsEvents), must be alone
        #expect(plan.count == 3)
    }

    @Test func readOnlySystemsCanParallelize() {
        let scheduler = SystemScheduler()
        let a = SystemA()           // writes PosA
        let r = ReadOnlySystem()    // reads PosA, VelA
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: a, priority: 10),
            SystemEntry(system: r, priority: 40),
        ])
        // r reads PosA which a writes → separate stages
        #expect(plan.count == 2)
    }

    @Test func multipleReadOnlySystemsParallelize() {
        let scheduler = SystemScheduler()
        let r1 = ReadOnlySystem()  // reads PosA, VelA
        let r2 = ReadOnlySystem()  // reads PosA, VelA
        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: r1, priority: 40),
            SystemEntry(system: r2, priority: 41),
        ])
        // Both read-only with no writes → same stage
        #expect(plan.count == 1)
        #expect(plan[0].count == 2)
    }
}

// MARK: - Read-Only Query Tests

@Suite("ReadOnly Query Tests")
struct ReadOnlyQueryTests {

    @Test func forEachReadOnlyOneComponent() {
        let world = World()
        let e1 = world.createEntity()
        let e2 = world.createEntity()
        world.addComponent(PosA(x: 1), to: e1)
        world.addComponent(PosA(x: 2), to: e2)

        var sum: Float = 0
        world.forEachReadOnly { (_: Entity, pos: PosA) in
            sum += pos.x
        }
        #expect(sum == 3)
    }

    @Test func forEachReadOnlyTwoComponents() {
        let world = World()
        let e1 = world.createEntity()
        world.addComponent(PosA(x: 5), to: e1)
        world.addComponent(VelA(dx: 3), to: e1)

        var posX: Float = 0
        var velDx: Float = 0
        world.forEachReadOnly { (_: Entity, pos: PosA, vel: VelA) in
            posX = pos.x
            velDx = vel.dx
        }
        #expect(posX == 5)
        #expect(velDx == 3)
    }

    @Test func forEachReadOnlyMatchesMutableForEach() {
        let world = World()
        for i in 0..<10 {
            let e = world.createEntity()
            world.addComponent(PosA(x: Float(i)), to: e)
        }

        var mutableEntities: [Entity] = []
        world.forEach { (entity: Entity, _: inout PosA) in
            mutableEntities.append(entity)
        }

        var readOnlyEntities: [Entity] = []
        world.forEachReadOnly { (entity: Entity, _: PosA) in
            readOnlyEntities.append(entity)
        }

        #expect(mutableEntities == readOnlyEntities)
    }
}

// MARK: - Parallel Update Tests

@Suite("Parallel World Update Tests")
struct ParallelWorldUpdateTests {

    @Test func parallelUpdateRunsAllSystems() async {
        let world = World()
        let a = SystemA()
        let b = SystemB()
        world.addSystem(a)
        world.addSystem(b)
        world.parallelSchedulingEnabled = true

        await world.updateParallel(deltaTime: 1.0 / 60.0)

        #expect(a.updateCount == 1)
        #expect(b.updateCount == 1)
    }

    @Test func parallelUpdateProducesSameResultAsSequential() async {
        // Create two identical worlds
        let worldSeq = World()
        let worldPar = World()

        for world in [worldSeq, worldPar] {
            let e = world.createEntity()
            world.addComponent(PosA(x: 0), to: e)
            world.addComponent(VelA(dx: 10), to: e)
        }

        // A system that moves position by velocity
        final class MoveSystem: System, @unchecked Sendable {
            var priority: Int { 10 }
            var componentAccess: ComponentAccess {
                ComponentAccess(writes: [PosA.self, VelA.self])
            }
            func update(context: SystemContext) {
                context.world.forEach { (_: Entity, pos: inout PosA, vel: inout VelA) in
                    pos.x += vel.dx * Float(context.deltaTime)
                }
            }
        }

        worldSeq.addSystem(MoveSystem())
        worldPar.addSystem(MoveSystem())
        worldPar.parallelSchedulingEnabled = true

        // Run multiple ticks
        for _ in 0..<10 {
            worldSeq.update(deltaTime: 1.0 / 60.0)
            await worldPar.updateParallel(deltaTime: 1.0 / 60.0)
        }

        // Compare results
        var seqX: Float = 0
        var parX: Float = 0
        worldSeq.forEachReadOnly { (_: Entity, pos: PosA) in seqX = pos.x }
        worldPar.forEachReadOnly { (_: Entity, pos: PosA) in parX = pos.x }

        #expect(seqX == parX)
    }

    @Test func parallelUpdateWithDisjointSystems() async {
        let world = World()
        let e = world.createEntity()
        world.addComponent(PosA(x: 0), to: e)
        world.addComponent(ParticleData(count: 0), to: e)

        // Two systems writing to completely different components
        final class PosSystem: System, @unchecked Sendable {
            var priority: Int { 10 }
            var componentAccess: ComponentAccess {
                ComponentAccess(writes: [PosA.self])
            }
            func update(context: SystemContext) {
                context.world.forEach { (_: Entity, pos: inout PosA) in
                    pos.x += 1
                }
            }
        }

        final class ParticleCountSystem: System, @unchecked Sendable {
            var priority: Int { 20 }
            var componentAccess: ComponentAccess {
                ComponentAccess(writes: [ParticleData.self])
            }
            func update(context: SystemContext) {
                context.world.forEach { (_: Entity, p: inout ParticleData) in
                    p.count += 1
                }
            }
        }

        world.addSystem(PosSystem())
        world.addSystem(ParticleCountSystem())
        world.parallelSchedulingEnabled = true

        await world.updateParallel(deltaTime: 1.0 / 60.0)

        var posX: Float = 0
        var particleCount: Int = 0
        world.forEachReadOnly { (_: Entity, pos: PosA) in posX = pos.x }
        world.forEachReadOnly { (_: Entity, p: ParticleData) in particleCount = p.count }

        #expect(posX == 1)
        #expect(particleCount == 1)
    }
}

// MARK: - Built-in System ComponentAccess Tests

@Suite("Built-in System ComponentAccess Tests")
struct BuiltinSystemAccessTests {

    @Test func animationSystemAccess() {
        let system = AnimationSystem()
        let access = system.componentAccess
        #expect(!access.mutatesEntities)
        #expect(!access.emitsEvents)
        #expect(access.writes.count == 2) // SpriteAnimator, Sprite
    }

    @Test func animationStateMachineSystemAccess() {
        let system = AnimationStateMachineSystem()
        let access = system.componentAccess
        #expect(!access.mutatesEntities)
        #expect(access.emitsEvents)
        #expect(access.reads.count == 1)  // SpriteAnimator
        #expect(access.writes.count == 2) // AnimationStateMachine, SpriteAnimator
    }

    @Test func particleSystemAccess() {
        let system = ParticleSystem()
        let access = system.componentAccess
        #expect(!access.mutatesEntities)
        #expect(!access.emitsEvents)
        #expect(access.reads.count == 1)  // Transform2D
        #expect(access.writes.count == 1) // ParticleEmitter
    }

    @Test func lightingSystemAccess() {
        let system = LightingSystem()
        let access = system.componentAccess
        #expect(!access.mutatesEntities)
        #expect(!access.emitsEvents)
        #expect(access.reads.count == 5) // Transform2D, Light2D, Collider2D, ShadowCaster2D, Sprite
        #expect(access.writes.isEmpty)
    }

    @Test func physicsSystemAccess() {
        let system = PhysicsWorld2D()
        let access = system.componentAccess
        #expect(!access.mutatesEntities)
        #expect(!access.emitsEvents)
        #expect(access.reads.count == 2)  // RigidBody2D, Collider2D
        #expect(access.writes.count == 3) // Transform2D, PreviousTransform2D, Velocity2D
    }

    @Test func tweenSystemAccess() {
        let system = TweenSystem()
        let access = system.componentAccess
        #expect(!access.mutatesEntities)
        #expect(access.emitsEvents)
        #expect(access.writes.count == 2) // Transform2D, Sprite
    }

    @Test func builtinSystemsParticleAndLightingCanParallelize() {
        let scheduler = SystemScheduler()
        let particle = ParticleSystem()
        let lighting = LightingSystem()

        let plan = scheduler.buildExecutionPlan(systems: [
            SystemEntry(system: particle, priority: particle.priority),
            SystemEntry(system: lighting, priority: lighting.priority),
        ])

        // ParticleSystem writes ParticleEmitter, reads Transform2D
        // LightingSystem reads Transform2D, Light2D, Collider2D, ShadowCaster2D, Sprite
        // LightingSystem has no writes.
        // ParticleSystem writes ParticleEmitter which Lighting doesn't read.
        // But ParticleSystem reads Transform2D and LightingSystem reads Transform2D
        // — both are reads, which is fine (no write-read conflict).
        // Only conflict would be if one writes what the other reads/writes.
        // ParticleSystem writes ParticleEmitter (Lighting doesn't touch it).
        // LightingSystem writes nothing.
        // → They CAN parallelize!
        #expect(plan.count == 1)
        #expect(plan[0].count == 2)
    }
}
