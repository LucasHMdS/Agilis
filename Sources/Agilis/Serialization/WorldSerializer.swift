import Foundation
import AgilisCore

/// Serializes and deserializes ECS world state to and from JSON.
///
/// Only component types that have been registered via `register(_:)` are included
/// in serialization. Entity hierarchy (parent/child), names, and tags are always
/// preserved. Systems are **not** serialized — re-add them after loading.
///
/// ## Usage
/// ```swift
/// let serializer = WorldSerializer()
/// serializer.registerDefaults()       // all built-in components
/// serializer.register(Health.self)    // custom component
///
/// // Save
/// let data = try serializer.encode(world: world)
///
/// // Load into a fresh world
/// let newWorld = World()
/// let remap = try serializer.decode(from: data, into: newWorld)
/// ```
///
/// ## Limitations
/// - **TextureHandle / SoundHandle / MusicHandle** serialize as raw UInt32 IDs.
///   These refer to GPU or audio resources and are meaningless after reload.
///   Re-map handles after deserialization if needed.
/// - **ParticleEmitter** serializes config only; active particles are not preserved.
/// - **SpriteAnimator.lastEvent** is transient and not serialized.
public final class WorldSerializer: @unchecked Sendable {

    // MARK: - Type-Erased Registration

    private struct Registration {
        let componentName: String
        let encode: (Entity, World) throws -> Data?
        let decode: (Entity, World, Data) throws -> Void
    }

    private var registrations: [String: Registration] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a serializable component type.
    ///
    /// Only registered types are included when encoding. Unregistered component
    /// types in JSON are silently skipped when decoding.
    public func register<T: SerializableComponent>(_ type: T.Type) {
        let name = T.componentName
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let reg = Registration(
            componentName: name,
            encode: { entity, world in
                guard let component = world.getComponent(T.self, from: entity) else {
                    return nil
                }
                return try encoder.encode(component)
            },
            decode: { entity, world, data in
                let component = try decoder.decode(T.self, from: data)
                world.addComponent(component, to: entity)
            }
        )
        registrations[name] = reg
    }

    /// Register all built-in Agilis component types.
    ///
    /// Registers: Transform2D, PreviousTransform2D, Velocity2D, RigidBody2D,
    /// Collider2D, Sprite, SpriteAnimator, ParticleEmitter, Light2D,
    /// ShadowCaster2D, AnimationStateMachine, NormalMapData.
    public func registerDefaults() {
        register(Transform2D.self)
        register(PreviousTransform2D.self)
        register(Velocity2D.self)
        register(RigidBody2D.self)
        register(Collider2D.self)
        register(Sprite.self)
        register(SpriteAnimator.self)
        register(ParticleEmitter.self)
        register(Light2D.self)
        register(ShadowCaster2D.self)
        register(AnimationStateMachine.self)
        register(NormalMapData.self)
    }

    /// The names of all currently registered component types.
    public var registeredComponentNames: [String] {
        Array(registrations.keys).sorted()
    }

    // MARK: - Encode

    /// Encode all entities and their registered components to JSON.
    ///
    /// - Parameter world: The world to serialize.
    /// - Returns: UTF-8 JSON data.
    public func encode(world: World) throws -> Data {
        var entitySnapshots: [[String: Any]] = []

        for entity in world.allEntities {
            var snapshot: [String: Any] = [:]
            snapshot["index"] = entity.index

            // Encode components
            var components: [String: Any] = [:]
            for (name, reg) in registrations {
                if let data = try reg.encode(entity, world) {
                    // Parse component JSON into a dictionary for nesting
                    let json = try JSONSerialization.jsonObject(with: data)
                    components[name] = json
                }
            }
            if !components.isEmpty {
                snapshot["components"] = components
            }

            // Encode metadata
            if let name = world.name(of: entity) {
                snapshot["name"] = name
            }

            let tags = world.tags(of: entity)
            if !tags.isEmpty {
                snapshot["tags"] = tags.sorted()
            }

            // Encode hierarchy
            if let parent = world.parent(of: entity) {
                snapshot["parentIndex"] = parent.index
            }

            entitySnapshots.append(snapshot)
        }

        let root: [String: Any] = ["entities": entitySnapshots]
        return try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    // MARK: - Decode

    /// Decode JSON into a world, creating new entities for each serialized entity.
    ///
    /// - Parameters:
    ///   - data: UTF-8 JSON data previously produced by `encode(world:)`.
    ///   - world: The target world to populate. Existing entities are not removed.
    /// - Returns: A mapping from old entity indices to newly created `Entity` handles.
    @discardableResult
    public func decode(from data: Data, into world: World) throws -> [UInt32: Entity] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entityArray = root["entities"] as? [[String: Any]] else {
            throw SerializationError.invalidFormat
        }

        // First pass: create entities, build remap table
        var remap: [UInt32: Entity] = [:]
        var entitySnapshots: [(UInt32, [String: Any])] = []

        for snapshot in entityArray {
            guard let oldIndex = snapshot["index"] as? UInt32
                    ?? (snapshot["index"] as? Int).flatMap({ $0 >= 0 ? UInt32($0) : nil })
                    ?? (snapshot["index"] as? NSNumber).flatMap({ $0.intValue >= 0 ? UInt32($0.intValue) : nil }) else {
                throw SerializationError.missingEntityIndex
            }

            let newEntity = world.createEntity()
            remap[oldIndex] = newEntity
            entitySnapshots.append((oldIndex, snapshot))
        }

        // Second pass: decode components
        for (_, snapshot) in entitySnapshots {
            guard let oldIndex = snapshot["index"] as? UInt32
                    ?? (snapshot["index"] as? Int).flatMap({ $0 >= 0 ? UInt32($0) : nil })
                    ?? (snapshot["index"] as? NSNumber).flatMap({ $0.intValue >= 0 ? UInt32($0.intValue) : nil }),
                  let newEntity = remap[oldIndex] else {
                continue
            }

            if let components = snapshot["components"] as? [String: Any] {
                for (name, value) in components {
                    guard let reg = registrations[name] else {
                        continue // Unknown component — skip gracefully
                    }
                    let componentData = try JSONSerialization.data(withJSONObject: value)
                    try reg.decode(newEntity, world, componentData)
                }
            }
        }

        // Third pass: restore metadata and hierarchy
        for (_, snapshot) in entitySnapshots {
            guard let oldIndex = snapshot["index"] as? UInt32
                    ?? (snapshot["index"] as? Int).flatMap({ $0 >= 0 ? UInt32($0) : nil })
                    ?? (snapshot["index"] as? NSNumber).flatMap({ $0.intValue >= 0 ? UInt32($0.intValue) : nil }),
                  let newEntity = remap[oldIndex] else {
                continue
            }

            // Restore name
            if let name = snapshot["name"] as? String {
                world.setName(name, for: newEntity)
            }

            // Restore tags
            if let tags = snapshot["tags"] as? [String] {
                for tag in tags {
                    world.addTag(tag, to: newEntity)
                }
            }

            // Restore hierarchy (parent index remapped)
            if let parentIndex = snapshot["parentIndex"] as? UInt32
                ?? (snapshot["parentIndex"] as? Int).flatMap({ $0 >= 0 ? UInt32($0) : nil })
                ?? (snapshot["parentIndex"] as? NSNumber).flatMap({ $0.intValue >= 0 ? UInt32($0.intValue) : nil }) {
                if let parentEntity = remap[parentIndex] {
                    world.setParent(parentEntity, for: newEntity)
                }
            }
        }

        return remap
    }
}

// MARK: - Errors

/// Errors that can occur during world serialization or deserialization.
public enum SerializationError: Error, Sendable {
    /// The JSON data is not in the expected format.
    case invalidFormat
    /// An entity snapshot is missing its index field.
    case missingEntityIndex
}
