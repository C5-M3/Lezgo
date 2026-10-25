import SwiftUI

/// Sheet displaying the trip room code and a share link for inviting members.
public struct InviteSheetView: View {
    public let roomCode: String
    public let inviteURL: URL
    @Environment(\.dismiss) private var dismiss

    public init(roomCode: String, inviteURL: URL) {
        self.roomCode = roomCode
        self.inviteURL = inviteURL
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Large room code card
            Text(roomCode)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .background(Color(uiColor: .systemGray))
                .clipShape(.rect(cornerRadius: 16))
                .accessibilityLabel("Room code: \(roomCode.map(String.init).joined(separator: ", "))")

            // "or" divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(height: 1)

                Text("or")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(height: 1)
            }
            .padding(.horizontal, 4)

            // Share Link Button
            ShareLink(item: inviteURL) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityHidden(true)

                    Text("Share Link")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Color(uiColor: .systemGray))
                .clipShape(.rect(cornerRadius: 14))
            }
            .accessibilityLabel("Share Link")
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 36)
        .presentationDetents([.height(290)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    InviteSheetView(
        roomCode: "5JUV83",
        inviteURL: URL(string: "lezgo://join?code=5JUV83") ?? URL(fileURLWithPath: "/")
    )
}
