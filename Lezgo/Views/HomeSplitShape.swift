//
//  HomeSplitShape.swift
//  Lezgo
//
//  Created by Nathan Sudiara on 16/11/26.
//

import SwiftUI

/// One area of the split-screen Home (issue #329), cut along a diagonal from `HomeSplitMotion`. It animates with
/// `progress`, so a yellow half or the next screen sweeps across without the views inside it being rebuilt.
struct HomeSplitShape: Shape {
    enum Part {
        /// The yellow LEAD half, or the whole yellow sheet during the Swing.
        case topSlab
        /// The dark area under the yellow LEAD half: JOIN's tap area on the LEAD home.
        case underTopSlab
        /// The yellow JOIN half, or the whole yellow sheet during the Swing.
        case bottomSlab
        /// The dark area over the yellow JOIN half: LEAD's tap area on the JOIN home.
        case overBottomSlab
        /// The part of the screen Set Route covers.
        case leadDestination
        /// The part of the screen Enter room code covers.
        case joinDestination
    }

    let part: Part
    let flow: HomeSplitMotion.Flow
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let frame = HomeSplitMotion.FrameAt(flow, progress: progress)
        if let sheet = frame.sheet, part == .topSlab || part == .bottomSlab {
            return Sheet(sheet, in: rect)
        }
        switch part {
        case .topSlab: return Above(frame.topSlab, in: rect)
        case .underTopSlab: return Below(frame.topSlab, in: rect)
        case .bottomSlab: return Below(frame.bottomSlab, in: rect)
        case .overBottomSlab: return Above(frame.bottomSlab, in: rect)
        case .leadDestination: return Above(frame.leadDestination, in: rect)
        case .joinDestination: return Below(frame.joinDestination, in: rect)
        }
    }

    private func Above(_ edge: HomeSplitMotion.Edge, in rect: CGRect) -> Path {
        let (left, right) = Heights(of: edge, in: rect)
        // When the edge is above the screen the shape is empty, rather than turned inside out.
        let top = min(rect.minY, left, right)
        return Path { path in
            path.addLines([
                CGPoint(x: rect.minX, y: top),
                CGPoint(x: rect.maxX, y: top),
                CGPoint(x: rect.maxX, y: right),
                CGPoint(x: rect.minX, y: left)
            ])
            path.closeSubpath()
        }
    }

    private func Below(_ edge: HomeSplitMotion.Edge, in rect: CGRect) -> Path {
        let (left, right) = Heights(of: edge, in: rect)
        // When the edge is below the screen the shape is empty, rather than turned inside out.
        let bottom = max(rect.maxY, left, right)
        return Path { path in
            path.addLines([
                CGPoint(x: rect.minX, y: left),
                CGPoint(x: rect.maxX, y: right),
                CGPoint(x: rect.maxX, y: bottom),
                CGPoint(x: rect.minX, y: bottom)
            ])
            path.closeSubpath()
        }
    }

    /// The yellow as one half-plane, drawn as a quad far larger than the screen. The design is mapped onto the screen
    /// the way the slabs are, its width onto the screen's width, so the sheet lines up with them at both homes.
    private func Sheet(_ sheet: HomeSplitMotion.Sheet, in rect: CGRect) -> Path {
        let scale = HomeSplitMotion.FitOn(width: rect.width, height: rect.height).scale
        let across = rect.width / HomeSplitMotion.canvasWidth
        let reach = 2000.0
        let along = (x: cos(sheet.angle), y: sin(sheet.angle))
        // The yellow side: the left of the edge's direction, with y growing downwards.
        let toYellow = (x: sin(sheet.angle), y: -cos(sheet.angle))
        let start = (x: sheet.x - reach * along.x, y: sheet.y - reach * along.y)
        let end = (x: sheet.x + reach * along.x, y: sheet.y + reach * along.y)
        let corners = [
            start,
            end,
            (x: end.x + reach * toYellow.x, y: end.y + reach * toYellow.y),
            (x: start.x + reach * toYellow.x, y: start.y + reach * toYellow.y)
        ]
        return Path { path in
            path.addLines(corners.map { CGPoint(x: rect.minX + $0.x * across, y: rect.minY + $0.y * scale) })
            path.closeSubpath()
        }
    }

    /// The edge's heights on this screen. Kept inside the screen so the shape never folds over itself.
    private func Heights(of edge: HomeSplitMotion.Edge, in rect: CGRect) -> (left: Double, right: Double) {
        let scale = HomeSplitMotion.FitOn(width: rect.width, height: rect.height).scale
        let top = rect.minY - rect.height
        let bottom = rect.maxY + rect.height
        let left = min(max(rect.minY + edge.left * scale, top), bottom)
        let right = min(max(rect.minY + edge.right * scale, top), bottom)
        return (left, right)
    }
}
