import Agilis

// MARK: - TextureAtlas → AnimationClip Bridge

extension AnimationClip {

    /// Creates an animation clip from a TexturePacker atlas by matching a name prefix.
    ///
    /// Frames are selected from the atlas where the frame name starts with `prefix`,
    /// then sorted alphabetically (matching TexturePacker's default naming convention
    /// of `"sprite_0000"`, `"sprite_0001"`, etc.).
    ///
    /// - Parameters:
    ///   - atlas: Parsed TexturePacker atlas data.
    ///   - prefix: Name prefix to match (e.g. `"walk_"` matches `"walk_0000"`, `"walk_0001"`).
    ///   - frameDuration: Duration per frame in seconds.
    ///   - mode: Playback mode. Default: `.forward`.
    /// - Returns: An animation clip with the matched frames sorted by name.
    ///
    /// ## Example
    /// ```swift
    /// let loader = TextureAtlasLoader()
    /// let atlas = try loader.load(from: jsonData)
    /// let walkClip = AnimationClip.fromTextureAtlas(atlas, prefix: "walk_", frameDuration: 0.1)
    /// ```
    public static func fromTextureAtlas(
        _ atlas: TextureAtlasData,
        prefix: String,
        frameDuration: Float,
        mode: PlaybackMode = .forward
    ) -> AnimationClip {
        // Filter and sort by name for deterministic ordering
        let matchedFrames = atlas.frames
            .filter { $0.key.hasPrefix(prefix) }
            .sorted { $0.key < $1.key }
            .map { (_, atlasFrame) in
                AnimationFrame(
                    sourceRect: Rect(
                        x: Float(atlasFrame.frame.x),
                        y: Float(atlasFrame.frame.y),
                        width: Float(atlasFrame.frame.w),
                        height: Float(atlasFrame.frame.h)
                    ),
                    duration: frameDuration
                )
            }

        return AnimationClip(name: prefix, frames: matchedFrames, mode: mode)
    }

    /// Creates an animation clip from specific named frames in a TexturePacker atlas.
    ///
    /// Use this when you need exact control over which frames are included and
    /// their order, rather than prefix matching.
    ///
    /// - Parameters:
    ///   - atlas: Parsed TexturePacker atlas data.
    ///   - name: Clip name.
    ///   - frameNames: Ordered list of frame names in the atlas.
    ///   - frameDuration: Duration per frame in seconds.
    ///   - mode: Playback mode. Default: `.forward`.
    /// - Returns: An animation clip. Frames not found in the atlas are skipped.
    public static func fromTextureAtlas(
        _ atlas: TextureAtlasData,
        name: String,
        frameNames: [String],
        frameDuration: Float,
        mode: PlaybackMode = .forward
    ) -> AnimationClip {
        let frames = frameNames.compactMap { frameName -> AnimationFrame? in
            guard let atlasFrame = atlas.frames[frameName] else { return nil }
            return AnimationFrame(
                sourceRect: Rect(
                    x: Float(atlasFrame.frame.x),
                    y: Float(atlasFrame.frame.y),
                    width: Float(atlasFrame.frame.w),
                    height: Float(atlasFrame.frame.h)
                ),
                duration: frameDuration
            )
        }

        return AnimationClip(name: name, frames: frames, mode: mode)
    }
}
