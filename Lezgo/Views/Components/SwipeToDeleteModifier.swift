//
//  SwipeToDeleteModifier.swift
//  Lezgo
//
//  Created by Farrell Sudjatmiko on 05/11/26.
//

import SwiftUI

struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        offset = 0
                    }
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 28)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
                .transition(.opacity)
            }

            content
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { gesture in
                            if gesture.translation.width < 0 && abs(gesture.translation.height) < 30 {
                                offset = max(gesture.translation.width, -52)
                            } else if offset < 0 && gesture.translation.width > 0 {
                                offset = min(0, -52 + gesture.translation.width)
                            }
                        }
                        .onEnded { gesture in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                if gesture.translation.width < -28 {
                                    offset = -52
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}

extension View {
    func swipeToDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(onDelete: onDelete))
    }
}
