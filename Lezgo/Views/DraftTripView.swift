//
//  DraftTripView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import SwiftUI

/// Screen displayed when user has an unfinished or draft trip (US-03).
///
/// Presents the "You have a trip in progress" screen with trip route details,
/// and provides options to continue the active trip or confirm creating a new trip.
struct DraftTripView: View {
    // MARK: - Properties

    @State var viewModel: DraftTripViewModel
    var onContinueTrip: (() -> Void)?
    var onNewTrip: (() -> Void)?

    // MARK: - Initializer

    init(
        viewModel: DraftTripViewModel,
        onContinueTrip: (() -> Void)? = nil,
        onNewTrip: (() -> Void)? = nil
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.onContinueTrip = onContinueTrip
        self.onNewTrip = onNewTrip
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main Draft Trip Screen
            mainContent
                .disabled(viewModel.isConfirmingNewTrip)
                .accessibilityHidden(viewModel.isConfirmingNewTrip)

            // Confirmation Modal ("Confirm New Trip")
            if viewModel.isConfirmingNewTrip {
                confirmNewTripOverlay
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isConfirmingNewTrip)
        .task {
            await viewModel.CheckServerStatus()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            Color(red: 0.49, green: 0.49, blue: 0.49)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Illustration Circle & Headline
                VStack(spacing: 24) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 190, height: 190)
                        .accessibilityHidden(true)

                    Text("You have a trip\nin progress")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // Bottom Summary Card
                bottomCard
            }
        }
    }

    // MARK: - Bottom Summary Card

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Start Point
            HStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.black)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(viewModel.startPointName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
            }

            // Route Distance Indicator with 3 vertical dots
            HStack(spacing: 12) {
                VStack(spacing: 3) {
                    Circle().fill(Color.gray).frame(width: 3, height: 3)
                    Circle().fill(Color.gray).frame(width: 3, height: 3)
                    Circle().fill(Color.gray).frame(width: 3, height: 3)
                }
                .frame(width: 24)
                .accessibilityHidden(true)

                if !viewModel.distanceText.isEmpty {
                    Text(viewModel.distanceText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }

            // Destination
            HStack(spacing: 12) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.black)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(viewModel.destinationName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
            }

            // Participants
            if !viewModel.membersText.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(viewModel.membersText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }

            // Action Buttons: New Trip & Continue Trip
            HStack(spacing: 12) {
                // New Trip Button
                Button {
                    viewModel.TapNewTrip()
                } label: {
                    Text("New Trip")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.50, green: 0.50, blue: 0.50))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New Trip")

                // Continue Trip Button
                Button {
                    onContinueTrip?()
                } label: {
                    Text("Continue Trip")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.50, green: 0.50, blue: 0.50))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue Trip")
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Confirm New Trip Overlay

    private var confirmNewTripOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Menahan interaksi agar fokus tetap pada tombol aksi modal dan latar belakang tidak dapat menutup modal
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 50) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.confirmTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.primary)

                    if let message = viewModel.confirmMessage {
                        Text(message)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.secondary)
                    }
                }

                HStack(spacing: 12) {
                    // Cancel Button
                    Button {
                        viewModel.DismissConfirmation()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.65, green: 0.65, blue: 0.65))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel new trip creation")

                    // Create Button
                    Button {
                        Task {
                            let success = await viewModel.ConfirmNewTrip()
                            if success {
                                onNewTrip?()
                            }
                        }
                    } label: {
                        Text("Create")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(white: 0.95))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Confirm create new trip")
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(white: 0.88))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture {
                // Menahan ketukan di dalam kartu agar tidak memicu interaksi lain
            }
        }
        .zIndex(100)
    }
}

// MARK: - Previews & Simulated

#if DEBUG
extension DraftTripView {
    static func Simulated(isLeader: Bool = false) -> DraftTripView {
        DraftTripView(viewModel: isLeader ? .sampleLeader : .sample)
    }
}

#Preview("Draft Road Trip - Member") {
    DraftTripView(viewModel: .sample)
}

#Preview("Draft Road Trip - Leader") {
    DraftTripView(viewModel: .sampleLeader)
}
#endif
