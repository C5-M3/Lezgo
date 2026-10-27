#if DEBUG
import CloudKit
import Foundation
import Testing
@testable import Lezgo

struct LoadCheckViewModelTests {
    let server = FakeCloudServer()
    let folder = URL.temporaryDirectory.appending(path: "LoadCheckTests-\(UUID().uuidString)")
    let viewModel: LoadCheckViewModel

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        viewModel = LoadCheckViewModel(
            database: FakeCloudDatabase(server: server, userRecordName: "_load"),
            tick: .milliseconds(10),
            resultsFolder: folder
        )
        viewModel.carCount = 3
    }

    @Test func RunRecordsRequestsAndDelays() async throws {
        await viewModel.Run(for: .milliseconds(400))

        let summary = try #require(viewModel.summary)
        #expect(summary.carCount == 3)
        #expect(summary.requestCount > 0)
        #expect(summary.delayCount > 0)
        #expect(viewModel.isRunning == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func RunSavesTheReportForTheIssue() async throws {
        await viewModel.Run(for: .milliseconds(200))

        let file = try #require(viewModel.savedFile)
        let report = try String(contentsOf: file, encoding: .utf8)
        #expect(report.contains("| Cars | 3 |"))
        #expect(file.deletingLastPathComponent().lastPathComponent == folder.lastPathComponent)
    }

    @Test func RunEndsTheTestTrip() async throws {
        await viewModel.Run(for: .milliseconds(200))

        let trips = server.records.values.filter { $0.recordType == "Trip" }
        #expect(trips.count == 1)
        #expect(trips.first?["status"] as? String == "ENDED")
        #expect(server.records.values.filter { $0.recordType == "Participant" }.count == 3)
    }

    @Test func ThrottlingBeforeTheStartIsReported() async throws {
        server.failure = CKError(.requestRateLimited)

        await viewModel.Run(for: .milliseconds(200))

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isRunning == false)
        #expect(try #require(viewModel.summary).rateLimitedCount >= 1)
    }

    @Test func OneCarMeasuresItsOwnPositions() async throws {
        // One car per phone is the real load. Its own position, read back from the server, takes the same path as
        // the one another phone sees.
        viewModel.carCount = 1

        await viewModel.Run(for: .milliseconds(300))

        let summary = try #require(viewModel.summary)
        #expect(summary.carCount == 1)
        #expect(summary.delayCount > 0)
    }

    @Test func OneCarIsTheDefault() {
        let fresh = LoadCheckViewModel(database: FakeCloudDatabase(server: server, userRecordName: "_load"))

        #expect(fresh.carCount == 1)
    }
}
#endif
