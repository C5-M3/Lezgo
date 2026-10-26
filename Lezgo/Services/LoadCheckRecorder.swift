#if DEBUG
import Foundation

/// Collects the requests and delays of a load check and summarises them.
final class LoadCheckRecorder {
    /// The sync target from `specs/UserStories.md` → "Sync and timing".
    static let delayTarget: Double = 2

    private(set) var samples: [LoadCheckSample] = []
    private(set) var delays: [Double] = []

    func Record(_ sample: LoadCheckSample) {}

    /// Records the seconds between a car saving its position and another car seeing it.
    func RecordDelay(seconds: Double) {}

    func Summary(carCount: Int, elapsed: Duration) -> LoadCheckSummary {
        LoadCheckSummary(
            carCount: carCount,
            elapsed: elapsed,
            requestCount: 0,
            errorCounts: [:],
            requestMillisecondsP50: 0,
            requestMillisecondsP95: 0,
            delaySecondsP50: 0,
            delaySecondsP95: 0,
            delaySecondsMax: 0,
            delayWithinTarget: 0,
            delayCount: 0
        )
    }

    /// The nearest-rank percentile of `values`, or 0 when there are none.
    static func Percentile(_ percent: Double, of values: [Double]) -> Double {
        0
    }
}
#endif
