/// Keyboard keys using USB HID Usage codes (Page 0x07).
///
/// Raw values are USB HID keyboard usage IDs — the universal standard for
/// keyboard key identification. Backends map from their native key codes
/// (VK_* on Windows, Carbon kVK_* on macOS, X11 KeySym on Linux) to these
/// values internally.
public enum Key: Int, Sendable, Hashable, CaseIterable {
    // Letters (USB HID 0x04–0x1D)
    case a = 4, b, c, d, e, f, g, h, i, j, k, l, m
    case n = 17, o, p, q, r, s, t, u, v, w, x, y, z

    // Numbers (USB HID 0x1E–0x27) — note: 1 comes first, 0 is last
    case one = 30, two, three, four, five, six, seven, eight, nine, zero

    // Special keys (USB HID 0x28–0x2C)
    case enter = 40
    case escape = 41
    case backspace = 42
    case tab = 43
    case space = 44

    // Punctuation (USB HID 0x2D–0x38)
    /// Minus key (- and _).
    case minus = 45
    /// Equal key (= and +).
    case equal = 46
    /// Left bracket key ([ and {).
    case leftBracket = 47
    /// Right bracket key (] and }).
    case rightBracket = 48
    /// Backslash key (\ and |).
    case backslash = 49
    /// Semicolon key (; and :).
    case semicolon = 51
    /// Apostrophe key (' and ").
    case apostrophe = 52
    /// Grave/tilde key (` and ~). Often used for debug console.
    case grave = 53
    /// Comma key (, and <).
    case comma = 54
    /// Period key (. and >).
    case period = 55
    /// Slash key (/ and ?).
    case slash = 56

    // Lock keys
    case capsLock = 57      // USB HID 0x39
    case scrollLock = 71    // USB HID 0x47
    case numLock = 83       // USB HID 0x53

    // Function keys (USB HID 0x3A–0x45)
    case f1 = 58, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    // System keys
    case printScreen = 70   // USB HID 0x46
    case pause = 72         // USB HID 0x48

    // Navigation (USB HID 0x49–0x52)
    case insert = 73
    case home = 74
    case pageUp = 75
    case delete = 76
    case end = 77
    case pageDown = 78
    case right = 79
    case left = 80
    case down = 81
    case up = 82

    // Application key (USB HID 0x65)
    /// Context menu key (Application key on Windows keyboards).
    case menu = 101

    // Modifiers (USB HID 0xE0–0xE7)
    case leftControl = 224
    case leftShift = 225
    case leftAlt = 226
    /// Left Super key (Windows key / Command key).
    case leftSuper = 227
    case rightControl = 228
    case rightShift = 229
    case rightAlt = 230
    /// Right Super key (Windows key / Command key).
    case rightSuper = 231
}

/// Mouse buttons.
public enum MouseButton: Int, Sendable, Hashable, CaseIterable {
    case left = 0
    case right = 1
    case middle = 2
    /// Side button (back/thumb button 1).
    case button4 = 3
    /// Side button (forward/thumb button 2).
    case button5 = 4
}
