//
//  TripMapSheet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import SwiftUI

/// The sheet at the bottom of the trip map, as in Apple Maps (#221).
///
/// Collapsed it shows only its top: the destination and time left, a tapped car, or the arrival message. Pulled up
/// it adds only what the driver may need to do: Edit Route for the leader, and End Trip or Exit Trip, so the big red
/// button is never one stray tap away while driving. The cars are on the map, so the sheet does not list them.
struct TripMapSheet: View {
    let viewModel: TripMapViewModel
    /// Opens the planner for a New Destination after arriving; `nil` hides the button.
    let onNewDestination: (() -> Void)?

    var body: some View {
        List {
            Section {
                Summary(viewModel: viewModel, onNewDestination: onNewDestination)
            }
            // The top reads as the sheet itself, not a card in it, as in Apple Maps.
            .listRowBackground(Color.clear)

            if viewModel.canEditRoute {
                Section {
                    Button(.tripMapEditRoute, systemImage: "pencil", action: viewModel.RequestEditRoute)
                }
            }

            Section {
                TripMapLeaveButton(isLeader: viewModel.isLeader, action: viewModel.RequestLeave)
                    .disabled(viewModel.isLeaving)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .scrollContentBackground(.hidden)
    }
}

extension TripMapSheet {
    /// The sheet's top, the part that shows while it is collapsed: a tapped car, the arrival message, or the
    /// destination with the time and distance left.
    struct Summary: View {
        let viewModel: TripMapViewModel
        let onNewDestination: (() -> Void)?

        var body: some View {
            if let carStatus = viewModel.selectedCarStatus {
                TripMapCarStatusCard(status: carStatus, onClose: { viewModel.SelectCar(nil) })
            } else if let arrivalCard = viewModel.arrivalCard {
                TripMapArrivalCardView(
                    card: arrivalCard,
                    isLeader: viewModel.isLeader,
                    onNewDestination: onNewDestination
                )
                .disabled(viewModel.isLeaving)
            } else if let destinationName = viewModel.destinationName {
                TripMapDestinationSummary(
                    destinationName: destinationName,
                    timeLeft: viewModel.guidance?.timeLeft,
                    distanceLeft: viewModel.guidance?.distanceLeft
                )
            } else {
                ProgressView(.tripMapLoading)
            }
        }
    }
}

#if DEBUG
// The sheet only shows over the trip map, so the previews open the map with a simulated drive.
#Preview("Leader") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.agusID)
}

#Preview("Member") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
}
#endif
