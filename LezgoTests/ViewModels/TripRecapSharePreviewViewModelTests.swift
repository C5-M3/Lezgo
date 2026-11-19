//
//  TripRecapSharePreviewViewModelTests.swift
//  LezgoTests
//

import Foundation
import Testing
@testable import Lezgo

@MainActor
struct TripRecapSharePreviewViewModelTests {
    private struct SaveFailure: Error {}

    private func MakeViewModel() throws -> (TripRecapSharePreviewViewModel, Data) {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "PreviewViewModelTest-\(UUID()).png")
        try data.write(to: fileURL)
        return (TripRecapSharePreviewViewModel(image: TripRecapShareImage(fileURL: fileURL)), data)
    }

    @Test func SavingSendsThePngBytesOfThePicture() async throws {
        let (viewModel, data) = try MakeViewModel()
        var savedData: Data?

        await viewModel.Save { savedData = $0 }

        #expect(savedData == data)
        #expect(viewModel.saveState == .saved)
    }

    @Test func FailedSaveCanBeTriedAgain() async throws {
        let (viewModel, _) = try MakeViewModel()

        await viewModel.Save { _ in throw SaveFailure() }
        #expect(viewModel.saveState == .failed)

        await viewModel.Save { _ in }
        #expect(viewModel.saveState == .saved)
    }

    @Test func SavedPictureIsNotSavedTwice() async throws {
        let (viewModel, _) = try MakeViewModel()
        var saveCount = 0

        await viewModel.Save { _ in saveCount += 1 }
        await viewModel.Save { _ in saveCount += 1 }

        #expect(saveCount == 1)
    }

    @Test func UnreadablePictureFailsWithoutAskingTheSaver() async {
        let missing = TripRecapShareImage(fileURL: URL(filePath: "/tmp/DoesNotExist-\(UUID()).png"))
        let viewModel = TripRecapSharePreviewViewModel(image: missing)
        var saveCount = 0

        await viewModel.Save { _ in saveCount += 1 }

        #expect(viewModel.saveState == .failed)
        #expect(saveCount == 0)
    }
}
