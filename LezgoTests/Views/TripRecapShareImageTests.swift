//
//  TripRecapShareImageTests.swift
//  LezgoTests
//

import CoreGraphics
import CoreTransferable
import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers
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

    private func RenderedImage(format: TripRecapShareFormat = .classic) throws -> CGImage {
        let content = TripRecapShareCardContent(recap: .sample)
        let shareImage = try #require(
            TripRecapShareImage.Render(content: content, mapPicture: stubMapPicture, format: format)
        )
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

    @Test func ShareSheetGetsThePngBytesAndNotAFilePath() async throws {
        let content = TripRecapShareCardContent(recap: .sample)
        let shareImage = try #require(
            TripRecapShareImage.Render(content: content, mapPicture: stubMapPicture, format: .classic)
        )

        let exported = try await shareImage.exported(as: .png)

        #expect(exported == (try Data(contentsOf: shareImage.fileURL)))
        #expect(exported.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func PreviewShowsTheRenderedPictureEvenWhenTheFileNameHasSpaces() throws {
        let content = TripRecapShareCardContent(recap: .sample)
        let shareImage = try #require(
            TripRecapShareImage.Render(content: content, mapPicture: stubMapPicture, format: .classic)
        )

        #expect(shareImage.fileURL.lastPathComponent.contains(" "))
        #expect(shareImage.previewUIImage?.cgImage?.width == 1080)
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

    @Test func EveryFormatIsNineBySixteenAt1080By1920() throws {
        for format in TripRecapShareFormat.allCases {
            let image = try RenderedImage(format: format)

            #expect(image.width == 1080)
            #expect(image.height == 1920)
        }
    }

    @Test func EveryFormatKeepsItsTransparentBackground() throws {
        for format in TripRecapShareFormat.allCases {
            let image = try RenderedImage(format: format)

            #expect(Alpha(of: image, x: 5, y: 5) == 0)
            #expect(Alpha(of: image, x: 1075, y: 1915) == 0)
        }
    }

    @Test func RouteLineCardHasTextAtTheTopWhereClassicHasNone() throws {
        let image = try RenderedImage(format: .routeLine)
        let opaqueTop = stride(from: 80, to: 700, by: 5).contains { Alpha(of: image, x: $0, y: 400) > 0 }

        #expect(opaqueTop == true)
    }

    @Test func FormatsSaveToDifferentFiles() throws {
        let content = TripRecapShareCardContent(recap: .sample)
        let urls = try TripRecapShareFormat.allCases.map {
            try #require(TripRecapShareImage.Render(content: content, mapPicture: stubMapPicture, format: $0)).fileURL
        }

        #expect(Set(urls).count == urls.count)
    }

    @Test func MapCenterCardFillsTheWidthWhileClassicStaysOnTheLeft() throws {
        let classic = try RenderedImage(format: .classic)
        let mapCenter = try RenderedImage(format: .mapCenter)
        // 1080 pixels wide: the right column of the new card is there, and the classic card ends at about 850.
        func HasPixels(in image: CGImage) -> Bool {
            stride(from: 880, to: 1040, by: 10).contains { x in
                stride(from: 1300, to: 1700, by: 10).contains { Alpha(of: image, x: x, y: $0) > 0 }
            }
        }

        #expect(HasPixels(in: classic) == false)
        #expect(HasPixels(in: mapCenter) == true)
    }
}
