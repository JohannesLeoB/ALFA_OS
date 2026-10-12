/// Repeatable pseudo-random numbers (SplitMix64). The same seed gives the same board on every run.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// A number from 0 to below `bound`. `bound` must be above 0.
    public mutating func below(_ bound: Int) -> Int {
        Int(next() % UInt64(max(bound, 1)))
    }

    /// A number from 0 up to, not including, `limit`.
    public mutating func fraction(of limit: Double) -> Double {
        Double(next() % 1_000_000) / 1_000_000 * limit
    }
}
