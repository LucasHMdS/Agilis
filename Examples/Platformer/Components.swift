import Agilis

// MARK: - Collision Layer Bitmasks

enum PlatformerLayers {
    static let player: UInt32   = 1 << 0
    static let ground: UInt32   = 1 << 1
    static let enemy: UInt32    = 1 << 2
    static let coin: UInt32     = 1 << 3
    static let block: UInt32    = 1 << 4
    static let pipe: UInt32     = 1 << 5
    static let flagpole: UInt32 = 1 << 6

    static let solid: UInt32 = ground | block | pipe
}

// MARK: - Player Component

struct Player: Component {
    var isGrounded: Bool = false
    var isJumping: Bool = false
    var jumpHeld: Bool = false
    var coyoteTimer: Float = 0
    var jumpBufferTimer: Float = 0
    var facingRight: Bool = true
    var isDead: Bool = false
    var deathTimer: Float = 0
    var isInvincible: Bool = false
    var invincibleTimer: Float = 0
    var walkAnimTimer: Float = 0
}

// MARK: - Enemy Components

enum EnemyType {
    case goomba
}

struct Enemy: Component {
    var type: EnemyType
    var moveDirection: Float = -1
    var isDead: Bool = false
    var deathTimer: Float = 0
}

// MARK: - Collectible Components

struct Coin: Component {
    var collected: Bool = false
}

enum BlockState {
    case active
    case used
    case bouncing
}

struct QuestionBlock: Component {
    var state: BlockState = .active
    var coinsRemaining: Int = 1
    var bounceTimer: Float = 0
    var originalY: Float = 0
}

// MARK: - Tile Component

enum TileType {
    case ground
    case groundTop
    case brick
    case pipeTop
    case pipeBody
}

struct Tile: Component {
    var tileType: TileType
}

// MARK: - Flagpole

struct Flagpole: Component {
    var reached: Bool = false
}

// MARK: - Game Events

struct CoinCollectedEvent: Event {
    let coinEntity: Entity
    let playerEntity: Entity
}

struct BlockHitEvent: Event {
    let blockEntity: Entity
    let playerEntity: Entity
}

struct EnemyStompedEvent: Event {
    let enemyEntity: Entity
    let playerEntity: Entity
}

struct LevelCompleteEvent: Event {
    let playerEntity: Entity
}

struct PlayerHurtEvent: Event {
    let playerEntity: Entity
    let enemyEntity: Entity
}
