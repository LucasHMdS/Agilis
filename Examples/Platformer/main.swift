import Agilis

let config = WindowConfig(
    title: "Agilis - Platformer",
    width: Int(Mario.screenWidth),
    height: Int(Mario.screenHeight),
    targetFPS: 60,
    resizable: false
)

let app = Application(config: config)
app.renderer.setBackgroundColor(Mario.skyColor)
app.world.parallelSchedulingEnabled = true
app.sceneManager.push(MenuScene(), app: app)

try await app.runAsync()
