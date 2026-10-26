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
        let english = Locale(identifier: "en_US")
        let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2)).locale(english)
        let percent = FloatingPointFormatStyle<Double>.Percent.percent.precision(.fractionLength(0)).locale(english)
        let units = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes, .seconds], width: .abbreviated)
        let otherErrors = errorCounts
            .filter { $0.key != "requestRateLimited" }
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        let requestTimes = [requestMillisecondsP50, requestMillisecondsP95].map { $0.formatted(number) }
        let delays = [delaySecondsP50, delaySecondsP95, delaySecondsMax].map { $0.formatted(number) }
        let rows = [
            ("Cars", "\(carCount)"),
            ("Duration", elapsed.formatted(units.locale(english))),
            ("Requests", "\(requestCount) (\(requestsPerSecond.formatted(number)) per second)"),
            ("Throttled (`requestRateLimited`)", "\(rateLimitedCount)"),
            ("Other errors", otherErrors.isEmpty ? "none" : otherErrors),
            ("Request time p50 / p95", requestTimes.joined(separator: " / ") + " ms"),
            ("Delay to another car p50 / p95 / max", delays.joined(separator: " / ") + " s"),
            ("Seen within 2 s", delayWithinTarget.formatted(percent)),
            ("Positions measured", "\(delayCount)")
        ]
        return (["| Measure | Result |", "| --- | --- |"] + rows.map { "| \($0.0) | \($0.1) |" })
            .joined(separator: "\n")
    }
}
#endif
