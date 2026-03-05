import AgilisCore
import AgilisBackendRaylib

/// Creates an Application with the default raylib backend.
public func createApplication(config: WindowConfig = WindowConfig()) -> Application {
    let renderer = RaylibRenderer()
    let audio = RaylibAudioEngine()
    let input = RaylibInputBackend()
    return Application(config: config, renderer: renderer, audio: audio, inputBackend: input)
}

/// Deprecated — use `createApplication(config:)` instead.
@available(*, deprecated, renamed: "createApplication(config:)")
public func createRaylibApplication(config: WindowConfig = WindowConfig()) -> Application {
    createApplication(config: config)
}
