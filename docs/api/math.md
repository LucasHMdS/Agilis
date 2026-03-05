# Math

## Vector2

`Sources/AgilisCore/Math/Vector2.swift`

2D floating-point vector.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `x` | `Float` | X component |
| `y` | `Float` | Y component |
| `length` | `Float` | Magnitude (computed) |
| `lengthSquared` | `Float` | Squared magnitude (faster, no sqrt) |
| `normalized` | `Vector2` | Unit vector (computed) |

### Constants

`.zero`, `.one`, `.unitX` (1,0), `.unitY` (0,1)

### Methods

```swift
func dot(_ other: Vector2) -> Float
func cross(_ other: Vector2) -> Float       // Z component of 3D cross product
func distance(to other: Vector2) -> Float
func lerp(to target: Vector2, t: Float) -> Vector2
```

### Operators

`+`, `-`, `*` (scalar and component-wise), `/` (scalar), unary `-`, `+=`, `-=`, `*=`

---

## Rect

`Sources/AgilisCore/Math/Rect.swift`

Axis-aligned rectangle.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `x`, `y` | `Float` | Top-left corner |
| `width`, `height` | `Float` | Dimensions |
| `origin` | `Vector2` | Position (get/set) |
| `size` | `Size` | Dimensions (get/set) |
| `center` | `Vector2` | Center point (computed) |
| `minX`, `maxX`, `minY`, `maxY` | `Float` | Edges (computed) |

### Initializers

```swift
init(x: Float = 0, y: Float = 0, width: Float = 0, height: Float = 0)
init(origin: Vector2, size: Size)
```

### Methods

```swift
func contains(_ point: Vector2) -> Bool
func intersects(_ other: Rect) -> Bool          // Touching edges = no intersection
func intersection(_ other: Rect) -> Rect?       // Returns overlap area or nil
```

---

## Size

`Sources/AgilisCore/Math/Size.swift`

```swift
struct Size: Sendable, Equatable {
    var width: Float
    var height: Float
    static let zero = Size(width: 0, height: 0)
}
```

---

## Matrix3

`Sources/Agilis/Math/Matrix3.swift`

Column-major 3x3 matrix for 2D transforms.

### Factory Methods

```swift
static var identity: Matrix3
static func translation(_ tx: Float, _ ty: Float) -> Matrix3
static func translation(_ v: Vector2) -> Matrix3
static func scale(_ sx: Float, _ sy: Float) -> Matrix3
static func rotation(_ radians: Float) -> Matrix3
```

### Operations

```swift
// Matrix multiplication
static func * (lhs: Matrix3, rhs: Matrix3) -> Matrix3

// Transform a point
func transformPoint(_ point: Vector2) -> Vector2
```

### Example

```swift
let transform = Matrix3.translation(100, 200)
    * Matrix3.rotation(degreesToRadians(45))
    * Matrix3.scale(2, 2)
let worldPos = transform.transformPoint(localPos)
```

---

## Color

`Sources/AgilisCore/Graphics/Color.swift`

RGBA color with 0-255 byte components.

### Initializers

```swift
init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255)      // Byte values
init(rf: Float, gf: Float, bf: Float, af: Float = 1.0)   // Normalized floats 0.0-1.0
```

### Predefined Colors

`.white`, `.black`, `.red`, `.green`, `.blue`, `.yellow`, `.cyan`, `.magenta`, `.gray`, `.darkGray`, `.clear`, `.cornflowerBlue`

---

## EasingFunction

`Sources/AgilisCore/Math/Easing.swift`

Standard easing functions for smooth interpolation. All functions map `t` in [0, 1] to an output value.

### Cases

| Group | Functions |
|-------|-----------|
| Linear | `.linear` |
| Quad | `.quadIn`, `.quadOut`, `.quadInOut` |
| Cubic | `.cubicIn`, `.cubicOut`, `.cubicInOut` |
| Sine | `.sineIn`, `.sineOut`, `.sineInOut` |
| Elastic | `.elasticIn`, `.elasticOut`, `.elasticInOut` |
| Bounce | `.bounceIn`, `.bounceOut`, `.bounceInOut` |
| Back | `.backIn`, `.backOut`, `.backInOut` |

### Methods

```swift
func apply(_ t: Float) -> Float   // Apply easing to a normalized time value
```

### Convenience Function

```swift
func ease(_ function: EasingFunction, t: Float) -> Float
```

### Usage

```swift
let t = EasingFunction.cubicOut.apply(progress)
let value = lerp(startValue, endValue, t: t)

// Or using the convenience wrapper
let eased = ease(.bounceOut, t: progress)
```

---

## Utility Functions

`Sources/AgilisCore/Math/MathUtilities.swift`

```swift
func lerp(_ a: Float, _ b: Float, t: Float) -> Float
func clamp(_ value: Float, min: Float, max: Float) -> Float
func degreesToRadians(_ degrees: Float) -> Float
func radiansToDegrees(_ radians: Float) -> Float
```
