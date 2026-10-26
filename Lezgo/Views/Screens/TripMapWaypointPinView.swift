import SwiftUI

/// A start point, checkpoint or destination on the trip map. Visited checkpoints are shown with a check mark.
struct TripMapWaypointPinView: View {
    let waypoint: TripMapWaypoint
    let isVisited: Bool

    var body: some View {
        Image(systemName: Symbol())
            .font(.title)
            .symbolRenderingMode(.palette)
            .foregroundStyle(AnyShapeStyle(.background), isVisited ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .frame(minWidth: 44, minHeight: 44)
            // A map graphic: keep it from covering the route at the largest text sizes.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: waypoint.name))
            .accessibilityValue(Text(Description().formatted(.list(type: .and, width: .narrow))))
    }

    private func Symbol() -> String {
        if isVisited { return "checkmark.circle.fill" }
        switch waypoint.kind {
        case .start: return "circle.circle.fill"
        case .checkpoint: return "mappin.circle.fill"
        case .destination: return "flag.circle.fill"
        }
    }

    private func Description() -> [String] {
        let kind: LocalizedStringResource = switch waypoint.kind {
        case .start: .tripMapStartPoint
        case .checkpoint: .tripMapCheckpoint
        case .destination: .tripMapDestination
        }
        return isVisited ? [String(localized: kind), String(localized: .tripMapVisited)] : [String(localized: kind)]
    }
}

#Preview("Every kind of waypoint") {
    let coordinate = TripMapCoordinate(latitude: 0, longitude: 0)
    let waypoints = [
        TripMapWaypoint(id: UUID(), orderIndex: 0, kind: .start, name: "Tunjungan Plaza", coordinate: coordinate),
        TripMapWaypoint(id: UUID(), orderIndex: 1, kind: .checkpoint, name: "Ciputra World", coordinate: coordinate),
        TripMapWaypoint(id: UUID(), orderIndex: 2, kind: .destination, name: "Pakuwon mall", coordinate: coordinate)
    ]
    HStack(spacing: 16) {
        ForEach(waypoints) { waypoint in
            TripMapWaypointPinView(waypoint: waypoint, isVisited: waypoint.kind == .start)
        }
    }
    .padding()
}
