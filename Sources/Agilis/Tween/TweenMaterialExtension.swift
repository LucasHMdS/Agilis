extension TweenSystem {

    /// Animate a float material uniform on a sprite from its current value to a target.
    ///
    /// Reads the current uniform value from the sprite's material, then creates
    /// a custom tween that updates it each frame.
    ///
    /// Returns `.invalid` if the entity has no `Sprite`, no material, or the
    /// named uniform is not a `.float`.
    ///
    /// ```swift
    /// // Animate dissolve threshold from 0 to 1 over 2 seconds
    /// tweens.tweenMaterialUniform(
    ///     entity, uniform: "threshold",
    ///     to: 1.0, duration: 2.0, easing: .cubicIn, in: world
    /// )
    /// ```
    @discardableResult
    public func tweenMaterialUniform(
        _ entity: Entity,
        uniform name: String,
        to targetValue: Float,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        guard let sprite = world.getComponent(Sprite.self, from: entity),
              let material = sprite.material,
              case .float(let startValue) = material.uniforms[name] else {
            return .invalid
        }

        return custom(entity, duration: duration, easing: easing, delay: delay) { w, e, t in
            w.updateComponent(Sprite.self, on: e) { s in
                s.material?.uniforms[name] = .float(lerp(startValue, targetValue, t: t))
            }
        }
    }

    /// Animate a color material uniform on a sprite from its current value to a target.
    ///
    /// Returns `.invalid` if the entity has no `Sprite`, no material, or the
    /// named uniform is not a `.color`.
    ///
    /// ```swift
    /// tweens.tweenMaterialColor(
    ///     entity, uniform: "flashColor",
    ///     to: .red, duration: 0.5, easing: .sineOut, in: world
    /// )
    /// ```
    @discardableResult
    public func tweenMaterialColor(
        _ entity: Entity,
        uniform name: String,
        to targetColor: Color,
        duration: Float,
        easing: EasingFunction = .linear,
        delay: Float = 0,
        in world: World
    ) -> TweenHandle {
        guard let sprite = world.getComponent(Sprite.self, from: entity),
              let material = sprite.material,
              case .color(let startColor) = material.uniforms[name] else {
            return .invalid
        }

        return custom(entity, duration: duration, easing: easing, delay: delay) { w, e, t in
            let r = UInt8(lerp(Float(startColor.r), Float(targetColor.r), t: t))
            let g = UInt8(lerp(Float(startColor.g), Float(targetColor.g), t: t))
            let b = UInt8(lerp(Float(startColor.b), Float(targetColor.b), t: t))
            let a = UInt8(lerp(Float(startColor.a), Float(targetColor.a), t: t))
            w.updateComponent(Sprite.self, on: e) { s in
                s.material?.uniforms[name] = .color(Color(r: r, g: g, b: b, a: a))
            }
        }
    }
}
