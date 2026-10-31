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
/// it also lists every car, the room code, Edit Route for the leader, and End Trip or Exit Trip, so the big red
/// button is never one stray tap away while driving.
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

            Section {
                ForEach(viewModel.carStatuses) { status in
                    Button { viewModel.SelectCar(status.id) } label: {
                        CarRow(status: status)
                    }
                    .tint(.primary)
                }
            } header: {
                Text(.tripMapCars)
            }

            Section {
                if let roomCode = viewModel.roomCode {
                    LabeledContent {
                        Text(verbatim: roomCode)
                            .monospacedDigit()
                            .textSelection(.enabled)
                    } label: {
                        Text(.tripMapRoomCode)
                    }
                }
                if viewModel.canEditRoute {
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

    /// One car in the pulled-up list: who drives it and what it is doing. Tapping it opens its status at the top.
    struct CarRow: View {
        let status: TripMapCarStatus

        var body: some View {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Title())
                        .font(.headline)
                    Text(verbatim: status.statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: status.isLeader ? "crown.fill" : "car.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }

        /// "Agus", "Agus · Leader" or "Budi · You".
        private func Title() -> String {
            var parts = [status.displayName]
            if status.isLeader { parts.append(String(localized: .tripMapCarLeader)) }
            if status.isMe { parts.append(String(localized: .tripMapCarYou)) }
            return parts.joined(separator: " · ")
        }
    }
}

#Preview("Car row, leader on this phone") {
    List {
        TripMapSheet.CarRow(status: TripMapCarStatus(
            id: UUID(),
            displayName: "Agus",
            activity: .driving(street: "Ahmad Yani Street"),
            isLeader: true,
            isMe: true
        ))
        TripMapSheet.CarRow(status: TripMapCarStatus(
            id: UUID(),
            displayName: "Bartholomew Alexander Wicaksono",
            activity: .offline(lastSeen: .seconds(180))
        ))
    }
}

#Preview("Car row, largest text") {
    List {
        TripMapSheet.CarRow(status: TripMapCarStatus(
            id: UUID(),
            displayName: "Citra",
            activity: .stopped(street: "Jalan Raya Prapen Indah Blok A No. 12, Tenggilis Mejoyo, Surabaya")
        ))
    }
    .dynamicTypeSize(.accessibility5)
}
