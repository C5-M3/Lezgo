import SwiftUI

/// The bottom card once this phone's car has arrived (`specs/UserStories.md` → US-07, "Arrive"): who has arrived,
/// and for the leader the "New Destination" choice. The leader is never blocked by late cars, so the choice is
/// there while others are still on the way.
struct TripMapArrivalCardView: View {
    let card: TripMapArrivalCard
    let isLeader: Bool
    /// Opens the planner with the start point locked to this destination (#115). `nil` hides the button.
    let onNewDestination: (() -> Void)?
    let onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Title())
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = Subtitle() {
                    Text(subtitle)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            if isLeader, let onNewDestination {
                Button(action: onNewDestination) {
                    Text(.tripMapNewDestination)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            TripMapLeaveButton(isLeader: isLeader, action: onLeave)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private func Title() -> LocalizedStringResource {
        switch card {
        case .waitingForEveryone: .tripMapYouHaveArrived
        case .everyoneArrived: .tripMapEveryoneHasArrived
        }
    }

    private func Subtitle() -> LocalizedStringResource? {
        switch card {
        case .waitingForEveryone: .tripMapWaitingForEveryone
        case .everyoneArrived: isLeader ? .tripMapContinueYourTrip : nil
        }
    }
}

#Preview("Member, waiting") {
    TripMapArrivalCardView(card: .waitingForEveryone, isLeader: false, onNewDestination: nil, onLeave: {})
        .padding()
}

#Preview("Member, everyone arrived") {
    TripMapArrivalCardView(card: .everyoneArrived, isLeader: false, onNewDestination: nil, onLeave: {})
        .padding()
}

#Preview("Leader, waiting") {
    TripMapArrivalCardView(card: .waitingForEveryone, isLeader: true, onNewDestination: {}, onLeave: {})
        .padding()
}

#Preview("Leader, everyone arrived, largest text") {
    TripMapArrivalCardView(card: .everyoneArrived, isLeader: true, onNewDestination: {}, onLeave: {})
        .padding()
        .dynamicTypeSize(.accessibility5)
}
