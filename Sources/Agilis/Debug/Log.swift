/// Global logging facade. Dispatches log entries to registered outputs.
///
/// ## Usage
/// ```swift
/// Log.addOutput(ConsoleLogOutput(minimumLevel: .info))
/// Log.info("Physics", "Simulation started with \(bodyCount) bodies")
/// Log.error("Rendering", "Failed to load texture: \(path)")
/// ```
public enum Log {

    /// Global minimum level. Entries below this are discarded before reaching any output.
    nonisolated(unsafe) public static var minimumLevel: LogLevel = .info

    /// Registered log outputs.
    nonisolated(unsafe) public private(set) static var outputs: [LogOutput] = []

    private static let clock = Clock()
    nonisolated(unsafe) private static var initialized = false

    /// Add a log output destination.
    public static func addOutput(_ output: LogOutput) {
        if !initialized {
            // Prime the clock on first use
            _ = clock.totalTime()
            initialized = true
        }
        outputs.append(output)
    }

    /// Remove all registered outputs.
    public static func removeAllOutputs() {
        outputs.removeAll()
    }

    // MARK: - Level-specific methods

    public static func trace(_ category: String, _ message: String) {
        log(level: .trace, category: category, message: message)
    }

    public static func debug(_ category: String, _ message: String) {
        log(level: .debug, category: category, message: message)
    }

    public static func info(_ category: String, _ message: String) {
        log(level: .info, category: category, message: message)
    }

    public static func warn(_ category: String, _ message: String) {
        log(level: .warn, category: category, message: message)
    }

    public static func error(_ category: String, _ message: String) {
        log(level: .error, category: category, message: message)
    }

    // MARK: - Internal

    private static func log(level: LogLevel, category: String, message: String) {
        guard level >= minimumLevel else { return }

        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            timestamp: clock.totalTime()
        )

        for output in outputs {
            guard level >= output.minimumLevel else { continue }
            output.write(entry)
        }
    }
}
