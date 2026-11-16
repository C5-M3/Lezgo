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
        /// The yellow LEAD half.
        case topSlab
        /// The dark area under the yellow LEAD half: JOIN's tap area on the LEAD home.
        case underTopSlab
        /// The yellow JOIN half.
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

    /// The edge's heights on this screen. Kept inside the screen so the shape never folds over itself.
    private func Heights(of edge: HomeSplitMotion.Edge, in rect: CGRect) -> (left: Double, right: Double) {
        let scale = rect.height / HomeSplitMotion.canvasHeight
        let top = rect.minY - rect.height
        let bottom = rect.maxY + rect.height
        let left = min(max(rect.minY + edge.left * scale, top), bottom)
        let right = min(max(rect.minY + edge.right * scale, top), bottom)
        return (left, right)
    }
}
