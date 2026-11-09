//
//  JoinTripView.swift
//  Lezgo
//
//  Created by Rizal Pratama on 25/10/26.
//

import SwiftUI

/// Animasi shake horizontal untuk menandai error pada field input.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

/// Penanda kursor berkedip (blinking cursor) untuk field input aktif.
private struct BlinkingCursor: View {
    let color: Color
    @State private var isVisible: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 2.5, height: 24)
            .opacity(isVisible ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.5),
                value: isVisible
            )
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(530))
                    isVisible.toggle()
                }
            }
    }
}

/// Bottom sheet component untuk memasukkan kode ruangan (room code) 6 digit perjalanan.
/// Dirancang sesuai pedoman Apple Human Interface Guidelines (HIG).
@MainActor
struct JoinTripView: View {
    // MARK: - Properties

    @Binding var isPresented: Bool
    @State private var viewModel: JoinTripViewModel
    @State private var enteredCode: String = ""
    @FocusState private var isFieldFocused: Bool
    @Environment(\.tripService) private var tripService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sheetHeight: CGFloat = 290
    @State private var shakeAttempts: Int = 0
    @State private var hasSubmittedSuccessfully: Bool = false

    var onBack: (() -> Void)?
    var onEnter: ((String) -> Void)?
    var onNavigateToTripRoom: ((TripSession) -> Void)?

    private let boxBackground = Color(red: 32/255, green: 32/255, blue: 34/255)
    private let sheetBackground = Color(red: 24/255, green: 24/255, blue: 26/255)
    private let disabledButtonBackground = Color(red: 36/255, green: 36/255, blue: 38/255)

    // MARK: - Initializer

    init(
        isPresented: Binding<Bool>,
        viewModel: JoinTripViewModel? = nil,
        onBack: (() -> Void)? = nil,
        onEnter: ((String) -> Void)? = nil,
        onNavigateToTripRoom: ((TripSession) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        let vm = viewModel ?? JoinTripViewModel()
        self._viewModel = State(initialValue: vm)
        self._enteredCode = State(initialValue: vm.roomCode)
        self.onBack = onBack
        self.onEnter = onEnter
        self.onNavigateToTripRoom = onNavigateToTripRoom
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            VStack(alignment: .leading, spacing: 12) {
                codeBoxesSection

                if let errorMessage = viewModel.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(errorMessage)
                }
            }

            enterButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
            sheetHeight = newHeight
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(sheetBackground)
        .presentationSizing(.page)
        .presentationCompactAdaptation(.sheet)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.error, trigger: shakeAttempts)
        .task {
            // Memunculkan keyboard secara otomatis saat sheet tampil
            try? await Task.sleep(for: .milliseconds(150))
            isFieldFocused = true
        }
        .onAppear {
            viewModel.setTripServiceIfNeeded(tripService)
        }
        .onDisappear {
            if !hasSubmittedSuccessfully {
                onBack?()
            }
            viewModel.reset()
        }
        .onChange(of: viewModel.roomCode) { _, newValue in
            if enteredCode != newValue {
                enteredCode = newValue
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("Enter room code")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("Ask the leader for the 6 digits")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.6))
        }
    }

    // MARK: - Code Boxes Section

    private var codeBoxesSection: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    digitBox(at: index)
                }
            }

            TextField("Room code", text: $enteredCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFieldFocused)
                .tint(.clear)
                .foregroundStyle(.clear)
                .opacity(0.01)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onSubmit {
                    submitRoomCode()
                }
                .onChange(of: enteredCode) { _, newValue in
                    let digitsOnly = newValue.filter { $0.isNumber }
                    let limited = String(digitsOnly.prefix(6))
                    if enteredCode != limited {
                        enteredCode = limited
                    }
                    if viewModel.roomCode != enteredCode {
                        viewModel.roomCode = enteredCode
                    }
                }
        }
        .frame(height: 60)
        .contentShape(Rectangle())
        .onTapGesture {
            isFieldFocused = true
        }
        .modifier(ShakeEffect(animatableData: CGFloat(shakeAttempts)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Room code")
        .accessibilityValue(enteredCode)
        .accessibilityHint("Enter 6 digit room code")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func digitBox(at index: Int) -> some View {
        let hasDigit = index < enteredCode.count
        let hasError = viewModel.errorMessage != nil
        let isCurrentSlot = isFieldFocused && index == enteredCode.count
        let charString: String = {
            if hasDigit {
                let stringIndex = enteredCode.index(enteredCode.startIndex, offsetBy: index)
                return String(enteredCode[stringIndex])
            }
            return ""
        }()

        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(boxBackground)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    hasError ? Color(.tripAlertRed) : (isCurrentSlot ? Color(.brandYellow) : Color.clear),
                    lineWidth: 2
                )

            if isCurrentSlot && !hasError {
                BlinkingCursor(color: Color(.brandYellow))
            }

            if hasDigit {
                Text(charString)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.identity)
                    .transaction { $0.animation = nil }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
    }

    // MARK: - Enter Button

    private var enterButton: some View {
        Button {
            submitRoomCode()
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(Color.brandYellow)
                } else {
                    Text("Enter")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(viewModel.isValidCode ? .black : Color(white: 0.45))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule()
                    .fill(
                        viewModel.isValidCode && !viewModel.isSubmitting
                            ? Color(.brandYellow)
                            : disabledButtonBackground
                    )
            )
        }
        .disabled(!viewModel.isValidCode || viewModel.isSubmitting)
        .buttonStyle(.plain)
        .accessibilityLabel("Enter")
    }

    // MARK: - Actions

    private func triggerErrorFeedback() {
        // `sensoryFeedback(.error, trigger: shakeAttempts)` plays the haptic, so the count goes up even with Reduce
        // Motion; only the shake itself is skipped then.
        withAnimation(Animation.easeInOut(duration: 0.36).Respecting(reduceMotion: reduceMotion)) {
            shakeAttempts += 1
        }
    }

    private func submitRoomCode() {
        guard viewModel.isValidCode, !viewModel.isSubmitting else { return }
        // Tidak menutup keyboard saat proses validasi berlangsung agar angka/layout tidak bergerak/jump
        Task {
            let success = await viewModel.submitCode()
            if success {
                isFieldFocused = false
                hasSubmittedSuccessfully = true
                let code = viewModel.roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
                onEnter?(code)
                if let session = viewModel.joinedSession {
                    onNavigateToTripRoom?(session)
                }
                isPresented = false
            } else {
                triggerErrorFeedback()
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Menampilkan sheet Join Trip secara modular.
    @MainActor
    func joinTripSheet(
        isPresented: Binding<Bool>,
        viewModel: JoinTripViewModel? = nil,
        onBack: (() -> Void)? = nil,
        onEnter: ((String) -> Void)? = nil,
        onNavigateToTripRoom: ((TripSession) -> Void)? = nil
    ) -> some View {
        sheet(isPresented: isPresented) {
            JoinTripView(
                isPresented: isPresented,
                viewModel: viewModel,
                onBack: onBack,
                onEnter: onEnter,
                onNavigateToTripRoom: onNavigateToTripRoom
            )
        }
    }

    /// Menampilkan modal Join Trip (dukungan backward compatibility).
    @MainActor
    func joinTripModal(
        isPresented: Binding<Bool>,
        viewModel: JoinTripViewModel? = nil,
        onBack: (() -> Void)? = nil,
        onEnter: ((String) -> Void)? = nil,
        onNavigateToTripRoom: ((TripSession) -> Void)? = nil
    ) -> some View {
        joinTripSheet(
            isPresented: isPresented,
            viewModel: viewModel,
            onBack: onBack,
            onEnter: onEnter,
            onNavigateToTripRoom: onNavigateToTripRoom
        )
    }
}

// MARK: - Previews

#Preview("Join Trip Sheet") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            JoinTripView(isPresented: .constant(true))
        }
}

#Preview("Join Trip Sheet - Error") {
    let vm = JoinTripViewModel(roomCode: "000000")
    vm.errorMessage = "No trip found with this code."
    return Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            JoinTripView(
                isPresented: .constant(true),
                viewModel: vm
            )
        }
}
