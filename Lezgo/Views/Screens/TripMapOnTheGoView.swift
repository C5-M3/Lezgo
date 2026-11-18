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

    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 32

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(.tripMapOnTheGoTitle)
                    .font(.largeTitle.weight(.heavy))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                NextStopCard()
                Text(.tripMapOnTheGoParticipants)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                ForEach(viewModel.participantRows) { row in
                    TripMapOnTheGoRow(row: row)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            // Room for the buttons, so the last row can be scrolled above them.
            .padding(.bottom, 120)
        }
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
                        .font(.system(size: timeSize, weight: .black))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            TripMapOnTheGoTrack(progress: viewModel.routeProgress)
        }
        .padding(20)
        .lezgoSurface(.level1, radius: LezgoRadius.card)
        .accessibilityElement(children: .combine)
    }

    private func Buttons() -> some View {
        HStack(spacing: 12) {
            TripMapLeaveButton(isLeader: viewModel.isLeader, action: viewModel.RequestLeave)
                .disabled(viewModel.isLeaving)
            if viewModel.canEditRoute {
                Button(action: viewModel.RequestEditRoute) {
                    Text(.tripMapEditRoute)
                }
                .lezgoGlassButton(.main)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
