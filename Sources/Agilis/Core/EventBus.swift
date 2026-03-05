/// Lightweight type-keyed event pub/sub system.
///
/// Extracted from `World` to separate event dispatch from entity and
/// component management. World delegates event operations to this type.
///
/// Re-entrant safe: `emit()` iterates a value-type snapshot, so emitting
/// from inside a handler works correctly. Handlers added during emission
/// don't fire for the current call.
internal final class EventBus: @unchecked Sendable {

    /// Type-erased event handler storage. Key = event type, Value = array of optional closures.
    /// Nil entries are slots where handlers were removed via `removeSubscription`.
    private var handlers: [ObjectIdentifier: [((Any) -> Void)?]] = [:]

    /// Subscribe to events of a given type. Returns an opaque subscription for removal.
    @discardableResult
    func on<T: Event>(_ type: T.Type, handler: @escaping (T) -> Void) -> EventSubscription {
        let key = ObjectIdentifier(T.self)
        let erased: (Any) -> Void = { any in
            guard let typed = any as? T else { return }
            handler(typed)
        }
        handlers[key, default: []].append(erased)
        let index = (handlers[key]?.count ?? 1) - 1
        return EventSubscription(typeKey: key, index: index)
    }

    /// Remove a single event handler by its subscription.
    func removeSubscription(_ subscription: EventSubscription) {
        guard var list = handlers[subscription.typeKey],
              subscription.index < list.count else { return }
        list[subscription.index] = nil
        handlers[subscription.typeKey] = list
    }

    /// Emit an event, calling all registered handlers synchronously.
    func emit<T: Event>(_ event: T) {
        let key = ObjectIdentifier(T.self)
        guard let snapshot = handlers[key] else { return }
        for handler in snapshot {
            handler?(event)
        }
    }

    /// Remove all handlers for a specific event type.
    func removeHandlers<T: Event>(for type: T.Type) {
        let key = ObjectIdentifier(T.self)
        handlers.removeValue(forKey: key)
    }

    /// Remove all event handlers for all event types.
    func removeAll() {
        handlers.removeAll()
    }

    /// Compact nil slots from handler arrays to reclaim memory.
    ///
    /// Call periodically (e.g., on scene transitions) to prevent unbounded
    /// growth from repeated subscribe/unsubscribe cycles. Invalidates any
    /// outstanding `EventSubscription` tokens, so only call when no
    /// subscriptions are being held.
    func compact() {
        for (key, list) in handlers {
            let compacted = list.compactMap { $0 }
            if compacted.isEmpty {
                handlers.removeValue(forKey: key)
            } else {
                handlers[key] = compacted
            }
        }
    }
}

/// An opaque token representing a single event handler subscription.
/// Use with `World.removeSubscription(_:)` to unsubscribe.
public struct EventSubscription: Sendable {
    internal let typeKey: ObjectIdentifier
    internal let index: Int
}
