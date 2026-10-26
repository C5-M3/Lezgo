#if DEBUG
import Foundation
import Observation

/// Runs a CloudKit load check (#69) from one phone: several simulated cars, each saving its location and fetching
/// the trip every second through `LiveTripService`, while every request and delay is recorded.
///
/// Open it with `-DebugScreen loadCheck`. Debug builds only; its text is for developers and is not localized.
@Observable
final class LoadCheckViewModel {
    private(set) var isRunning = false
    private(set) var elapsed: Duration = .zero
    private(set) var summary: LoadCheckSummary?
    private(set) var errorMessage: String?
    private(set) var savedFile: URL?
    var carCount = 5
    var minutes = 30

    private let database: any CloudDatabase
    private let tick: Duration
    private let resultsFolder: URL

    /// - Parameters:
    ///   - database: the real public database on a phone, a fake in tests.
    ///   - tick: how often each car saves and fetches (1 second in the app, as in "Sync and timing").
    ///   - resultsFolder: where the Markdown report is saved.
    init(database: any CloudDatabase, tick: Duration = .seconds(1), resultsFolder: URL = .documentsDirectory) {
        self.database = database
        self.tick = tick
        self.resultsFolder = resultsFolder
    }

    /// Runs the check for `duration`, then ends the test trip and saves the report.
    func Run(for duration: Duration) async {}
}
#endif
