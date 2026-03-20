import Agilis

// MARK: - Aseprite → AnimationClip Bridge

extension AnimationClip {

    /// Creates animation clips from an Aseprite JSON export using its frame tags.
    ///
    /// Each `AsepriteFrameTag` in the metadata becomes an `AnimationClip`.
    /// Frame durations are converted from milliseconds (Aseprite) to seconds.
    /// The tag's `direction` field maps to a `PlaybackMode`:
    /// - `"forward"` → `.forward`
    /// - `"reverse"` → `.reverse`
    /// - `"pingpong"` → `.pingPong`
    ///
    /// - Parameter aseprite: Parsed Aseprite JSON data.
    /// - Returns: An array of animation clips, one per frame tag. Empty if no tags.
    ///
    /// ## Example
    /// ```swift
    /// let loader = AsepriteLoader()
    /// let aseprite = try loader.load(from: jsonData)
    /// let clips = AnimationClip.fromAseprite(aseprite)
    /// // clips might be: [walkClip, idleClip, attackClip]
    /// ```
    public static func fromAseprite(_ aseprite: AsepriteData) -> [AnimationClip] {
        guard let tags = aseprite.meta.frameTags, !tags.isEmpty else { return [] }

        return tags.map { tag in
            let fromIndex = max(0, tag.from)
            let toIndex = min(tag.to, aseprite.frames.count - 1)

            let frames: [AnimationFrame]
            if fromIndex <= toIndex {
                frames = (fromIndex...toIndex).map { i in
                    let aseFrame = aseprite.frames[i]
                    return AnimationFrame(
                        sourceRect: Rect(
                            x: Float(aseFrame.frame.x),
                            y: Float(aseFrame.frame.y),
                            width: Float(aseFrame.frame.w),
                            height: Float(aseFrame.frame.h)
                        ),
                        duration: Float(aseFrame.duration) / 1_000.0
                    )
                }
            } else {
                frames = []
            }

            let mode = playbackMode(from: tag.direction)
            return AnimationClip(name: tag.name, frames: frames, mode: mode)
        }
    }

    /// Creates a single animation clip from all frames in an Aseprite export.
    ///
    /// Use this when the sprite sheet has no frame tags, or when you want
    /// a single clip containing every frame.
    ///
    /// - Parameters:
    ///   - aseprite: Parsed Aseprite JSON data.
    ///   - name: Clip name. Default: `"default"`.
    ///   - mode: Playback mode. Default: `.forward`.
    /// - Returns: An animation clip with all frames.
    public static func fromAsepriteAllFrames(
        _ aseprite: AsepriteData,
        name: String = "default",
        mode: PlaybackMode = .forward
    ) -> AnimationClip {
        let frames = aseprite.frames.map { aseFrame in
            AnimationFrame(
                sourceRect: Rect(
                    x: Float(aseFrame.frame.x),
                    y: Float(aseFrame.frame.y),
                    width: Float(aseFrame.frame.w),
                    height: Float(aseFrame.frame.h)
                ),
                duration: Float(aseFrame.duration) / 1_000.0
            )
        }
        return AnimationClip(name: name, frames: frames, mode: mode)
    }

    // MARK: - Helpers

    /// Maps Aseprite direction strings to PlaybackMode.
    private static func playbackMode(from direction: String) -> PlaybackMode {
        switch direction.lowercased() {
        case "reverse":
            return .reverse

        case "pingpong":
            return .pingPong

        default:
            return .forward
        }
    }
}
