//
//  TripRecapShareImage.swift
//  Lezgo
//

import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// The trip recap as a transparent PNG file, ready for the share sheet.
struct TripRecapShareImage: Transferable, Equatable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { image in
            SentTransferredFile(image.fileURL)
        }
    }

    /// Draws the card with `mapPicture` and writes it as a PNG. `nil` when the picture cannot be made.
    static func Render(content: TripRecapShareCardContent, mapPicture: TripRecapMapPicture) -> TripRecapShareImage? {
        nil
    }

    /// Makes the map picture and the PNG for a recap. `nil` when either step fails.
    static func Make(recap: TripRecap) async -> TripRecapShareImage? {
        nil
    }
}
