import Agilis

// MARK: - Game-Specific ECS Components
// Position, velocity, and transform are now provided by the framework:
//   Transform2D, PreviousTransform2D, Velocity2D, RigidBody2D, Collider2D

/// Paddle configuration. Stores dimensions and speed for gameplay logic.
struct Paddle: Component {
    var halfWidth: Float
    var halfHeight: Float
    var speed: Float
}

/// Ball configuration. Tracks game-specific speed (increases on paddle hits).
struct Ball: Component {
    var radius: Float
    var speed: Float
}

/// Marks a paddle as AI-controlled with trajectory prediction.
struct AIControlled: Component {
    var targetY: Float
}

/// Collision layer bitmasks for Pong entities.
enum PongLayers {
    static let ball: UInt32     = 1 << 0
    static let paddle: UInt32   = 1 << 1
    static let wall: UInt32     = 1 << 2
}

// MARK: - Game Events (Event Bus)

/// Emitted when the ball hits a paddle.
struct PaddleHitEvent: Event {
    let paddle: Entity
    let ballSpeed: Float
}

/// Emitted when the ball bounces off a wall (top or bottom).
struct WallBounceEvent: Event {}

/// Emitted when a goal is scored (ball exits left or right).
struct GoalScoredEvent: Event {
    let scorer: Side

    enum Side { case left, right }
}
