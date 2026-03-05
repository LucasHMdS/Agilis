/// Layout strategies for arranging children within a container.
public enum UILayout: Sendable {
    /// Stack children vertically.
    case vertical(spacing: Float = 8, alignment: HorizontalAlignment = .center)

    /// Stack children horizontally.
    case horizontal(spacing: Float = 8, alignment: VerticalAlignment = .center)

    /// Position children manually (each child's frame.origin is used as-is).
    case manual

    public enum HorizontalAlignment: Sendable {
        case leading
        case center
        case trailing
    }

    public enum VerticalAlignment: Sendable {
        case top
        case center
        case bottom
    }
}
