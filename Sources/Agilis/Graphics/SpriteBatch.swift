

/// Controls how sprites are ordered when a SpriteBatch is flushed.
public enum SpriteSortMode: Sendable {
    /// Preserve insertion order. No sorting performed.
    case none
    /// Sort by texture ID to minimize texture switches and draw calls.
    case byTexture
    /// Sort by layer (ascending), then by texture within each layer.
    case byLayer
}

/// Collects sprites and draws them in an optimized order to minimize draw calls.
///
/// SpriteBatch groups sprites by shader, blend mode, and texture before drawing,
/// which reduces the number of state switches in the rendering backend.
///
/// Usage:
/// ```swift
/// let batch = SpriteBatch()
/// batch.add(playerSprite)
/// batch.add(enemySprite1)
/// batch.add(enemySprite2)
/// batch.flush(to: app.renderer)
/// ```
///
/// For layered ordering:
/// ```swift
/// let batch = SpriteBatch(sortMode: .byLayer)
/// batch.add(backgroundSprite, layer: 0)
/// batch.add(playerSprite, layer: 1)
/// batch.add(foregroundSprite, layer: 2)
/// batch.flush(to: app.renderer)
/// ```
public final class SpriteBatch: @unchecked Sendable {

    /// How sprites are sorted before drawing.
    public var sortMode: SpriteSortMode

    private var entries: [BatchEntry] = []
    private var spriteBuffer: [Sprite] = []

    /// Number of state change groups in the last flush (approximates GPU draw calls).
    public private(set) var lastDrawCallCount: Int = 0

    /// Number of sprites drawn in the last flush.
    public private(set) var lastSpriteCount: Int = 0

    public init(sortMode: SpriteSortMode = .byTexture, initialCapacity: Int = 256) {
        self.sortMode = sortMode
        entries.reserveCapacity(initialCapacity)
        spriteBuffer.reserveCapacity(initialCapacity)
    }

    /// Add a sprite to the batch.
    public func add(_ sprite: Sprite, layer: Int = 0) {
        entries.append(BatchEntry(sprite: sprite, layer: layer))
    }

    /// Add multiple sprites to the batch.
    public func add(_ sprites: [Sprite], layer: Int = 0) {
        for sprite in sprites {
            entries.append(BatchEntry(sprite: sprite, layer: layer))
        }
    }

    /// Draw all queued sprites to the renderer and clear the batch.
    public func flush(to renderer: Renderer) {
        lastSpriteCount = entries.count

        guard !entries.isEmpty else {
            lastDrawCallCount = 0
            return
        }

        switch sortMode {
        case .none:
            lastDrawCallCount = countStateChanges()
            for entry in entries {
                renderer.drawSprite(entry.sprite)
            }

        case .byTexture:
            entries.sort { a, b in
                let aMat = a.sprite.material?.sortKey ?? 0
                let bMat = b.sprite.material?.sortKey ?? 0
                if aMat != bMat { return aMat < bMat }
                let aBlend = effectiveBlendRaw(a.sprite)
                let bBlend = effectiveBlendRaw(b.sprite)
                if aBlend != bBlend { return aBlend < bBlend }
                return a.sprite.texture.id < b.sprite.texture.id
            }
            lastDrawCallCount = countStateChanges()
            fillSpriteBuffer()
            renderer.drawSprites(spriteBuffer)

        case .byLayer:
            entries.sort { a, b in
                if a.layer != b.layer { return a.layer < b.layer }
                let aMat = a.sprite.material?.sortKey ?? 0
                let bMat = b.sprite.material?.sortKey ?? 0
                if aMat != bMat { return aMat < bMat }
                let aBlend = effectiveBlendRaw(a.sprite)
                let bBlend = effectiveBlendRaw(b.sprite)
                if aBlend != bBlend { return aBlend < bBlend }
                return a.sprite.texture.id < b.sprite.texture.id
            }
            lastDrawCallCount = countStateChanges()
            fillSpriteBuffer()
            renderer.drawSprites(spriteBuffer)
        }

        entries.removeAll(keepingCapacity: true)
    }

    /// Clear all queued sprites without drawing.
    public func clear() {
        entries.removeAll(keepingCapacity: true)
    }

    /// The number of sprites currently queued.
    public var count: Int { entries.count }

    /// Whether the batch is empty.
    public var isEmpty: Bool { entries.isEmpty }

    // MARK: - Private

    private struct BatchEntry {
        var sprite: Sprite
        var layer: Int
    }

    /// Copy sprites from entries into the reusable sprite buffer.
    private func fillSpriteBuffer() {
        spriteBuffer.removeAll(keepingCapacity: true)
        for entry in entries {
            spriteBuffer.append(entry.sprite)
        }
    }

    /// Get the effective blend mode raw value (material override or sprite default).
    private func effectiveBlendRaw(_ sprite: Sprite) -> Int {
        (sprite.material?.blendMode ?? sprite.blendMode).rawValue
    }

    private func countStateChanges() -> Int {
        guard let first = entries.first else { return 0 }
        var count = 1
        var currentTexture = first.sprite.texture.id
        var currentBlend = effectiveBlendRaw(first.sprite)
        var currentMaterial = first.sprite.material?.sortKey ?? 0
        for i in 1..<entries.count {
            let s = entries[i].sprite
            let matKey = s.material?.sortKey ?? 0
            let blend = effectiveBlendRaw(s)
            if s.texture.id != currentTexture ||
               blend != currentBlend ||
               matKey != currentMaterial {
                currentTexture = s.texture.id
                currentBlend = blend
                currentMaterial = matKey
                count += 1
            }
        }
        return count
    }
}
