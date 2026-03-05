// swift-tools-version: 6.0

import PackageDescription

// MARK: - RaylibC build configuration (vendored raylib 5.5)

var raylibCSources: [String] {
    var sources: [String] = []

    // Core raylib
    let raylib = ["rcore.c", "rmodels.c", "raudio.c", "rshapes.c", "rtext.c", "rtextures.c", "utils.c"]
    sources += raylib.map { "src/" + $0 }

    // GLFW common
    let glfw = ["context.c", "init.c", "input.c", "monitor.c", "vulkan.c", "window.c",
                "platform.c", "osmesa_context.c", "egl_context.c"]
    sources += glfw.map { "src/external/glfw/src/" + $0 }

    // Platform-specific GLFW
#if os(Windows)
    let platform = ["win32_init.c", "win32_joystick.c", "win32_monitor.c", "win32_time.c",
                     "win32_thread.c", "win32_window.c", "win32_module.c", "wgl_context.c"]
    sources += platform.map { "src/external/glfw/src/" + $0 }
#elseif os(macOS)
    let mac = ["cocoa_init.m", "cocoa_joystick.m", "cocoa_monitor.m", "cocoa_window.m",
               "cocoa_time.c", "nsgl_context.m", "posix_thread.c", "posix_module.c"]
    sources += mac.map { "src/external/glfw/src/" + $0 }
#elseif os(Linux)
    let linux = ["x11_init.c", "x11_monitor.c", "x11_window.c", "xkb_unicode.c",
                 "posix_time.c", "posix_thread.c", "posix_module.c", "posix_poll.c",
                 "glx_context.c", "linux_joystick.c"]
    sources += linux.map { "src/external/glfw/src/" + $0 }
#endif

    return sources
}

var raylibCExclude: [String] {
    var list = [
        // Non-source files
        "src/rglfw.c",
        "src/Makefile",
        "src/CMakeLists.txt",
        "src/shell.html",
        "src/minshell.html",
        "src/raylib.rc",
        "src/raylib.rc.data",
        "src/raylib.dll.rc",
        "src/raylib.dll.rc.data",
        "src/raylib.ico",
        // Platform files are #included by rcore.c, not compiled directly
        "src/platforms",
        // GLFW build files
        "src/external/glfw/CMakeLists.txt",
        "src/external/glfw/CMake",
        "src/external/glfw/deps",
        "src/external/glfw/LICENSE.md",
        "src/external/glfw/README.md",
        "src/external/glfw/CONTRIBUTORS.md",
        "src/external/glfw/src/CMakeLists.txt",
        // Null/Wayland backends (unused)
        "src/external/glfw/src/null_init.c",
        "src/external/glfw/src/null_monitor.c",
        "src/external/glfw/src/null_window.c",
        "src/external/glfw/src/null_joystick.c",
        "src/external/glfw/src/wl_init.c",
        "src/external/glfw/src/wl_monitor.c",
        "src/external/glfw/src/wl_window.c",
    ]

    // Exclude other platforms' GLFW sources
#if os(Windows)
    list += [
        "src/external/glfw/src/cocoa_init.m",
        "src/external/glfw/src/cocoa_joystick.m",
        "src/external/glfw/src/cocoa_monitor.m",
        "src/external/glfw/src/cocoa_window.m",
        "src/external/glfw/src/cocoa_time.c",
        "src/external/glfw/src/nsgl_context.m",
        "src/external/glfw/src/posix_thread.c",
        "src/external/glfw/src/posix_time.c",
        "src/external/glfw/src/posix_module.c",
        "src/external/glfw/src/posix_poll.c",
        "src/external/glfw/src/glx_context.c",
        "src/external/glfw/src/x11_init.c",
        "src/external/glfw/src/x11_monitor.c",
        "src/external/glfw/src/x11_window.c",
        "src/external/glfw/src/xkb_unicode.c",
        "src/external/glfw/src/linux_joystick.c",
    ]
#elseif os(macOS)
    list += [
        "src/external/glfw/src/posix_time.c",
        "src/external/glfw/src/posix_poll.c",
        "src/external/glfw/src/win32_init.c",
        "src/external/glfw/src/win32_joystick.c",
        "src/external/glfw/src/win32_monitor.c",
        "src/external/glfw/src/win32_time.c",
        "src/external/glfw/src/win32_thread.c",
        "src/external/glfw/src/win32_window.c",
        "src/external/glfw/src/win32_module.c",
        "src/external/glfw/src/wgl_context.c",
        "src/external/glfw/src/glx_context.c",
        "src/external/glfw/src/x11_init.c",
        "src/external/glfw/src/x11_monitor.c",
        "src/external/glfw/src/x11_window.c",
        "src/external/glfw/src/xkb_unicode.c",
        "src/external/glfw/src/linux_joystick.c",
    ]
#elseif os(Linux)
    list += [
        "src/external/glfw/src/cocoa_init.m",
        "src/external/glfw/src/cocoa_joystick.m",
        "src/external/glfw/src/cocoa_monitor.m",
        "src/external/glfw/src/cocoa_window.m",
        "src/external/glfw/src/cocoa_time.c",
        "src/external/glfw/src/nsgl_context.m",
        "src/external/glfw/src/win32_init.c",
        "src/external/glfw/src/win32_joystick.c",
        "src/external/glfw/src/win32_monitor.c",
        "src/external/glfw/src/win32_time.c",
        "src/external/glfw/src/win32_thread.c",
        "src/external/glfw/src/win32_window.c",
        "src/external/glfw/src/win32_module.c",
        "src/external/glfw/src/wgl_context.c",
    ]
#endif

    return list
}

var raylibCSettings: [CSetting] {
    var settings: [CSetting] = []

    settings.append(.define("PLATFORM_DESKTOP", .when(platforms: [.macOS, .windows, .linux])))
    settings.append(.define("SUPPORT_DEFAULT_FONT"))
    settings.append(.define("_DEBUG", .when(configuration: .debug)))

    // Windows
    settings.append(.define("_GLFW_WIN32", .when(platforms: [.windows])))
    settings.append(.define("_CRT_SECURE_NO_WARNINGS", .when(platforms: [.windows])))

    // Linux
    settings.append(.define("_GLFW_X11", .when(platforms: [.linux])))
    settings.append(.define("_DEFAULT_SOURCE", .when(platforms: [.linux])))

    // macOS
    settings.append(.define("_GLFW_COCOA", .when(platforms: [.macOS])))

    settings.append(.headerSearchPath("src/external/glfw/include"))
    settings.append(.headerSearchPath("src"))

    return settings
}

// MARK: - Package

let package = Package(
    name: "Agilis",
    products: [
        .library(name: "Agilis", targets: ["Agilis"]),
        .library(name: "AgilisCore", targets: ["AgilisCore"]),
        .library(name: "AgilisBackendRaylib", targets: ["AgilisBackendRaylib"]),
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
        // Backend-agnostic protocols and value types (no platform dependencies)
        .target(
            name: "AgilisCore",
            dependencies: [],
            path: "Sources/AgilisCore"
        ),

        // Main framework — re-exports AgilisCore and AgilisBackendRaylib
        .target(
            name: "Agilis",
            dependencies: ["AgilisCore", "AgilisBackendRaylib"],
            path: "Sources/Agilis"
        ),

        // Vendored raylib C library
        .target(
            name: "RaylibC",
            exclude: raylibCExclude,
            sources: raylibCSources,
            publicHeadersPath: "include",
            cSettings: raylibCSettings
        ),

        // Raylib backend
        .target(
            name: "AgilisBackendRaylib",
            dependencies: ["AgilisCore", "RaylibC"],
            path: "Sources/AgilisBackendRaylib"
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
