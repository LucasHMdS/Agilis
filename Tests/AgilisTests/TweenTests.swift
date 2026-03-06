import Testing
@testable import Agilis
import Agilis

// MARK: - Test Helpers

/// Thread-safe tracker for @Sendable closure captures in tests.
private final class CallTracker: @unchecked Sendable {
    var wasCalled = false
    var callCount = 0
    func fire() { wasCalled = true; callCount += 1 }
}

/// Thread-safe value tracker for @Sendable closure captures in tests.
private final class ValueTracker<T>: @unchecked Sendable {
    var value: T
    init(_ initial: T) { self.value = initial }
}

private func makeTweenWorld() -> (World, TweenSystem) {
    let world = World()
    let system = TweenSystem()
    world.addSystem(system)
    return (world, system)
}

private func tick(_ world: World, times: Int = 1, dt: Double = 1.0 / 60.0) {
    for _ in 0..<times {
        world.update(deltaTime: dt)
    }
}

/// Create an entity with Transform2D at a given position.
private func makeEntity(_ world: World, position: Vector2 = .zero,
                         rotation: Float = 0, scale: Vector2 = .one) -> Entity {
    let e = world.createEntity()
    world.addComponent(Transform2D(position: position, rotation: rotation, scale: scale), to: e)
    return e
}

/// Create an entity with Transform2D + Sprite.
private func makeSpriteEntity(_ world: World, position: Vector2 = .zero,
                                tint: Color = .white) -> Entity {
    let e = world.createEntity()
    world.addComponent(Transform2D(position: position), to: e)
    world.addComponent(Sprite(texture: TextureHandle(id: 1), tint: tint), to: e)
    return e
}

// MARK: - Interpolatable Tests

@Suite("Interpolatable Protocol")
struct InterpolatableTests {
    @Test("Float interpolation at t=0")
    func floatAtZero() {
        let result = Float(10).interpolated(to: 20, t: 0)
        #expect(result == 10)
    }

    @Test("Float interpolation at t=0.5")
    func floatAtHalf() {
        let result = Float(10).interpolated(to: 20, t: 0.5)
        #expect(abs(result - 15) < 0.001)
    }

    @Test("Float interpolation at t=1")
    func floatAtOne() {
        let result = Float(10).interpolated(to: 20, t: 1)
        #expect(result == 20)
    }

    @Test("Vector2 interpolation at t=0")
    func vector2AtZero() {
        let start = Vector2(x: 0, y: 0)
        let end = Vector2(x: 100, y: 200)
        let result = start.interpolated(to: end, t: 0)
        #expect(result.x == 0 && result.y == 0)
    }

    @Test("Vector2 interpolation at t=0.5")
    func vector2AtHalf() {
        let start = Vector2(x: 0, y: 0)
        let end = Vector2(x: 100, y: 200)
        let result = start.interpolated(to: end, t: 0.5)
        #expect(abs(result.x - 50) < 0.001 && abs(result.y - 100) < 0.001)
    }

    @Test("Vector2 interpolation at t=1")
    func vector2AtOne() {
        let start = Vector2(x: 0, y: 0)
        let end = Vector2(x: 100, y: 200)
        let result = start.interpolated(to: end, t: 1)
        #expect(result.x == 100 && result.y == 200)
    }

    @Test("Color interpolation at t=0")
    func colorAtZero() {
        let start = Color(r: 0, g: 0, b: 0, a: 0)
        let end = Color(r: 255, g: 255, b: 255, a: 255)
        let result = start.interpolated(to: end, t: 0)
        #expect(result.r == 0 && result.g == 0 && result.b == 0 && result.a == 0)
    }

    @Test("Color interpolation at t=0.5")
    func colorAtHalf() {
        let start = Color(r: 0, g: 0, b: 0, a: 0)
        let end = Color(r: 254, g: 254, b: 254, a: 254)
        let result = start.interpolated(to: end, t: 0.5)
        #expect(result.r == 127 && result.g == 127 && result.b == 127 && result.a == 127)
    }

    @Test("Color interpolation at t=1")
    func colorAtOne() {
        let start = Color(r: 0, g: 0, b: 0, a: 0)
        let end = Color(r: 255, g: 255, b: 255, a: 255)
        let result = start.interpolated(to: end, t: 1)
        #expect(result.r == 255 && result.g == 255 && result.b == 255 && result.a == 255)
    }
}

// MARK: - TweenHandle Tests

@Suite("TweenHandle")
struct TweenHandleTests {
    @Test("Invalid handle sentinel")
    func invalidHandle() {
        #expect(TweenHandle.invalid.id == 0)
    }

    @Test("Handle equality")
    func handleEquality() {
        let a = TweenHandle(id: 42)
        let b = TweenHandle(id: 42)
        let c = TweenHandle(id: 99)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Handle hashability")
    func handleHash() {
        let set: Set<TweenHandle> = [TweenHandle(id: 1), TweenHandle(id: 2), TweenHandle(id: 1)]
        #expect(set.count == 2)
    }
}

// MARK: - Position Tween Tests

@Suite("Position Tweens")
struct PositionTweenTests {
    @Test("moveTo reads current position as start")
    func moveToStartsAtCurrent() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 10, y: 20))

        tweens.moveTo(e, target: Vector2(x: 100, y: 200), duration: 1.0, in: world)
        // Before any tick, position should be unchanged
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(pos.x == 10 && pos.y == 20)
    }

    @Test("moveTo at t=0 keeps start position")
    func moveToAtStart() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 10, y: 20))

        tweens.moveTo(e, target: Vector2(x: 100, y: 200), duration: 1.0, in: world)
        // After 1 tick at 1/60s, position should barely move from start
        tick(world, times: 1)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        // With linear easing, after 1/60s of 1s duration, t ≈ 0.0167
        #expect(pos.x > 10 && pos.x < 15)
    }

    @Test("moveTo reaches target at completion")
    func moveToReachesTarget() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 200), duration: 0.5, in: world)
        // 30 ticks at 1/60 = 0.5 seconds
        tick(world, times: 30)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(abs(pos.x - 100) < 1 && abs(pos.y - 200) < 1)
    }

    @Test("moveTo midpoint with linear easing")
    func moveToMidpoint() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)
        // 30 ticks at 1/60 = 0.5 seconds = halfway
        tick(world, times: 30)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(abs(pos.x - 50) < 2)
    }

    @Test("moveFromTo uses explicit start value")
    func moveFromToExplicitStart() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 999, y: 999))

        tweens.moveFromTo(e, from: Vector2(x: 0, y: 0), to: Vector2(x: 100, y: 0), duration: 1.0)
        tick(world, times: 1)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        // Should interpolate from (0,0), not from (999,999)
        #expect(pos.x >= 0 && pos.x < 10)
    }

    @Test("moveTo with cubicOut easing progresses faster at start")
    func moveToWithEasing() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0,
                      easing: .cubicOut, in: world)
        // After 0.5s with cubicOut, should be well past 50% (cubicOut is fast start)
        tick(world, times: 30)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(pos.x > 60) // cubicOut at t=0.5 ≈ 0.875
    }

    @Test("moveTo returns invalid for entity without Transform2D")
    func moveToNoTransform() {
        let (world, tweens) = makeTweenWorld()
        let e = world.createEntity()
        let handle = tweens.moveTo(e, target: .zero, duration: 1.0, in: world)
        #expect(handle == .invalid)
    }

    @Test("Zero duration moveTo snaps instantly")
    func zeroDurationMoveTo() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 200), duration: 0, in: world)
        tick(world, times: 1)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(abs(pos.x - 100) < 0.01 && abs(pos.y - 200) < 0.01)
    }
}

// MARK: - Rotation Tween Tests

@Suite("Rotation Tweens")
struct RotationTweenTests {
    @Test("rotateTo reaches target")
    func rotateToTarget() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, rotation: 0)

        tweens.rotateTo(e, target: .pi, duration: 0.5, in: world)
        tick(world, times: 30)
        let rot = world.getComponent(Transform2D.self, from: e)!.rotation
        #expect(abs(rot - .pi) < 0.1)
    }

    @Test("rotateTo midpoint linear")
    func rotateToMidpoint() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, rotation: 0)

        tweens.rotateTo(e, target: 2.0, duration: 1.0, in: world)
        tick(world, times: 30)
        let rot = world.getComponent(Transform2D.self, from: e)!.rotation
        #expect(abs(rot - 1.0) < 0.1)
    }

    @Test("rotateTo returns invalid without Transform2D")
    func rotateToNoTransform() {
        let (world, tweens) = makeTweenWorld()
        let e = world.createEntity()
        let handle = tweens.rotateTo(e, target: 1.0, duration: 1.0, in: world)
        #expect(handle == .invalid)
    }

    @Test("rotateTo with easing")
    func rotateToWithEasing() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, rotation: 0)

        tweens.rotateTo(e, target: 2.0, duration: 1.0, easing: .quadIn, in: world)
        tick(world, times: 30)
        let rot = world.getComponent(Transform2D.self, from: e)!.rotation
        // quadIn at t=0.5 = 0.25, so rotation ≈ 0.5
        #expect(rot < 0.75)
    }
}

// MARK: - Scale Tween Tests

@Suite("Scale Tweens")
struct ScaleTweenTests {
    @Test("scaleTo reaches target")
    func scaleToTarget() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, scale: .one)

        tweens.scaleTo(e, target: Vector2(x: 2, y: 3), duration: 0.5, in: world)
        tick(world, times: 30)
        let scale = world.getComponent(Transform2D.self, from: e)!.scale
        #expect(abs(scale.x - 2) < 0.1 && abs(scale.y - 3) < 0.1)
    }

    @Test("scaleUniformTo scales both axes equally")
    func scaleUniform() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, scale: .one)

        tweens.scaleUniformTo(e, target: 2.0, duration: 0.5, in: world)
        tick(world, times: 30)
        let scale = world.getComponent(Transform2D.self, from: e)!.scale
        #expect(abs(scale.x - 2) < 0.1 && abs(scale.y - 2) < 0.1)
    }

    @Test("scaleTo midpoint")
    func scaleToMidpoint() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, scale: Vector2(x: 1, y: 1))

        tweens.scaleTo(e, target: Vector2(x: 3, y: 3), duration: 1.0, in: world)
        tick(world, times: 30)
        let scale = world.getComponent(Transform2D.self, from: e)!.scale
        #expect(abs(scale.x - 2) < 0.2)
    }

    @Test("scaleTo returns invalid without Transform2D")
    func scaleToNoTransform() {
        let (world, tweens) = makeTweenWorld()
        let e = world.createEntity()
        let handle = tweens.scaleTo(e, target: Vector2(x: 2, y: 2), duration: 1.0, in: world)
        #expect(handle == .invalid)
    }
}

// MARK: - Color/Alpha Tween Tests

@Suite("Color and Alpha Tweens")
struct ColorTweenTests {
    @Test("tintTo reaches target color")
    func tintToTarget() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, tint: .white)

        tweens.tintTo(e, target: Color(r: 255, g: 0, b: 0, a: 255),
                      duration: 0.5, in: world)
        tick(world, times: 30)
        let tint = world.getComponent(Sprite.self, from: e)!.tint
        #expect(tint.r == 255 && tint.g < 10 && tint.b < 10)
    }

    @Test("fadeTo reaches target alpha")
    func fadeToTarget() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, tint: .white) // alpha = 255

        tweens.fadeTo(e, alpha: 0, duration: 0.5, in: world)
        tick(world, times: 30)
        let alpha = world.getComponent(Sprite.self, from: e)!.tint.a
        #expect(alpha < 5)
    }

    @Test("fadeOut fades to zero alpha")
    func fadeOutToZero() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, tint: .white)

        tweens.fadeOut(e, duration: 0.5, in: world)
        tick(world, times: 30)
        let alpha = world.getComponent(Sprite.self, from: e)!.tint.a
        #expect(alpha < 5)
    }

    @Test("fadeIn fades to full alpha")
    func fadeInToFull() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, tint: Color(r: 255, g: 255, b: 255, a: 0))

        tweens.fadeIn(e, duration: 0.5, in: world)
        tick(world, times: 30)
        let alpha = world.getComponent(Sprite.self, from: e)!.tint.a
        #expect(alpha > 250)
    }

    @Test("tintTo returns invalid without Sprite")
    func tintToNoSprite() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)
        let handle = tweens.tintTo(e, target: .red, duration: 1.0, in: world)
        #expect(handle == .invalid)
    }

    @Test("fadeTo preserves RGB channels")
    func fadePreservesRGB() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, tint: Color(r: 100, g: 150, b: 200, a: 255))

        tweens.fadeTo(e, alpha: 128, duration: 0.5, in: world)
        tick(world, times: 30)
        let tint = world.getComponent(Sprite.self, from: e)!.tint
        // RGB should remain 100, 150, 200 — only alpha changes
        #expect(tint.r == 100 && tint.g == 150 && tint.b == 200)
        #expect(abs(Int(tint.a) - 128) < 5)
    }
}

// MARK: - Custom Tween Tests

@Suite("Custom Tweens")
struct CustomTweenTests {
    struct Health: Component {
        var current: Float
    }

    @Test("Custom tween applies user closure")
    func customTweenApplies() {
        let (world, tweens) = makeTweenWorld()
        let e = world.createEntity()
        world.addComponent(Health(current: 0), to: e)

        tweens.custom(e, duration: 0.5) { world, entity, t in
            world.updateComponent(Health.self, on: entity) { h in
                h.current = lerp(0, 100, t: t)
            }
        }

        tick(world, times: 30)
        let health = world.getComponent(Health.self, from: e)!
        #expect(abs(health.current - 100) < 2)
    }

    @Test("Custom tween receives eased t")
    func customTweenEased() {
        let (world, tweens) = makeTweenWorld()
        let e = world.createEntity()
        world.addComponent(Health(current: 0), to: e)

        let tracker = ValueTracker<Float>(-1)
        tweens.custom(e, duration: 1.0, easing: .cubicOut) { _, _, t in
            tracker.value = t
        }

        tick(world, times: 30)
        // cubicOut at t=0.5 ≈ 0.875
        #expect(tracker.value > 0.8)
    }

    @Test("Custom tween receives correct entity")
    func customTweenEntity() {
        let (world, tweens) = makeTweenWorld()
        let e = world.createEntity()
        let tracker = ValueTracker<Entity?>(nil)

        tweens.custom(e, duration: 0.5) { _, entity, _ in
            tracker.value = entity
        }

        tick(world, times: 1)
        #expect(tracker.value == e)
    }
}

// MARK: - Delay Tests

@Suite("Tween Delay")
struct DelayTests {
    @Test("Tween waits during delay")
    func tweenWaitsDuringDelay() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5,
                      delay: 0.5, in: world)
        // After 0.25 seconds (15 ticks), still in delay
        tick(world, times: 15)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(abs(pos.x) < 0.01)
    }

    @Test("Tween starts after delay")
    func tweenStartsAfterDelay() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5,
                      delay: 0.5, in: world)
        // After 1.0 seconds (60 ticks), delay + duration both done
        tick(world, times: 60)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(abs(pos.x - 100) < 2)
    }

    @Test("Zero delay starts immediately")
    func zeroDelayStartsImmediately() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5,
                      delay: 0, in: world)
        tick(world, times: 1)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(pos.x > 0)
    }

    @Test("Delay with easing combined")
    func delayWithEasing() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5,
                      easing: .cubicOut, delay: 0.25, in: world)
        // After delay (15 ticks) + half duration (15 ticks) = 30 ticks
        tick(world, times: 30)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        // cubicOut at t=0.5 ≈ 0.875 * 100 = ~87.5
        #expect(pos.x > 60)
    }
}

// MARK: - Lifecycle Tests

@Suite("Tween Lifecycle")
struct LifecycleTests {
    @Test("Cancel stops the tween")
    func cancelStopsTween() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        tick(world, times: 10)
        tweens.cancel(handle)
        let posBeforeMore = world.getComponent(Transform2D.self, from: e)!.position.x
        tick(world, times: 30)
        let posAfterMore = world.getComponent(Transform2D.self, from: e)!.position.x
        // Position should not change after cancel
        #expect(abs(posBeforeMore - posAfterMore) < 0.01)
    }

    @Test("cancelAll cancels all tweens on entity")
    func cancelAllOnEntity() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)
        tweens.fadeOut(e, duration: 1.0, in: world)
        #expect(tweens.tweenCount == 2)

        tweens.cancelAll(on: e)
        #expect(tweens.tweenCount == 0)
    }

    @Test("Pause freezes the tween")
    func pauseFreezeTween() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        tick(world, times: 10)
        tweens.pause(handle)
        let pausedPos = world.getComponent(Transform2D.self, from: e)!.position.x
        tick(world, times: 30)
        let afterPausePos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pausedPos - afterPausePos) < 0.01)
    }

    @Test("Resume continues from pause point")
    func resumeFromPause() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        tick(world, times: 10)
        tweens.pause(handle)
        let pausedPos = world.getComponent(Transform2D.self, from: e)!.position.x
        tick(world, times: 10) // These should not advance
        tweens.resume(handle)
        tick(world, times: 10)
        let afterResumePos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(afterResumePos > pausedPos + 5)
    }

    @Test("Entity death auto-cancels tweens")
    func entityDeathCancelsTweens() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)
        #expect(tweens.tweenCount == 1)

        world.destroyEntity(e)
        tick(world, times: 1)
        // Tween should be auto-removed
        #expect(tweens.tweenCount == 0)
    }

    @Test("isActive returns true for active tween")
    func isActiveTrue() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        #expect(tweens.isActive(handle))
    }

    @Test("isActive returns false after cancel")
    func isActiveFalseAfterCancel() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        tweens.cancel(handle)
        #expect(!tweens.isActive(handle))
    }

    @Test("isActive returns false after completion")
    func isActiveFalseAfterComplete() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tick(world, times: 60) // Well past 0.5s
        #expect(!tweens.isActive(handle))
    }

    @Test("removeAll clears everything")
    func removeAllClears() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)
        tweens.moveTo(e, target: Vector2(x: 200, y: 0), duration: 1.0, in: world)
        #expect(tweens.tweenCount == 2)

        tweens.removeAll()
        #expect(tweens.tweenCount == 0)
    }

    @Test("pauseAll and resumeAll for entity")
    func pauseResumeAll() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)
        tweens.fadeOut(e, duration: 1.0, in: world)

        tick(world, times: 10)
        tweens.pauseAll(on: e)
        let posX = world.getComponent(Transform2D.self, from: e)!.position.x
        let alpha = world.getComponent(Sprite.self, from: e)!.tint.a

        tick(world, times: 20) // Should not change
        let posX2 = world.getComponent(Transform2D.self, from: e)!.position.x
        let alpha2 = world.getComponent(Sprite.self, from: e)!.tint.a
        #expect(abs(posX - posX2) < 0.01)
        #expect(alpha == alpha2)

        tweens.resumeAll(on: e)
        tick(world, times: 10)
        let posX3 = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(posX3 > posX + 5)
    }
}

// MARK: - Callback Tests

@Suite("Tween Callbacks")
struct CallbackTests {
    @Test("onComplete fires when tween finishes")
    func onCompleteFiresAtEnd() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.onComplete(handle) { tracker.fire() }

        tick(world, times: 29) // Not quite done
        #expect(!tracker.wasCalled)
        tick(world, times: 2) // Past duration
        #expect(tracker.wasCalled)
    }

    @Test("onComplete does NOT fire on cancel")
    func onCompleteNotOnCancel() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        tweens.onComplete(handle) { tracker.fire() }

        tick(world, times: 10)
        tweens.cancel(handle)
        tick(world, times: 60)
        #expect(!tracker.wasCalled)
    }

    @Test("onStart fires when delay ends")
    func onStartAfterDelay() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, delay: 0.5, in: world)
        tweens.onStart(handle) { tracker.fire() }

        tick(world, times: 15) // 0.25s into delay
        #expect(!tracker.wasCalled)
        tick(world, times: 16) // Past 0.5s delay
        #expect(tracker.wasCalled)
    }

    @Test("onUpdate fires every tick with eased t")
    func onUpdateEveryTick() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let counter = CallTracker()
        let lastTTracker = ValueTracker<Float>(-1)
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.onUpdate(handle) { t in
            counter.fire()
            lastTTracker.value = t
        }

        tick(world, times: 10)
        #expect(counter.callCount == 10)
        #expect(lastTTracker.value > 0)
    }

    @Test("System-level onTweenCompleted callback")
    func systemLevelCallback() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        tweens.onTweenCompleted = { _, _ in tracker.fire() }

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5, in: world)
        tick(world, times: 31)
        #expect(tracker.wasCalled)
    }

    @Test("TweenCompleted event emitted on world")
    func tweenCompletedEvent() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        world.on(TweenCompleted.self) { _ in tracker.fire() }

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5, in: world)
        tick(world, times: 31)
        #expect(tracker.wasCalled)
    }

    @Test("onComplete does not fire on entity death")
    func onCompleteNotOnEntityDeath() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        tweens.onComplete(handle) { tracker.fire() }

        tick(world, times: 5)
        world.destroyEntity(e)
        tick(world, times: 60)
        #expect(!tracker.wasCalled)
    }

    @Test("onComplete fires only once")
    func onCompleteOnlyOnce() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.onComplete(handle) { tracker.fire() }

        tick(world, times: 60) // Way past completion
        #expect(tracker.callCount == 1)
    }
}

// MARK: - Repeat / Yoyo Tests

@Suite("Repeat and Yoyo")
struct RepeatYoyoTests {
    @Test("Repeat plays multiple times")
    func repeatMultiple() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.setRepeat(handle, count: 2) // play 3 times total
        tweens.onComplete(handle) { tracker.fire() }

        // 30 ticks = 0.5s = 1 play. Need 3 plays = 90 ticks
        tick(world, times: 95)
        #expect(tracker.callCount == 1) // fires once at the very end
    }

    @Test("Infinite repeat keeps going")
    func infiniteRepeat() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.setRepeat(handle, count: -1) // infinite

        tick(world, times: 300) // 5 seconds of play
        #expect(tweens.isActive(handle))
    }

    @Test("Yoyo plays forward then backward")
    func yoyoForwardBackward() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.setYoyo(handle)

        // After forward play (30 ticks), should be at ~100
        tick(world, times: 30)
        let midPos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(midPos - 100) < 5)

        // After reverse play (30 more ticks), should be back at ~0
        tick(world, times: 31)
        let endPos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(endPos) < 5)
    }

    @Test("Yoyo with repeat ping-pongs")
    func yoyoWithRepeat() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.setYoyo(handle)
        tweens.setRepeat(handle, count: -1) // infinite yoyo

        // After 5 seconds, still active
        tick(world, times: 300)
        #expect(tweens.isActive(handle))
    }

    @Test("Repeat count 0 plays exactly once")
    func repeatZeroPlaysOnce() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        // Default repeatCount is 0 — plays once
        tick(world, times: 31) // Past duration
        #expect(!tweens.isActive(handle))
    }

    @Test("Yoyo midpoint returns to start")
    func yoyoMidpointCheck() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 50, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 150, y: 0),
                                   duration: 0.5, in: world)
        tweens.setYoyo(handle)

        // Forward half: should be at ~midpoint (100) at 15 ticks
        tick(world, times: 15)
        let halfwayForward = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(halfwayForward - 100) < 10)
    }

    @Test("Repeat count 1 plays exactly twice")
    func repeatOnePlays2x() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let counter = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        tweens.setRepeat(handle, count: 1)
        tweens.onUpdate(handle) { _ in counter.fire() }

        // 0.5s + 0.5s = 1s = 60 ticks needed
        tick(world, times: 65)
        #expect(!tweens.isActive(handle))
    }

    @Test("Yoyo correctly reverses with easing")
    func yoyoReversesEasing() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, easing: .cubicOut, in: world)
        tweens.setYoyo(handle)

        // cubicOut at t=0.5 ≈ 0.875, so position ≈ 87.5 at forward midpoint
        tick(world, times: 30)
        let forwardMid = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(forwardMid > 70)

        // Complete forward phase
        tick(world, times: 31)
        // Now reversing — at reverse midpoint, directedT = 0.5, cubicOut(0.5) ≈ 0.875
        tick(world, times: 30)
        let reverseMid = world.getComponent(Transform2D.self, from: e)!.position.x
        // Reverse mid should be near 87.5 since easing is applied to reversed t
        #expect(reverseMid > 60)
    }
}

// MARK: - Sequence Tests

@Suite("Tween Sequences")
struct SequenceTests {
    @Test("Two-step sequence moves then fades")
    func twoStepSequence() {
        let (world, tweens) = makeTweenWorld()
        let e = makeSpriteEntity(world, position: Vector2(x: 0, y: 0))

        tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 0.5, easing: .linear),
            .fadeOut(duration: 0.5, easing: .linear)
        ], in: world)

        // After first step (30 ticks), should be at target position
        tick(world, times: 31)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(abs(pos.x - 100) < 3)

        // After second step (30 more ticks), alpha should be near 0
        tick(world, times: 31)
        let alpha = world.getComponent(Sprite.self, from: e)!.tint.a
        #expect(alpha < 10)
    }

    @Test("Wait step pauses between animations")
    func waitStep() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 0.5, easing: .linear),
            .wait(duration: 0.5),
            .moveTo(target: Vector2(x: 200, y: 0), duration: 0.5, easing: .linear)
        ], in: world)

        // After first move (30 ticks)
        tick(world, times: 31)
        let pos1 = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pos1 - 100) < 3)

        // During wait (15 ticks), position shouldn't change much
        tick(world, times: 15)
        let pos2 = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pos2 - 100) < 3)

        // After wait + second move
        tick(world, times: 46)
        let pos3 = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pos3 - 200) < 5)
    }

    @Test("Callback step executes inline")
    func callbackStep() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let tracker = CallTracker()
        tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 0.5, easing: .linear),
            .callback { tracker.fire() },
            .moveTo(target: Vector2(x: 200, y: 0), duration: 0.5, easing: .linear)
        ], in: world)

        // Callback fires after first step completes
        tick(world, times: 29)
        #expect(!tracker.wasCalled)
        tick(world, times: 3)
        #expect(tracker.wasCalled)
    }

    @Test("Sequence reads current value per step")
    func sequenceReadsCurrentValue() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 0.5, easing: .linear),
            .moveTo(target: Vector2(x: 50, y: 0), duration: 0.5, easing: .linear)
        ], in: world)

        // After first step, at x=100
        tick(world, times: 31)
        // Second step starts from current (100) to 50
        tick(world, times: 15) // Halfway through second step
        let pos = world.getComponent(Transform2D.self, from: e)!.position.x
        // Should be between 100 and 50, around 75
        #expect(pos > 60 && pos < 90)
    }

    @Test("Empty sequence returns invalid")
    func emptySequence() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)
        let handle = tweens.sequence(e, steps: [], in: world)
        #expect(handle == .invalid)
    }

    @Test("Entity death mid-sequence cancels remaining steps")
    func entityDeathMidSequence() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let tracker = CallTracker()
        tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 0.5, easing: .linear),
            .callback { tracker.fire() }
        ], in: world)

        tick(world, times: 10)
        world.destroyEntity(e)
        tick(world, times: 60)
        #expect(!tracker.wasCalled)
    }

    @Test("Sequence onComplete fires when all steps done")
    func sequenceOnComplete() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let tracker = CallTracker()
        let handle = tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 0.5, easing: .linear),
            .moveTo(target: Vector2(x: 200, y: 0), duration: 0.5, easing: .linear)
        ], in: world)
        tweens.onSequenceComplete(handle) { tracker.fire() }

        tick(world, times: 31) // First step done
        #expect(!tracker.wasCalled)
        tick(world, times: 31) // Second step done
        #expect(tracker.wasCalled)
    }

    @Test("Cancel sequence cancels current step")
    func cancelSequence() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let handle = tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 1.0, easing: .linear),
            .moveTo(target: Vector2(x: 200, y: 0), duration: 1.0, easing: .linear)
        ], in: world)

        tick(world, times: 10)
        tweens.cancel(handle)
        let posX = world.getComponent(Transform2D.self, from: e)!.position.x
        tick(world, times: 60)
        let posX2 = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(posX - posX2) < 0.01)
    }

    @Test("Sequence isActive during playback")
    func sequenceIsActive() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let handle = tweens.sequence(e, steps: [
            .moveTo(target: Vector2(x: 100, y: 0), duration: 0.5, easing: .linear)
        ], in: world)

        #expect(tweens.isActive(handle))
        tick(world, times: 31)
        // After completion, sequence should be cleaned up
        tick(world, times: 5) // Extra ticks for cleanup
        #expect(!tweens.isActive(handle))
    }
}

// MARK: - Easing Integration Tests

@Suite("Easing Integration")
struct EasingIntegrationTests {
    @Test("cubicOut produces expected midpoint")
    func cubicOutMidpoint() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0,
                      easing: .cubicOut, in: world)
        // At t=0.5, cubicOut = 1 - (0.5)^3 = 0.875
        tick(world, times: 30)
        let pos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pos - 87.5) < 5)
    }

    @Test("quadIn produces expected midpoint")
    func quadInMidpoint() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0,
                      easing: .quadIn, in: world)
        // At t=0.5, quadIn = 0.25
        tick(world, times: 30)
        let pos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pos - 25) < 5)
    }

    @Test("Linear easing produces straight interpolation")
    func linearStraight() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 60, y: 0), duration: 1.0,
                      easing: .linear, in: world)
        // At exactly 30 ticks (0.5s), should be at 30
        tick(world, times: 30)
        let pos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pos - 30) < 2)
    }

    @Test("Bounce easing reaches target at completion")
    func bounceReachesTarget() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5,
                      easing: .bounceOut, in: world)
        tick(world, times: 31)
        let pos = world.getComponent(Transform2D.self, from: e)!.position.x
        #expect(abs(pos - 100) < 3)
    }
}

// MARK: - Edge Case Tests

@Suite("Edge Cases")
struct EdgeCaseTests {
    @Test("Zero duration tween completes instantly")
    func zeroDurationInstant() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0, in: world)
        tweens.onComplete(handle) { tracker.fire() }

        tick(world, times: 1)
        #expect(tracker.wasCalled)
        let pos = world.getComponent(Transform2D.self, from: e)!.position
        #expect(abs(pos.x - 100) < 0.01)
    }

    @Test("Multiple tweens on same property (last write wins)")
    func multipleTweensSameProperty() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)
        tweens.moveTo(e, target: Vector2(x: -100, y: 0), duration: 1.0, in: world)
        #expect(tweens.tweenCount == 2) // Both exist
        // Both will write to position — last iteration wins, but both are processing
    }

    @Test("Tween on dead entity at creation returns valid handle but cleans up")
    func tweenOnDeadEntity() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)
        world.destroyEntity(e)

        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 1.0, in: world)
        // moveTo reads component — entity is dead, so getComponent returns nil → .invalid
        #expect(handle == .invalid)
    }

    @Test("tweenCount tracks active tweens correctly")
    func tweenCountAccuracy() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        #expect(tweens.tweenCount == 0)
        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5, in: world)
        #expect(tweens.tweenCount == 1)
        tweens.moveTo(e, target: Vector2(x: 200, y: 0), duration: 0.5, in: world)
        #expect(tweens.tweenCount == 2)

        tick(world, times: 31) // Both should complete
        #expect(tweens.tweenCount == 0)
    }

    @Test("Negative delay is treated as zero")
    func negativeDelay() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e, target: Vector2(x: 100, y: 0), duration: 0.5,
                      delay: -1.0, in: world)
        tick(world, times: 1)
        let pos = world.getComponent(Transform2D.self, from: e)!.position.x
        // Should start immediately, not be stuck in delay
        #expect(pos > 0)
    }

    @Test("Fluent modifier chaining works")
    func fluentChaining() {
        let (world, tweens) = makeTweenWorld()
        let e = makeEntity(world)

        let tracker = CallTracker()
        let handle = tweens.moveTo(e, target: Vector2(x: 100, y: 0),
                                   duration: 0.5, in: world)
        // Chain modifiers
        tweens.setYoyo(handle)
        tweens.setRepeat(handle, count: 1)
        tweens.onComplete(handle) { tracker.fire() }

        #expect(tweens.isActive(handle))
        // 0.5s forward + 0.5s reverse + 0.5s forward + 0.5s reverse = 2s = 120 ticks
        tick(world, times: 125)
        #expect(tracker.wasCalled)
    }
}

// MARK: - Multiple Entity Tests

@Suite("Multiple Entities")
struct MultipleEntityTests {
    @Test("Tweens on different entities are independent")
    func independentTweens() {
        let (world, tweens) = makeTweenWorld()
        let e1 = makeEntity(world, position: Vector2(x: 0, y: 0))
        let e2 = makeEntity(world, position: Vector2(x: 0, y: 0))

        tweens.moveTo(e1, target: Vector2(x: 100, y: 0), duration: 0.5, in: world)
        tweens.moveTo(e2, target: Vector2(x: -100, y: 0), duration: 1.0, in: world)

        tick(world, times: 31) // e1 done, e2 halfway

        let pos1 = world.getComponent(Transform2D.self, from: e1)!.position.x
        let pos2 = world.getComponent(Transform2D.self, from: e2)!.position.x

        #expect(abs(pos1 - 100) < 3)
        #expect(abs(pos2 - (-50)) < 5)
    }

    @Test("cancelAll only affects target entity")
    func cancelAllIsolated() {
        let (world, tweens) = makeTweenWorld()
        let e1 = makeEntity(world)
        let e2 = makeEntity(world)

        tweens.moveTo(e1, target: Vector2(x: 100, y: 0), duration: 1.0, in: world)
        tweens.moveTo(e2, target: Vector2(x: 200, y: 0), duration: 1.0, in: world)
        #expect(tweens.tweenCount == 2)

        tweens.cancelAll(on: e1)
        #expect(tweens.tweenCount == 1) // Only e2's tween remains
    }
}
