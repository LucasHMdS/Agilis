import Agilis

enum Dungeon {
    static let screenWidth: Float = 960
    static let screenHeight: Float = 540
    static let mapCols: Int = 40
    static let mapRows: Int = 30
    static let tileSize: Int = 32
    static let playerSpeed: Float = 100
    static let torchRadius: Float = 200
    static let sconceRadius: Float = 140
    static let enemySpeed: Float = 40

    static let ambientColor = Color(r: 30, g: 30, b: 45)
    static let torchColor = Color(r: 255, g: 180, b: 80)
    static let sconceColor = Color(r: 200, g: 160, b: 100)
    static let wallColor = Color(r: 130, g: 135, b: 155)
    static let floorColor = Color(r: 160, g: 165, b: 180)
    static let playerColor = Color(r: 120, g: 200, b: 255)
    static let enemyColor = Color(r: 240, g: 90, b: 90)
    static let textBright = Color(r: 220, g: 220, b: 230)
    static let textDim = Color(r: 100, g: 100, b: 120)

    // Physics layers
    static let layerPlayer: UInt32 = 1
    static let layerWall: UInt32 = 2
    static let layerEnemy: UInt32 = 4
}
