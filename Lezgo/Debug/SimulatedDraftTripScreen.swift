//
//  SimulatedDraftTripScreen.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

#if DEBUG
import SwiftUI

/// The Draft Trip prompt screen for debug and preview flows (US-03).
struct SimulatedDraftTripScreen: View {
    let isLeader: Bool
    @State private var hasReturnedHome = false

    var body: some View {
        if hasReturnedHome {
            HomeView()
        } else {
            DraftTripView(
                viewModel: isLeader ? .sampleLeader : .sample,
                onContinueTrip: {},
                onNewTrip: {
                    withAnimation {
                        hasReturnedHome = true
                    }
                },
                onTripEnded: {
                    withAnimation {
                        hasReturnedHome = true
                    }
                }
            )
        }
    }
}

extension DraftTripView {
    static func Simulated(isLeader: Bool = false) -> some View {
        SimulatedDraftTripScreen(isLeader: isLeader)
    }
}

#Preview("Member Draft Trip") {
    DraftTripView.Simulated(isLeader: false)
}

#Preview("Leader Draft Trip") {
    DraftTripView.Simulated(isLeader: true)
}
#endif
