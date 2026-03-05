import Agilis

let config = WindowConfig(
    title: "Agilis - Tween Showcase",
    width: Int(Showcase.screenWidth),
    height: Int(Showcase.screenHeight),
    targetFPS: 60,
    resizable: false
)

let app = createApplication(config: config)
app.renderer.setBackgroundColor(Color(r: 25, g: 25, b: 35))
app.sceneManager.push(MenuScene(), app: app)

try app.run()
