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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `true` once the card with the next stop has scrolled off, so the navigation bar takes the title over.
    @State private var showsTitleInBar = false

    /// "To Alun Alun Malang"; the plain label until the route is known.
    private var nextStopTitle: String {
        viewModel.nextStopTitle ?? String(localized: .tripMapOnTheGoNextStop)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    NextStopCard()
                    Text(.tripMapOnTheGoParticipants)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 3)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(viewModel.participantRows) { row in
                        TripMapOnTheGoRow(row: row)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                // Room for the buttons, so the last row can be scrolled above them.
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Color(.tripCard))
            // The system bar centres the title and slides the content under it; the title is only shown while the
            // card, which carries it, is out of sight. `navigationTitle` stays for VoiceOver.
            .navigationTitle(nextStopTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text(verbatim: nextStopTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .opacity(showsTitleInBar ? 1 : 0)
                }
            }
            .toolbarBackground(Color(.tripCard), for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .scrollEdgeEffectStyle(.hard, for: .top)
            .overlay(alignment: .bottom) {
                // The rows fade out under the buttons, as in the hi-fi.
                LinearGradient(colors: [.clear, Color(.tripCard)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) { Buttons() }
        }
        .task { await viewModel.TrackAllCars() }
    }

    private func NextStopCard() -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: nextStopTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .onScrollVisibilityChange { isVisible in
                        withAnimation(Animation.lezgoFade.Respecting(reduceMotion: reduceMotion)) {
                            showsTitleInBar = isVisible == false
                        }
                    }
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
