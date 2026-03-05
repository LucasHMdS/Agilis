# Time

## Clock

`Sources/Agilis/Time/Clock.swift`

High-resolution timer used internally by the game loop. Can also be used directly for custom timing.

### Methods

```swift
// Seconds elapsed since the last call to elapsed().
// First call returns time since clock creation.
func elapsed() -> Double

// Total seconds since the clock was created.
// Does not affect elapsed() tracking.
func totalTime() -> Double
```

### Platform Implementations

| Platform | API |
|----------|-----|
| Windows | `QueryPerformanceCounter` / `QueryPerformanceFrequency` |
| macOS/iOS | `mach_absolute_time` / `mach_timebase_info` |
| Linux | `clock_gettime(CLOCK_MONOTONIC)` |

### Usage

```swift
let clock = Clock()

// Measure elapsed time
let dt = clock.elapsed()   // Seconds since last call

// Total time since creation
let total = clock.totalTime()
```

### In the Game Loop

The `Application` uses `Clock` internally:

- `app.fps` — Frames per second, updated once per second
- `app.frameTime` — Duration of the last frame in seconds

---

## Time Scaling

Control game speed with a single property on `Application`.

### Application.timeScale

```swift
public var timeScale: Double   // Default: 1.0
```

| Value | Effect |
|-------|--------|
| `0` | Paused (rendering continues, audio stays real-time) |
| `0.5` | Slow motion (half speed) |
| `1.0` | Normal speed |
| `2.0+` | Fast forward |

Negative values are clamped to 0.

### What It Affects

- Physics, animation, particles, scene transitions, plugins (all fixed-timestep systems)

### What It Does NOT Affect

- Audio fading/music, input polling, rendering

### How It Works

Applied to the fixed-timestep accumulator: `accumulator += frameTime * max(timeScale, 0)`. When `timeScale` is 0, no fixed-timestep ticks run, but the render loop continues (useful for pause menus).

### Usage

```swift
// Slow-motion bullet time
app.timeScale = 0.25

// Pause game (render still runs for pause menu overlay)
app.timeScale = 0

// Fast-forward for debugging
app.timeScale = 4.0

// Resume normal speed
app.timeScale = 1.0
```
