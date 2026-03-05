/// Component lifecycle event types.
///
/// Component events are registered on the `World` and fired automatically
/// when components are added to or removed from entities. Events are fired
/// synchronously during `addComponent` and `removeComponent` calls (including
/// during command buffer flush and entity destruction).
///
/// Usage:
/// ```swift
/// world.onComponentAdded(Health.self) { entity, world in
///     print("Entity \(entity.index) gained a Health component")
/// }
///
/// world.onComponentRemoved(Health.self) { entity, world in
///     print("Entity \(entity.index) lost its Health component")
/// }
/// ```
///
/// Note: Event handlers are stored on the `World` and registered via
/// `World.onComponentAdded(_:handler:)` and `World.onComponentRemoved(_:handler:)`.
/// This file exists as documentation; the actual implementation lives in `World.swift`.
