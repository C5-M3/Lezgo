#if DEBUG
import Foundation

/// Collects the requests and delays of a load check and summarises them.
final class LoadCheckRecorder {
    /// The sync target from `specs/UserStories.md` → "Sync and timing".
    static let delayTarget: Double = 2

    private(set) var samples: [LoadCheckSample] = []
    private(set) var delays: [Double] = []

    func Record(_ sample: LoadCheckSample) {
        samples.append(sample)
    }

    /// Records the seconds between a car saving its position and another car seeing it.
    func RecordDelay(seconds: Double) {
        delays.append(seconds)
    }

    func Summary(carCount: Int, elapsed: Duration) -> LoadCheckSummary {
        let milliseconds = samples.map { Self.Milliseconds($0.duration) }
        let errorCounts = samples.compactMap(\.errorCode).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let withinTarget = delays.filter { $0 <= Self.delayTarget }.count
        return LoadCheckSummary(
            carCount: carCount,
            elapsed: elapsed,
            requestCount: samples.count,
            errorCounts: errorCounts,
            requestMillisecondsP50: Self.Percentile(50, of: milliseconds),
            requestMillisecondsP95: Self.Percentile(95, of: milliseconds),
            delaySecondsP50: Self.Percentile(50, of: delays),
            delaySecondsP95: Self.Percentile(95, of: delays),
            delaySecondsMax: delays.max() ?? 0,
            delayWithinTarget: delays.isEmpty ? 0 : Double(withinTarget) / Double(delays.count),
            delayCount: delays.count
        )
    }

    private static func Milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
    }

    /// The nearest-rank percentile of `values`, or 0 when there are none.
    static func Percentile(_ percent: Double, of values: [Double]) -> Double {
        let sorted = values.sorted()
        guard sorted.isEmpty == false else { return 0 }
        let rank = Int((percent / 100 * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank, 1), sorted.count) - 1]
    }
}
#endif
