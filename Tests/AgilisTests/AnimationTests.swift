import Testing
@testable import Agilis

// MARK: - Test Helpers

/// Creates a simple animation clip with uniform frame durations.
private func makeClip(
    name: String = "test",
    frameCount: Int = 4,
    frameDuration: Float = 0.1,
    mode: PlaybackMode = .forward
) -> AnimationClip {
    let frames = (0..<frameCount).map { i in
        AnimationFrame(
            sourceRect: Rect(x: Float(i) * 32, y: 0, width: 32, height: 32),
            duration: frameDuration
        )
    }
    return AnimationClip(name: name, frames: frames, mode: mode)
}

/// Creates a World with an AnimationSystem, sets up entities, then runs N ticks.
private func runAnimation(
    ticks: Int = 1,
    deltaTime: Double = 1.0 / 60.0,
    priority: Int = 50,
    afterTick: ((World, AnimationSystem, Int) -> Void)? = nil,
    setup: (World, AnimationSystem) -> Void
) -> (World, AnimationSystem) {
    let world = World()
    let system = AnimationSystem(priority: priority)
    world.addSystem(system)
    setup(world, system)
    for tick in 0..<ticks {
        world.update(deltaTime: deltaTime)
        afterTick?(world, system, tick)
    }
    return (world, system)
}

// MARK: - AnimationClip Tests

@Suite("AnimationClip Tests")
struct AnimationClipTests {

    @Test("AnimationClip totalDuration sums all frame durations")
    func totalDuration() {
        let clip = makeClip(frameCount: 4, frameDuration: 0.1)
        #expect(abs(clip.totalDuration - 0.4) < 0.001)
    }

    @Test("AnimationClip frameCount")
    func frameCount() {
        let clip = makeClip(frameCount: 6)
        #expect(clip.frameCount == 6)
    }

    @Test("AnimationClip empty clip has zero duration")
    func emptyClipDuration() {
        let clip = AnimationClip(name: "empty", frames: [], mode: .forward)
        #expect(clip.totalDuration == 0)
        #expect(clip.frameCount == 0)
    }

    @Test("AnimationClip.fromSpriteSheet creates correct frames")
    func fromSpriteSheet() {
        let clip = AnimationClip.fromSpriteSheet(
            name: "walk",
            startX: 0, y: 64,
            frameWidth: 32, frameHeight: 32,
            count: 4, frameDuration: 0.1
        )
        #expect(clip.name == "walk")
        #expect(clip.frameCount == 4)
        #expect(clip.mode == .forward)

        #expect(clip.frames[0].sourceRect == Rect(x: 0, y: 64, width: 32, height: 32))
        #expect(clip.frames[1].sourceRect == Rect(x: 32, y: 64, width: 32, height: 32))
        #expect(clip.frames[2].sourceRect == Rect(x: 64, y: 64, width: 32, height: 32))
        #expect(clip.frames[3].sourceRect == Rect(x: 96, y: 64, width: 32, height: 32))

        for frame in clip.frames {
            #expect(abs(frame.duration - 0.1) < 0.001)
        }
    }

    @Test("AnimationClip.fromSpriteSheet with custom mode")
    func fromSpriteSheetCustomMode() {
        let clip = AnimationClip.fromSpriteSheet(
            name: "bounce",
            startX: 0, y: 0,
            frameWidth: 16, frameHeight: 16,
            count: 3, frameDuration: 0.2,
            mode: .pingPong
        )
        #expect(clip.mode == .pingPong)
        #expect(clip.frameCount == 3)
    }

    @Test("AnimationClip Equatable")
    func equatable() {
        let a = makeClip(name: "walk", frameCount: 3, frameDuration: 0.1)
        let b = makeClip(name: "walk", frameCount: 3, frameDuration: 0.1)
        let c = makeClip(name: "run", frameCount: 3, frameDuration: 0.1)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("AnimationClip with variable frame durations")
    func variableDurations() {
        let frames = [
            AnimationFrame(sourceRect: Rect(x: 0, y: 0, width: 32, height: 32), duration: 0.1),
            AnimationFrame(sourceRect: Rect(x: 32, y: 0, width: 32, height: 32), duration: 0.2),
            AnimationFrame(sourceRect: Rect(x: 64, y: 0, width: 32, height: 32), duration: 0.15),
        ]
        let clip = AnimationClip(name: "varied", frames: frames, mode: .forward)
        #expect(abs(clip.totalDuration - 0.45) < 0.001)
    }
}

// MARK: - SpriteAnimator Tests

@Suite("SpriteAnimator Tests")
struct SpriteAnimatorTests {

    @Test("SpriteAnimator default init starts playing")
    func defaultInit() {
        let clip = makeClip()
        let animator = SpriteAnimator(clip: clip)
        #expect(animator.isPlaying == true)
        #expect(animator.currentFrameIndex == 0)
        #expect(animator.frameTime == 0)
        #expect(animator.speed == 1.0)
        #expect(animator.lastEvent == nil)
    }

    @Test("SpriteAnimator init with startPlaying false")
    func initNotPlaying() {
        let clip = makeClip()
        let animator = SpriteAnimator(clip: clip, startPlaying: false)
        #expect(animator.isPlaying == false)
    }

    @Test("SpriteAnimator init with custom speed")
    func initCustomSpeed() {
        let clip = makeClip()
        let animator = SpriteAnimator(clip: clip, speed: 2.0)
        #expect(animator.speed == 2.0)
    }

    @Test("SpriteAnimator play/pause")
    func playPause() {
        let clip = makeClip()
        var animator = SpriteAnimator(clip: clip)
        animator.pause()
        #expect(animator.isPlaying == false)
        animator.play()
        #expect(animator.isPlaying == true)
    }

    @Test("SpriteAnimator stop resets to frame 0")
    func stop() {
        let clip = makeClip()
        var animator = SpriteAnimator(clip: clip)
        animator.currentFrameIndex = 2
        animator.frameTime = 0.05
        animator.stop()
        #expect(animator.isPlaying == false)
        #expect(animator.currentFrameIndex == 0)
        #expect(animator.frameTime == 0)
    }

    @Test("SpriteAnimator restart resets and plays")
    func restart() {
        let clip = makeClip()
        var animator = SpriteAnimator(clip: clip, startPlaying: false)
        animator.currentFrameIndex = 3
        animator.frameTime = 0.05
        animator.restart()
        #expect(animator.isPlaying == true)
        #expect(animator.currentFrameIndex == 0)
        #expect(animator.frameTime == 0)
    }

    @Test("SpriteAnimator setClip skips if same name")
    func setClipSameName() {
        let clipA = makeClip(name: "walk", frameCount: 4)
        var animator = SpriteAnimator(clip: clipA)
        animator.currentFrameIndex = 2
        animator.frameTime = 0.05

        let clipB = makeClip(name: "walk", frameCount: 6) // Same name, different frames
        animator.setClip(clipB)

        // Should NOT have reset because names match
        #expect(animator.currentFrameIndex == 2)
        #expect(animator.frameTime == 0.05)
        #expect(animator.clip.frameCount == 4) // Still old clip
    }

    @Test("SpriteAnimator setClip resets for different name")
    func setClipDifferentName() {
        let clipA = makeClip(name: "walk")
        var animator = SpriteAnimator(clip: clipA)
        animator.currentFrameIndex = 2
        animator.frameTime = 0.05

        let clipB = makeClip(name: "run", frameCount: 6)
        animator.setClip(clipB)

        #expect(animator.currentFrameIndex == 0)
        #expect(animator.frameTime == 0)
        #expect(animator.clip.name == "run")
        #expect(animator.isPlaying == true)
    }

    @Test("SpriteAnimator forceSetClip always resets")
    func forceSetClip() {
        let clipA = makeClip(name: "walk")
        var animator = SpriteAnimator(clip: clipA)
        animator.currentFrameIndex = 2

        let clipB = makeClip(name: "walk", frameCount: 6) // Same name
        animator.forceSetClip(clipB)

        #expect(animator.currentFrameIndex == 0)
        #expect(animator.clip.frameCount == 6)
    }

    @Test("SpriteAnimator setFrame clamps to valid range")
    func setFrame() {
        let clip = makeClip(frameCount: 4)
        var animator = SpriteAnimator(clip: clip)

        animator.setFrame(2)
        #expect(animator.currentFrameIndex == 2)
        #expect(animator.frameTime == 0)

        animator.setFrame(100)
        #expect(animator.currentFrameIndex == 3) // Clamped to last

        animator.setFrame(-5)
        #expect(animator.currentFrameIndex == 0) // Clamped to first
    }

    @Test("SpriteAnimator setFrame on empty clip does nothing")
    func setFrameEmpty() {
        let clip = AnimationClip(name: "empty", frames: [], mode: .forward)
        var animator = SpriteAnimator(clip: clip)
        animator.setFrame(0) // Should not crash
        #expect(animator.currentFrameIndex == 0)
    }

    @Test("SpriteAnimator currentSourceRect")
    func currentSourceRect() {
        let clip = makeClip(frameCount: 3)
        var animator = SpriteAnimator(clip: clip)
        #expect(animator.currentSourceRect == Rect(x: 0, y: 0, width: 32, height: 32))

        animator.currentFrameIndex = 2
        #expect(animator.currentSourceRect == Rect(x: 64, y: 0, width: 32, height: 32))
    }

    @Test("SpriteAnimator currentSourceRect on empty clip returns zero rect")
    func currentSourceRectEmpty() {
        let clip = AnimationClip(name: "empty", frames: [], mode: .forward)
        let animator = SpriteAnimator(clip: clip)
        #expect(animator.currentSourceRect == Rect())
    }

    @Test("SpriteAnimator progress")
    func progress() {
        let clip = makeClip(frameCount: 5)
        var animator = SpriteAnimator(clip: clip)
        #expect(animator.progress == 0)

        animator.currentFrameIndex = 2
        #expect(abs(animator.progress - 0.5) < 0.001)

        animator.currentFrameIndex = 4
        #expect(abs(animator.progress - 1.0) < 0.001)
    }

    @Test("SpriteAnimator progress on single frame clip is 0")
    func progressSingleFrame() {
        let clip = makeClip(frameCount: 1)
        let animator = SpriteAnimator(clip: clip)
        #expect(animator.progress == 0)
    }

    @Test("SpriteAnimator isFinished only for oneShot")
    func isFinished() {
        let forwardClip = makeClip(mode: .forward)
        var animator = SpriteAnimator(clip: forwardClip, startPlaying: false)
        animator.currentFrameIndex = 3
        #expect(animator.isFinished == false) // Not oneShot

        let oneShotClip = makeClip(mode: .oneShot)
        var animator2 = SpriteAnimator(clip: oneShotClip, startPlaying: false)
        animator2.currentFrameIndex = 3
        #expect(animator2.isFinished == true) // oneShot, on last frame, not playing
    }
}

// MARK: - AnimationSystem Integration Tests

@Suite("AnimationSystem Integration Tests")
struct AnimationSystemTests {

    @Test("AnimationSystem priority")
    func systemPriority() {
        let system = AnimationSystem(priority: 42)
        #expect(system.priority == 42)

        let defaultSystem = AnimationSystem()
        #expect(defaultSystem.priority == 50)
    }

    @Test("AnimationSystem forward playback advances frames")
    func forwardPlayback() {
        // 4 frames at 0.1s each, dt = 0.1s → should advance one frame per tick
        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: makeClip(frameDuration: 0.1)), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!
        #expect(animator.currentFrameIndex == 1)
    }

    @Test("AnimationSystem writes sourceRect to Sprite")
    func writesSourceRect() {
        let clip = makeClip(frameCount: 3, frameDuration: 0.1)
        let (world, _) = runAnimation(ticks: 2, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let sprite = world.getComponent(Sprite.self, from: e)!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        // After 2 ticks at 0.1s per frame: should be on frame 2
        #expect(animator.currentFrameIndex == 2)
        #expect(sprite.sourceRect == Rect(x: 64, y: 0, width: 32, height: 32))
    }

    @Test("AnimationSystem forward loop emits event")
    func forwardLoopEvent() {
        var receivedEvents: [(Entity, AnimationEvent)] = []

        // 4 frames at 0.1s → completes a cycle at 0.4s → 4 ticks at dt=0.1
        let (world, _) = runAnimation(ticks: 4, deltaTime: 0.1) { world, system in
            system.onAnimationEvent = { entity, event in
                receivedEvents.append((entity, event))
            }
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: makeClip(frameDuration: 0.1)), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        // Should have looped back to frame 0
        #expect(animator.currentFrameIndex == 0)
        #expect(receivedEvents.count >= 1)
        #expect(receivedEvents.last?.1 == .looped)
    }

    @Test("AnimationSystem reverse playback")
    func reversePlayback() {
        let clip = makeClip(frameCount: 4, frameDuration: 0.1, mode: .reverse)

        // Reverse starts at frame 0 and goes backward → wraps to last frame
        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            // Start at frame 3 (last frame) for reverse to make sense
            var animator = SpriteAnimator(clip: clip)
            animator.currentFrameIndex = 3
            world.addComponent(animator, to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        // Should have gone from 3 → 2
        #expect(animator.currentFrameIndex == 2)
    }

    @Test("AnimationSystem reverse wraps and emits looped")
    func reverseWrap() {
        let clip = makeClip(frameCount: 3, frameDuration: 0.1, mode: .reverse)
        var receivedEvents: [(Entity, AnimationEvent)] = []

        // Start at frame 0, advance once → should wrap to frame 2
        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.1) { world, system in
            system.onAnimationEvent = { entity, event in
                receivedEvents.append((entity, event))
            }
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        #expect(animator.currentFrameIndex == 2)
        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].1 == .looped)
    }

    @Test("AnimationSystem pingPong bounces without double endpoints")
    func pingPong() {
        // 4 frames: 0,1,2,3, then back: 2,1, then forward: 0,1,2,3,...
        let clip = makeClip(frameCount: 4, frameDuration: 0.1, mode: .pingPong)
        var frameSequence: [Int] = []

        let (_, _) = runAnimation(
            ticks: 8, deltaTime: 0.1,
            afterTick: { world, _, tick in
                let e = world.entity(named: "sprite")!
                let animator = world.getComponent(SpriteAnimator.self, from: e)!
                frameSequence.append(animator.currentFrameIndex)
            },
            setup: { world, _ in
                let e = world.createEntity()
                world.setName("sprite", for: e)
                world.addComponent(SpriteAnimator(clip: clip), to: e)
                world.addComponent(Sprite(texture: .invalid), to: e)
            }
        )

        // Expected: start at 0, after ticks:
        // Tick 0: 0→1
        // Tick 1: 1→2
        // Tick 2: 2→3
        // Tick 3: 3→4(≥4), reverses to index 2
        // Tick 4: 2→1
        // Tick 5: 1→0
        // Tick 6: 0→-1(<0), reverses to index 1
        // Tick 7: 1→2
        // No double endpoints: 0,1,2,3,2,1,0,1,2,3,...
        #expect(frameSequence == [1, 2, 3, 2, 1, 0, 1, 2])
    }

    @Test("AnimationSystem oneShot stops on last frame")
    func oneShotStops() {
        let clip = makeClip(frameCount: 3, frameDuration: 0.1, mode: .oneShot)
        var receivedEvents: [(Entity, AnimationEvent)] = []

        // Run 5 ticks — should reach end at tick 2 and stay there
        let (world, _) = runAnimation(ticks: 5, deltaTime: 0.1) { world, system in
            system.onAnimationEvent = { entity, event in
                receivedEvents.append((entity, event))
            }
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        #expect(animator.currentFrameIndex == 2) // Last frame
        #expect(animator.isPlaying == false)
        #expect(animator.isFinished == true)
        #expect(receivedEvents.count == 1)
        #expect(receivedEvents[0].1 == .completed)
    }

    @Test("AnimationSystem paused animation does not advance")
    func pausedNoAdvance() {
        let clip = makeClip(frameDuration: 0.1)

        let (world, _) = runAnimation(ticks: 5, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip, startPlaying: false), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        #expect(animator.currentFrameIndex == 0)
    }

    @Test("AnimationSystem paused animation still writes sourceRect")
    func pausedWritesSourceRect() {
        let clip = makeClip(frameCount: 3)

        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            var animator = SpriteAnimator(clip: clip, startPlaying: false)
            animator.currentFrameIndex = 1 // Manually set to frame 1
            world.addComponent(animator, to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let sprite = world.getComponent(Sprite.self, from: e)!

        // Even though paused, sprite should show frame 1's sourceRect
        #expect(sprite.sourceRect == Rect(x: 32, y: 0, width: 32, height: 32))
    }

    @Test("AnimationSystem speed multiplier")
    func speedMultiplier() {
        // 2x speed: 0.1s frames at dt=0.05 should still advance one frame per tick
        let clip = makeClip(frameDuration: 0.1)

        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.05) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip, speed: 2.0), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        // 0.05 * 2.0 = 0.1 → exactly one frame
        #expect(animator.currentFrameIndex == 1)
    }

    @Test("AnimationSystem half speed")
    func halfSpeed() {
        let clip = makeClip(frameDuration: 0.1)

        // 0.5x speed, dt=0.1 → effective advance = 0.05 → not enough for one frame
        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip, speed: 0.5), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        #expect(animator.currentFrameIndex == 0) // Not enough time
    }

    @Test("AnimationSystem lastEvent cleared each tick")
    func lastEventCleared() {
        let clip = makeClip(frameCount: 3, frameDuration: 0.1, mode: .oneShot)

        // Tick 1: frame 0→1, tick 2: frame 1→2, tick 3: frame 2→3(clamped to 2, completed)
        // Tick 4: paused, event cleared
        let (world, _) = runAnimation(ticks: 4, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        // Event was completed on tick 3, cleared on tick 4
        #expect(animator.lastEvent == nil)
    }

    @Test("AnimationSystem skips entities without Sprite")
    func skipsMissingSpriteComponent() {
        // Entity with SpriteAnimator but no Sprite — should not crash
        let (world, _) = runAnimation(ticks: 3, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("animOnly", for: e)
            world.addComponent(SpriteAnimator(clip: makeClip()), to: e)
            // NO Sprite component
        }

        // Should not crash, animator is untouched since forEach won't match
        let e = world.entity(named: "animOnly")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!
        #expect(animator.currentFrameIndex == 0) // Unchanged
    }

    @Test("AnimationSystem handles empty clip gracefully")
    func emptyClip() {
        let clip = AnimationClip(name: "empty", frames: [], mode: .forward)

        let (world, _) = runAnimation(ticks: 3, deltaTime: 0.1) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let sprite = world.getComponent(Sprite.self, from: e)!

        // Should not crash, sourceRect should be zero
        #expect(sprite.sourceRect == Rect())
    }

    @Test("AnimationSystem single frame clip doesn't loop")
    func singleFrame() {
        let clip = makeClip(frameCount: 1, frameDuration: 0.1)
        var eventCount = 0

        let (world, _) = runAnimation(ticks: 5, deltaTime: 0.1) { world, system in
            system.onAnimationEvent = { _, _ in eventCount += 1 }
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        // Single frame loops back to itself, emitting looped events
        #expect(animator.currentFrameIndex == 0)
        #expect(eventCount >= 1) // Loops each time it wraps
    }

    @Test("AnimationSystem multiple entities animate independently")
    func multipleEntities() {
        let fastClip = makeClip(name: "fast", frameDuration: 0.05)
        let slowClip = makeClip(name: "slow", frameDuration: 0.2)

        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.1) { world, _ in
            let e1 = world.createEntity()
            world.setName("fast", for: e1)
            world.addComponent(SpriteAnimator(clip: fastClip), to: e1)
            world.addComponent(Sprite(texture: .invalid), to: e1)

            let e2 = world.createEntity()
            world.setName("slow", for: e2)
            world.addComponent(SpriteAnimator(clip: slowClip), to: e2)
            world.addComponent(Sprite(texture: .invalid), to: e2)
        }

        let fast = world.entity(named: "fast")!
        let slow = world.entity(named: "slow")!
        let fastAnim = world.getComponent(SpriteAnimator.self, from: fast)!
        let slowAnim = world.getComponent(SpriteAnimator.self, from: slow)!

        // 0.1s elapsed: fast (0.05s frames) should be on frame 2, slow (0.2s) on frame 0
        #expect(fastAnim.currentFrameIndex == 2)
        #expect(slowAnim.currentFrameIndex == 0)
    }

    @Test("AnimationSystem large deltaTime skips multiple frames")
    func largeTimestep() {
        let clip = makeClip(frameCount: 4, frameDuration: 0.1)

        // dt = 0.25 → should advance past 2 frames (0.1 + 0.1 = 0.2)
        let (world, _) = runAnimation(ticks: 1, deltaTime: 0.25) { world, _ in
            let e = world.createEntity()
            world.setName("sprite", for: e)
            world.addComponent(SpriteAnimator(clip: clip), to: e)
            world.addComponent(Sprite(texture: .invalid), to: e)
        }

        let e = world.entity(named: "sprite")!
        let animator = world.getComponent(SpriteAnimator.self, from: e)!

        #expect(animator.currentFrameIndex == 2) // Skipped past frame 0 and 1
    }
}
