import Agilis

enum Shooter {
    static let screenWidth: Float = 960
    static let screenHeight: Float = 540
    static let arenaWidth: Float = 900
    static let arenaHeight: Float = 480

    static let playerSpeed: Float = 150
    static let playerRadius: Float = 12
    static let playerMaxHealth: Int = 100

    static let enemySpeedBasic: Float = 50
    static let enemySpeedFast: Float = 90
    static let enemySpeedTank: Float = 30
    static let enemyRadius: Float = 10

    static let bulletSpeed: Float = 600
    static let bulletRadius: Float = 3
    static let shotgunPellets: Int = 5
    static let shotgunSpread: Float = 0.3
    static let laserRange: Float = 500

    static let waveInterval: Float = 5.0
    static let shakeIntensity: Float = 4.0
    static let shakeDuration: Float = 0.15

    // Colors
    static let textBright = Color(r: 220, g: 220, b: 230)
    static let textDim = Color(r: 120, g: 120, b: 140)
    static let playerColor = Color(r: 80, g: 200, b: 255)
    static let enemyBasicColor = Color(r: 220, g: 80, b: 80)
    static let enemyFastColor = Color(r: 255, g: 180, b: 60)
    static let enemyTankColor = Color(r: 180, g: 80, b: 180)
    static let bulletColor = Color(r: 255, g: 255, b: 150)
    static let laserColor = Color(r: 255, g: 50, b: 50)
    static let arenaColor = Color(r: 25, g: 28, b: 38)
    static let wallColor = Color(r: 60, g: 65, b: 80)

    // Physics layers
    static let layerPlayer: UInt32 = 1
    static let layerEnemy: UInt32 = 2
    static let layerBullet: UInt32 = 4
    static let layerWall: UInt32 = 8
}
