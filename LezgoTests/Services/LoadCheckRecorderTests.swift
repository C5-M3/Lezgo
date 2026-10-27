#if DEBUG
import Foundation
import Testing
@testable import Lezgo

struct LoadCheckRecorderTests {
    let recorder = LoadCheckRecorder()

    private func Request(_ operation: String, milliseconds: Int, error: String? = nil) -> LoadCheckSample {
        LoadCheckSample(operation: operation, duration: .milliseconds(milliseconds), errorCode: error)
    }

    @Test func EmptyCheckSummarisesToZero() {
        let summary = recorder.Summary(carCount: 5, elapsed: .zero)

        #expect(summary.requestCount == 0)
        #expect(summary.requestsPerSecond == 0)
        #expect(summary.delaySecondsP95 == 0)
        #expect(summary.delayWithinTarget == 0)
    }

    @Test(arguments: [(50.0, 50.0), (95.0, 95.0), (100.0, 100.0), (1.0, 1.0)])
    func PercentileUsesTheNearestRank(percent: Double, expected: Double) {
        let values = (1...100).map(Double.init).shuffled()

        #expect(LoadCheckRecorder.Percentile(percent, of: values) == expected)
    }

    @Test func PercentileOfOneValueIsThatValue() {
        #expect(LoadCheckRecorder.Percentile(95, of: [0.4]) == 0.4)
    }

    @Test func ErrorsAreCountedByCode() {
        recorder.Record(Request("save", milliseconds: 80))
        recorder.Record(Request("save", milliseconds: 90, error: "requestRateLimited"))
        recorder.Record(Request("query", milliseconds: 70, error: "requestRateLimited"))
        recorder.Record(Request("fetch", milliseconds: 60, error: "networkFailure"))

        let summary = recorder.Summary(carCount: 5, elapsed: .seconds(2))

        #expect(summary.requestCount == 4)
        #expect(summary.requestsPerSecond == 2)
        #expect(summary.rateLimitedCount == 2)
        #expect(summary.errorCounts == ["requestRateLimited": 2, "networkFailure": 1])
    }

    @Test func RequestTimesAreInMilliseconds() {
        for milliseconds in [100, 200, 300, 400] {
            recorder.Record(Request("fetch", milliseconds: milliseconds))
        }

        let summary = recorder.Summary(carCount: 1, elapsed: .seconds(1))

        #expect(summary.requestMillisecondsP50 == 200)
        #expect(summary.requestMillisecondsP95 == 400)
    }

    @Test func DelaysAreJudgedAgainstTheTwoSecondTarget() {
        for seconds in [0.5, 1.0, 1.5, 2.0, 3.5] {
            recorder.RecordDelay(seconds: seconds)
        }

        let summary = recorder.Summary(carCount: 5, elapsed: .seconds(10))

        #expect(summary.delayCount == 5)
        #expect(summary.delaySecondsP50 == 1.5)
        #expect(summary.delaySecondsMax == 3.5)
        #expect(summary.delayWithinTarget == 0.8)
    }

    @Test func MarkdownHasTheNumbersForTheIssue() {
        recorder.Record(Request("save", milliseconds: 90, error: "requestRateLimited"))
        recorder.RecordDelay(seconds: 1.2)

        let markdown = recorder.Summary(carCount: 5, elapsed: .seconds(60)).Markdown()

        #expect(markdown.contains("| Cars | 5 |"))
        #expect(markdown.contains("| Duration | 1 min |"))
        #expect(markdown.contains("| Throttled (`requestRateLimited`) | 1 |"))
        #expect(markdown.contains("| Seen within 2 s | 100% |"))
    }
}
#endif
