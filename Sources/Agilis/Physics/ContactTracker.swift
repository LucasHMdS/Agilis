/// Tracks collision pairs across frames to generate began/ongoing/ended events.
///
/// At the start of each physics step, `beginFrame()` clears the current frame data.
/// During the step, `recordCollision()` is called for each detected collision.
/// At the end, `endFrame()` compares current pairs against previous pairs to
/// produce `CollisionEvent`s.
internal final class ContactTracker: @unchecked Sendable {
    deinit {}

    /// Pairs that were colliding last frame.
    private var previousPairs: Set<CollisionPair> = []

    /// Pairs colliding this frame.
    private var currentPairs: Set<CollisionPair> = []

    /// Contact data for current pairs.
    private var currentContacts: [CollisionPair: Contact] = [:]

    /// Clear current frame data. Called at the start of each physics step.
    func beginFrame() {
        currentPairs.removeAll(keepingCapacity: true)
        currentContacts.removeAll(keepingCapacity: true)
    }

    /// Record a collision detected this frame.
    func recordCollision(pair: CollisionPair, contact: Contact) {
        currentPairs.insert(pair)
        currentContacts[pair] = contact
    }

    /// Compare current and previous frame pairs to generate collision events.
    /// Updates `previousPairs` for the next frame.
    ///
    /// - Returns: All collision events for this frame (began, ongoing, ended).
    func endFrame() -> [CollisionEvent] {
        var events: [CollisionEvent] = []
        events.reserveCapacity(currentPairs.count + previousPairs.count)

        // Began + ongoing: pairs in current frame
        for pair in currentPairs {
            let contact = currentContacts[pair]
            if previousPairs.contains(pair) {
                events.append(CollisionEvent(
                    entityA: pair.entityA,
                    entityB: pair.entityB,
                    type: .ongoing,
                    contact: contact
                ))
            } else {
                events.append(CollisionEvent(
                    entityA: pair.entityA,
                    entityB: pair.entityB,
                    type: .began,
                    contact: contact
                ))
            }
        }

        // Ended: pairs that were in previous frame but not current
        for pair in previousPairs where !currentPairs.contains(pair) {
            events.append(CollisionEvent(
                entityA: pair.entityA,
                entityB: pair.entityB,
                type: .ended,
                contact: nil
            ))
        }

        // Swap for next frame — reuses hash table capacity
        swap(&previousPairs, &currentPairs)

        return events
    }

    /// Clear all tracked state.
    func reset() {
        previousPairs.removeAll(keepingCapacity: true)
        currentPairs.removeAll(keepingCapacity: true)
        currentContacts.removeAll(keepingCapacity: true)
    }
}
