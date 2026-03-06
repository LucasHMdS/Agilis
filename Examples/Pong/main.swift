import Agilis

// MARK: - Entry Point

let config = WindowConfig(
    title: "Agilis - Pong",
    width: Int(Pong.screenWidth),
    height: Int(Pong.screenHeight),
    targetFPS: 60,
    resizable: false
)

let app = Application(config: config)
app.renderer.setBackgroundColor(.black)
app.sceneManager.push(MenuScene(), app: app)

try app.run()
