//
//  SimulatedArrivalsScreen.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 05/11/26.
//

#if DEBUG
import SwiftUI

/// The top card and the arrival card with cars arriving one by one, to check the robots' animation on a phone. The
/// real map only shows it when several cars reach the destination, which the simulated drive does not do.
struct SimulatedArrivalsScreen: View {
    let totalCount: Int
    @State private var arrived = 1
    @State private var ids = (0..<TripMapArrivalProgress.maxRobots).map { _ in UUID() }

    private static let colors: [TripMapCarPin.CarColor] = [.yellow, .blue, .pink, .purple, .green]

    var body: some View {
        VStack(spacing: 24) {
            TripMapArrivalTopCard(
                progress: TripMapArrivalProgress(
                    robots: zip(ids, Self.colors).prefix(arrived).map { .init(id: $0, carColor: $1) },
                    arrivedCount: arrived,
                    totalCount: totalCount
                )
            )
            Spacer()
            TripMapArrivalCardView(
                card: arrived == totalCount ? .everyoneArrived : .waitingForEveryone,
                isLeader: true,
                onNewDestination: {}
            )
            .padding(20)
            .background(Color(.tripCard), in: .rect(cornerRadius: 30))
            .foregroundStyle(Color(.tripCardText))
        }
        .padding(12)
        .background(Color(.tripCardSubtext).opacity(0.3))
        .environment(\.colorScheme, .dark)
        .task { await ArriveOneByOne() }
    }

    private func ArriveOneByOne() async {
        while arrived < totalCount {
            let wait = arrived < TripMapArrivalProgress.maxRobots ? TripMapArrivalMotion.duration + 0.4 : 1
            try? await Task.sleep(for: .seconds(wait))
            arrived += 1
        }
    }
}

#Preview("Seven cars") {
    SimulatedArrivalsScreen(totalCount: 7)
}
#endif
