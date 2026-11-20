//
//  TripRecapSharePreviewViewModel.swift
//  Lezgo
//

import Foundation
import Observation

/// State of the preview screen that opens from the share button: the pictures, which format is in the middle and
/// whether that picture is saved to Photos.
@Observable
@MainActor
final class TripRecapSharePreviewViewModel {
    enum SaveState {
        case idle
        case saving
        case saved
        case failed
    }

    let options: [TripRecapShareOption]
    private(set) var selectedIndex = 0
    private(set) var saveState = SaveState.idle

    /// The picture in the middle of the carousel: the one that Save and Share send.
    var selectedOption: TripRecapShareOption { options[selectedIndex] }

    init(options: [TripRecapShareOption]) {
        // The recap screen only opens this screen when it has pictures.
        precondition(!options.isEmpty, "The preview needs at least one picture")
        self.options = options
    }

    /// Puts another format in the middle. An index past either end loops round. Another picture has not been saved
    /// yet, so a saved or failed state goes back to idle.
    func Select(index: Int) {
        let wrappedIndex = LoopingPosition(count: options.count).NearestIndex(to: Double(index))
        guard wrappedIndex != selectedIndex else { return }
        selectedIndex = wrappedIndex
        if saveState != .saving { saveState = .idle }
    }

    /// Hands the PNG bytes of the selected picture to `save`. `save` is the Photos library in the app and a fake in
    /// tests.
    func Save(using save: (Data) async throws -> Void) async {
        guard saveState != .saving, saveState != .saved else { return }
        let savedIndex = selectedIndex
        saveState = .saving
        do {
            try await save(Data(contentsOf: options[savedIndex].image.fileURL))
            saveState = selectedIndex == savedIndex ? .saved : .idle
        } catch {
            saveState = selectedIndex == savedIndex ? .failed : .idle
        }
    }
}
