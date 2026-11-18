//
//  TripMapOnTheGoView.swift
//  Lezgo
//
//  Created by Oky Faishal on 18/11/26.
//

import SwiftUI

/// What the phone shows instead of the trip map while CarPlay is connected: the car's screen has the map, so the
/// phone lists the time to the next stop and every participant. The leader can end the trip or edit the route; a
/// member can exit (ADR 0034).
struct TripMapOnTheGoView: View {
    let viewModel: TripMapViewModel

    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // The title, the card and the heading stay in place; only the participants scroll under them.
            Text(.tripMapOnTheGoTitle)
                .font(.largeTitle.weight(.heavy))
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)
            NextStopCard()
            Text(.tripMapOnTheGoParticipants)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.top, 3)
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(viewModel.participantRows) { row in
                        TripMapOnTheGoRow(row: row)
                    }
                }
                .padding(.top, 2)
                // Room for the buttons, so the last row can be scrolled above them.
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        // Solid, so the rows never show through the fixed part while they scroll.
        .background(Color(.tripCard))
        .overlay(alignment: .bottom) {
            // The rows fade out under the buttons, as in the hi-fi.
            LinearGradient(colors: [.clear, Color(.tripCard)], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) { Buttons() }
        .task { await viewModel.TrackAllCars() }
    }

    private func NextStopCard() -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(.tripMapOnTheGoNextStop)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if let timeToNextStop = viewModel.timeToNextStop {
                    Text(timeToNextStop.formatted(TripMapCarStatus.durationStyle))
                        .font(.system(size: timeSize, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            TripMapOnTheGoTrack(progress: viewModel.routeProgress)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .lezgoSurface(.page, radius: LezgoRadius.card)
        .overlay {
            RoundedRectangle(cornerRadius: LezgoRadius.card)
                .strokeBorder(Color(.surfaceSeparator), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func Buttons() -> some View {
        HStack(spacing: 12) {
            TripMapLeaveButton(isLeader: viewModel.isLeader, action: viewModel.RequestLeave)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isLeaving)
            if viewModel.canEditRoute {
                Button(action: viewModel.RequestEditRoute) {
                    Text(.tripMapEditRoute)
                }
                .lezgoGlassButton(.main)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
