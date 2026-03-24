// swift-tools-version: 6.0

import PackageDescription
import Foundation

// Absolute path to package directory for rpath resolution
let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

// MARK: - PlatformC build configuration
//
// All platform source files are included; each file uses C preprocessor guards
// (#ifdef _WIN32, #ifdef __linux__, TARGET_OS_IOS, etc.) to compile to an empty
// translation unit on non-matching platforms. This avoids SPM's #if os() limitation
// where the host OS is evaluated instead of the cross-compilation target.

var platformCSettings: [CSetting] {
    var settings: [CSetting] = []
    settings.append(.headerSearchPath("include"))
    return settings
}

var platformCLinkerSettings: [LinkerSetting] {
    var settings: [LinkerSetting] = []
    // Windows: Win32 + XInput
    settings.append(.linkedLibrary("user32", .when(platforms: [.windows])))
    settings.append(.linkedLibrary("gdi32", .when(platforms: [.windows])))
    settings.append(.linkedLibrary("xinput", .when(platforms: [.windows])))
    // Linux: X11
    settings.append(.linkedLibrary("X11", .when(platforms: [.linux])))
    // macOS: GameController framework for gamepad support
    settings.append(.linkedFramework("GameController", .when(platforms: [.macOS])))
    // iOS: UIKit + GameController + QuartzCore (for CADisplayLink/CAEAGLLayer)
    settings.append(.linkedFramework("UIKit", .when(platforms: [.iOS])))
    settings.append(.linkedFramework("GameController", .when(platforms: [.iOS])))
    settings.append(.linkedFramework("QuartzCore", .when(platforms: [.iOS])))
    return settings
}

// MARK: - AngleC build configuration

var angleCSettings: [CSetting] {
    var settings: [CSetting] = []
    settings.append(.headerSearchPath("include"))
    return settings
}

var angleCLinkerSettings: [LinkerSetting] {
    var settings: [LinkerSetting] = []
    // Link pre-built ANGLE libraries (libEGL + libGLESv2)
    settings.append(.unsafeFlags([
        "-Xlinker", "/LIBPATH:Sources/AngleC/lib/windows",
        "-Xlinker", "libEGL.dll.lib",
        "-Xlinker", "libGLESv2.dll.lib"
    ], .when(platforms: [.windows])))
    settings.append(.unsafeFlags([
        "-L", "Sources/AngleC/lib/macos", "-lEGL", "-lGLESv2",
        "-Xlinker", "-rpath", "-Xlinker", "\(packageDirectory)/Sources/AngleC/lib/macos"
    ], .when(platforms: [.macOS])))
    settings.append(.unsafeFlags([
        "-L", "Sources/AngleC/lib/linux", "-lEGL", "-lGLESv2"
    ], .when(platforms: [.linux])))
    settings.append(.unsafeFlags([
        "-F", "Sources/AngleC/lib/ios",
        "-framework", "libEGL", "-framework", "libGLESv2",
        "-Xlinker", "-rpath", "-Xlinker", "@executable_path/Frameworks"
    ], .when(platforms: [.iOS])))
    return settings
}

// MARK: - MiniaudioC build configuration

var miniaudioCSettings: [CSetting] {
    var settings: [CSetting] = []
    settings.append(.headerSearchPath("include"))
    // Disable unused audio backends
    settings.append(.define("MA_NO_JACK"))
    return settings
}

var miniaudioCLinkerSettings: [LinkerSetting] {
    var settings: [LinkerSetting] = []
    // Windows audio backends
    settings.append(.linkedLibrary("ole32", .when(platforms: [.windows])))
    // Linux audio backends
    settings.append(.linkedLibrary("pthread", .when(platforms: [.linux])))
    settings.append(.linkedLibrary("m", .when(platforms: [.linux])))
    settings.append(.linkedLibrary("dl", .when(platforms: [.linux])))
    return settings
}

// MARK: - StbC build configuration

var stbCSettings: [CSetting] {
    var settings: [CSetting] = []
    settings.append(.headerSearchPath("include"))
    return settings
}

// MARK: - Package
let package = Package(
    name: "Agilis",
    // Minimum OS versions for Apple platforms (Swift Concurrency requirement)
    // Windows/Linux: Supported via Swift 6.0 toolchain
    platforms: [
        .macOS(.v12),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "Agilis", targets: ["Agilis"]),
        .library(name: "AgilisFormats", targets: ["AgilisFormats"]),
        .executable(name: "UIDemo", targets: ["UIDemo"]),
        .executable(name: "Pong", targets: ["Pong"]),
        .executable(name: "Platformer", targets: ["Platformer"]),
        .executable(name: "TweenShowcase", targets: ["TweenShowcase"]),
        .executable(name: "PhysicsSandbox", targets: ["PhysicsSandbox"]),
        .executable(name: "SaveLoadDemo", targets: ["SaveLoadDemo"]),
        .executable(name: "DungeonCrawler", targets: ["DungeonCrawler"]),
        .executable(name: "TopDownShooter", targets: ["TopDownShooter"]),
    ],
    targets: [
        // Native platform windowing and input (Win32/Cocoa/X11/UIKit)
        // All platform files included; preprocessor guards select the right one.
        .target(
            name: "PlatformC",
            publicHeadersPath: "include",
            cSettings: platformCSettings,
            linkerSettings: platformCLinkerSettings
        ),

        // ANGLE — EGL + OpenGL ES 3.0 (pre-built binaries)
        .target(
            name: "AngleC",
            publicHeadersPath: "include",
            cSettings: angleCSettings,
            linkerSettings: angleCLinkerSettings
        ),

        // MiniAudio — cross-platform audio (single-header)
        .target(
            name: "MiniaudioC",
            publicHeadersPath: "include",
            cSettings: miniaudioCSettings,
            linkerSettings: miniaudioCLinkerSettings
        ),

        // stb libraries — image loading, font rasterization, image writing
        .target(
            name: "StbC",
            publicHeadersPath: "include",
            cSettings: stbCSettings
        ),

        // Main framework
        .target(
            name: "Agilis",
            dependencies: ["PlatformC", "AngleC", "MiniaudioC", "StbC"],
            path: "Sources/Agilis"
        ),

        // Pure Swift file format parsers
        .target(
            name: "AgilisFormats",
            dependencies: ["Agilis"],
            path: "Sources/AgilisFormats"
        ),

        // Examples
        .executableTarget(
            name: "UIDemo",
            dependencies: ["Agilis"],
            path: "Examples/UIDemo",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        .executableTarget(
            name: "Pong",
            dependencies: ["Agilis"],
            path: "Examples/Pong",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        .executableTarget(
            name: "Platformer",
            dependencies: ["Agilis"],
            path: "Examples/Platformer",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        .executableTarget(
            name: "TweenShowcase",
            dependencies: ["Agilis"],
            path: "Examples/TweenShowcase",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        .executableTarget(
            name: "PhysicsSandbox",
            dependencies: ["Agilis"],
            path: "Examples/PhysicsSandbox",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        .executableTarget(
            name: "SaveLoadDemo",
            dependencies: ["Agilis"],
            path: "Examples/SaveLoadDemo",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        .executableTarget(
            name: "DungeonCrawler",
            dependencies: ["Agilis"],
            path: "Examples/DungeonCrawler",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        .executableTarget(
            name: "TopDownShooter",
            dependencies: ["Agilis"],
            path: "Examples/TopDownShooter",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(platforms: [.windows]))
            ]
        ),

        // Tests
        .testTarget(
            name: "AgilisTests",
            dependencies: ["Agilis"],
            path: "Tests/AgilisTests"
        ),
        .testTarget(
            name: "AgilisFormatsTests",
            dependencies: ["AgilisFormats"],
            path: "Tests/AgilisFormatsTests"
        ),
    ],
    cLanguageStandard: .c99
)
