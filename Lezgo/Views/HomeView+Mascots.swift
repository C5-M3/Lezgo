//
//  HomeView+Mascots.swift
//  Lezgo
//
//  Created by Muhammad Rizal Pratama on 06/11/26.
//

import SwiftUI

extension HomeView {
    /// Mascot illustrations displayed at the bottom of the Home screen.
    /// In its own file so `HomeView.swift` stays under SwiftLint's 400-line limit.
    struct MascotsView: View {
        var body: some View {
            GeometryReader { proxy in
                let width = proxy.size.width
                let centerX = width / 2

                ZStack(alignment: .bottom) {
                    // Blue (Mid Left)
                    Image("BlueMascotHome")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .position(x: centerX - 118, y: 160)

                    // Purple (Back Left)
                    Image("PurpleMascotHome")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                        .position(x: 43, y: 70)

                    // Green (Back Right)
                    Image("GreenMascotHome")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 105)
                        .position(x: width - 50, y: 75)

                    // Pink (Mid Right)
                    Image("PinkMascotHome")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 110)
                        .position(x: centerX + 116, y: 155)

                    // Yellow (Front Center)
                    Image("YellowMascotHome")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 130)
                        .position(x: centerX, y: 150)
                }
                .frame(width: width, height: 240)
            }
            .frame(height: 240)
            .ignoresSafeArea(edges: .bottom)
            .accessibilityHidden(true)
        }
    }
}
