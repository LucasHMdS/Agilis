/// Severity level for log messages.
///
/// Ordered from most verbose (`trace`) to most severe (`error`).
/// Used for filtering: only messages at or above the configured minimum level are output.
public enum LogLevel: Int, Comparable, Sendable, CustomStringConvertible {
    case trace = 0
    case debug = 1
    case info = 2
    case warn = 3
    case error = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .trace: return "TRACE"
        case .debug: return "DEBUG"
        case .info:  return "INFO"
        case .warn:  return "WARN"
        case .error: return "ERROR"
        }
    }
}
