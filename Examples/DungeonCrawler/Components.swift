import Agilis

struct PlayerComp: Component {
    var facingAngle: Float = 0
    var speed: Float = 0
}

struct EnemyComp: Component {
    var patrolPath: [Vector2]
    var currentWaypoint: Int = 0
    var alertLevel: Float = 0
    var facingAngle: Float = 0
}

struct Torch: Component {
    var flickerPhase: Float = 0
}

struct WallSconce: Component {
    var roomIndex: Int
}
