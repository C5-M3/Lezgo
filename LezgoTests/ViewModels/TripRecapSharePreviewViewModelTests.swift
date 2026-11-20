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

    private let classicData = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])
    private let routeLineData = Data([0x89, 0x50, 0x4E, 0x47, 0x03, 0x04])

    private func MakeOption(_ format: TripRecapShareFormat, data: Data) throws -> TripRecapShareOption {
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "PreviewViewModelTest-\(UUID()).png")
        try data.write(to: fileURL)
        return TripRecapShareOption(format: format, image: TripRecapShareImage(fileURL: fileURL))
    }

    private func MakeViewModel() throws -> TripRecapSharePreviewViewModel {
        TripRecapSharePreviewViewModel(options: [
            try MakeOption(.classic, data: classicData),
            try MakeOption(.routeLine, data: routeLineData)
        ])
    }

    @Test func SavingSendsThePngBytesOfThePicture() async throws {
        let viewModel = try MakeViewModel()
        var savedData: Data?

        await viewModel.Save { savedData = $0 }

        #expect(savedData == classicData)
        #expect(viewModel.saveState == .saved)
    }

    @Test func FailedSaveCanBeTriedAgain() async throws {
        let viewModel = try MakeViewModel()

        await viewModel.Save { _ in throw SaveFailure() }
        #expect(viewModel.saveState == .failed)

        await viewModel.Save { _ in }
        #expect(viewModel.saveState == .saved)
    }

    @Test func SavedPictureIsNotSavedTwice() async throws {
        let viewModel = try MakeViewModel()
        var saveCount = 0

        await viewModel.Save { _ in saveCount += 1 }
        await viewModel.Save { _ in saveCount += 1 }

        #expect(saveCount == 1)
    }

    @Test func UnreadablePictureFailsWithoutAskingTheSaver() async {
        let missing = TripRecapShareImage(fileURL: URL(filePath: "/tmp/DoesNotExist-\(UUID()).png"))
        let option = TripRecapShareOption(format: .classic, image: missing)
        let viewModel = TripRecapSharePreviewViewModel(options: [option])
        var saveCount = 0

        await viewModel.Save { _ in saveCount += 1 }

        #expect(viewModel.saveState == .failed)
        #expect(saveCount == 0)
    }

    @Test func FirstFormatIsSelectedAtTheStart() throws {
        let viewModel = try MakeViewModel()

        #expect(viewModel.selectedIndex == 0)
        #expect(viewModel.selectedOption.format == .classic)
    }

    @Test func SavingSendsTheFormatThatIsSelected() async throws {
        let viewModel = try MakeViewModel()
        var savedData: Data?

        viewModel.Select(index: 1)
        await viewModel.Save { savedData = $0 }

        #expect(savedData == routeLineData)
    }

    @Test func SelectingPastTheEndsLoopsAround() throws {
        let viewModel = try MakeViewModel()

        viewModel.Select(index: 2)
        #expect(viewModel.selectedIndex == 0)

        viewModel.Select(index: -1)
        #expect(viewModel.selectedIndex == 1)
    }

    @Test func ChoosingAnotherFormatAllowsSavingItEvenAfterASave() async throws {
        let viewModel = try MakeViewModel()
        var saveCount = 0

        await viewModel.Save { _ in saveCount += 1 }
        viewModel.Select(index: 1)
        #expect(viewModel.saveState == .idle)
        await viewModel.Save { _ in saveCount += 1 }

        #expect(saveCount == 2)
        #expect(viewModel.saveState == .saved)
    }

    @Test func SelectingTheSameFormatKeepsTheSavedState() async throws {
        let viewModel = try MakeViewModel()

        await viewModel.Save { _ in }
        viewModel.Select(index: 0)

        #expect(viewModel.saveState == .saved)
    }
}
