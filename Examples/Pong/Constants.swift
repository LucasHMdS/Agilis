import Agilis

// MARK: - Constants

enum Pong {
    nonisolated(unsafe) static var screenWidth: Float = 800
    nonisolated(unsafe) static var screenHeight: Float = 600

    /// Scale factor relative to the 600px baseline height.
    nonisolated(unsafe) static var uiScale: Float = 1.0

    static func configure(screenSize: Size) {
        screenWidth = screenSize.width
        screenHeight = screenSize.height
        uiScale = screenSize.height / 600.0
    }

    /// Scale a font size by the UI scale factor.
    static func fontSize(_ base: Float) -> Float {
        base * uiScale
    }

    // Paddles
    static let basePaddleWidth: Float = 15
    static let basePaddleHeight: Float = 80
    static let basePaddleMargin: Float = 30
    static let basePaddleSpeed: Float = 300
    static let baseAISpeed: Float = 250
    static var paddleWidth: Float { basePaddleWidth * uiScale }
    static var paddleHeight: Float { basePaddleHeight * uiScale }
    static var paddleMargin: Float { basePaddleMargin * uiScale }
    static var paddleSpeed: Float { basePaddleSpeed * uiScale }
    static var aiSpeed: Float { baseAISpeed * uiScale }

    // Ball
    static var ballRadius: Float { 8 * uiScale }
    static var ballInitialSpeed: Float { 300 * uiScale }
    static var ballSpeedIncrease: Float { 25 * uiScale }
    static var ballMaxSpeed: Float { 600 * uiScale }
    static let serveDelay: Double = 0.75

    // Scoring
    static let winningScore: Int = 5

    // Court
    static var lineThickness: Float { 2 * uiScale }
    static var dashLength: Float { 15 * uiScale }
    static var dashGap: Float { 10 * uiScale }

    // Digit rendering
    static var digitWidth: Float { 20 * uiScale }
    static var digitHeight: Float { 36 * uiScale }
    static var digitThickness: Float { 4 * uiScale }
}
