//
//  PhotoLibrarySaver.swift
//  Lezgo
//

import Photos

/// Adds a picture to the person's Photos library. Lezgo only adds, so it asks for the add-only permission, and the
/// system asks the person the first time.
enum PhotoLibrarySaver {
    struct NotAllowed: Error {}

    /// Saves `pngData` as it is, so the transparent background stays. Throws when the person has not allowed it.
    static func Save(pngData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw NotAllowed() }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: pngData, options: nil)
        }
    }
}
