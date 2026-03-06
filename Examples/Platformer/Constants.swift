import Agilis

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

enum Mario {
    // Screen
    static let screenWidth: Float = 960
    static let screenHeight: Float = 540

    // Tile grid
    static let tileSize: Float = 32
    static let levelWidthTiles: Int = 200
    static let levelHeightTiles: Int = 17
    static let groundRow: Int = 15

    // Player
    static let playerWidth: Float = 24
    static let playerHeight: Float = 30
    static let playerMoveSpeed: Float = 200
    static let playerJumpVelocity: Float = -580
    static let playerJumpCutMultiplier: Float = 0.4
    static let coyoteTime: Float = 0.08
    static let jumpBufferTime: Float = 0.1

    // Enemies
    static let goombaWidth: Float = 28
    static let goombaHeight: Float = 26
    static let goombaMoveSpeed: Float = 50
    static let goombaSquishedTime: Float = 0.3
    static let stompBounceVelocity: Float = -350

    // Coins
    static let coinRadius: Float = 8
    static let coinScore: Int = 100

    // Question blocks
    static let blockBounceDistance: Float = 8
    static let blockBounceTime: Float = 0.15

    // Camera
    static let cameraLookAheadX: Float = 60
    static let cameraSmoothSpeed: Float = 5.0
    static let cameraVerticalDeadzone: Float = 40

    // Physics
    static let gravity: Float = 980
    static let physicsGridCell: Float = 64

    // Game
    static let startLives: Int = 3
    static let deathY: Float = 600
    static let deathBounceVelocity: Float = -300
    static let deathDuration: Float = 1.5

    // Colors
    static let skyColor = Color(r: 107, g: 140, b: 255)
    static let groundColor = Color(r: 139, g: 90, b: 43)
    static let groundTopColor = Color(r: 34, g: 139, b: 34)
    static let brickColor = Color(r: 180, g: 100, b: 50)
    static let questionBlockColor = Color(r: 255, g: 200, b: 50)
    static let questionBlockUsedColor = Color(r: 120, g: 80, b: 30)
    static let pipeGreen = Color(r: 0, g: 160, b: 0)
    static let pipeDarkGreen = Color(r: 0, g: 120, b: 0)
    static let pipeHighlight = Color(r: 100, g: 220, b: 100)
    static let playerBodyColor = Color(r: 255, g: 0, b: 0)
    static let playerHeadColor = Color(r: 255, g: 200, b: 150)
    static let playerOverallColor = Color(r: 0, g: 0, b: 200)
    static let goombaColor = Color(r: 160, g: 100, b: 50)
    static let goombaFeetColor = Color(r: 80, g: 50, b: 25)
    static let coinColor = Color(r: 255, g: 215, b: 0)
    static let flagpoleColor = Color(r: 80, g: 80, b: 80)
    static let flagColor = Color(r: 0, g: 200, b: 0)
}
