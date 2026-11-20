//
//  TripRecapSharePreviewView.swift
//  Lezgo
//

import SwiftUI

/// The screen that opens from the share button on a trip recap: the picture as it will be sent, over a checkerboard
/// so the transparent background can be seen, with "Save" (to Photos) and "Share" (the share sheet).
struct TripRecapSharePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TripRecapSharePreviewViewModel
    @State private var isSaveFailureShown = false

    init(options: [TripRecapShareOption]) {
        _viewModel = State(initialValue: TripRecapSharePreviewViewModel(options: options))
    }

    var body: some View {
        VStack(spacing: 8) {
            topBar

            TripRecapShareCarousel(options: viewModel.options, selectedIndex: selectedIndex)

            if viewModel.options.count > 1 {
                TripRecapShareDots(
                    options: viewModel.options,
                    selectedIndex: viewModel.selectedIndex,
                    select: { viewModel.Select(index: $0) }
                )
            }

            actionButtons
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Color(LezgoSurface.page.color))
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .confirmDialog(
            isPresented: $isSaveFailureShown,
            title: Text("Couldn't save the picture"),
            message: Text("Allow Lezgo to add photos in Settings, then try again."),
            cancelTitle: nil,
            confirmTitle: "OK",
            onConfirm: { }
        )
    }
}

private extension TripRecapSharePreviewView {
    var topBar: some View {
        ZStack {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.callout.weight(.bold))
                    .lezgoGlassButton(.round)

                Spacer()
            }
        }
    }

    var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { buttons }
            VStack(spacing: 12) { buttons }
        }
    }

    @ViewBuilder
    var buttons: some View {
        Button(action: Save) {
            saveLabel
        }
        .lezgoGlassButton(.second)
        .sensoryFeedback(trigger: viewModel.saveState) { _, newState in
            switch newState {
            case .saved: .success
            case .failed: .error
            default: nil
            }
        }

        ShareLink(
            item: viewModel.selectedOption.image,
            preview: SharePreview(Text("Trip recap picture"), image: viewModel.selectedOption.image.previewImage)
        ) {
            Text("Share")
        }
        .lezgoGlassButton(.main)
    }

    var selectedIndex: Binding<Int> {
        Binding(get: { viewModel.selectedIndex }, set: { viewModel.Select(index: $0) })
    }

    /// "Save", a spinner while saving, and a checkmark with "Saved" when it is done. Tapping again does nothing:
    /// the view model ignores a save that is running or done.
    @ViewBuilder
    var saveLabel: some View {
        if viewModel.saveState == .saved {
            Label("Saved", systemImage: "checkmark")
        } else {
            LezgoButtonLabel(title: "Save", isLoading: viewModel.saveState == .saving)
        }
    }

    func Save() {
        Task {
            await viewModel.Save { try await PhotoLibrarySaver.Save(pngData: $0) }
            isSaveFailureShown = viewModel.saveState == .failed
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TripRecapSharePreviewView(
            options: TripRecapShareFormat.allCases.map {
                TripRecapShareOption(format: $0, image: TripRecapShareImage(fileURL: URL(filePath: "/tmp/Preview.png")))
            }
        )
    }
}
#endif
