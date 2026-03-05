/// A component that can be serialized to and from JSON.
///
/// Conform to this protocol to make a component type work with `WorldSerializer`.
/// Each type must provide a unique `componentName` used as the key in serialized data.
///
/// ## Conforming a Custom Component
/// ```swift
/// struct Health: SerializableComponent {
///     static let componentName = "Health"
///     var current: Float
///     var maximum: Float
/// }
/// ```
///
/// ## Registration
/// ```swift
/// let serializer = WorldSerializer()
/// serializer.register(Health.self)
/// ```
public protocol SerializableComponent: Component, Codable {
    /// Unique string identifier for this component type.
    /// Used as the JSON key when serializing. Must be stable across versions.
    static var componentName: String { get }
}
