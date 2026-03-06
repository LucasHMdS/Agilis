

/// Stores recent log entries in a fixed-size circular buffer.
///
/// Useful for displaying an on-screen log overlay via the `DebugOverlay`.
/// When the buffer is full, the oldest entry is overwritten.
///
/// ## Usage
/// ```swift
/// let ringBuffer = RingBufferLogOutput(capacity: 256, minimumLevel: .debug)
/// Log.addOutput(ringBuffer)
///
/// // Read recent entries for display
/// let recent = ringBuffer.entries  // oldest first
/// ```
public final class RingBufferLogOutput: LogOutput, @unchecked Sendable {

    public var minimumLevel: LogLevel

    /// Maximum number of entries stored.
    public let capacity: Int

    private var buffer: [LogEntry?]
    private var writeIndex: Int = 0
    private var count: Int = 0

    public init(capacity: Int = 256, minimumLevel: LogLevel = .debug) {
        self.minimumLevel = minimumLevel
        self.capacity = capacity
        self.buffer = [LogEntry?](repeating: nil, count: capacity)
    }

    public func write(_ entry: LogEntry) {
        buffer[writeIndex] = entry
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity { count += 1 }
    }

    /// Returns all stored entries, oldest first.
    public var entries: [LogEntry] {
        guard count > 0 else { return [] }
        var result = [LogEntry]()
        result.reserveCapacity(count)
        let start = count < capacity ? 0 : writeIndex
        for i in 0..<count {
            let index = (start + i) % capacity
            if let entry = buffer[index] {
                result.append(entry)
            }
        }
        return result
    }

    /// Number of entries currently stored.
    public var entryCount: Int { count }

    /// Remove all stored entries.
    public func clear() {
        buffer = [LogEntry?](repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }
}
