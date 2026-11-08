//
//  DraftTripView+BottomCard.swift
//  Lezgo
//
//  Created by Rizal Pratama on 27/10/26.
//

import SwiftUI

extension DraftTripView {
    /// Bottom card presenting saved trip details and actions.
    /// In its own file so `DraftTripView.swift` stays under SwiftLint's line and length limits.
    struct BottomCard: View {
        let viewModel: DraftTripViewModel
        let bottomInset: CGFloat
        let onContinueTrip: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                headerSection
                routeSection
                dividerSection
                participantsSection
                actionButtonsSection
            }
            .frame(maxWidth: .infinity)
            .background(Color.black)
        }

        // MARK: - Sections

        private var headerSection: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("WAIT!")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)

                Text("YOU HAVE A TRIP IN PROGRESS")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(white: 0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }

        private var routeSection: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.brandYellow)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    Text(viewModel.startPointName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Rectangle()
                    .fill(Color(white: 0.35))
                    .clipShape(.capsule)
                    .frame(width: 2, height: 18)
                    .padding(.leading, 11)
                    .padding(.vertical, 6)

                HStack(spacing: 16) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.brandYellow)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)

                    Text(viewModel.destinationName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }

        private var dividerSection: some View {
            Rectangle()
                .fill(Color(white: 0.22))
                .frame(height: 1)
                .padding(.horizontal, 24)
        }

        private var participantsSection: some View {
            HStack(spacing: 0) {
                let avatarNames = [
                    "FrontballActiveYellow",
                    "FrontballActivePink",
                    "FrontballActiveBlue",
                    "FrontballActivePurple",
                    "FrontballActiveGreen"
                ]
                let count = min(max(viewModel.memberCount, 1), avatarNames.count)

                HStack(spacing: -40) {
                    ForEach(0..<count, id: \.self) { index in
                        Image(avatarNames[index])
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                    }
                }
                .accessibilityHidden(true)

                Text(viewModel.tripInfoText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(white: 0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var actionButtonsSection: some View {
            HStack(spacing: 14) {
                Button {
                    viewModel.TapNewTrip()
                } label: {
                    Text("New Trip")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255))
                        .clipShape(Capsule())
                }
                .contentShape(Capsule())
                .buttonStyle(.plain)
                .accessibilityLabel("New Trip")

                Button {
                    onContinueTrip()
                } label: {
                    Text("Continue Trip")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.brandYellow)
                        .clipShape(Capsule())
                }
                .contentShape(Capsule())
                .buttonStyle(.plain)
                .accessibilityLabel("Continue Trip")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, bottomInset + 32)
        }
    }
}
