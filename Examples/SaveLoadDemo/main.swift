import Agilis

let config = WindowConfig(
    title: "Agilis - Save & Load Demo",
    width: Int(RPG.screenWidth),
    height: Int(RPG.screenHeight),
    targetFPS: 60,
    resizable: false
)
let app = Application(config: config)
app.renderer.setBackgroundColor(Color(r: 20, g: 25, b: 35))
app.sceneManager.push(MenuScene(), app: app)
try app.run()
