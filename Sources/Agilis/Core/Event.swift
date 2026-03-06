/// A marker protocol for events in the pub/sub event bus.
///
/// Events are simple data types (structs recommended) that carry information
/// about something that happened in the game. They are emitted via
/// `World.emit(_:)` and received by handlers registered with `World.on(_:_:)`.
///
/// ## Defining Events
/// ```swift
/// struct PlayerDied: Event {
///     let entity: Entity
///     let killedBy: Entity?
/// }
///
/// struct ScoreChanged: Event {
///     let oldScore: Int
///     let newScore: Int
/// }
/// ```
///
/// ## Subscribing and Emitting
/// ```swift
/// world.on(PlayerDied.self) { event in
///     print("Player \(event.entity.index) died!")
/// }
///
/// world.emit(PlayerDied(entity: player, killedBy: enemy))
/// ```
///
/// Note: This is separate from component lifecycle events (`onComponentAdded`/
/// `onComponentRemoved`), which are triggered automatically by the ECS.
/// The event bus is for user-defined game events.
public protocol Event {}
