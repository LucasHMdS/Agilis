/// Keyboard keys. Values are backend-agnostic; backends map from their native key codes.
public enum Key: Int, Sendable, Hashable, CaseIterable {
    // Letters
    case a = 65, b, c, d, e, f, g, h, i, j, k, l, m
    case n = 78, o, p, q, r, s, t, u, v, w, x, y, z

    // Numbers
    case zero = 48, one, two, three, four, five, six, seven, eight, nine

    // Function keys
    case f1 = 290, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    // Arrow keys
    case up = 265, down = 264, left = 263, right = 262

    // Special keys
    case space = 32
    case enter = 257
    case escape = 256
    case backspace = 259
    case tab = 258
    case delete = 261
    case insert = 260

    // Modifiers
    case leftShift = 340
    case leftControl = 341
    case leftAlt = 342
    case rightShift = 344
    case rightControl = 345
    case rightAlt = 346
}

/// Mouse buttons.
public enum MouseButton: Int, Sendable, Hashable, CaseIterable {
    case left = 0
    case right = 1
    case middle = 2
}
