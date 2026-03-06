#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

#if os(Windows)
import WinSDK
#endif

/// A high-resolution clock for timing game loops.
public final class Clock: @unchecked Sendable {
    #if os(Windows)
    private var frequency: LARGE_INTEGER = LARGE_INTEGER()
    private var startTime: LARGE_INTEGER = LARGE_INTEGER()
    private var lastTime: LARGE_INTEGER = LARGE_INTEGER()
    #else
    private var startTime: UInt64 = 0
    private var lastTime: UInt64 = 0
    #endif

    public init() {
        #if os(Windows)
        QueryPerformanceFrequency(&frequency)
        QueryPerformanceCounter(&startTime)
        lastTime = startTime
        #elseif os(macOS) || os(iOS)
        startTime = mach_absolute_time()
        lastTime = startTime
        #else
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        startTime = UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
        lastTime = startTime
        #endif
    }

    /// Returns elapsed time in seconds since the last call to `elapsed()`.
    public func elapsed() -> Double {
        #if os(Windows)
        var now = LARGE_INTEGER()
        QueryPerformanceCounter(&now)
        let delta = Double(now.QuadPart - lastTime.QuadPart) / Double(frequency.QuadPart)
        lastTime = now
        return delta
        #elseif os(macOS) || os(iOS)
        let now = mach_absolute_time()
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let nanos = (now - lastTime) * UInt64(info.numer) / UInt64(info.denom)
        lastTime = now
        return Double(nanos) / 1_000_000_000.0
        #else
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        let now = UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
        let delta = now - lastTime
        lastTime = now
        return Double(delta) / 1_000_000_000.0
        #endif
    }

    /// Returns total time in seconds since the clock was created.
    public func totalTime() -> Double {
        #if os(Windows)
        var now = LARGE_INTEGER()
        QueryPerformanceCounter(&now)
        return Double(now.QuadPart - startTime.QuadPart) / Double(frequency.QuadPart)
        #elseif os(macOS) || os(iOS)
        let now = mach_absolute_time()
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let nanos = (now - startTime) * UInt64(info.numer) / UInt64(info.denom)
        return Double(nanos) / 1_000_000_000.0
        #else
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        let now = UInt64(ts.tv_sec) * 1_000_000_000 + UInt64(ts.tv_nsec)
        return Double(now - startTime) / 1_000_000_000.0
        #endif
    }
}
