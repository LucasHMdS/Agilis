import Testing
@testable import Agilis

private let epsilon: Float = 0.0001

// MARK: - Boundary Tests

@Suite("EasingFunction Boundary Tests")
struct EasingBoundaryTests {

    /// All easing functions must return 0 at t=0 and 1 at t=1.
    static let allFunctions: [EasingFunction] = [
        .linear,
        .quadIn, .quadOut, .quadInOut,
        .cubicIn, .cubicOut, .cubicInOut,
        .sineIn, .sineOut, .sineInOut,
        .elasticIn, .elasticOut, .elasticInOut,
        .bounceIn, .bounceOut, .bounceInOut,
        .backIn, .backOut, .backInOut,
    ]

    @Test("All easing functions return 0 at t=0", arguments: allFunctions)
    func zeroAtStart(function: EasingFunction) {
        #expect(abs(function.apply(0)) < epsilon)
    }

    @Test("All easing functions return 1 at t=1", arguments: allFunctions)
    func oneAtEnd(function: EasingFunction) {
        #expect(abs(function.apply(1) - 1) < epsilon)
    }
}

// MARK: - Individual Function Tests

@Suite("EasingFunction Value Tests")
struct EasingValueTests {

    @Test("linear is identity")
    func linear() {
        #expect(EasingFunction.linear.apply(0.25) == 0.25)
        #expect(EasingFunction.linear.apply(0.5) == 0.5)
        #expect(EasingFunction.linear.apply(0.75) == 0.75)
    }

    @Test("quadIn: t=0.5 → 0.25")
    func quadIn() {
        #expect(abs(EasingFunction.quadIn.apply(0.5) - 0.25) < epsilon)
    }

    @Test("quadOut: t=0.5 → 0.75")
    func quadOut() {
        #expect(abs(EasingFunction.quadOut.apply(0.5) - 0.75) < epsilon)
    }

    @Test("quadInOut: symmetric around midpoint")
    func quadInOut() {
        let mid = EasingFunction.quadInOut.apply(0.5)
        #expect(abs(mid - 0.5) < epsilon)
    }

    @Test("cubicIn: t=0.5 → 0.125")
    func cubicIn() {
        #expect(abs(EasingFunction.cubicIn.apply(0.5) - 0.125) < epsilon)
    }

    @Test("cubicOut: t=0.5 → 0.875")
    func cubicOut() {
        #expect(abs(EasingFunction.cubicOut.apply(0.5) - 0.875) < epsilon)
    }

    @Test("cubicInOut: symmetric around midpoint")
    func cubicInOut() {
        let mid = EasingFunction.cubicInOut.apply(0.5)
        #expect(abs(mid - 0.5) < epsilon)
    }

    @Test("sineIn: slower start than linear")
    func sineIn() {
        let val = EasingFunction.sineIn.apply(0.5)
        #expect(val < 0.5)
        #expect(val > 0)
    }

    @Test("sineOut: faster start than linear")
    func sineOut() {
        let val = EasingFunction.sineOut.apply(0.5)
        #expect(val > 0.5)
        #expect(val < 1)
    }

    @Test("sineInOut: midpoint is 0.5")
    func sineInOut() {
        let mid = EasingFunction.sineInOut.apply(0.5)
        #expect(abs(mid - 0.5) < epsilon)
    }

    @Test("elasticIn: overshoots below 0 near start")
    func elasticIn() {
        // Elastic curves oscillate, values can go negative
        var hasNegative = false
        for i in 1..<10 {
            let t = Float(i) / 10.0
            if EasingFunction.elasticIn.apply(t) < 0 {
                hasNegative = true
            }
        }
        #expect(hasNegative)
    }

    @Test("elasticOut: overshoots above 1 near end")
    func elasticOut() {
        var hasOvershoot = false
        for i in 1..<10 {
            let t = Float(i) / 10.0
            if EasingFunction.elasticOut.apply(t) > 1 {
                hasOvershoot = true
            }
        }
        #expect(hasOvershoot)
    }

    @Test("bounceOut: stays in [0,1]")
    func bounceOut() {
        for i in 0...100 {
            let t = Float(i) / 100.0
            let val = EasingFunction.bounceOut.apply(t)
            #expect(val >= -epsilon)
            #expect(val <= 1 + epsilon)
        }
    }

    @Test("bounceIn: stays in [0,1]")
    func bounceIn() {
        for i in 0...100 {
            let t = Float(i) / 100.0
            let val = EasingFunction.bounceIn.apply(t)
            #expect(val >= -epsilon)
            #expect(val <= 1 + epsilon)
        }
    }

    @Test("backIn: goes below 0 (overshoot)")
    func backIn() {
        let val = EasingFunction.backIn.apply(0.25)
        #expect(val < 0)
    }

    @Test("backOut: goes above 1 (overshoot)")
    func backOut() {
        let val = EasingFunction.backOut.apply(0.75)
        #expect(val > 1)
    }
}

// MARK: - Symmetry Tests

@Suite("EasingFunction Symmetry Tests")
struct EasingSymmetryTests {

    /// easeOut(t) == 1 - easeIn(1 - t) for each family
    @Test("quadOut is inverse of quadIn")
    func quadSymmetry() {
        for i in 0...10 {
            let t = Float(i) / 10.0
            let out = EasingFunction.quadOut.apply(t)
            let inInverse = 1 - EasingFunction.quadIn.apply(1 - t)
            #expect(abs(out - inInverse) < epsilon)
        }
    }

    @Test("cubicOut is inverse of cubicIn")
    func cubicSymmetry() {
        for i in 0...10 {
            let t = Float(i) / 10.0
            let out = EasingFunction.cubicOut.apply(t)
            let inInverse = 1 - EasingFunction.cubicIn.apply(1 - t)
            #expect(abs(out - inInverse) < epsilon)
        }
    }

    @Test("sineOut is inverse of sineIn")
    func sineSymmetry() {
        for i in 0...10 {
            let t = Float(i) / 10.0
            let out = EasingFunction.sineOut.apply(t)
            let inInverse = 1 - EasingFunction.sineIn.apply(1 - t)
            #expect(abs(out - inInverse) < epsilon)
        }
    }

    @Test("bounceOut is inverse of bounceIn")
    func bounceSymmetry() {
        for i in 0...10 {
            let t = Float(i) / 10.0
            let inVal = EasingFunction.bounceIn.apply(t)
            let expected = 1 - EasingFunction.bounceOut.apply(1 - t)
            #expect(abs(inVal - expected) < epsilon)
        }
    }
}

// MARK: - Convenience Function Tests

@Suite("ease() Convenience Tests")
struct EaseConvenienceTests {

    @Test("ease() matches apply()")
    func convenienceMatchesApply() {
        let t: Float = 0.3
        #expect(ease(.cubicIn, t: t) == EasingFunction.cubicIn.apply(t))
        #expect(ease(.bounceOut, t: t) == EasingFunction.bounceOut.apply(t))
        #expect(ease(.linear, t: t) == EasingFunction.linear.apply(t))
    }

    @Test("Monotonic: quadIn increases over [0,1]")
    func quadInMonotonic() {
        var prev: Float = 0
        for i in 1...100 {
            let t = Float(i) / 100.0
            let val = EasingFunction.quadIn.apply(t)
            #expect(val >= prev - epsilon)
            prev = val
        }
    }

    @Test("Monotonic: cubicOut increases over [0,1]")
    func cubicOutMonotonic() {
        var prev: Float = 0
        for i in 1...100 {
            let t = Float(i) / 100.0
            let val = EasingFunction.cubicOut.apply(t)
            #expect(val >= prev - epsilon)
            prev = val
        }
    }

    @Test("Monotonic: sineInOut increases over [0,1]")
    func sineInOutMonotonic() {
        var prev: Float = 0
        for i in 1...100 {
            let t = Float(i) / 100.0
            let val = EasingFunction.sineInOut.apply(t)
            #expect(val >= prev - epsilon)
            prev = val
        }
    }
}
