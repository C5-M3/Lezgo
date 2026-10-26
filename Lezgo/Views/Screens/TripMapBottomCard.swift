import SwiftUI

/// The bottom card on the trip map: "To [destination]" and the time left.
struct TripMapBottomCard: View {
    let destinationName: String
    /// `nil` until the first guidance arrives; the card then shows only the destination.
    let timeLeft: Duration?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(.tripMapToDestination(destinationName))
                .font(.headline)
            if let timeLeft {
                Text(timeLeft.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

#Preview("With time left") {
    TripMapBottomCard(destinationName: "Ciputra World Surabaya", timeLeft: .seconds(3_000))
        .padding()
}

#Preview("Before guidance, long name, largest text") {
    TripMapBottomCard(
        destinationName: "Pakuwon Mall, Jalan Puncak Indah Lontar No. 2, Babatan, Wiyung, Surabaya",
        timeLeft: nil
    )
    .padding()
    .dynamicTypeSize(.accessibility5)
}
