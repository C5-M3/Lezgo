//
//  HomeView+Cards.swift
//  Lezgo
//
//  Created by Rizal Pratama on 17/11/26.
//

import SwiftUI

struct LeadTripCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onLeadTrip: () -> Void

    var body: some View {
        Button(action: onLeadTrip) {
            ZStack(alignment: .trailing) {
                // Mascot watermark on the right side
                Image("LeadTripMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 180)
                    .offset(y: 15)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 54) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(.black)
                                .frame(width: 50, height: 50)

                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.brandYellow)
                                // The icon must stay inside its 50-point circle.
                                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                                .accessibilityHidden(true)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.black)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Lead a trip")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.black)

                        Text("Plan the trip and make a room for friends to join trip!")
                            .font(.subheadline)
                            .foregroundStyle(.black)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .background(Color.brandYellow)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

struct JoinTripCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onJoinTrip: () -> Void

    private let cardDarkBackground = Color(red: 28/255, green: 28/255, blue: 30/255)

    var body: some View {
        Button(action: onJoinTrip) {
            ZStack(alignment: .trailing) {
                // Mascot watermark on the right side
                Image("JoinTripMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .offset(x: -10, y: -8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 54) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(Color.brandYellow)
                                .frame(width: 50, height: 50)

                            Image(systemName: "door.left.hand.open")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.black)
                                // The icon must stay inside its 50-point circle.
                                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                                .accessibilityHidden(true)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(white: 0.6))
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Join a trip")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)

                        Text("Got a room code from friend leader? Join the room now!")
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.6))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .background(cardDarkBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
