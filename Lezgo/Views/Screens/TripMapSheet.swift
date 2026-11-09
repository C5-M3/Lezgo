//
//  TripMapSheet.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 31/10/26.
//

import SwiftUI

/// The card at the bottom of the trip map, drawn by hand so it can look like the hi-fi design.
///
/// Collapsed it shows only its top: the destination and time left, a tapped car, or the arrival message. Pulled up
/// it adds only what the driver may need to do: Edit Route for the leader, I've Arrived near the destination, and
/// End Trip or Exit Trip, so the red button is never one stray tap away while driving. The cars are on the map, so
/// the card does not list them.
struct TripMapSheet: View {
    let viewModel: TripMapViewModel
    /// Opens the planner for a New Destination after arriving; `nil` hides the button.
    let onNewDestination: (() -> Void)?
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far a drag must go to open or close the card, in points.
    private static let dragDistance = 24.0

    var body: some View {
        ZStack(alignment: .top) {
            ViewThatFits(in: .vertical) {
                Content(viewModel: viewModel, onNewDestination: onNewDestination, isExpanded: isExpanded)
                ScrollView {
                    Content(viewModel: viewModel, onNewDestination: onNewDestination, isExpanded: isExpanded)
                }
            }

            Button(action: TapGrabber, label: {
                Capsule()
                    .fill(Color(.tripCardSubtext))
                    .frame(width: 40, height: 3)
                    .padding(.top, 9)
                    .frame(width: 160, height: 44, alignment: .top)
                    .contentShape(.rect)
            })
            .buttonStyle(.plain)
            .accessibilityLabel(Text(GrabberLabel()))
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(Color(.tripCardText))
        .background(Color(.tripCard), in: .rect(cornerRadius: 30))
        .contentShape(.rect(cornerRadius: 30))
        // A tapped car, the arrival message and the destination swap in place, and the card grows or shrinks with
        // them instead of jumping to its new height.
        .animation(Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion), value: viewModel.selectedCarID)
        .animation(Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion), value: viewModel.arrivalCard)
        .gesture(
            DragGesture(minimumDistance: 12).onEnded { drag in
                if drag.translation.height < -Self.dragDistance { SetExpanded(true) }
                if drag.translation.height > Self.dragDistance { PullDown() }
            }
        )
    }

    /// With a car's status open, the grabber closes it; otherwise it opens or closes the card.
    private func TapGrabber() {
        if viewModel.selectedCarStatus != nil {
            viewModel.SelectCar(nil)
        } else {
            SetExpanded(isExpanded == false)
        }
    }

    private func PullDown() {
        if viewModel.selectedCarStatus != nil { viewModel.SelectCar(nil) }
        SetExpanded(false)
    }

    private func GrabberLabel() -> LocalizedStringResource {
        if viewModel.selectedCarStatus != nil { return .tripMapCloseCarStatus }
        return isExpanded ? .tripMapCollapseCard : .tripMapExpandCard
    }

    private func SetExpanded(_ expanded: Bool) {
        withAnimation(Animation.lezgoPanel.Respecting(reduceMotion: reduceMotion)) { isExpanded = expanded }
    }
}

extension TripMapSheet {
    /// What the card holds. Its own view, so it can be laid out plain or in a scroll view at very large text sizes.
    struct Content: View {
        let viewModel: TripMapViewModel
        let onNewDestination: (() -> Void)?
        /// `false` while the card is collapsed: Edit Route and the red button stay out of reach.
        let isExpanded: Bool

        var body: some View {
            VStack(spacing: 18) {
                Summary(viewModel: viewModel, onNewDestination: onNewDestination)
                if isExpanded {
                    VStack(spacing: 10) {
                        // After arriving the choices are New Destination and leaving (US-07, "Arrive").
                        if viewModel.canEditRoute, viewModel.arrivalCard == nil {
                            Button(action: viewModel.RequestEditRoute) {
                                Label(.tripMapEditRoute, systemImage: "pencil")
                            }
                            .buttonStyle(TripMapCardButtonStyle())
                        }
                        // Near a destination whose point is a little off, such as the far side of a big mall.
                        if viewModel.canMarkArrived {
                            Button(action: viewModel.RequestMarkArrived) {
                                Label(.tripMapIveArrived, systemImage: "flag.checkered")
                            }
                            .buttonStyle(TripMapCardButtonStyle())
                            .disabled(viewModel.manualArrival.isSaving)
                        }
                        TripMapLeaveButton(isLeader: viewModel.isLeader, action: viewModel.RequestLeave)
                            .disabled(viewModel.isLeaving)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 20)
        }
    }
}

extension TripMapSheet {
    /// The card's top, the part that shows while it is collapsed: a tapped car, the arrival message, or the
    /// destination with the time and distance left.
    struct Summary: View {
        let viewModel: TripMapViewModel
        let onNewDestination: (() -> Void)?

        var body: some View {
            if let carStatus = viewModel.selectedCarStatus {
                TripMapCarStatusCard(status: carStatus, onClose: { viewModel.SelectCar(nil) })
                    .transition(.opacity)
            } else if let arrivalCard = viewModel.arrivalCard {
                TripMapArrivalCardView(
                    card: arrivalCard,
                    isLeader: viewModel.isLeader,
                    onNewDestination: onNewDestination
                )
                .disabled(viewModel.isLeaving)
                .transition(.opacity)
            } else if let destinationName = viewModel.destinationName {
                TripMapDestinationSummary(
                    destinationName: destinationName,
                    timeLeft: viewModel.guidance?.timeLeft
                )
                .transition(.opacity)
            } else {
                ProgressView(.tripMapLoading)
                    .transition(.opacity)
            }
        }
    }
}

#if DEBUG
// The card needs a live view model, so the previews open the map with a simulated drive.
#Preview("Leader") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.agusID)
}

#Preview("Member") {
    SimulatedTripMapScreen(myParticipantID: SampleTrip.budiID)
}
#endif
