import Agilis

enum Sandbox {
    static let screenWidth: Float = 1_024
    static let screenHeight: Float = 768

    static let gravity = Vector2(x: 0, y: 400)

    // Tab names
    static let tabNames = [
        "1: Ragdoll",
        "2: Bridge",
        "3: Crane",
        "4: Elevator",
        "5: Motor",
        "6: Projectiles"
    ]

    // Colors
    static let textBright = Color(r: 220, g: 220, b: 230)
    static let textDim = Color(r: 140, g: 140, b: 160)
    static let panelBg = Color(r: 30, g: 32, b: 42)
    static let activeTab = Color(r: 70, g: 140, b: 220)
    static let inactiveTab = Color(r: 50, g: 52, b: 65)
    static let wallColor = Color(r: 60, g: 65, b: 80)
    static let dynamicColor = Color(r: 80, g: 200, b: 220)
    static let staticColor = Color(r: 100, g: 100, b: 120)
    static let accentColor = Color(r: 255, g: 180, b: 60)
    static let dangerColor = Color(r: 230, g: 70, b: 70)

    // Physics layers
    static let layerObject: UInt32 = 1
    static let layerWall: UInt32 = 2
    static let layerProjectile: UInt32 = 4
}
