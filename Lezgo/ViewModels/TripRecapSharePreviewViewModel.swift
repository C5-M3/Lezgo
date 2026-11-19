//
//  TripRecapSharePreviewViewModel.swift
//  Lezgo
//

import Foundation
import Observation

/// State of the preview screen that opens from the share button: the picture and whether it is saved to Photos.
@Observable
@MainActor
final class TripRecapSharePreviewViewModel {
    enum SaveState {
        case idle
        case saving
        case saved
        case failed
    }

    let image: TripRecapShareImage
    private(set) var saveState = SaveState.idle

    init(image: TripRecapShareImage) {
        self.image = image
    }

    /// Hands the PNG bytes to `save`. `save` is the Photos library in the app and a fake in tests.
    func Save(using save: (Data) async throws -> Void) async {
        guard saveState != .saving, saveState != .saved else { return }
        saveState = .saving
        do {
            try await save(Data(contentsOf: image.fileURL))
            saveState = .saved
        } catch {
            saveState = .failed
        }
    }
}
