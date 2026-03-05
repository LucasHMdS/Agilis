import Agilis

enum RPG {
    static let screenWidth: Float = 800
    static let screenHeight: Float = 600
    static let tileSize: Float = 32
    static let roomCols: Int = 15
    static let roomRows: Int = 13
    static let playerSpeed: Float = 120

    // UI panel on the right side
    static let panelWidth: Float = 200
    static let gameAreaWidth: Float = screenWidth - panelWidth

    // Colors
    static let textBright = Color(r: 220, g: 220, b: 230)
    static let textDim = Color(r: 140, g: 140, b: 160)
    static let floorColor = Color(r: 40, g: 45, b: 55)
    static let wallColor = Color(r: 70, g: 75, b: 90)
    static let playerColor = Color(r: 80, g: 180, b: 255)
    static let itemColor = Color(r: 255, g: 220, b: 60)
    static let chestColor = Color(r: 180, g: 120, b: 60)
    static let chestOpenColor = Color(r: 120, g: 90, b: 50)
    static let npcColor = Color(r: 100, g: 220, b: 120)
    static let panelBg = Color(r: 30, g: 32, b: 42)
    static let buttonColor = Color(r: 60, g: 130, b: 200)

    // Physics layers
    static let layerPlayer: UInt32 = 1
    static let layerWall: UInt32 = 2
    static let layerItem: UInt32 = 4
    static let layerNPC: UInt32 = 8
    static let layerChest: UInt32 = 16
}
