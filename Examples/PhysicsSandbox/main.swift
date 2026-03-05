import Agilis

let config = WindowConfig(
    title: "Agilis - Physics Sandbox",
    width: Int(Sandbox.screenWidth),
    height: Int(Sandbox.screenHeight),
    targetFPS: 60,
    resizable: false
)
let app = createApplication(config: config)
app.renderer.setBackgroundColor(Color(r: 20, g: 22, b: 30))
app.sceneManager.push(GameScene(), app: app)
try app.run()
