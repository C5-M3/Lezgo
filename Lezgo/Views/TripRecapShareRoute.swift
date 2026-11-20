//
//  TripRecapShareRoute.swift
//  Lezgo
//

import SwiftUI

/// The route of the trip as one clean line, with no map, scaled to fill the space it is given. The dark posters use
/// it in white; `outlineColor` draws a thin dark edge so the line stays readable over a big yellow number.
///
/// This is a picture, not a screen: sizes are fixed on purpose.
struct TripRecapShareRoute: View {
    /// The route in the map picture's own points. Only the shape matters; it is scaled to fit.
    let points: [CGPoint]
    var lineWidth: CGFloat = 4
    var lineColor: Color = .white
    var outlineColor: Color?
    /// A ring around the last point, to mark the destination.
    var showsDestinationRing = false

    /// Room around the line so the ring and the round ends are not cut off at the edges.
    private let margin = 14.0

    var body: some View {
        Canvas { context, size in
            let area = CGSize(width: size.width - margin * 2, height: size.height - margin * 2)
            let fitted = Self.FittedPoints(points, in: area).map { CGPoint(x: $0.x + margin, y: $0.y + margin) }
            guard fitted.count > 1 else { return }

            var path = Path()
            path.addLines(fitted)
            if let outlineColor {
                context.stroke(path, with: .color(outlineColor), style: Self.Stroke(width: lineWidth + 4))
            }
            context.stroke(path, with: .color(lineColor), style: Self.Stroke(width: lineWidth))

            if showsDestinationRing, let end = fitted.last {
                let ring = Path(ellipseIn: CGRect(x: end.x - 11, y: end.y - 11, width: 22, height: 22))
                context.stroke(ring, with: .color(lineColor), style: Self.Stroke(width: lineWidth))
            }
        }
        .accessibilityHidden(true)
    }

    private static func Stroke(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    /// `points` scaled up or down, keeping their shape, to fill `size` as far as it goes, and centred in it. The
    /// result starts at the top-left corner of `size`.
    static func FittedPoints(_ points: [CGPoint], in size: CGSize) -> [CGPoint] {
        guard let first = points.first else { return [] }
        let minX = points.reduce(first.x) { min($0, $1.x) }
        let maxX = points.reduce(first.x) { max($0, $1.x) }
        let minY = points.reduce(first.y) { min($0, $1.y) }
        let maxY = points.reduce(first.y) { max($0, $1.y) }
        let width = maxX - minX
        let height = maxY - minY

        // A route with no width (or no height) is limited by the other side only.
        let scales = [width > 0 ? size.width / width : nil, height > 0 ? size.height / height : nil].compactMap { $0 }
        let scale = scales.min() ?? 1
        let offsetX = (size.width - width * scale) / 2
        let offsetY = (size.height - height * scale) / 2

        return points.map { CGPoint(x: ($0.x - minX) * scale + offsetX, y: ($0.y - minY) * scale + offsetY) }
    }
}
