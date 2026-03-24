/// Base class for all UI elements. Provides bounds, visibility, and the
/// update/render contract.
public class UINode: @unchecked Sendable {
    /// Unique identifier for this node.
    public var id: String

    /// The computed frame in screen coordinates, set by the layout system.
    public var frame = Rect(x: 0, y: 0, width: 0, height: 0)

    /// Whether this node is visible and receives input.
    public var isVisible: Bool = true

    /// Whether this node can receive keyboard focus.
    public var isFocusable: Bool = false

    /// Whether this node currently has keyboard focus. Set by UIContext.
    public internal(set) var isFocused: Bool = false

    /// The parent node, if any.
    public weak var parent: UINode?

    nonisolated(unsafe) private static var nextAutoId: UInt64 = 0

    public init(id: String? = nil) {
        if let id {
            self.id = id
        } else {
            UINode.nextAutoId += 1
            self.id = "node-\(UINode.nextAutoId)"
        }
    }

    /// Called each fixed-timestep tick. Override to handle input and state.
    public func update(context _: UIContext, deltaTime _: Double) {}

    /// Called each frame. Override to draw.
    public func render(renderer _: any RenderBackend, theme _: UITheme) {}

    /// Called after the main render pass. Override to draw overlays (e.g. dropdown popups)
    /// that need to appear above sibling nodes.
    public func renderOverlay(renderer _: any RenderBackend, theme _: UITheme, screenSize _: Size) {}

    /// Returns the size this node would like to occupy, given available space.
    public func sizeThatFits(_ available: Size) -> Size {
        available
    }
}
