/// A marker protocol for ECS components. Components hold data, not behavior.
///
/// Both value types (structs) and reference types (classes) can be components.
/// Struct components are recommended for cache-friendly iteration in the sparse-set storage.
public protocol Component {}
