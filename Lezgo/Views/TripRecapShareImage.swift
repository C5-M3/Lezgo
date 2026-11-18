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

    /// The picture itself for the share sheet's header, or the logo if the file cannot be read.
    var previewImage: Image {
        guard let uiImage = UIImage(contentsOfFile: fileURL.path()) else { return Image(.lezgoBlack) }
        return Image(uiImage: uiImage)
    }

    static var transferRepresentation: some TransferRepresentation {
        // The PNG bytes go to the share sheet themselves. Handing over a file path in this app's temporary folder
        // left WhatsApp empty and made Instagram say "Content currently unavailable", because those share
        // extensions could not use the file.
        DataRepresentation(exportedContentType: .png) { image in
            try Data(contentsOf: image.fileURL)
        }
        .suggestedFileName { $0.fileURL.lastPathComponent }
    }

    /// Draws the card with `mapPicture` and writes it as a PNG. `nil` when the picture cannot be made.
    @MainActor
    static func Render(content: TripRecapShareCardContent, mapPicture: TripRecapMapPicture) -> TripRecapShareImage? {
        let renderer = ImageRenderer(content: TripRecapShareCardView(content: content, mapPicture: mapPicture))
        renderer.scale = TripRecapMapPicture.scale
        renderer.isOpaque = false
        guard let data = renderer.uiImage?.pngData() else { return nil }

        let fileURL = FileManager.default.temporaryDirectory.appending(path: "Lezgo Trip \(content.dateText).png")
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return nil
        }
        return TripRecapShareImage(fileURL: fileURL)
    }

    /// Makes the map picture and the PNG for a recap. `nil` when either step fails.
    @MainActor
    static func Make(recap: TripRecap) async -> TripRecapShareImage? {
        guard let mapPicture = await TripRecapMapPicture.Make(recap: recap) else { return nil }
        return Render(content: TripRecapShareCardContent(recap: recap), mapPicture: mapPicture)
    }
}
