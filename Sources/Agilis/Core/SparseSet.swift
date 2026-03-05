/// A generic sparse-set data structure mapping `UInt32` keys to dense, contiguous values.
///
/// Provides O(1) insert, remove, and lookup, with O(n) iteration over the dense value array.
/// Uses the swap-and-pop technique for removal, keeping the dense array contiguous.
internal struct SparseSet<T> {
    /// Maps key -> index in the dense/values arrays. `nil` means no entry.
    private var sparse: [UInt32?] = []

    /// Dense array of keys (parallel to `values`).
    private(set) var dense: [UInt32] = []

    /// Dense array of stored values (parallel to `dense`).
    var values: [T] = []

    /// The number of entries in the set.
    var count: Int { dense.count }

    /// Whether the set is empty.
    var isEmpty: Bool { dense.isEmpty }

    /// Check if a key exists in the set.
    func contains(key: UInt32) -> Bool {
        let k = Int(key)
        guard k < sparse.count, let index = sparse[k] else { return false }
        return Int(index) < dense.count && dense[Int(index)] == key
    }

    /// Get the value for a key, or `nil` if not present.
    func get(key: UInt32) -> T? {
        let k = Int(key)
        guard k < sparse.count, let index = sparse[k] else { return nil }
        let i = Int(index)
        guard i < dense.count, dense[i] == key else { return nil }
        return values[i]
    }

    /// Access the value for a key by index into the dense array, or `nil` if not present.
    @inline(__always) func denseIndex(for key: UInt32) -> Int? {
        let k = Int(key)
        guard k < sparse.count, let index = sparse[k] else { return nil }
        let i = Int(index)
        guard i < dense.count, dense[i] == key else { return nil }
        return i
    }

    /// Insert or overwrite a value for the given key.
    mutating func insert(key: UInt32, value: T) {
        let k = Int(key)

        // Grow sparse array if needed
        while sparse.count <= k { sparse.append(nil) }

        if let existing = sparse[k], Int(existing) < dense.count, dense[Int(existing)] == key {
            // Overwrite existing value
            values[Int(existing)] = value
        } else {
            // New entry
            sparse[k] = UInt32(dense.count)
            dense.append(key)
            values.append(value)
        }
    }

    /// Remove the value for a key using swap-and-pop. Returns the removed value, or `nil`.
    @discardableResult
    mutating func remove(key: UInt32) -> T? {
        let k = Int(key)
        guard k < sparse.count, let index = sparse[k] else { return nil }
        let i = Int(index)
        guard i < dense.count, dense[i] == key else { return nil }

        let removed = values[i]
        let lastIndex = dense.count - 1

        if i < lastIndex {
            // Swap with last element
            let lastKey = dense[lastIndex]
            dense[i] = lastKey
            values[i] = values[lastIndex]
            sparse[Int(lastKey)] = UInt32(i)
        }

        // Pop last
        dense.removeLast()
        values.removeLast()
        sparse[k] = nil

        return removed
    }

    /// Mutate the value for a key in-place. Returns `true` if the key existed.
    @discardableResult
    mutating func withValue(for key: UInt32, _ body: (inout T) -> Void) -> Bool {
        let k = Int(key)
        guard k < sparse.count, let index = sparse[k] else { return false }
        let i = Int(index)
        guard i < dense.count, dense[i] == key else { return false }
        body(&values[i])
        return true
    }

    /// Remove all entries, optionally keeping capacity.
    mutating func removeAll(keepingCapacity: Bool = false) {
        sparse.removeAll(keepingCapacity: keepingCapacity)
        dense.removeAll(keepingCapacity: keepingCapacity)
        values.removeAll(keepingCapacity: keepingCapacity)
    }
}
