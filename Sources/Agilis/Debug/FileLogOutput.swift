

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Writes log entries to a file on disk.
///
/// Uses C `fopen`/`fprintf`/`fflush` for cross-platform portability (Windows, Linux, macOS).
/// Each entry is written immediately and flushed to avoid data loss on crash.
///
/// ## Usage
/// ```swift
/// if let fileLog = FileLogOutput(path: "game.log", minimumLevel: .debug) {
///     Log.addOutput(fileLog)
/// }
/// ```
public final class FileLogOutput: LogOutput, @unchecked Sendable {

    public var minimumLevel: LogLevel
    private let fileHandle: UnsafeMutablePointer<FILE>

    /// Open a file for logging. Returns `nil` if the file cannot be opened.
    ///
    /// - Parameters:
    ///   - path: File path to write to. Created if it doesn't exist, appended if it does.
    ///   - minimumLevel: Minimum log level to write.
    public init?(path: String, minimumLevel: LogLevel = .debug) {
        self.minimumLevel = minimumLevel
        guard let handle = fopen(path, "a") else { return nil }
        self.fileHandle = handle
    }

    deinit {
        fclose(fileHandle)
    }

    public func write(_ entry: LogEntry) {
        let time = String(format: "%.3f", entry.timestamp)
        let line = "[\(time)] [\(entry.level)] [\(entry.category)] \(entry.message)\n"
        fputs(line, fileHandle)
        fflush(fileHandle)
    }
}
