import Agilis

struct Draggable: Component {
    var isDragging: Bool = false
    var dragOffset: Vector2 = .zero
}

struct Breakable: Component {
    var jointHandle: JointHandle
}

struct Projectile: Component {
    var lifetime: Float
}

struct DemoTag: Component {
    var tabIndex: Int
}
