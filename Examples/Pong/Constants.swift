import Agilis

// MARK: - Constants

enum Pong {
    static let screenWidth: Float = 800
    static let screenHeight: Float = 600

    // Paddles
    static let paddleWidth: Float = 15
    static let paddleHeight: Float = 80
    static let paddleMargin: Float = 30
    static let paddleSpeed: Float = 300
    static let aiSpeed: Float = 250

    // Ball
    static let ballRadius: Float = 8
    static let ballInitialSpeed: Float = 300
    static let ballSpeedIncrease: Float = 25
    static let ballMaxSpeed: Float = 600
    static let serveDelay: Double = 0.75

    // Scoring
    static let winningScore: Int = 5

    // Court
    static let lineThickness: Float = 2
    static let dashLength: Float = 15
    static let dashGap: Float = 10

    // Digit rendering
    static let digitWidth: Float = 20
    static let digitHeight: Float = 36
    static let digitThickness: Float = 4
}
