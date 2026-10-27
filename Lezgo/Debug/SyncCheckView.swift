//
//  SyncCheckView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

#if DEBUG
import SwiftUI

/// A developer tool to check iCloud sync between real phones (#111): create a trip on one phone, join it from
/// another, hand over the lead, start and end it, and watch each change arrive in the log.
///
/// Open it with `-DebugScreen syncCheck`. It uses the app's real `TripService` from the environment, so it talks to
/// CloudKit. Debug builds only; its text is for developers and is not localized.
struct SyncCheckView: View {
    @Environment(\.tripService) private var tripService
    @State private var viewModel: SyncCheckViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    SyncCheckForm(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text(verbatim: "Sync Check"))
        }
        .task {
            if viewModel == nil {
                viewModel = SyncCheckViewModel(tripService: tripService)
            }
        }
    }
}

#Preview("No trip yet") {
    SyncCheckView()
        .environment(\.tripService, InMemoryTripService())
}

#Preview("Sample trip, largest text") {
    SyncCheckView()
        .environment(\.tripService, SampleTrip.Service(status: .lobby, me: SampleTrip.budiID))
        .dynamicTypeSize(.accessibility5)
}
#endif
