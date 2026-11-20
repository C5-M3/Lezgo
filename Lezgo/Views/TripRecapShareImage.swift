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
        guard let uiImage = previewUIImage else { return Image(.lezgoBlack) }
        return Image(uiImage: uiImage)
    }

    /// The picture read from its file, or `nil` if it cannot be read. `percentEncoded: false` matters because the
    /// file name has spaces, and the default `path()` would turn them into `%20` and find no file.
    var previewUIImage: UIImage? {
        UIImage(contentsOfFile: fileURL.path(percentEncoded: false))
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

    /// Draws the card in `format` with `mapPicture` and writes it as a PNG. `nil` when the picture cannot be made.
    @MainActor
    static func Render(
        content: TripRecapShareCardContent,
        mapPicture: TripRecapMapPicture,
        format: TripRecapShareFormat
    ) -> TripRecapShareImage? {
        let renderer = ImageRenderer(content: Card(format: format, content: content, mapPicture: mapPicture))
        renderer.scale = TripRecapMapPicture.scale
        renderer.isOpaque = false
        guard let data = renderer.uiImage?.pngData() else { return nil }

        let fileURL = FileManager.default.temporaryDirectory.appending(
            path: "Lezgo Trip \(content.dateText)\(format.fileNameSuffix).png"
        )
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return nil
        }
        return TripRecapShareImage(fileURL: fileURL)
    }

    /// Makes the map picture and then one PNG for every format. Empty when any step fails, so the user never sees
    /// a half-filled set of styles.
    @MainActor
    static func MakeAll(recap: TripRecap) async -> [TripRecapShareOption] {
        guard let mapPicture = await TripRecapMapPicture.Make(recap: recap) else { return [] }
        let content = TripRecapShareCardContent(recap: recap)
        let options = TripRecapShareFormat.allCases.compactMap { format in
            Render(content: content, mapPicture: mapPicture, format: format)
                .map { TripRecapShareOption(format: format, image: $0) }
        }
        return options.count == TripRecapShareFormat.allCases.count ? options : []
    }

    @MainActor @ViewBuilder
    private static func Card(
        format: TripRecapShareFormat,
        content: TripRecapShareCardContent,
        mapPicture: TripRecapMapPicture
    ) -> some View {
        switch format {
        case .classic: TripRecapShareCardView(content: content, mapPicture: mapPicture)
        case .routeLine: TripRecapRouteLineCardView(content: content, mapPicture: mapPicture)
        case .mapCenter: TripRecapMapCenterCardView(content: content, mapPicture: mapPicture)
        case .together: TripRecapTogetherCardView(content: content, mapPicture: mapPicture)
        case .convoy: TripRecapConvoyCardView(content: content, mapPicture: mapPicture)
        }
    }
}
