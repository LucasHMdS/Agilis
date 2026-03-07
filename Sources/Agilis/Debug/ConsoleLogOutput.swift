/// Prints log entries to stdout with level and category tags.
///
/// ## Usage
/// ```swift
/// Log.addOutput(ConsoleLogOutput(minimumLevel: .info))
/// ```
public final class ConsoleLogOutput: LogOutput, @unchecked Sendable {

    deinit {}

    public var minimumLevel: LogLevel

    public init(minimumLevel: LogLevel = .info) {
        self.minimumLevel = minimumLevel
    }

    public func write(_ entry: LogEntry) {
        let time = String(format: "%.3f", entry.timestamp)
        print("[\(time)] [\(entry.level)] [\(entry.category)] \(entry.message)")
    }
}
