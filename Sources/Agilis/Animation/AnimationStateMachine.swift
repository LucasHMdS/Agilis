import AgilisCore

// MARK: - Animation State

/// A named state in an animation state machine, mapping to an animation clip.
///
/// Each state defines which `AnimationClip` plays when the state machine
/// enters that state, along with an optional speed override.
public struct AnimationState: Sendable, Equatable, Codable {
    /// The unique name of this state (e.g., "idle", "walk", "attack").
    public var name: String
    /// The animation clip to play in this state.
    public var clip: AnimationClip
    /// Playback speed multiplier (default 1.0).
    public var speed: Float

    public init(name: String, clip: AnimationClip, speed: Float = 1.0) {
        self.name = name
        self.clip = clip
        self.speed = speed
    }
}

// MARK: - Transition Condition

/// A condition that must be satisfied for an animation transition to fire.
///
/// Multiple conditions on a single transition use AND logic — all must pass.
/// For OR logic, create multiple transitions from the same source state.
///
/// ## Condition Types
/// - **Parameter checks**: `.boolEquals`, `.floatGreater`, `.floatLess`, `.intEquals`
/// - **Triggers**: `.trigger` — consumed (auto-cleared) when the transition fires
/// - **Animation events**: `.animationFinished`, `.animationLooped`
/// - **Time-based**: `.afterTime` — seconds spent in the current state
public enum TransitionCondition: Sendable, Equatable, Codable {
    /// True when the named bool parameter equals the expected value.
    case boolEquals(String, Bool)
    /// True when the named float parameter is greater than the threshold.
    case floatGreater(String, Float)
    /// True when the named float parameter is less than the threshold.
    case floatLess(String, Float)
    /// True when the named int parameter equals the expected value.
    case intEquals(String, Int)
    /// True when the named trigger is set. The trigger is consumed (auto-cleared)
    /// only when **all** conditions on the transition pass.
    case trigger(String)
    /// True when the current animation has finished (one-shot completed).
    case animationFinished
    /// True when the current animation has looped (fires for one tick).
    case animationLooped
    /// True when time in the current state exceeds the given seconds.
    case afterTime(Float)
}

// MARK: - Animation Transition

/// Defines a transition between two states in the animation state machine.
///
/// Transitions are checked each tick in definition order. The first transition
/// whose conditions all pass is taken. Any-state transitions are checked
/// before per-state transitions.
public struct AnimationTransition: Sendable, Equatable, Codable {
    /// Source state name. Empty string indicates an any-state transition (internal).
    public var from: String
    /// Destination state name.
    public var to: String
    /// Conditions that must all be true for this transition to fire (AND logic).
    public var conditions: [TransitionCondition]
    /// Optional exit time gate. If set, the transition only fires when the
    /// animator's progress (0–1) is at or beyond this value.
    /// `nil` means the transition can fire at any point in the animation.
    public var exitTime: Float?

    public init(
        from: String,
        to: String,
        conditions: [TransitionCondition],
        exitTime: Float? = nil
    ) {
        self.from = from
        self.to = to
        self.conditions = conditions
        self.exitTime = exitTime
    }
}

// MARK: - Parameter Value

/// Storage for a named parameter in the animation state machine.
public enum ParameterValue: Sendable, Equatable, Codable {
    /// A boolean parameter.
    case bool(Bool)
    /// A floating-point parameter.
    case float(Float)
    /// An integer parameter.
    case int(Int)
    /// A trigger parameter. When `true`, it is consumed (set to `false`)
    /// the first time a transition successfully evaluates it.
    case trigger(Bool)
}

// MARK: - Animation State Changed Event

/// Event emitted when an animation state machine transitions between states.
///
/// Subscribe via `world.on(AnimationStateChanged.self)` for decoupled logic.
///
/// ## Usage
/// ```swift
/// world.on(AnimationStateChanged.self) { event in
///     if event.to == "death" {
///         spawnDeathParticles(at: event.entity)
///     }
/// }
/// ```
public struct AnimationStateChanged: Event {
    /// The entity whose state machine transitioned.
    public let entity: Entity
    /// The state that was exited.
    public let from: String
    /// The state that was entered.
    public let to: String
}

// MARK: - Animation State Machine (Component)

/// A declarative animation state machine that manages transitions between
/// animation clips on an entity's `SpriteAnimator`.
///
/// Define states (each mapping to an `AnimationClip`), transitions between
/// them with conditions, and set parameters from game logic. The
/// `AnimationStateMachineSystem` evaluates transitions each tick and
/// switches clips automatically.
///
/// ## Usage
/// ```swift
/// var sm = AnimationStateMachine(defaultState: "idle")
/// sm.addState("idle", clip: idleClip)
/// sm.addState("walk", clip: walkClip)
/// sm.addTransition(from: "idle", to: "walk",
///     conditions: [.floatGreater("speed", 0.1)])
/// sm.addTransition(from: "walk", to: "idle",
///     conditions: [.floatLess("speed", 0.1)])
///
/// world.addComponent(sm, to: entity)
///
/// // Game logic — just set parameters
/// world.updateComponent(AnimationStateMachine.self, on: entity) { sm in
///     sm.setFloat("speed", velocity.length)
/// }
/// ```
public struct AnimationStateMachine: Component, Sendable, SerializableComponent {
    public static let componentName = "AnimationStateMachine"

    // MARK: - Definition

    /// All states, keyed by name.
    public var states: [String: AnimationState]

    /// Per-state transitions (checked after any-state transitions).
    /// Order matters — first matching transition wins.
    public var transitions: [AnimationTransition]

    /// Transitions that can fire from any current state.
    /// Checked before per-state transitions. Skips if destination == current state.
    public var anyStateTransitions: [AnimationTransition]

    /// The name of the default/entry state.
    public var defaultStateName: String

    // MARK: - Runtime State

    /// The name of the current active state.
    public var currentStateName: String

    /// Seconds elapsed since entering the current state.
    public var timeInState: Float

    /// The state that was active before the most recent transition.
    public var previousStateName: String?

    /// Whether the system needs to initialize this component on first tick.
    internal var needsInitialization: Bool

    // MARK: - Parameters

    /// Named parameters used by transition conditions.
    public var parameters: [String: ParameterValue]

    // MARK: - Init

    /// Creates an animation state machine with the given default state.
    ///
    /// - Parameter defaultState: The name of the initial state.
    ///   Must match a state added via `addState(_:clip:speed:)`.
    public init(defaultState: String) {
        self.states = [:]
        self.transitions = []
        self.anyStateTransitions = []
        self.defaultStateName = defaultState
        self.currentStateName = defaultState
        self.timeInState = 0
        self.previousStateName = nil
        self.needsInitialization = true
        self.parameters = [:]
    }

    // MARK: - State Definition

    /// Add a state to the state machine.
    ///
    /// - Parameters:
    ///   - name: Unique state name.
    ///   - clip: The animation clip to play in this state.
    ///   - speed: Playback speed multiplier (default 1.0).
    @discardableResult
    public mutating func addState(
        _ name: String,
        clip: AnimationClip,
        speed: Float = 1.0
    ) -> Self {
        states[name] = AnimationState(name: name, clip: clip, speed: speed)
        return self
    }

    // MARK: - Transition Definition

    /// Add a transition between two named states.
    ///
    /// Transitions are evaluated in definition order each tick. The first
    /// transition whose conditions all pass is taken.
    ///
    /// - Parameters:
    ///   - from: Source state name.
    ///   - to: Destination state name.
    ///   - conditions: Conditions that must all be true (AND logic).
    ///   - exitTime: Optional progress gate (0–1). The transition only fires
    ///     when the animator's progress is at or beyond this value.
    @discardableResult
    public mutating func addTransition(
        from: String,
        to: String,
        conditions: [TransitionCondition],
        exitTime: Float? = nil
    ) -> Self {
        transitions.append(AnimationTransition(
            from: from, to: to,
            conditions: conditions,
            exitTime: exitTime
        ))
        return self
    }

    /// Add a transition that can fire from any current state.
    ///
    /// Any-state transitions are checked before per-state transitions.
    /// They will not fire if the destination is already the current state
    /// (prevents infinite loops).
    ///
    /// - Parameters:
    ///   - to: Destination state name.
    ///   - conditions: Conditions that must all be true.
    ///   - exitTime: Optional progress gate (0–1).
    @discardableResult
    public mutating func addAnyStateTransition(
        to: String,
        conditions: [TransitionCondition],
        exitTime: Float? = nil
    ) -> Self {
        anyStateTransitions.append(AnimationTransition(
            from: "",
            to: to,
            conditions: conditions,
            exitTime: exitTime
        ))
        return self
    }

    // MARK: - Parameters

    /// Set a boolean parameter.
    public mutating func setBool(_ name: String, _ value: Bool) {
        parameters[name] = .bool(value)
    }

    /// Get a boolean parameter (returns `false` if not set or wrong type).
    public func getBool(_ name: String) -> Bool {
        if case .bool(let v) = parameters[name] { return v }
        return false
    }

    /// Set a float parameter.
    public mutating func setFloat(_ name: String, _ value: Float) {
        parameters[name] = .float(value)
    }

    /// Get a float parameter (returns `0` if not set or wrong type).
    public func getFloat(_ name: String) -> Float {
        if case .float(let v) = parameters[name] { return v }
        return 0
    }

    /// Set an integer parameter.
    public mutating func setInt(_ name: String, _ value: Int) {
        parameters[name] = .int(value)
    }

    /// Get an integer parameter (returns `0` if not set or wrong type).
    public func getInt(_ name: String) -> Int {
        if case .int(let v) = parameters[name] { return v }
        return 0
    }

    /// Set a trigger parameter. Triggers are automatically consumed (cleared)
    /// when a transition that checks them successfully fires.
    public mutating func setTrigger(_ name: String) {
        parameters[name] = .trigger(true)
    }

    /// Check if a trigger is currently set (without consuming it).
    public func isTriggerSet(_ name: String) -> Bool {
        if case .trigger(true) = parameters[name] { return true }
        return false
    }

    // MARK: - Internal: Trigger Consumption

    /// Check if a trigger is set. Does NOT consume it.
    internal func checkTrigger(_ name: String) -> Bool {
        if case .trigger(true) = parameters[name] { return true }
        return false
    }

    /// Consume a trigger (set it to false).
    internal mutating func consumeTrigger(_ name: String) {
        parameters[name] = .trigger(false)
    }

    // MARK: - Read-Only Accessors

    /// The current state definition, or `nil` if the state name is not found.
    public var currentState: AnimationState? {
        states[currentStateName]
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case states, transitions, anyStateTransitions, defaultStateName
        case currentStateName, timeInState, previousStateName, parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(states, forKey: .states)
        try container.encode(transitions, forKey: .transitions)
        try container.encode(anyStateTransitions, forKey: .anyStateTransitions)
        try container.encode(defaultStateName, forKey: .defaultStateName)
        try container.encode(currentStateName, forKey: .currentStateName)
        try container.encode(timeInState, forKey: .timeInState)
        try container.encodeIfPresent(previousStateName, forKey: .previousStateName)
        try container.encode(parameters, forKey: .parameters)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.states = try container.decode([String: AnimationState].self, forKey: .states)
        self.transitions = try container.decode([AnimationTransition].self, forKey: .transitions)
        self.anyStateTransitions = try container.decode([AnimationTransition].self, forKey: .anyStateTransitions)
        self.defaultStateName = try container.decode(String.self, forKey: .defaultStateName)
        self.currentStateName = try container.decode(String.self, forKey: .currentStateName)
        self.timeInState = try container.decode(Float.self, forKey: .timeInState)
        self.previousStateName = try container.decodeIfPresent(String.self, forKey: .previousStateName)
        self.parameters = try container.decode([String: ParameterValue].self, forKey: .parameters)
        self.needsInitialization = false  // Already initialized from saved state
    }
}

// MARK: - Type-Safe Identifiers

/// Strongly-typed state identifier for compile-time-safe state machine configuration.
///
/// Define states as static properties for autocomplete and typo prevention:
/// ```swift
/// extension StateID {
///     static let idle = StateID("idle")
///     static let walk = StateID("walk")
/// }
/// ```
public struct StateID: Hashable, Sendable, Codable, ExpressibleByStringLiteral {
    public let name: String

    public init(_ name: String) { self.name = name }
    public init(stringLiteral value: String) { self.name = value }
}

/// Strongly-typed parameter identifier for compile-time-safe parameter access.
///
/// The phantom type `T` indicates the expected parameter kind:
/// ```swift
/// extension ParameterID where T == Float {
///     static let speed = ParameterID("speed")
/// }
/// ```
public struct ParameterID<T>: Hashable, Sendable {
    public let name: String

    public init(_ name: String) { self.name = name }
}

// MARK: - Type-Safe Convenience API

extension AnimationStateMachine {

    // MARK: State Definition

    /// Add a state using a typed `StateID`.
    @discardableResult
    public mutating func addState(
        _ id: StateID,
        clip: AnimationClip,
        speed: Float = 1.0
    ) -> Self {
        addState(id.name, clip: clip, speed: speed)
    }

    // MARK: Transition Definition

    /// Add a transition between two typed state IDs.
    @discardableResult
    public mutating func addTransition(
        from: StateID,
        to: StateID,
        conditions: [TransitionCondition],
        exitTime: Float? = nil
    ) -> Self {
        addTransition(from: from.name, to: to.name, conditions: conditions, exitTime: exitTime)
    }

    /// Add an any-state transition using a typed state ID.
    @discardableResult
    public mutating func addAnyStateTransition(
        to: StateID,
        conditions: [TransitionCondition],
        exitTime: Float? = nil
    ) -> Self {
        addAnyStateTransition(to: to.name, conditions: conditions, exitTime: exitTime)
    }

    // MARK: Typed Parameter Setters/Getters

    public mutating func setBool(_ param: ParameterID<Bool>, _ value: Bool) {
        setBool(param.name, value)
    }

    public func getBool(_ param: ParameterID<Bool>) -> Bool {
        getBool(param.name)
    }

    public mutating func setFloat(_ param: ParameterID<Float>, _ value: Float) {
        setFloat(param.name, value)
    }

    public func getFloat(_ param: ParameterID<Float>) -> Float {
        getFloat(param.name)
    }

    public mutating func setInt(_ param: ParameterID<Int>, _ value: Int) {
        setInt(param.name, value)
    }

    public func getInt(_ param: ParameterID<Int>) -> Int {
        getInt(param.name)
    }

    public mutating func setTrigger(_ param: ParameterID<Bool>) {
        setTrigger(param.name)
    }

    public func isTriggerSet(_ param: ParameterID<Bool>) -> Bool {
        isTriggerSet(param.name)
    }
}

// MARK: - Type-Safe TransitionCondition Factories

extension TransitionCondition {
    /// Type-safe bool parameter condition.
    public static func boolEquals(_ param: ParameterID<Bool>, _ expected: Bool) -> TransitionCondition {
        .boolEquals(param.name, expected)
    }

    /// Type-safe float greater-than condition.
    public static func floatGreater(_ param: ParameterID<Float>, _ threshold: Float) -> TransitionCondition {
        .floatGreater(param.name, threshold)
    }

    /// Type-safe float less-than condition.
    public static func floatLess(_ param: ParameterID<Float>, _ threshold: Float) -> TransitionCondition {
        .floatLess(param.name, threshold)
    }

    /// Type-safe int equality condition.
    public static func intEquals(_ param: ParameterID<Int>, _ expected: Int) -> TransitionCondition {
        .intEquals(param.name, expected)
    }

    /// Type-safe trigger condition.
    public static func trigger(_ param: ParameterID<Bool>) -> TransitionCondition {
        .trigger(param.name)
    }
}
