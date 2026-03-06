import Agilis

let config = WindowConfig(
    title: "Agilis - Top-Down Shooter",
    width: Int(Shooter.screenWidth),
    height: Int(Shooter.screenHeight),
    targetFPS: 60,
    resizable: false
)
let app = Application(config: config)
app.renderer.setBackgroundColor(Color(r: 15, g: 18, b: 25))
app.sceneManager.push(MenuScene(), app: app)
try app.run()
