import Foundation

enum StochasticEngine {
    struct Component: Equatable {
        let median: Double
        let sigma: Double

        init(median: Double, sigma: Double) {
            self.median = median
            self.sigma = max(0, sigma)
        }
    }

    struct Summary: Equatable {
        let low: Double
        let median: Double
        let mean: Double
        let high: Double

        var relativeWidth: Double { median > 0 ? (high - low) / (2 * median) : 1 }
    }

    static let defaultCorrelation: Double = 0.35
    static let defaultDraws: Int = 20_000
    static let defaultSeed: UInt64 = 0x5EED_1234_ABCD_0001

    static func aggregate(
        components: [Component],
        correlation: Double = defaultCorrelation,
        draws: Int = defaultDraws,
        seed: UInt64 = defaultSeed
    ) -> Summary {
        let active = components.filter { $0.median > 0 }

        let medianSum = active.reduce(0.0) { $0 + $1.median }
        guard !active.isEmpty else {
            return Summary(low: 0, median: 0, mean: 0, high: 0)
        }

        let deterministic = active.filter { $0.sigma == 0 }.reduce(0.0) { $0 + $1.median }
        let stochastic = active.filter { $0.sigma > 0 }
        guard !stochastic.isEmpty else {
            return Summary(low: medianSum, median: medianSum, mean: medianSum, high: medianSum)
        }

        let rho = min(1, max(0, correlation))
        let sqrtRho = rho.squareRoot()
        let sqrtOneMinusRho = (1 - rho).squareRoot()

        var rng = SeededRandom(seed: seed)
        var totals = [Double]()
        totals.reserveCapacity(draws)
        var sumForMean = 0.0

        for _ in 0..<draws {
            let common = rng.nextStandardNormal()
            var sum = deterministic
            for component in stochastic {
                let idio = rng.nextStandardNormal()
                let z = sqrtRho * common + sqrtOneMinusRho * idio
                sum += component.median * exp(component.sigma * z)
            }
            totals.append(sum)
            sumForMean += sum
        }

        totals.sort()
        return Summary(
            low: percentile(sorted: totals, p: 0.10),
            median: percentile(sorted: totals, p: 0.50),
            mean: sumForMean / Double(draws),
            high: percentile(sorted: totals, p: 0.90)
        )
    }

    static func confidence(evidenceScore: Double, relativeWidth: Double) -> Double {
        let bandPrecision = max(0.1, min(1.0, 1.0 - relativeWidth))
        let blended = (max(0, evidenceScore) * bandPrecision).squareRoot()
        return max(0.1, min(0.95, blended))
    }

    static func sigma(fromRelativeSpread spread: Double) -> Double {
        let clamped = min(0.95, max(0, spread))
        guard clamped > 0 else { return 0 }
        let ratio = (1 + clamped) / (1 - clamped)
        return log(ratio) / (2 * 1.2816)
    }

    static func percentile(sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        if sorted.count == 1 { return sorted[0] }
        let rank = p * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let frac = rank - Double(lower)
        return sorted[lower] * (1 - frac) + sorted[upper] * frac
    }
}

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnitInterval() -> Double {
        let bits = next() >> 11
        return (Double(bits) + 0.5) / Double(1 << 53)
    }

    mutating func nextStandardNormal() -> Double {
        let u1 = nextUnitInterval()
        let u2 = nextUnitInterval()
        return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
}
