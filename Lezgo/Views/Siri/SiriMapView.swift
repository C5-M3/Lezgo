//
//  SiriMapView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// The still map on a Siri card (US-08): MapKit's picture with Lezgo's yellow route line and the robots on top.
struct SiriMapView: View {
    let map: SiriMapPicture
    /// The robot colour of each car, in the order of `map.carPoints`.
    let colors: [TripMapCarPin.CarColor]
    /// "1.2 km", in a dark chip between the first two cars.
    var label: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: map.image)
                .resizable()
            RouteLine(points: map.routePoints)
            ForEach(Array(zip(map.carPoints, colors).enumerated()), id: \.offset) { _, car in
                Image(car.1.TopViewImage(isGlowing: false))
                    .resizable()
                    .frame(width: 30, height: 30)
                    .background(Color(.tripCard), in: .circle)
                    .position(car.0)
            }
            if let label, map.carPoints.count >= 2 {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(Color(.tripCardText))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tripCard), in: .capsule)
                    .position(Midpoint(map.carPoints[0], map.carPoints[1]))
            }
        }
        .frame(width: SiriMapPicture.size.width, height: SiriMapPicture.size.height)
        .clipShape(.rect(cornerRadius: 18))
        .accessibilityHidden(true)
    }

    private func Midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}

/// The group's road on the still map: yellow with a dark edge, like the trip map's route.
private struct RouteLine: View {
    let points: [CGPoint]

    var body: some View {
        let path = Path { path in path.addLines(points) }
        path.stroke(Color(.tripCard), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
        path.stroke(Color(.brandYellow), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
    }
}

#Preview {
    SiriMapView(
        map: SiriMapPicture(
            image: UIImage(),
            carPoints: [CGPoint(x: 80, y: 120), CGPoint(x: 260, y: 30)],
            routePoints: [CGPoint(x: 40, y: 150), CGPoint(x: 170, y: 80), CGPoint(x: 330, y: 0)]
        ),
        colors: [.blue, .yellow],
        label: "1.2 km"
    )
    .padding()
}
