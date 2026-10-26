#if DEBUG
import Foundation

/// The result of a load check (#69): how many requests CloudKit served, how many it throttled, and how long a
/// car's new position took to be seen.
struct LoadCheckSummary: Hashable {
    var carCount: Int
    var elapsed: Duration
    var requestCount: Int
    /// Failed requests by `CKError` code name.
    var errorCounts: [String: Int]
    var requestMillisecondsP50: Double
    var requestMillisecondsP95: Double
    /// Seconds from a car saving its position to another car seeing it.
    var delaySecondsP50: Double
    var delaySecondsP95: Double
    var delaySecondsMax: Double
    /// Share of positions seen within the 2-second target, from 0 to 1.
    var delayWithinTarget: Double
    var delayCount: Int

    var rateLimitedCount: Int {
        errorCounts["requestRateLimited", default: 0]
    }

    var requestsPerSecond: Double {
        let seconds = Double(elapsed.components.seconds)
        return seconds > 0 ? Double(requestCount) / seconds : 0
    }

    /// The summary as Markdown, ready to paste into the GitHub issue.
    func Markdown() -> String {
        ""
    }
}
#endif
