import LastysCore
import SwiftUI
import UIKit

/// Invite your partner: one Invite link to copy or share, waiting until it's used, cancelled or 7 days old.
/// Phase A: the link doesn't open the app yet (#20), and accepting it comes with #39.
struct InvitePartnerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied = false
    @State private var sharing: ShareItems?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 18) {
                    intro
                    if let link = model.inviteLink {
                        linkBox(link)
                        shareTiles(link)
                        if model.isInviteSent { waitingCard(link) }
                    } else if model.isWorkingOnInvite {
                        ProgressView().frame(minHeight: 120)
                    }
                    if let problem = model.inviteProblem {
                        Text(problem.message)
                            .font(.jakarta(13, .medium))
                            .foregroundStyle(Theme.roseDeep)
                            .multilineTextAlignment(.center)
                        if problem != .notSingleNow {
                            Button("Try again") { Task { await model.openInvite() } }
                                .buttonStyle(GhostButtonStyle())
                        }
                    }
                    Text("Works for one person only. Expires after 7 days.")
                        .font(.jakarta(12))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.background.ignoresSafeArea())
        .task { await model.openInvite() }
        .sheet(item: $sharing) { items in
            ShareSheet(items: items.items)
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack {
            Text("Invite your partner")
                .font(.jakarta(20, .bold))
                .tracking(-0.2)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var intro: some View {
        VStack(spacing: 14) {
            HStack(spacing: -14) {
                Text(String(model.nickname.prefix(1)).uppercased())
                    .font(.jakarta(26, .heavy))
                    .foregroundStyle(Theme.roseDark)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Theme.roseTint))
                    .overlay(Circle().strokeBorder(Theme.background, lineWidth: 4))
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xA8A29E))
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Theme.background))
                    .overlay(Circle().strokeBorder(Color(hex: 0xD6CFCA), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
            }
            .accessibilityHidden(true)
            Text("Link with your partner")
                .font(.jakarta(22, .heavy))
                .tracking(-0.4)
            Text("Send your link. When they open it and accept, you're linked.")
                .font(.jakarta(15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(.top, 8)
    }

    private func linkBox(_ link: InviteLink) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: link.url)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = Self.fullURL(link)
                copied = true
                model.inviteWasSent()
            } label: {
                Text(copied ? LocalizedStringKey("Copied") : LocalizedStringKey("Copy"))
                    .font(.jakarta(14, .bold))
                    .foregroundStyle(copied ? Color(hex: 0x14532D) : .white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(copied ? Theme.greenTint : Theme.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    private func shareTiles(_ link: InviteLink) -> some View {
        let message = AppText.string("Link with me on Lastys: \(Self.fullURL(link))")
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedURL = Self.fullURL(link).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return HStack(spacing: 8) {
            tile("Telegram", icon: "paperplane") {
                open("tg://msg_url?url=\(encodedURL)&text=\(encoded)", orShare: message)
            }
            tile("Messenger", icon: "message") {
                open("fb-messenger://share?link=\(encodedURL)", orShare: message)
            }
            tile("Messages", icon: "envelope") {
                open("sms:&body=\(encoded)", orShare: message)
            }
            tile("More", icon: "ellipsis") {
                model.inviteWasSent()
                sharing = ShareItems(items: [message])
            }
        }
    }

    private func tile(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.rose)
                Text(title)
                    .font(.jakarta(12, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    /// Opens the app with the link filled in; without that app, the system share sheet instead.
    private func open(_ address: String, orShare message: String) {
        model.inviteWasSent()
        guard let url = URL(string: address) else {
            sharing = ShareItems(items: [message])
            return
        }
        openURL(url) { opened in
            if !opened { sharing = ShareItems(items: [message]) }
        }
    }

    private func waitingCard(_ link: InviteLink) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Waiting for your partner")
                    .font(.jakarta(12, .semibold))
                    .foregroundStyle(Color(hex: 0x78350F))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: 0xFEF3C7)))
                Spacer()
                Button("Cancel invite", role: .destructive) {
                    Task { await model.cancelInvite() }
                }
                .font(.jakarta(13, .semibold))
                .frame(minHeight: 44)
                .disabled(model.isWorkingOnInvite)
            }
            Text("Expires \(link.expiresAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())")
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private static func fullURL(_ link: InviteLink) -> String {
        "https://" + link.url
    }
}

extension InviteProblem {
    var message: LocalizedStringKey {
        switch self {
        case .needsInternet: return "Invite links need an internet connection."
        case .notSingleNow: return "You can invite a partner only while you're Verified Single and not in a Cooling-off period."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Try again."
        }
    }
}

/// What to hand the share sheet, so it can be shown as an item.
private struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// The system share sheet for text or links.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
