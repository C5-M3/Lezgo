#if DEBUG
import SwiftUI

/// A developer tool for the CloudKit load check (#69): runs several simulated cars from this phone against the real
/// public database and shows requests, throttling and delays as they happen.
///
/// Open it with `-DebugScreen loadCheck`. Set Auto-Lock to Never while it runs: a locked phone pauses the check.
/// Debug builds only; its text is for developers and is not localized.
struct LoadCheckView: View {
    @State var viewModel: LoadCheckViewModel
    @State private var run: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                SettingsSection()
                if let summary = viewModel.summary {
                    ResultsSection(summary: summary)
                }
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label { Text(verbatim: errorMessage) } icon: { Image(systemName: "exclamationmark.triangle") }
                    }
                }
                if let file = viewModel.savedFile {
                    Section {
                        Text(verbatim: file.lastPathComponent)
                            .textSelection(.enabled)
                    } header: {
                        Text(verbatim: "Report saved in Documents")
                    }
                }
            }
            .navigationTitle(Text(verbatim: "Load Check"))
        }
    }

    private func SettingsSection() -> some View {
        Section {
            Stepper(value: $viewModel.carCount, in: 1...10) {
                Text(verbatim: "Cars: \(viewModel.carCount)")
            }
            Picker(selection: $viewModel.minutes) {
                ForEach([1, 5, 30], id: \.self) { minutes in
                    Text(verbatim: "\(minutes) min").tag(minutes)
                }
            } label: {
                Text(verbatim: "Duration")
            }
            if viewModel.isRunning {
                LabeledContent {
                    Text(viewModel.elapsed.formatted(.time(pattern: .minuteSecond)))
                        .monospacedDigit()
                } label: {
                    Text(verbatim: "Running")
                }
                Button(role: .destructive) { run?.cancel() } label: { Text(verbatim: "Stop early") }
            } else {
                Button { Start() } label: { Text(verbatim: "Start load check") }
            }
        } header: {
            Text(verbatim: "Check")
        }
    }

    private func ResultsSection(summary: LoadCheckSummary) -> some View {
        Section {
            let perSecond = summary.requestsPerSecond.formatted(.number.precision(.fractionLength(1)))
            Row("Requests", "\(summary.requestCount) (\(perSecond)/s)")
            Row("Throttled", "\(summary.rateLimitedCount)")
            Row("Other errors", "\(summary.errorCounts.values.reduce(0, +) - summary.rateLimitedCount)")
            Row("Request p50 / p95", Milliseconds(summary.requestMillisecondsP50, summary.requestMillisecondsP95))
            let delays = Seconds(summary.delaySecondsP50, summary.delaySecondsP95, summary.delaySecondsMax)
            Row("Delay p50 / p95 / max", delays)
            Row("Seen within 2 s", summary.delayWithinTarget.formatted(.percent.precision(.fractionLength(0))))
        } header: {
            Text(verbatim: "Results")
        }
    }

    private func Row(_ title: String, _ value: String) -> some View {
        LabeledContent { Text(verbatim: value).monospacedDigit() } label: { Text(verbatim: title) }
    }

    private func Milliseconds(_ values: Double...) -> String {
        values.map { $0.formatted(.number.precision(.fractionLength(0))) }.joined(separator: " / ") + " ms"
    }

    private func Seconds(_ values: Double...) -> String {
        values.map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: " / ") + " s"
    }

    private func Start() {
        let duration = Duration.seconds(viewModel.minutes * 60)
        run = Task {
            await viewModel.Run(for: duration)
            run = nil
        }
    }
}

#Preview("Ready") {
    LoadCheckView(viewModel: LoadCheckViewModel(database: LiveCloudDatabase()))
}
#endif
