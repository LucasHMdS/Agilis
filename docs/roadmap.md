# Agilis Feature Roadmap

Feature gap analysis comparing Agilis against Godot 4.4+, Unity 6, Bevy 0.15+, MonoGame/FNA, Love2D, Defold, and Macroquad. Organized by impact and priority.

---

## Feature Comparison Matrix

How Agilis stacks up against competitors across major feature categories.

| Feature | Agilis | Godot 4.x | Unity 6 | Bevy 0.15+ | Love2D | Defold | MonoGame | Macroquad |
|---|---|---|---|---|---|---|---|---|
| **Sprites & Rendering** | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in |
| **Sprite Batching** | Manual (SpriteBatch) | Automatic | Automatic | Automatic | Manual (SpriteBatch) | Automatic | Manual (SpriteBatch) | Automatic |
| **Tilemaps** | Built-in + Tiled/LDtk bridges | Built-in + editor | Built-in | Third-party | Third-party (STI) | Built-in + editor | Third-party | Third-party |
| **Custom Shaders** | GLSL 330 | Godot Shading Lang + visual | ShaderLab/HLSL + ShaderGraph | WGSL | GLSL | GLSL | HLSL (.fx) | GLSL |
| **Material System** | Built-in (6 effects + composer) | ShaderMaterial | Full material pipeline | Material2d trait | Manual | Built-in materials | Effect system | Material API |
| **2D Lighting** | Built-in (point, spot, shadows) | Built-in (point, directional) | URP 2D Lights | Third-party | Third-party | Third-party | Third-party | Third-party |
| **Normal Mapping** | Built-in (diffuse + specular) | Built-in (CanvasTexture) | Built-in | Third-party | Third-party | Third-party | Third-party | Third-party |
| **Soft Shadows** | Built-in (Gaussian blur) | Filter modes (PCF) | Built-in | Third-party | Third-party | N/A | N/A | N/A |
| **Particles** | Built-in (CPU) | Built-in (GPU + CPU) | Built-in (GPU) | Third-party | Built-in (CPU) | Built-in + editor | Third-party | Companion crate |
| **Post-Processing** | Built-in (6 effects) | Manual (shader + viewport) | Built-in (full pipeline) | Built-in (bloom, FXAA, etc.) | Manual | Manual | Manual | Manual |
| **Blend Modes** | 4 modes | 5+ modes | Full control | Custom pipeline | 9+ modes | Full control | Full control | Via miniquad |
| **Render Targets** | Built-in | Built-in (SubViewport) | Built-in | Built-in | Built-in (Canvas) | Built-in | Built-in | Built-in |
| **Physics Engine** | Custom (SAT, impulse) | Custom (GodotPhysics) | PhysX / Box2D | Third-party (Rapier) | Built-in (Box2D) | Built-in (Box2D) | Third-party | Third-party (Rapier) |
| **Collision Shapes** | AABB, Circle, Polygon | 8 shape types | Full set | Via Rapier | Box2D shapes | Box2D shapes | Via third-party | Via Rapier |
| **Physics Joints** | 6 types | 3 types (pin, spring, groove) | Full set | Via Rapier (full) | Box2D joints (11) | Box2D joints (5) | Via third-party | Via Rapier |
| **CCD** | Built-in (swept + angular) | Built-in (ray + shape) | Built-in | Via Rapier | Box2D bullet | Box2D bullet | Via third-party | Via Rapier |
| **Raycasting** | Built-in | Built-in (node + API) | Built-in | Via Rapier | Built-in | Built-in | Via third-party | Via Rapier |
| **Sprite Animation** | Built-in (clips + animator) | Built-in (AnimatedSprite2D) | Built-in | Basic built-in | Third-party (anim8) | Built-in (flip-book) | Third-party | Manual |
| **Animation State Machine** | Built-in | Built-in (AnimationTree) | Built-in (Animator) | Built-in (3D-focused) | Third-party | Not built-in | Third-party | N/A |
| **Skeletal Animation** | Not built-in | Built-in (Skeleton2D + IK) | Built-in (2D rigging) | Third-party (Spine) | Third-party (Spine) | Built-in (Spine, Rive) | Third-party (Spine) | N/A |
| **Tweening** | Built-in (19 easings, sequences) | Built-in (Tween class) | Third-party (DOTween) | Third-party | Third-party (flux) | Built-in (go.animate) | Third-party | Third-party |
| **Spatial Audio** | Not built-in | Built-in (AudioStreamPlayer2D) | Built-in | Built-in | Built-in (OpenAL) | Limited | Built-in (3D audio) | N/A |
| **Audio Effects** | Group volumes only | 15+ built-in effects | Full mixer | Third-party (Kira) | Built-in (reverb, chorus, etc.) | Limited | Limited | N/A |
| **Audio Buses** | 3 groups (music, sfx, ui) | Full bus routing | Full mixer | Third-party | Manual | Built-in groups | Limited (XACT) | N/A |
| **Keyboard/Mouse** | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in |
| **Gamepad** | Built-in (4 pads) | Built-in (8 pads, vibration) | Built-in | Built-in | Built-in (vibration) | Built-in | Built-in (4 pads) | Partial |
| **Touch Input** | Not built-in | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in | Built-in |
| **Action Mapping** | Built-in (KB + gamepad) | Built-in (KB + mouse + gamepad) | Built-in (Input System) | Third-party | Third-party | Built-in | Manual | Manual |
| **UI Widgets** | 12 widgets + theming | 30+ widgets + theming | Full UI toolkit | Basic (4 widgets) | Third-party | Built-in (GUI nodes) | Third-party | Built-in (IMGUI) |
| **ECS** | Built-in (sparse-set) | No (scene tree) | No (GameObject) | Built-in (archetype) | Third-party | No (component + msg) | Third-party | Third-party |
| **Parallel Systems** | Built-in (opt-in) | N/A (scene tree) | Job system | Built-in (automatic) | N/A | N/A | N/A | N/A |
| **Scene Management** | Built-in (stack + transitions) | Basic (change scene) | Built-in | States plugin | Manual | Built-in (collections) | Manual | Manual |
| **World Serialization** | Built-in (JSON) | Resource system | Prefabs + scenes | Built-in (RON) | Third-party | Built-in (sys.save) | Manual | Manual (serde) |
| **Event Bus** | Built-in | Built-in (signals) | Built-in | Built-in | Manual | Built-in (msg.post) | Manual | Manual |
| **HTTP Networking** | Not built-in | Built-in | Built-in | Third-party | Built-in (LuaSocket) | Built-in | Via .NET | Via Rust crates |
| **Multiplayer** | Not built-in | Built-in (ENet, WebRTC, RPCs) | Built-in (Netcode) | Third-party | Third-party (enet) | Third-party (Nakama) | Third-party | Third-party |
| **Hot Reload** | Not built-in | Editor-only | Built-in | Built-in (assets) | Manual | Built-in | Not built-in | Not built-in |
| **Asset Pipeline** | Basic (manual loader) | Built-in (auto-import) | Built-in (full pipeline) | Built-in (async, hot reload) | Manual | Built-in (editor + bob) | Built-in (MGCB) | None |
| **Format Bridges** | Aseprite, Tiled, LDtk, TP | Plugins needed | Plugins needed | Third-party | Third-party | Plugins needed | Third-party | Third-party |
| **Profiler** | FPS counter only | Built-in (full profiler) | Built-in (Frame Debugger) | Tracy integration | Third-party | Built-in (real-time) | External (.NET) | External |
| **Visual Editor** | None (framework) | Full IDE | Full IDE | In development | None | Full IDE | MGCB Editor only | None |
| **Windows** | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **macOS** | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Linux** | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Web/WASM** | No | Yes (WebGL 2) | Yes | Yes (WebGPU) | Third-party (love.js) | Yes (production) | Experimental | Yes (first-class) |
| **iOS/Android** | No | Yes | Yes | Experimental | Yes (official) | Yes (first-class) | Yes | Yes (Android) |
| **Consoles** | No | Third-party porting | Yes | No | No | Yes (Switch, PS, Xbox) | Yes (private access) | No |
| **Pathfinding** | Not built-in | Built-in (NavMesh 2D) | Built-in (NavMesh) | Third-party | Third-party | Not built-in | Third-party | Third-party |
| **Localization** | Not built-in | Built-in (TranslationServer) | Built-in | Third-party | Manual | Built-in | Via .NET | Manual |

---

## Critical Gaps

Features that most competing frameworks provide and that significantly limit what games can be built with Agilis.

### 1. Touch & Gesture Input
**Status:** Missing (PlatformC can be extended to support it)
**Priority:** Highest
**Competitors:** All major frameworks support touch input — Godot (InputEventScreenTouch + gestures), Unity (Touch API), Bevy (TouchInput events), Love2D (love.touch module), Defold (multi-touch via input bindings), MonoGame (TouchPanel + gestures), Macroquad (touches())

Agilis has keyboard, mouse, and gamepad but no touch input. This blocks mobile deployment even if platform support were added. PlatformC can be extended to support touch events — this requires platform-specific touch APIs in the InputBackend protocol and InputManager.

**Scope:** Add touch API to PlatformC and expose through InputBackend, add touch state tracking to InputManager, integrate with action mapping.

### 2. Web / Mobile Platform Support
**Status:** Desktop only (Windows, macOS, Linux)
**Priority:** Highest
**Competitors:**
- Web/WASM: Godot, Unity, Bevy, Macroquad (first-class), Defold (production-ready), Love2D (community port)
- iOS/Android: Godot, Unity, Defold (first-class), MonoGame, Love2D (official ports), Macroquad (Android good)
- Consoles: Unity, Defold, MonoGame/FNA (private access), Godot (third-party porting)

Desktop-only limits audience reach significantly. Web export alone would be a major competitive improvement, especially since Macroquad (Rust) has first-class WASM support. Swift's WASM story is still evolving but worth tracking.

---

## Major Gaps

Features expected in mid-level and above frameworks. Missing these creates friction for common game development patterns.

### 3. Spatial / Positional Audio
**Status:** Missing
**Priority:** High
**Competitors:** Godot (AudioStreamPlayer2D with distance attenuation, panning, area-based bus override), Unity (full spatial audio), Bevy (SpatialAudioBundle), Love2D (OpenAL 3D positional audio with distance models, Doppler), MonoGame (AudioListener + AudioEmitter with Apply3D), Defold (limited, manual gain/pan)

No distance attenuation, stereo panning, or listener/source model. Agilis has group volumes, fading, and crossfading but no spatial awareness. Important for atmosphere and gameplay feedback. Most competitors except Defold have robust built-in spatial audio.

**Scope:** Add AudioListener2D + AudioSource2D model, distance attenuation curves (linear, inverse, exponential), stereo panning based on relative position. MiniAudio supports spatial audio that could be leveraged.

### 4. Audio Effects & Buses
**Status:** Basic group volumes only
**Priority:** High
**Competitors:** Godot (15+ built-in effects: reverb, chorus, delay, distortion, EQ, compressor, limiter, filter, phaser, pitch shift, spectrum analyzer — plus full bus routing), Unity (Audio Mixer with full DSP), Love2D (OpenAL effects: reverb, chorus, distortion, echo, flanger, compressor, EQ), Bevy (third-party via bevy_kira_audio), Defold (sound groups with gain)

Godot and Love2D are particularly strong here. Agilis has 3 audio groups (music, sfx, ui) with volume multipliers but no reverb, echo, EQ, low-pass filters, or audio effect chains. The gap with Godot (which has a full audio bus mixer with stackable effects) is significant.

**Scope:** Consider an audio bus system with pluggable effects. Even basic reverb + low-pass filter would cover most 2D game needs.

### 5. Skeletal / Bone Animation
**Status:** Missing (sprite-sheet frame animation only)
**Priority:** Medium-High
**Competitors:** Godot (Skeleton2D + Bone2D + IK solvers + polygon mesh deformation), Unity (2D rigging + animation), Defold (built-in Spine + Rive runtimes), MonoGame (Spine runtime), Bevy (third-party bevy_spine), Love2D (spine-love)

No skeletal animation, no Spine/DragonBones runtime, no bone IK. Spine runtime integration as an optional module would cover the most common use case, since Spine is the industry standard for 2D skeletal animation. Godot's built-in Skeleton2D with IK solvers represents the most complete solution.

### 6. Networking / Multiplayer
**Status:** Missing entirely
**Priority:** Medium-High
**Competitors:** Godot (full multiplayer stack: ENet, WebSocket, WebRTC, RPCs, MultiplayerSpawner, MultiplayerSynchronizer, authority model), Unity (Netcode for GameObjects), Defold (HTTP + WebSocket built-in, Nakama/Colyseus integrations), Love2D (enet bundled, HTTP via LuaSocket), Bevy (third-party replicon/renet/lightyear), MonoGame (via .NET HttpClient + WebSocket)

No sockets, HTTP client, WebSockets, or multiplayer primitives. Even basic HTTP for leaderboards, auth, or cloud saves requires users to roll their own. Godot is the clear leader here with a complete multiplayer framework including RPCs and automatic state synchronization.

**Phased approach:**
1. HTTP client (leaderboards, auth, cloud saves)
2. WebSocket support (real-time communication)
3. High-level multiplayer (RPCs, state sync, authority)

### 7. Async Asset Loading
**Status:** Missing (all loads block the main thread)
**Priority:** Medium
**Competitors:** Godot (ResourceLoader.load_threaded_request with progress callbacks), Unity (Addressables, async loading), Bevy (AssetServer with async loading, reference counting, dependency tracking), Defold (live update system for runtime asset download)

All asset loads in Agilis are synchronous and block the main thread. This causes frame drops during level transitions or when loading large assets. Background loading with progress callbacks would significantly improve the player experience, especially for larger games.

**Scope:** Add async load methods to AssetManager with completion callbacks or Swift async/await. Progress reporting for loading screens.

### 8. Hot Reloading (Assets)
**Status:** Missing
**Priority:** Medium
**Competitors:** Godot (editor-based hot reload for scripts, textures, resources), Unity (full hot reload), Bevy (built-in file watcher with automatic asset reload), Defold (editor pushes changes to running game + Lua script hot reload)

No asset hot reload during development. Every change requires a full rebuild and restart. At minimum, texture and data file hot-reload would significantly improve iteration speed. Bevy's approach (file watcher + automatic reload) is a good model for a framework without an editor.

---

## Moderate Gaps

Nice-to-have features common in engines. Lower priority but improve developer experience and game quality.

### 9. Object Layers in Tiled/LDtk Import
**Status:** Missing (only tile layers imported)
**Priority:** Medium
**Competitors:** Most Tiled integrations support object layers. Godot's community plugins import objects. Defold has community Tiled converters that handle objects.

Object layers (spawn points, trigger zones, paths, collision polygons) from Tiled are silently dropped. Most Tiled workflows rely heavily on object layers for level design metadata. LDtk entity layers have a similar gap.

**Scope:** Parse Tiled object layers into a structured result type (points, rects, polygons, polylines with custom properties). Parse LDtk entity layers similarly.

### 10. Navigation / Pathfinding
**Status:** Missing
**Priority:** Medium
**Competitors:** Godot (NavigationAgent2D + NavigationRegion2D + navigation mesh baking, obstacle avoidance), Unity (NavMesh with 2D workarounds), Bevy (third-party), Love2D (third-party jumper/astar libraries)

No A*, navigation mesh, or steering behaviors. Common in top-down and strategy games. Godot has the most complete built-in solution with NavigationServer2D, navigation regions, agents, and obstacle avoidance. Most frameworks rely on third-party libraries.

**Scope:** At minimum, grid-based A* pathfinding. Navigation mesh support would be more versatile but higher effort.

### 11. GPU Particles
**Status:** CPU particles only
**Priority:** Medium
**Competitors:** Godot (GPUParticles2D with compute shaders, sub-emitters, SDF collision, trail rendering), Unity (VFX Graph, GPU particles), Bevy (third-party bevy_hanabi GPU particles)

Agilis has a functional CPU particle system with pooling, emission shapes, color/scale interpolation, and world-space support. However, GPU particles enable much higher particle counts (thousands to tens of thousands) with features like SDF collision and trail rendering. The CPU approach is fine for most 2D games but limits VFX-heavy effects.

### 12. Physics Interpolation
**Status:** PreviousTransform2D exists but no automatic interpolation
**Priority:** Medium
**Competitors:** Godot 4.3+ (built-in physics interpolation, per-node toggle)

Agilis stores `PreviousTransform2D` each physics tick, but there's no built-in rendering interpolation between physics frames. When the physics tick rate differs from the render frame rate, this causes visual jitter. Godot added automatic physics interpolation in 4.3. This would be a relatively small addition with significant visual quality improvement.

**Scope:** Add optional interpolated rendering using `lerp(previousTransform, currentTransform, alpha)` where alpha is the accumulator fraction within the fixed timestep.

### 13. Runtime Input Remapping UI
**Status:** Missing (action mapping exists, no rebinding UI)
**Priority:** Medium-Low
**Competitors:** Godot (InputMap runtime rebinding), Unity (Input System rebinding composites)

Agilis has action mapping but no built-in UI for players to rebind keys at runtime. Users must build this from scratch. A rebinding widget or utility that works with the existing UI system would be useful.

### 14. Built-in Profiler / Debug Inspector
**Status:** Implemented (DebugOverlay + per-system debug renderers)
**Priority:** Medium-Low
**Competitors:** Godot (CPU/GPU/script/network profiler, remote scene inspector, monitors), Unity (Frame Debugger, profiler), Bevy (Tracy integration + bevy-inspector-egui), Defold (real-time profiler via web interface), Love2D (love.graphics.getStats)

`DebugOverlay` provides FPS graph, entity/component counts, system execution timing, and on-screen log. Five per-system debug renderers (Animation, Tween, Particle, TileMap, UI) visualize subsystem state. `World.systemTimings` exposes per-system timing data. Still missing: memory stats, ECS entity inspector, draw call analysis beyond SpriteBatch stats, external profiler integration (Tracy).

**Remaining scope:** Memory profiling, entity inspector, Tracy or similar external profiler integration.

### 15. Texture Filtering & Mipmapping Control
**Status:** Missing (not yet exposed)
**Priority:** Medium-Low

No API to set per-texture filtering mode (nearest for pixel art, bilinear for smooth). Expose PlatformC support — Agilis just doesn't expose it yet. Small effort, useful for pixel art games that need crisp rendering.

### 16. Rich Text / Bitmap Font Support
**Status:** Basic TTF only
**Priority:** Medium-Low
**Competitors:** Godot (RichTextLabel with BBCode, text effects — wave, rainbow, shake, fade), Unity (TextMeshPro with SDF rendering, rich text), Love2D (BMFont support), Defold (GUI text nodes)

No SDF text rendering, no bitmap fonts (BMFont), no rich text (inline bold, italic, color changes). Godot's RichTextLabel with built-in text effects (wave, rainbow, shake) is the gold standard. Even basic BBCode-style inline formatting would be a significant improvement.

### 17. Localization / Internationalization
**Status:** Missing
**Priority:** Medium-Low
**Competitors:** Godot (TranslationServer with CSV/PO files, RTL text, BiDi, font fallback), Unity (Localization package), Defold (built-in)

No localization system. Games targeting multiple languages need to build string tables and translation lookup from scratch. A lightweight key-based translation system with CSV/JSON lookup would cover most needs.

---

## Minor Gaps

Polish features and advanced use cases. Low priority but worth tracking.

| Feature | Notes | Top Competitor Reference |
|---|---|---|
| Animation blending / crossfade | Can't smoothly blend between two animation clips | Godot (AnimationTree blend trees, BlendSpace1D/2D) |
| Immediate-mode UI option | Only retained-mode; no built-in immediate-mode UI | Macroquad (built-in IMGUI), Bevy (bevy_egui) |
| Screen reader / accessibility | No AccessKit or screen reader support | Godot (basic focus navigation), Unity (UGUI accessibility) |
| Asset packing / bundling | No way to pack assets into a single archive for distribution | Godot (PCK files), Defold (automatic bundling) |
| Sprite atlasing tool | Must use external tools (TexturePacker); no built-in atlas packer | Godot (auto-import atlas), Defold (auto atlas packing) |
| Trail / line renderers | No built-in trail effect for projectiles or motion trails | Godot (Line2D, GPU particle trails) |
| Multiple music tracks | AudioManager supports only single-track music playback | Godot (AudioStreamSynchronized for parallel tracks) |
| Runtime texture atlasing | Can't dynamically atlas small textures to reduce draw calls | Unity (runtime atlas), Bevy (TextureAtlas) |
| Scripting language | No embedded Lua/Wren scripting for rapid iteration or modding | Godot (GDScript + C# + GDExtension) |
| DirectionalLight2D | Only point and spot lights; no infinite directional light | Godot (DirectionalLight2D for sunlight) |
| Camera2D features | Basic camera; no smoothing, drag margins, or screen shake | Godot (Camera2D with smoothing, limits, drag) |
| Sub-state machines | Animation state machine doesn't support nested sub-states | Godot (sub-state machines in AnimationTree) |
| Blend trees | No parameter-driven animation blending | Godot (BlendSpace1D/2D, Blend2/3 nodes) |
| MultiMesh / Instancing | No GPU instancing for thousands of identical sprites | Godot (MultiMeshInstance2D) |

---

## Agilis's Competitive Strengths

Features where Agilis holds its own or excels compared to competitors:

### Architecture & Design
- **Zero external dependencies** — fully self-contained, no dependency management issues. Competitors like Bevy have deep dependency trees (100+ crates), and MonoGame requires NuGet packages for most features.
- **Type-safe ECS in Swift** — generational IDs, sparse sets, compile-time query safety, 1-8 component forEach overloads. Stronger ergonomics than Bevy's ECS (which requires understanding archetype internals) while being more structured than Godot's scene tree.
- **Opt-in parallel system scheduling** — ComponentAccess declarations with O(1) conflict detection via ComponentBitset. Bevy has automatic parallel scheduling but requires understanding its scheduling rules. Agilis gives explicit control.
- **Clean backend abstraction** — protocol-based architecture (RenderBackend, AudioBackend, InputBackend) could support Metal/WebGPU/Vulkan backends without changing game code.

### Physics & Collision
- **Custom physics from scratch** — SAT-based collision, not a Box2D wrapper. Full control over the pipeline. Godot also has custom physics (GodotPhysics2D), but Agilis's physics are more transparent and hackable.
- **6 joint types** — revolute, distance, weld, prismatic, rope, motor with sequential impulse solver, warm starting, and Baumgarte stabilization. More joint variety than Godot (3 built-in: pin, spring, groove). Comparable to Love2D's Box2D joints (11 types).
- **Continuous collision detection** — swept shape CCD with exact algorithms for circle/AABB pairs, angular sweep for rotating bodies, and bilateral CCD between two fast-moving bodies. More sophisticated than Godot's ray/shape cast CCD.
- **Spatial queries** — raycast, raycastAll, pointQuery, areaQuery with layer mask filtering. Pure geometry functions in SpatialQuery module.

### Rendering & Visual
- **Material system with shader composition** — Material2D + MaterialLibrary (6 built-in effects) + ShaderBuilder + ShaderComposer + ShaderIncludes (6 GLSL utility libraries) + ComposableEffects. More integrated than Godot's ShaderMaterial (which is powerful but requires writing raw shader code). Better than Bevy, Love2D, MonoGame, Macroquad, and Defold for out-of-the-box material effects.
- **2D lighting with normal mapping & specular** — dynamic point/spot lights, CPU shadow volumes, per-pixel GLSL falloff, tangent-space normal maps, Blinn-Phong specular highlights, soft shadows with Gaussian blur. Comparable to Godot's 2D lighting (which has CanvasTexture normal/specular maps). Better than all frameworks (Bevy, Love2D, MonoGame, Macroquad, Defold) which have no built-in 2D lighting.
- **Post-processing pipeline** — 6 built-in effects (bloom, chromatic aberration, color grading, vignette, scanlines, pixelate) with ping-pong render targets and custom effect protocol. Better out-of-the-box than Godot (which requires manual viewport + shader setup for 2D post-processing), Love2D, MonoGame, Macroquad, and Defold.

### Animation & Tweening
- **Animation state machine** — declarative state/transition definitions with parameter-driven conditions (bool, float, int, trigger, animation events, time-based), any-state transitions, trigger safety (two-pass evaluation). Comparable to Godot's AnimationTree StateMachine but code-first rather than editor-based.
- **Tweening system** — animate any property with 19 easing functions, sequences, yoyo, repeat, delay, callbacks, custom tweens for user-defined components. Handle-based API. Comparable to Godot's Tween class. Better integrated than Bevy, Love2D, MonoGame, Macroquad (all third-party).

### Game Framework Features
- **Format bridges** — first-class Aseprite, TexturePacker, Tiled, LDtk import with animation and tilemap conversion bridges. Better than any competitor for out-of-the-box format support — Godot, Unity, Bevy, Defold, and MonoGame all require plugins or third-party libraries.
- **Rich UI system** — 12 widgets (label, button, panel, slider, toggle, text input, progress bar, image, scroll container, dropdown, list view, modal dialog) with theming, keyboard/gamepad navigation, nine-patch rendering, overlay system. More complete than Bevy (4 basic widgets), Love2D (none), Macroquad (basic IMGUI). Comparable to Defold's GUI system. Less extensive than Godot (30+ widgets) or Unity.
- **World serialization** — save/load ECS state to JSON with 12 built-in serializable component types + custom component registration, entity hierarchy preservation, name/tag metadata. Uncommon at framework level — only Bevy (DynamicScene) and Godot (Resource system) have comparable built-in serialization.
- **Scene transitions** — built-in animated transitions (fade, flash, custom) with duration, color, easing, and midpoint callbacks. Godot has no built-in transition system. Better than most frameworks.
- **Time scaling** — single-property game speed control affecting all fixed-timestep systems. Simple but effective; competitors handle this differently (Godot: Engine.time_scale, Unity: Time.timeScale).
- **Event bus** — lightweight pub/sub on World for decoupled game logic. Type-keyed, re-entrant safe.
- **Comprehensive test suite** — 1350+ tests across 206 suites using Swift Testing framework. Unusual level of test coverage for a game framework.

---

## Recommended Implementation Order

Prioritized by value unlocked vs. implementation effort:

| Priority | Feature | Effort | Value | Notes |
|---|---|---|---|---|
| 1 | Touch input | Small | Very High | Add touch support to PlatformC; unblocks mobile |
| 2 | Texture filtering control | Small | Medium | Expose ANGLE texture filtering; quick win for pixel art games |
| 3 | Object layers (Tiled/LDtk) | Small | Medium | Completes the level design pipeline |
| 4 | Physics interpolation | Small | Medium | Smooth rendering between physics ticks; PreviousTransform2D already exists |
| 5 | Spatial audio | Medium | High | Significant atmosphere improvement; leverage MiniAudio support |
| 6 | Audio effects & buses | Medium | Medium-High | At minimum reverb + filter; large gap vs. Godot/Love2D |
| 7 | Async asset loading | Medium | Medium | Background loading with progress; prevents frame drops |
| 8 | HTTP networking | Medium | Medium | Leaderboards, auth, cloud saves |
| 9 | Navigation / pathfinding | Medium | Medium | Grid-based A* at minimum |
| 10 | Hot reload (assets) | Medium | Medium | Major DX improvement; file watcher + texture reload |
| 11 | Rich text / bitmap fonts | Medium | Medium-Low | BBCode-style inline formatting |
| 12 | Localization | Small-Medium | Medium-Low | Key-based string lookup with CSV/JSON |
| 13 | Input remapping UI | Small-Medium | Medium-Low | Rebinding widget for existing action mapping |
| 14 | Profiler / debug tools | Medium | Medium-Low | System timing, entity counts, draw call overlay |
| 15 | Skeletal animation | Large | Medium | Spine runtime integration as optional module |
| 16 | Web/WASM export | Large | Very High | Massive reach improvement; depends on Swift WASM maturity |
| 17 | GPU particles | Large | Medium | Higher particle counts; compute shader dependency |
| 18 | Multiplayer (WebSocket + RPCs) | Large | Medium | After HTTP; real-time communication |

---

## Completed Features (Previously on Roadmap)

These items were on the original roadmap and have been fully implemented:

| Feature | Implementation Summary |
|---|---|
| Shader / Material System | Material2D, MaterialLibrary (6 effects), ShaderBuilder, ShaderComposer, ShaderIncludes (6 GLSL libraries), ComposableEffects, MaterialTemplate, MaterialContext |
| 2D Lighting & Shadows | LightingSystem with point/spot lights, CPU shadow volumes, GLSL falloff, normal mapping, Blinn-Phong specular, soft shadows (Gaussian blur, quality levels) |
| Physics Joints | 6 types (revolute, distance, weld, prismatic, rope, motor) with sequential impulse solver, warm starting, breaking joints, debug rendering |
| CCD | Swept shape CCD, angular sweep, bilateral CCD, exact circle/AABB algorithms, conservative polygon fallback |
| Tweening | TweenSystem with 19 easings, sequences, yoyo, repeat, delay, callbacks, custom tweens, entity death cleanup |
| Animation State Machine | AnimationStateMachine component with parameter-driven transitions, any-state transitions, trigger safety, event bus integration |
| Post-Processing Pipeline | PostProcessPipeline with 6 effects (bloom, chromatic aberration, color grading, vignette, scanlines, pixelate), ping-pong buffers, custom effect protocol |

---

---

## Antipatterns Needing Fixes

Issues identified via deep codebase analysis. Organized by severity — critical items can cause crashes or data corruption, high items are serious bugs or fragile patterns, medium items hurt maintainability.

### Critical — Likely Crashes or Data Corruption

| # | Issue | Location | Description |
|---|---|---|---|
| 1 | Division by zero in physics | `NarrowPhase.swift:75,122,214`, `SpatialQuery.swift:212,264,537`, `SweptCollision.swift:238,262,313,333` | Multiple `.normalized` and manual division calls without guarding against zero-length vectors. Produces NaN that silently propagates through the entire physics pipeline. |
| 2 | Force unwrap in `smallestStore` | `Query.swift:515` | `stores.min(by:)!` in all 8 multi-component `forEach` variants (3-8 components). Crashes if called with empty varargs. |
| 3 | Force cast in event bus | `World.swift:492` | `handler(event as! T)` — type-erased event handlers use force downcast. Registration/emission type mismatch crashes at runtime with no diagnostic. |
| 4 | Array out-of-bounds in AnimationSystem | `AnimationSystem.swift:84-85` | `animator.clip.frames[animator.currentFrameIndex]` without validating index stays in bounds after clip swap. Crashes if new clip has fewer frames. |
| 5 | Unguarded String index in UITextInput | `UITextInput.swift:59-60` | `text.index(text.startIndex, offsetBy: cursorIndex)` with no bounds validation. Fatal error if `cursorIndex > text.count`. |
| 6 | `@unchecked Sendable` bypasses concurrency safety | `World.swift:547-557` | `UnsafeSystemRef` and `UnsafeBufferRef` disable the compiler's data-race checker. Incorrect `componentAccess` declarations cause silent data races. |
| 7 | Mutable shared state in ComponentRegistry | `ComponentRegistry.swift:9-25` | `typeToIndex` and `nextIndex` mutated freely, marked `@unchecked Sendable`. New component types encountered during parallel scheduling cause data races. |

### High — Serious Bugs or Fragile Patterns

| # | Issue | Location | Description |
|---|---|---|---|
| 8 | Stale entity references from hierarchy | `World.swift:393` | Entity handles reconstructed from `UInt32` indices don't verify generation. Recycled slots produce use-after-free semantics. |
| 9 | Joint entity liveness not verified | `PhysicsWorld2D.swift:313-348` | Dead entities detected but constraint solving continues that frame with stale data. JointSolver may access nil components. |
| 10 | CCD skin nudge division by near-zero | `PhysicsWorld2D.swift:599-601` | Uses `> 0` instead of epsilon. For `dispLen = 1e-20`, division produces infinity. |
| 11 | Float equality in physics dispatch | `PhysicsWorld2D.swift:278,295,345,358` | `if rotA == 0 && rotB == 0` — accumulated floating-point error means rotation is never exactly `0.0`. Bypasses optimized AABB path. |
| 12 | `precondition` only fires in debug | `CollisionShape.swift:20-22` | `ConvexPolygon` vertex count check skipped in release builds. Subsequent `vertices[0]` crashes on empty polygons. |
| 13 | Negative index wraps in WorldSerializer | `WorldSerializer.swift:167-182` | `UInt32(truncating: -1)` gives `4294967295`. Corrupted save data creates entities at wrapped indices without error. |
| 14 | RingBuffer entry ordering bug | `RingBufferLogOutput.swift:40-51` | On first wrap-around, `writeIndex` may not correctly identify the oldest entry, producing out-of-order or missing log lines. |
| 15 | UIContext focus index stale after removal | `UIContext.swift:137-143` | If nodes removed, `focusIndex` can point past `focusOrder` bounds. Next focus navigation crashes. |
| 16 | UIModalDialog empty focus crash | `UIModalDialog.swift:252` | `modalFocusOrder[modalFocusIndex]` without checking `isEmpty`. Modal with no buttons crashes on keyboard input. |
| 17 | Silent state machine failures | `AnimationStateMachineSystem.swift:63-66` | Transitioning to a non-existent state name silently fails. Animator left with previous clip, corrupting game logic. |
| 18 | AudioManager tracks invalid handles | `AudioManager.swift:141-142` | If `backend.playSound()` returns `.invalid`, the dead handle is still tracked, leaking memory. |
| 19 | NaN from degenerate polygon normals | `NarrowPhase.swift:469` | Zero-length edge produces NaN normal via `.normalized`. Corrupts all subsequent SAT tests. |
| 20 | Render target texture ownership confusion | `Renderer.swift` | RT textures bridged into `textures` dict. Double-free possible if `destroyTexture()` called before `destroyRenderTarget()`. Guard exists but is fragile. |

### Medium — Antipatterns & Maintainability

| # | Issue | Location | Description |
|---|---|---|---|
| 21 | God object: World | `World.swift` (541 lines) | Covers entity allocation, component storage, hierarchy, metadata, systems, events, and parallel scheduling in one file. |
| 22 | Duplicated geometry helpers | `NarrowPhase.swift`, `SpatialQuery.swift`, `SweptCollision.swift`, `PhysicsDebugRenderer.swift` | `transformVertices()`, `rotateNormals()`, `computeNormals()` copy-pasted across 4 files. Bug fixes don't propagate. |
| 23 | Boilerplate forEach overloads | `Query.swift` (517 lines, 16 methods) | Swift 5.9+ parameter packs could replace all 16 overloads with ~1 generic implementation. |
| 24 | Stringly-typed state machine | `AnimationStateMachine.swift` | State names and parameter names are raw `String`. Typos cause silent runtime failures. |
| 25 | Asset cache uses `Any` | `AssetManager.swift:5-6` | `private var cache: [String: Any]` — same path cached as different types causes silent `as? T` failure. |
| 26 | Inconsistent epsilon values | `JointStore.swift`, `PhysicsWorld2D.swift`, `SweptCollision.swift`, `JointSolver.swift` | `0.0001`, `1e-6`, `1e-8`, `1e-10` used inconsistently. Should be unified constants. |
| 27 | CCW winding assumed, never validated | `NarrowPhase.swift`, `SpatialQuery.swift`, `PhysicsDebugRenderer.swift` | CW polygons produce inward normals, breaking collision detection silently. No enforcement. |
| 28 | Integer overflow in tween handles | `TweenSystem.swift:597-598`, `TweenStore.swift:31-32` | `UInt32` IDs increment without overflow detection. After 4B tweens, IDs collide with active handles. |
| 29 | ParticleEmitter invalid ranges | `ParticleEmitter.swift:142-182` | No validation that `ClosedRange` properties are valid. `Float.random(in: 2.0...1.0)` panics. |
| 30 | UILayoutEngine cache not invalidated | `UILayoutEngine.swift:51-69` | `cachedTextSize` not invalidated when label text changes at runtime. Layout wrong until next `UIContext.update()`. |
| 31 | Spatial hash grid integer overflow | `SpatialHashGrid.swift:53-56` | `floorf() -> Int` cast on extreme coordinates overflows. No validation that coordinates are reasonable. |

### Low — Minor Issues

| # | Issue | Location | Description |
|---|---|---|---|
| 32 | Entity generation overflow | `World.swift:67` | Wrapping `&+= 1` after 2^32 recyclings causes ABA problem. Unlikely but undocumented. |
| 33 | InputManager iterates all enum cases | `InputManager.swift:52,61,72` | ~100+ keys polled every frame even if none pressed. |
| 34 | UILayoutEngine no infinite-loop guard | `UILayoutEngine.swift` | `sizeThatFits()` calling `invalidateLayout()` can deadlock. |
| 35 | FileLogOutput silently drops entries | `FileLogOutput.swift:34-35` | `fputs()`/`fflush()` fail silently if disk full after init. |
| 36 | No system priority validation | `World.swift:264-276` | Any `Int` accepted, no range documented or enforced. |
| 37 | `Set<String>` for entity tags | `EntityMetadata.swift:14` | Allocation-heavy for thousands of entities. |
| 38 | Sequence handle encoding undocumented | `TweenSystem.swift:609,618,634,680` | High bit `0x8000_0000` distinguishes sequences from tweens. Manually constructed handles could collide. |

---

*Last updated: 2026-03-03*
*Compared against: Godot 4.4+, Unity 6, Bevy 0.15+, MonoGame/FNA, Love2D 11.5, Defold 1.9.x, Macroquad 0.4.x*
