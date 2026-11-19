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

    init(image: TripRecapShareImage) {
        _viewModel = State(initialValue: TripRecapSharePreviewViewModel(image: image))
    }

    var body: some View {
        VStack(spacing: 20) {
            topBar

            viewModel.image.previewImage
                .resizable()
                .scaledToFit()
                .background { Checkerboard() }
                .clipShape(.rect(cornerRadius: 28))
                .accessibilityLabel(Text("Trip recap picture"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            actionButtons
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
            Text(saveTitle)
        }
        .disabled(viewModel.saveState == .saving || viewModel.saveState == .saved)
        .lezgoGlassButton(.second)

        ShareLink(
            item: viewModel.image,
            preview: SharePreview(Text("Trip recap picture"), image: viewModel.image.previewImage)
        ) {
            Text("Share")
        }
        .lezgoGlassButton(.main)
    }

    var saveTitle: LocalizedStringKey {
        viewModel.saveState == .saved ? "Saved" : "Save"
    }

    func Save() {
        Task {
            await viewModel.Save { try await PhotoLibrarySaver.Save(pngData: $0) }
            isSaveFailureShown = viewModel.saveState == .failed
        }
    }
}

/// Light and dark grey squares, the usual way to show that a picture is see-through.
private struct Checkerboard: View {
    private let squareSize: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns {
                    let isLight = (row + column).isMultiple(of: 2)
                    let square = CGRect(
                        x: CGFloat(column) * squareSize, y: CGFloat(row) * squareSize,
                        width: squareSize, height: squareSize
                    )
                    context.fill(Path(square), with: .color(isLight ? Color(white: 0.30) : Color(white: 0.24)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TripRecapSharePreviewView(image: TripRecapShareImage(fileURL: URL(filePath: "/tmp/Preview.png")))
    }
}
#endif
