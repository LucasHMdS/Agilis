/// A single log message with metadata.
public struct LogEntry: Sendable {
    /// Severity level of this log entry.
    public let level: LogLevel
    /// Category tag (e.g. "Physics", "Rendering", "ECS").
    public let category: String
    /// The log message.
    public let message: String
    /// Seconds since the logging system was initialized.
    public let timestamp: Double

    public init(level: LogLevel, category: String, message: String, timestamp: Double) {
        self.level = level
        self.category = category
        self.message = message
        self.timestamp = timestamp
    }
}
