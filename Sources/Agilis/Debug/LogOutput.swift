/// A destination for log entries (console, file, ring buffer, etc.).
///
/// Implement this protocol to create custom log outputs. Each output has its own
/// `minimumLevel` filter — entries below that level are skipped by the `Log` dispatcher.
public protocol LogOutput: AnyObject, Sendable {
    /// Minimum severity level this output will accept.
    var minimumLevel: LogLevel { get set }

    /// Write a log entry to this output.
    ///
    /// Called by `Log` after global and per-output level filtering.
    func write(_ entry: LogEntry)
}
