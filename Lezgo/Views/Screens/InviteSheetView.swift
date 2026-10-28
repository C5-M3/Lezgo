//
//  InviteSheetView.swift
//  Lezgo
//
//  Created by Oky Faishal on 26/10/26.
//

import SwiftUI

struct InviteSheetView: View {
    let roomCode: String
    let inviteURL: URL

    var body: some View {
        VStack(spacing: 20) {
            Text(roomCode)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 110)
                .background(Color(uiColor: .systemGray), in: .rect(cornerRadius: 16))
                .accessibilityLabel("Room code: \(roomCode.map(String.init).joined(separator: ", "))")
            HStack(spacing: 12) {
                Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                Text("or").font(.subheadline).foregroundStyle(.secondary)
                Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
            }
            ShareLink(item: inviteURL) {
                Label("Share Link", systemImage: "link")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color(uiColor: .systemGray), in: .rect(cornerRadius: 14))
            }
            .accessibilityLabel("Share Link")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .presentationDetents([.height(270)])
        .presentationDragIndicator(.visible)
    }
}
