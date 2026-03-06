import Agilis

let config = WindowConfig(
    title: "Agilis - Dungeon Crawler",
    width: Int(Dungeon.screenWidth),
    height: Int(Dungeon.screenHeight),
    targetFPS: 60,
    resizable: false
)
let app = Application(config: config)
app.renderer.setBackgroundColor(.black)
app.sceneManager.push(MenuScene(), app: app)
try app.run()
