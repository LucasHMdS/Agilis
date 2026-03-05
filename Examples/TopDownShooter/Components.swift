import Agilis

enum WeaponType: Int {
    case pistol = 0
    case shotgun = 1
    case laser = 2
}

struct PlayerShooter: Component {
    var aimAngle: Float = 0
    var health: Int = 100
    var currentWeapon: WeaponType = .pistol
    var shootCooldown: Float = 0
}

struct EnemyAI: Component {
    enum EnemyType { case basic, fast, tank }
    var type: EnemyType
    var health: Int
    var isDead: Bool = false
    var deathTimer: Float = 0
}

struct BulletComp: Component {
    var damage: Int
    var lifetime: Float
}

struct WaveManager: Component {
    var currentWave: Int = 0
    var enemiesRemaining: Int = 0
    var spawnTimer: Float = 0
    var waveActive: Bool = false
}

struct ScoreTracker: Component {
    var score: Int = 0
    var kills: Int = 0
}

// Events
struct EnemyKilledEvent: Event {
    let entity: Entity
    let position: Vector2
}

struct WaveStartedEvent: Event {
    let wave: Int
    let enemyCount: Int
}

struct PlayerDamagedEvent: Event {
    let damage: Int
}
