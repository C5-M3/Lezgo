//
//  RouteSwipeToDelete.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 06/11/26.
//

import SwiftUI

struct RouteSwipeToDelete: ViewModifier {
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isShowingDeleteButton: Bool = false

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            deleteButton
            rowContent(content)
        }
        .clipped()
    }

    @ViewBuilder
    private var deleteButton: some View {
        if isShowingDeleteButton || offset < 0 {
            Button(role: .destructive, action: HandleDeleteTapped) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 36)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
            .padding(.trailing, 2)
            .transition(.opacity)
        }
    }

    private func rowContent(_ content: Content) -> some View {
        content
            .offset(x: offset)
            .simultaneousGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .local)
            .onChanged(HandleDragChanged)
            .onEnded(HandleDragEnded)
    }

    private func HandleDeleteTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            offset = 0
            isShowingDeleteButton = false
        }
        onDelete()
    }

    private func HandleDragChanged(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        guard abs(horizontal) > abs(vertical) * 1.5 else { return }

        if horizontal < 0 {
            offset = max(horizontal, -140)
            isShowingDeleteButton = true
        } else if isShowingDeleteButton && horizontal > 0 {
            offset = min(0, -56 + horizontal)
        }
    }

    private func HandleDragEnded(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let velocity = value.predictedEndTranslation.width

        if horizontal < -120 || velocity < -200 {
            TriggerFullSwipeDelete()
        } else if horizontal < -32 || isShowingDeleteButton {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                offset = -56
                isShowingDeleteButton = true
            }
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                offset = 0
                isShowingDeleteButton = false
            }
        }
    }

    private func TriggerFullSwipeDelete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            offset = -300
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            onDelete()
            offset = 0
            isShowingDeleteButton = false
        }
    }
}

extension View {
    func routeSwipeToDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(RouteSwipeToDelete(onDelete: onDelete))
    }
}
