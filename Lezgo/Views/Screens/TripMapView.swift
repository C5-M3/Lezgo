//
//  TripMapView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 26/10/26.
//

import SwiftUI

/// The trip map (Trip Started screen): the shared route, its waypoints and every car, with the next turn on top
/// and a sheet at the bottom, as in Apple Maps.
struct TripMapView: View {
    @State private var viewModel: TripMapViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.dismiss) private var dismiss
    /// Where CarPlay finds this map, to mirror it while it is on screen (ADR 0023).
    @Environment(\.activeTripMap) private var activeTripMap
    /// Whether the bottom card is pulled up. It starts collapsed, so End Trip and Exit Trip are out of reach while
    /// driving.
    @State private var isSheetExpanded = false
    /// Which way the map is turned, for the compass button.
    @State private var mapHeading = TripMapHeading()
    /// The planner on screen; `nil` while it is closed.
    @State private var presentedEditRoute: EditRouteViewModel?
    /// The yellow "Lez Go!" animation is on top of the map.
    @State private var showsStartIntro: Bool
    /// The cards, the cars and the map buttons are in place; during the animation they wait out of sight.
    @State private var isTripScreenRevealed: Bool
    /// `false` until the robot has landed: while the cover slides up, the yellow does not yet reach the top of the
    /// screen, and the map would show there.
    @State private var isMapVisible: Bool
    /// The map starts a little zoomed in behind the animation and settles as the camera goes through the O.
    @State private var mapScale: Double

    /// Returns to Home once the map closes; `nil` dismisses the map.
    private let onClose: (() -> Void)?
    /// Opens the Trip Room with the trip back in `LOBBY` after a New Destination; `nil` hides "New Destination".
    private let onReturnToTripRoom: ((TripSession) -> Void)?

    init(
        viewModel: TripMapViewModel,
        onClose: (() -> Void)? = nil,
        onReturnToTripRoom: ((TripSession) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        _showsStartIntro = State(initialValue: viewModel.showsStartIntro)
        _isTripScreenRevealed = State(initialValue: viewModel.showsStartIntro == false)
        _isMapVisible = State(initialValue: viewModel.showsStartIntro == false)
        _mapScale = State(initialValue: viewModel.showsStartIntro ? 1.32 : 1)
        self.onClose = onClose
        self.onReturnToTripRoom = onReturnToTripRoom
    }

    var body: some View {
        // The map closes the car status on a tap (below) but is not a button, so it gets no button trait;
        // VoiceOver closes it with its Close button or the escape gesture instead.
        // swiftlint:disable:next accessibility_trait_for_button
        MapLayer(viewModel: viewModel, showsCars: isTripScreenRevealed, compassHeading: mapHeading)
        // Keeps Apple's Maps logo and Legal link above the bottom card, where they must stay visible, and the compass
        // under the turn card. Fixed, so the map never changes size as the cards come and go.
        .safeAreaPadding(.vertical, 140)
        .scaleEffect(mapScale)
        .opacity(isMapVisible ? 1 : 0)
        // Tapping the map anywhere but a car closes the car status.
        .onTapGesture { viewModel.SelectCar(nil) }
        .overlay(alignment: .top) {
            if isTripScreenRevealed {
                TopCards(viewModel: viewModel)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if isTripScreenRevealed {
                BottomControls(
                    viewModel: viewModel,
                    mapHeading: mapHeading,
                    onNewDestination: NewDestinationAction(),
                    isSheetExpanded: $isSheetExpanded
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            DialogLayer(viewModel: viewModel, close: Close)
        }
        .overlay {
            if showsStartIntro {
                TripStartIntroView()
                    .ignoresSafeArea()
                    // The cards come in just before the yellow has gone, and must already answer a tap.
                    .allowsHitTesting(isTripScreenRevealed == false)
                    .transition(.opacity)
            }
        }
        .background { (showsStartIntro ? Color(.brandYellow) : Color(.tripCard)).ignoresSafeArea() }
        // The hi-fi trip screen is dark in light and dark mode: it is read at a glance on the road.
        .environment(\.colorScheme, .dark)
        .fullScreenCover(item: $presentedEditRoute, onDismiss: viewModel.CloseEditRoute) { editRoute in
            EditRouteView(viewModel: editRoute, onClose: viewModel.CloseEditRoute)
        }
        .onChange(of: viewModel.editRoute?.id) {
            presentedEditRoute = viewModel.editRoute
        }
        .task { await viewModel.Start() }
        .onAppear { activeTripMap.Show(viewModel) }
        .onDisappear {
            activeTripMap.Hide(viewModel)
            viewModel.sound.Stop()
        }
        .task { await PlayStartIntro() }
        .task(id: viewModel.selectedCarID) { await viewModel.TrackSelectedCar() }
        .onChange(of: viewModel.selectedCarID) {
            // A car tapped: the card goes down so the car shows on the map.
            if viewModel.selectedCarID != nil { isSheetExpanded = false }
        }
        .onChange(of: viewModel.arrivalCard) {
            // Arriving is when the driver chooses what is next, so the card comes up with the choices.
            if viewModel.arrivalCard != nil { isSheetExpanded = true }
        }
        .onChange(of: viewModel.closeReason) {
            // Leaving on purpose needs no message: go straight back to Home.
            if viewModel.closeReason == .exited || viewModel.closeReason == .ended {
                Close()
            }
            if let session = viewModel.tripRoomSession {
                onReturnToTripRoom?(session)
            }
        }
    }

    /// Brings in the map at the right moments of the animation, then removes the yellow.
    private func PlayStartIntro() async {
        guard showsStartIntro else { return }
        if reduceMotion {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.easeInOut(duration: 0.3)) {
                isMapVisible = true
                mapScale = 1
                isTripScreenRevealed = true
                showsStartIntro = false
            }
            return
        }
        // The hole opens just before the robot leaves, so the map must be there by then.
        let mapAppears = TripStartIntro.robotLeaves - 0.2
        try? await Task.sleep(for: .seconds(mapAppears))
        isMapVisible = true
        try? await Task.sleep(for: .seconds(TripStartIntro.mapSettles - mapAppears))
        withAnimation(.easeOut(duration: 0.9)) { mapScale = 1 }
        try? await Task.sleep(for: .seconds(TripStartIntro.mapReveals - TripStartIntro.mapSettles))
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { isTripScreenRevealed = true }
        try? await Task.sleep(for: .seconds(TripStartIntro.duration - TripStartIntro.mapReveals))
        showsStartIntro = false
    }

    private func Close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    /// "New Destination" shows only where the screen that opened the map can take everyone back to the Trip Room.
    private func NewDestinationAction() -> (() -> Void)? {
        guard onReturnToTripRoom != nil else { return nil }
        return viewModel.RequestNewDestination
    }
}

/// The widest the turn card and the bottom card get, so they do not stretch across the map in landscape.
private let maxCardWidth = 480.0

extension TripMapView {
    /// The next turn and any notices, above the map.
    struct TopCards: View {
        let viewModel: TripMapViewModel
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        var body: some View {
            VStack(alignment: .trailing) {
                // After arriving there is no next turn, so the card counts who is there. While a new route is on its
                // way, the card says so instead of showing a turn that no longer fits.
                if let arrivalProgress = viewModel.arrivalProgress {
                    TripMapArrivalTopCard(progress: arrivalProgress)
                        .transition(.opacity)
                } else if viewModel.isRerouting {
                    TripMapTurnCard.Rerouting(isLeader: viewModel.isLeader)
                        .transition(.opacity)
                } else if let guidance = viewModel.guidance {
                    TripMapTurnCard(guidance: guidance)
                        .transition(.opacity)
                }
                if viewModel.isLocationImprecise {
                    PreciseLocationNotice()
                        .transition(.opacity)
                } else if viewModel.isConnectionLost {
                    ConnectionLostNotice()
                        .transition(.opacity)
                }
                if let notice = viewModel.noticeBanner {
                    TripMapNoticeBanner(
                        notice: notice,
                        timeLeft: viewModel.guidance?.timeLeft,
                        onClose: { viewModel.DismissNotice(notice) }
                    )
                    .transition(.opacity)
                } else if let alertBanner = viewModel.alertBanner {
                    // A fade, not a slide: sliding in, the banner would pass behind the turn card.
                    TripMapAlertBanner(banner: alertBanner, onClose: viewModel.DismissAlertBanner)
                        .transition(.opacity)
                }
            }
            // In landscape the cards stay beside the map instead of stretching across it.
            .frame(maxWidth: maxCardWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, verticalSizeClass == .compact ? 8 : 0)
            .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: Shown())
            .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: viewModel.alertBanner)
            .animation(Animation.lezgoSwap.Respecting(reduceMotion: reduceMotion), value: viewModel.noticeBanner)
        }

        /// Which cards are on screen, so one animation covers every card coming, going or swapping.
        private func Shown() -> [Bool] {
            [
                viewModel.arrivalProgress == nil,
                viewModel.isRerouting,
                viewModel.guidance == nil,
                viewModel.isLocationImprecise,
                viewModel.isConnectionLost
            ]
        }
    }

    /// The round map buttons and the card under them, which move up together as the card opens.
    struct BottomControls: View {
        let viewModel: TripMapViewModel
        let mapHeading: TripMapHeading
        let onNewDestination: (() -> Void)?
        @Binding var isSheetExpanded: Bool
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        var body: some View {
            VStack(alignment: .trailing, spacing: 14) {
                // At the largest text sizes the open card and the turn card fill the screen, with no room left.
                if isSheetExpanded == false || dynamicTypeSize.isAccessibilitySize == false {
                    TripMapCameraControls(
                        mapHeading: mapHeading,
                        cameraMode: viewModel.cameraMode,
                        isMuted: viewModel.sound.isMuted,
                        toggleMute: viewModel.sound.ToggleMute,
                        toggleCamera: viewModel.ToggleCamera
                    )
                }
                TripMapSheet(viewModel: viewModel, onNewDestination: onNewDestination, isExpanded: $isSheetExpanded)
                    .frame(maxWidth: maxCardWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 25)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// The questions and messages about leaving the trip and "I've Arrived".
    struct DialogLayer: View {
        let viewModel: TripMapViewModel
        /// Goes back to Home once someone else ended the trip or removed this member.
        let close: () -> Void

        var body: some View {
            // A fade only: the dialog's card brings its own small pop as it arrives.
            ZStack {
                Dialog()
                    .transition(.opacity)
            }
            .animation(.lezgoFade, value: Shown())
        }

        /// Which dialogs could show, so changing from one dialog to the next fades between them.
        private func Shown() -> [Bool] {
            [
                viewModel.leaveConfirmation != nil,
                viewModel.manualArrival.confirmation != nil,
                viewModel.manualArrival.errorMessage != nil,
                viewModel.leaveErrorMessage != nil,
                viewModel.closeReason == .endedByLeader || viewModel.closeReason == .removed
            ]
        }

        @ViewBuilder
        private func Dialog() -> some View {
            if let confirmation = viewModel.leaveConfirmation {
                ConfirmDialog(
                    title: Text(IsEndTrip(confirmation) ? .tripMapEndTripQuestion : .tripMapExitTripQuestion),
                    message: Message(of: confirmation),
                    cancelTitle: .tripMapCancel,
                    confirmTitle: .tripMapConfirm,
                    isDestructive: IsEndTrip(confirmation),
                    isConfirmDisabled: viewModel.isLeaving,
                    onCancel: viewModel.CancelLeave,
                    onConfirm: { Task { await viewModel.ConfirmLeave(confirmation) } }
                )
            } else if let confirmation = viewModel.manualArrival.confirmation {
                ArrivalQuestion(manualArrival: viewModel.manualArrival, confirmation: confirmation)
            } else if let error = viewModel.manualArrival.errorMessage {
                Message(Text(verbatim: error), onOK: viewModel.manualArrival.DismissError)
            } else if let error = viewModel.leaveErrorMessage {
                Message(Text(verbatim: error), onOK: viewModel.DismissLeaveError)
            } else if viewModel.closeReason == .endedByLeader || viewModel.closeReason == .removed {
                Message(
                    Text(viewModel.closeReason == .removed ? .tripMapRemovedFromTrip : .tripMapLeaderEndedTrip),
                    onOK: close
                )
            }
        }

        /// A message with only "OK".
        private func Message(_ title: Text, onOK: @escaping () -> Void) -> some View {
            ConfirmDialog(title: title, cancelTitle: nil, confirmTitle: .tripMapOK, onConfirm: onOK)
        }

        private func IsEndTrip(_ confirmation: TripMapViewModel.LeaveConfirmation) -> Bool {
            confirmation != .exitTrip
        }

        private func Message(of confirmation: TripMapViewModel.LeaveConfirmation) -> Text? {
            switch confirmation {
            case .exitTrip: Text(.tripMapExitTripMessage)
            case .endTrip(everyoneHasArrived: false): Text(.tripMapEndTripNotEveryoneMessage)
            case .endTrip: nil
            }
        }
    }
}

extension TripMapView {
    /// "Arrived at Tunjungan Plaza?" · "You are 200 m from the destination point. Are you sure you have arrived?"
    struct ArrivalQuestion: View {
        let manualArrival: TripMapManualArrival
        let confirmation: TripMapManualArrival.Confirmation

        var body: some View {
            // Always in metres, as the destination's point is at most 1 km away. A no-break space keeps "200 m" on
            // one line at large text sizes.
            let distance = confirmation.distance.formatted(.measurement(width: .abbreviated, usage: .asProvided))
                .replacing(" ", with: "\u{00A0}")
            ConfirmDialog(
                title: Text(.tripMapArrivedQuestion(confirmation.destinationName)),
                message: Text(.tripMapArrivedMessage(distance)),
                cancelTitle: .tripMapCancel,
                confirmTitle: .tripMapIveArrived,
                isConfirmDisabled: manualArrival.isSaving,
                onCancel: manualArrival.Cancel,
                onConfirm: { Task { await manualArrival.Confirm(confirmation) } }
            )
        }
    }
}

extension TripMapView {
    /// A quiet notice under the turn card while this phone cannot send its position (#220). It is not an alert:
    /// the driver needs no action, and it goes away by itself when the connection is back.
    struct ConnectionLostNotice: View {
        var body: some View {
            Label(.tripMapConnectionLost, systemImage: "wifi.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.tripCardText))
                .padding(.horizontal)
                .padding(.vertical, 8)
                // A dark capsule like the other trip map cards, instead of Liquid Glass.
                .background(Color(.tripCard), in: .capsule)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

#Preview("Connection lost") {
    TripMapView.ConnectionLostNotice()
        .padding()
}
