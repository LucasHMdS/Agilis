/// Maps `Component` types to stable bit indices for fast overlap checks
/// between system component access sets.
///
/// Used by the parallel scheduler to determine if two systems conflict
/// (i.e., one writes a component type the other reads or writes).
///
/// Registration happens during system setup (main thread, before the game loop).
/// Index lookups during scheduling are read-only and safe.
internal final class ComponentRegistry: @unchecked Sendable {
    deinit {}

    static let shared = ComponentRegistry()

    private var typeToIndex: [ObjectIdentifier: Int] = [:]
    private var nextIndex: Int = 0

    private init() {}

    /// Get or assign a stable bit index for a component type.
    ///
    /// Registration is lazy — component types get indices on first access.
    /// All component types should be registered before parallel scheduling starts
    /// to avoid data races on the mutable `typeToIndex` dictionary.
    func index(for type: any Component.Type) -> Int {
        let key = ObjectIdentifier(type)
        if let existing = typeToIndex[key] { return existing }
        let idx = nextIndex
        nextIndex += 1
        typeToIndex[key] = idx
        return idx
    }

    /// Build a bitset from an array of component types.
    func bitset(for types: [any Component.Type]) -> ComponentBitset {
        var bits = ComponentBitset()
        for type in types {
            bits.set(index(for: type))
        }
        return bits
    }

    /// Number of registered component types.
    var registeredCount: Int { nextIndex }
}

/// Fixed-size bitset (256 bits = 4 × UInt64) for component type sets.
///
/// Supports up to 256 distinct component types, which is sufficient for
/// the vast majority of game projects.
internal struct ComponentBitset: Sendable, Equatable {
    private var w0: UInt64 = 0
    private var w1: UInt64 = 0
    private var w2: UInt64 = 0
    private var w3: UInt64 = 0

    /// Set the bit at the given index. Indices >= 256 are ignored.
    mutating func set(_ index: Int) {
        guard index >= 0 && index < 256 else { return }
        let word = index / 64
        let bit: UInt64 = 1 << (index % 64)
        switch word {
        case 0: w0 |= bit
        case 1: w1 |= bit
        case 2: w2 |= bit
        case 3: w3 |= bit
        default: break
        }
    }

    /// Check if the bit at the given index is set.
    func test(_ index: Int) -> Bool {
        guard index >= 0 && index < 256 else { return false }
        let word = index / 64
        let bit: UInt64 = 1 << (index % 64)
        switch word {
        case 0: return w0 & bit != 0
        case 1: return w1 & bit != 0
        case 2: return w2 & bit != 0
        case 3: return w3 & bit != 0
        default: return false
        }
    }

    /// Check if any bit is set in both this and the other bitset.
    func intersects(_ other: ComponentBitset) -> Bool {
        (w0 & other.w0) != 0
            || (w1 & other.w1) != 0
            || (w2 & other.w2) != 0
            || (w3 & other.w3) != 0
    }

    /// Check if this bitset has no bits set.
    var isEmpty: Bool {
        w0 == 0 && w1 == 0 && w2 == 0 && w3 == 0
    }

    /// The number of set bits.
    var count: Int {
        w0.nonzeroBitCount + w1.nonzeroBitCount + w2.nonzeroBitCount + w3.nonzeroBitCount
    }
}
