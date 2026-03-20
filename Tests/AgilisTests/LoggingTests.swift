@testable import Agilis
import Testing

// MARK: - LogLevel Tests

@Suite("LogLevel Tests")
struct LogLevelTests {

    @Test("Levels are ordered by severity")
    func ordering() {
        #expect(LogLevel.trace < LogLevel.debug)
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warn)
        #expect(LogLevel.warn < LogLevel.error)
    }

    @Test("Description returns expected strings")
    func descriptions() {
        #expect(LogLevel.trace.description == "TRACE")
        #expect(LogLevel.debug.description == "DEBUG")
        #expect(LogLevel.info.description == "INFO")
        #expect(LogLevel.warn.description == "WARN")
        #expect(LogLevel.error.description == "ERROR")
    }

    @Test("Raw values are sequential")
    func rawValues() {
        #expect(LogLevel.trace.rawValue == 0)
        #expect(LogLevel.debug.rawValue == 1)
        #expect(LogLevel.info.rawValue == 2)
        #expect(LogLevel.warn.rawValue == 3)
        #expect(LogLevel.error.rawValue == 4)
    }
}

// MARK: - LogEntry Tests

@Suite("LogEntry Tests")
struct LogEntryTests {

    @Test("Init stores all fields")
    func initFields() {
        let entry = LogEntry(level: .warn, category: "Physics", message: "Low FPS", timestamp: 1.5)
        #expect(entry.level == .warn)
        #expect(entry.category == "Physics")
        #expect(entry.message == "Low FPS")
        #expect(entry.timestamp == 1.5)
    }
}

// MARK: - Spy Log Output

private final class SpyLogOutput: LogOutput, @unchecked Sendable {
    deinit {}

    var minimumLevel: LogLevel
    var entries: [LogEntry] = []

    init(minimumLevel: LogLevel = .trace) {
        self.minimumLevel = minimumLevel
    }

    func write(_ entry: LogEntry) {
        entries.append(entry)
    }
}

// MARK: - Log Facade Tests

@Suite("Log Facade Tests")
struct LogFacadeTests {

    @Test("addOutput and removeAllOutputs")
    func addRemoveOutputs() {
        let savedOutputs = Log.outputs
        let savedLevel = Log.minimumLevel
        defer {
            Log.removeAllOutputs()
            for o in savedOutputs { Log.addOutput(o) }
            Log.minimumLevel = savedLevel
        }

        Log.removeAllOutputs()
        #expect(Log.outputs.isEmpty)

        let spy = SpyLogOutput()
        Log.addOutput(spy)
        #expect(Log.outputs.count == 1)

        Log.removeAllOutputs()
        #expect(Log.outputs.isEmpty)
    }

    @Test("Log dispatches to output at matching level")
    func dispatchesToOutput() {
        let savedOutputs = Log.outputs
        let savedLevel = Log.minimumLevel
        defer {
            Log.removeAllOutputs()
            for o in savedOutputs { Log.addOutput(o) }
            Log.minimumLevel = savedLevel
        }

        Log.removeAllOutputs()
        Log.minimumLevel = .trace

        let spy = SpyLogOutput(minimumLevel: .trace)
        Log.addOutput(spy)

        Log.trace("Cat", "trace msg")
        Log.debug("Cat", "debug msg")
        Log.info("Cat", "info msg")
        Log.warn("Cat", "warn msg")
        Log.error("Cat", "error msg")

        #expect(spy.entries.count == 5)
        #expect(spy.entries[0].level == .trace)
        #expect(spy.entries[1].level == .debug)
        #expect(spy.entries[2].level == .info)
        #expect(spy.entries[3].level == .warn)
        #expect(spy.entries[4].level == .error)
    }

    @Test("Global minimumLevel filters entries")
    func globalMinLevel() {
        let savedOutputs = Log.outputs
        let savedLevel = Log.minimumLevel
        defer {
            Log.removeAllOutputs()
            for o in savedOutputs { Log.addOutput(o) }
            Log.minimumLevel = savedLevel
        }

        Log.removeAllOutputs()
        Log.minimumLevel = .warn

        let spy = SpyLogOutput(minimumLevel: .trace)
        Log.addOutput(spy)

        Log.debug("Cat", "should be filtered")
        Log.info("Cat", "should be filtered")
        Log.warn("Cat", "should pass")
        Log.error("Cat", "should pass")

        #expect(spy.entries.count == 2)
        #expect(spy.entries[0].level == .warn)
        #expect(spy.entries[1].level == .error)
    }

    @Test("Per-output minimumLevel filters entries")
    func perOutputMinLevel() {
        let savedOutputs = Log.outputs
        let savedLevel = Log.minimumLevel
        defer {
            Log.removeAllOutputs()
            for o in savedOutputs { Log.addOutput(o) }
            Log.minimumLevel = savedLevel
        }

        Log.removeAllOutputs()
        Log.minimumLevel = .trace

        let spyAll = SpyLogOutput(minimumLevel: .trace)
        let spyErrors = SpyLogOutput(minimumLevel: .error)
        Log.addOutput(spyAll)
        Log.addOutput(spyErrors)

        Log.info("Cat", "info")
        Log.error("Cat", "error")

        #expect(spyAll.entries.count == 2)
        #expect(spyErrors.entries.count == 1)
        #expect(spyErrors.entries[0].level == .error)
    }

    @Test("Log entries have category and message")
    func categoryAndMessage() {
        let savedOutputs = Log.outputs
        let savedLevel = Log.minimumLevel
        defer {
            Log.removeAllOutputs()
            for o in savedOutputs { Log.addOutput(o) }
            Log.minimumLevel = savedLevel
        }

        Log.removeAllOutputs()
        Log.minimumLevel = .trace

        let spy = SpyLogOutput(minimumLevel: .trace)
        Log.addOutput(spy)

        Log.info("Rendering", "Frame skipped")

        #expect(spy.entries.count == 1)
        #expect(spy.entries[0].category == "Rendering")
        #expect(spy.entries[0].message == "Frame skipped")
    }

    @Test("Log entries have increasing timestamps")
    func timestamps() {
        let savedOutputs = Log.outputs
        let savedLevel = Log.minimumLevel
        defer {
            Log.removeAllOutputs()
            for o in savedOutputs { Log.addOutput(o) }
            Log.minimumLevel = savedLevel
        }

        Log.removeAllOutputs()
        Log.minimumLevel = .trace

        let spy = SpyLogOutput(minimumLevel: .trace)
        Log.addOutput(spy)

        Log.info("A", "first")
        Log.info("A", "second")

        #expect(spy.entries.count == 2)
        #expect(spy.entries[0].timestamp >= 0)
        #expect(spy.entries[1].timestamp >= spy.entries[0].timestamp)
    }
}

// MARK: - RingBufferLogOutput Tests

@Suite("RingBufferLogOutput Tests")
struct RingBufferLogOutputTests {

    @Test("Stores entries up to capacity")
    func storesUpToCapacity() {
        let buffer = RingBufferLogOutput(capacity: 3, minimumLevel: .trace)
        buffer.write(LogEntry(level: .info, category: "A", message: "1", timestamp: 0))
        buffer.write(LogEntry(level: .info, category: "A", message: "2", timestamp: 1))
        buffer.write(LogEntry(level: .info, category: "A", message: "3", timestamp: 2))

        #expect(buffer.entryCount == 3)
        let entries = buffer.entries
        #expect(entries.count == 3)
        #expect(entries[0].message == "1")
        #expect(entries[1].message == "2")
        #expect(entries[2].message == "3")
    }

    @Test("Overwrites oldest when full")
    func overwritesOldest() {
        let buffer = RingBufferLogOutput(capacity: 2, minimumLevel: .trace)
        buffer.write(LogEntry(level: .info, category: "A", message: "1", timestamp: 0))
        buffer.write(LogEntry(level: .info, category: "A", message: "2", timestamp: 1))
        buffer.write(LogEntry(level: .info, category: "A", message: "3", timestamp: 2))

        #expect(buffer.entryCount == 2)
        let entries = buffer.entries
        #expect(entries.count == 2)
        #expect(entries[0].message == "2")
        #expect(entries[1].message == "3")
    }

    @Test("Empty buffer returns empty entries")
    func emptyBuffer() {
        let buffer = RingBufferLogOutput(capacity: 10, minimumLevel: .trace)
        #expect(buffer.entries.isEmpty)
        #expect(buffer.entryCount == 0)
    }

    @Test("Clear removes all entries")
    func clear() {
        let buffer = RingBufferLogOutput(capacity: 10, minimumLevel: .trace)
        buffer.write(LogEntry(level: .info, category: "A", message: "1", timestamp: 0))
        buffer.write(LogEntry(level: .info, category: "A", message: "2", timestamp: 1))

        buffer.clear()
        #expect(buffer.entryCount == 0)
        #expect(buffer.entries.isEmpty)
    }

    @Test("Wraps around correctly with many writes")
    func manyWrites() {
        let buffer = RingBufferLogOutput(capacity: 3, minimumLevel: .trace)
        for i in 0..<10 {
            buffer.write(LogEntry(level: .info, category: "A", message: "\(i)", timestamp: Double(i)))
        }

        #expect(buffer.entryCount == 3)
        let entries = buffer.entries
        #expect(entries[0].message == "7")
        #expect(entries[1].message == "8")
        #expect(entries[2].message == "9")
    }
}

// MARK: - ConsoleLogOutput Tests

@Suite("ConsoleLogOutput Tests")
struct ConsoleLogOutputTests {

    @Test("Default minimum level is info")
    func defaultLevel() {
        let output = ConsoleLogOutput()
        #expect(output.minimumLevel == .info)
    }

    @Test("Custom minimum level")
    func customLevel() {
        let output = ConsoleLogOutput(minimumLevel: .error)
        #expect(output.minimumLevel == .error)
    }
}

// MARK: - FileLogOutput Tests

@Suite("FileLogOutput Tests")
struct FileLogOutputTests {

    @Test("Returns nil for invalid path")
    func invalidPath() {
        let output = FileLogOutput(path: "/nonexistent/dir/file.log")
        #expect(output == nil)
    }
}
