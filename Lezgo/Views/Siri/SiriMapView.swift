//
//  SiriMapView.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 12/11/26.
//

import SwiftUI

/// The still map on a Siri card (US-08): MapKit's picture with Lezgo's yellow route line and the robots on top. It
/// fills the card's width, whatever the phone, and keeps the picture's shape.
struct SiriMapView: View {
    let map: SiriMapPicture
    /// The robot colour of each car, in the order of `map.carPoints`.
    let colors: [TripMapCarPin.CarColor]
    /// "1.2 km", in a dark chip between the first two cars.
    var label: String?

    private static let robotSize: CGFloat = 30

    var body: some View {
        Canvas { context, size in
            let scale = size.width / SiriMapPicture.size.width
            let place = { (point: CGPoint) in CGPoint(x: point.x * scale, y: point.y * scale) }
            context.draw(Image(uiImage: map.image), in: CGRect(origin: .zero, size: size))
            DrawRoute(map.routePoints.map(place), in: &context)
            for (point, color) in zip(map.carPoints.map(place), colors) {
                let robot = Image(uiImage: UIImage(resource: color.TopViewImage(isGlowing: false)))
                DrawRobot(robot, at: point, in: &context)
            }
            if let label, map.carPoints.count >= 2 {
                let middle = CGPoint(
                    x: (map.carPoints[0].x + map.carPoints[1].x) / 2,
                    y: (map.carPoints[0].y + map.carPoints[1].y) / 2
                )
                DrawChip(label, at: place(middle), in: &context)
            }
        }
        .aspectRatio(SiriMapPicture.size.width / SiriMapPicture.size.height, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 18))
        .accessibilityHidden(true)
    }

    /// The group's road: yellow with a dark edge, like the trip map's route.
    private func DrawRoute(_ points: [CGPoint], in context: inout GraphicsContext) {
        let path = Path { path in path.addLines(points) }
        let style = { (width: CGFloat) in StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round) }
        context.stroke(path, with: .color(Color(.tripCard)), style: style(8))
        context.stroke(path, with: .color(Color(.brandYellow)), style: style(5))
    }

    private func DrawRobot(_ robot: Image, at point: CGPoint, in context: inout GraphicsContext) {
        let size = Self.robotSize
        let frame = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        context.fill(Path(ellipseIn: frame.insetBy(dx: -2, dy: -2)), with: .color(Color(.tripCard)))
        context.draw(robot, in: frame)
    }

    private func DrawChip(_ label: String, at point: CGPoint, in context: inout GraphicsContext) {
        let text = context.resolve(
            Text(verbatim: label).font(.caption.bold()).foregroundStyle(Color(.tripCardText))
        )
        let textSize = text.measure(in: CGSize(width: 200, height: 40))
        let chip = CGRect(
            x: point.x - textSize.width / 2 - 8, y: point.y - textSize.height / 2 - 3,
            width: textSize.width + 16, height: textSize.height + 6
        )
        context.fill(Path(roundedRect: chip, cornerRadius: chip.height / 2), with: .color(Color(.tripCard)))
        context.draw(text, at: point)
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
