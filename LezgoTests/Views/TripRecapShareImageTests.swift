//
//  TripRecapShareImageTests.swift
//  LezgoTests
//

import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Lezgo

@MainActor
struct TripRecapShareImageTests {
    private var stubMapPicture: TripRecapMapPicture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 130, height: 130))
        let image = renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 130, height: 130))
        }
        return TripRecapMapPicture(
            image: image,
            routePoints: [CGPoint(x: 20, y: 100), CGPoint(x: 60, y: 60), CGPoint(x: 110, y: 25)],
            startPoint: CGPoint(x: 20, y: 100),
            destinationPoint: CGPoint(x: 110, y: 25)
        )
    }

    private func RenderedImage() throws -> CGImage {
        let content = TripRecapShareCardContent(recap: .sample)
        let shareImage = try #require(TripRecapShareImage.Render(content: content, mapPicture: stubMapPicture))
        let data = try Data(contentsOf: shareImage.fileURL)
        return try #require(UIImage(data: data)?.cgImage)
    }

    private func Alpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return pixel[3]
    }

    @Test func PictureIsNineBySixteenAt1080By1920() throws {
        let image = try RenderedImage()

        #expect(image.width == 1080)
        #expect(image.height == 1920)
    }

    @Test func PictureKeepsItsTransparentBackground() throws {
        let image = try RenderedImage()

        #expect(Alpha(of: image, x: 5, y: 5) == 0)
        #expect(Alpha(of: image, x: 1075, y: 5) == 0)
    }

    @Test func CardIsDrawnInTheBottomLeft() throws {
        let image = try RenderedImage()
        let opaqueTopHalf = (0..<image.width).contains { Alpha(of: image, x: $0, y: 400) > 0 }
        let opaqueBottomLeft = stride(from: 100, to: 500, by: 10).contains { Alpha(of: image, x: $0, y: 1500) > 0 }

        #expect(opaqueTopHalf == false)
        #expect(opaqueBottomLeft == true)
    }
}
