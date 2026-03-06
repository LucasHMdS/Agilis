/// Named tolerance constants for physics calculations.
///
/// Groups epsilons by their intended purpose to avoid ad-hoc magic numbers
/// throughout the physics module. Each category has a brief rationale:
///
/// - `vectorLength`: is this vector too short to normalize/use as a direction?
/// - `crossProduct`: are two edges parallel / is this determinant near-singular?
/// - `displacement`: is this movement too small to matter (CCD, rotation)?
/// - `matrixDeterminant`: is this effective-mass matrix invertible?
internal enum PhysicsConstants {
    enum Tolerance {
        /// For checks like "is this vector nearly zero?" (length or lengthSquared < threshold).
        /// Used in: axis normalization, direction validation, tangent computation.
        static let vectorLength: Float = 1e-4

        /// For cross-product / dot-product denominators and SAT overlap checks.
        /// Used in: ray-edge intersection, parallel edge detection, 2x2 matrix inversion.
        static let crossProduct: Float = 1e-6

        /// For positional/angular displacement thresholds.
        /// Used in: CCD sweep, rotation extent, skin nudge.
        static let displacement: Float = 1e-6

        /// For matrix determinant singularity checks.
        /// Used in: joint effective mass 2x2 inversion.
        static let matrixDeterminant: Float = 1e-6
    }
}
