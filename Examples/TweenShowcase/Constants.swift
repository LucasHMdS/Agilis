import Agilis

enum Showcase {
    static let screenWidth: Float = 960
    static let screenHeight: Float = 600

    // Easing grid layout (4 cols x 5 rows = 20 cells for 19 easings + 1 custom)
    static let gridCols: Int = 4
    static let gridRows: Int = 5
    static let cellWidth: Float = 210
    static let cellHeight: Float = 100
    static let cellPadding: Float = 10
    static let gridOffsetX: Float = 30
    static let gridOffsetY: Float = 50
    static let ballRadius: Float = 6
    static let trackLength: Float = 140

    // Sequence scene
    static let demoSpacing: Float = 200

    // Colors
    static let panelColor = Color(r: 40, g: 40, b: 55)
    static let panelBorderColor = Color(r: 60, g: 60, b: 80)
    static let accentColor = Color(r: 100, g: 180, b: 255)
    static let highlightColor = Color(r: 255, g: 200, b: 80)
    static let sequenceColor = Color(r: 120, g: 255, b: 150)
    static let textDim = Color(r: 140, g: 140, b: 160)
    static let textBright = Color(r: 220, g: 220, b: 240)
    static let trackColor = Color(r: 55, g: 55, b: 70)

    // All 19 easing functions in grid order
    static let allEasings: [(name: String, easing: EasingFunction)] = [
        ("linear", .linear),
        ("quadIn", .quadIn),
        ("quadOut", .quadOut),
        ("quadInOut", .quadInOut),

        ("cubicIn", .cubicIn),
        ("cubicOut", .cubicOut),
        ("cubicInOut", .cubicInOut),
        ("sineIn", .sineIn),

        ("sineOut", .sineOut),
        ("sineInOut", .sineInOut),
        ("elasticIn", .elasticIn),
        ("elasticOut", .elasticOut),

        ("elasticInOut", .elasticInOut),
        ("bounceIn", .bounceIn),
        ("bounceOut", .bounceOut),
        ("bounceInOut", .bounceInOut),

        ("backIn", .backIn),
        ("backOut", .backOut),
        ("backInOut", .backInOut)
    ]
}
