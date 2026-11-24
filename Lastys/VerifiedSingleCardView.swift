import LastysCore
import SwiftUI
import UIKit

/// Checks the status with Trustee, then shows the Verified Single card and shares it as an image.
struct VerifiedSingleCardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var renderFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let card = model.verifiedSingleCard {
                    VerifiedSingleCardArt(card: card)
                        .frame(width: 288, height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview(Text("Verified Single"), image: Image(uiImage: shareImage))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else if renderFailed {
                        Text("Couldn't make the card image. Close this and try again.")
                            .font(.jakarta(13))
                            .foregroundStyle(Theme.roseDeep)
                    }
                    Text("Anyone who doubts it can Scan your Lastys QR to see your status live.")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                } else if let problem = model.verifiedSingleCardProblem {
                    Text(problem.message)
                        .font(.jakarta(15, .semibold))
                        .foregroundStyle(Theme.roseDeep)
                        .multilineTextAlignment(.center)
                    if problem == .needsInternet || problem == .couldNotReachLastys {
                        Button("Try again") { Task { await check() } }
                            .buttonStyle(GhostButtonStyle())
                    }
                } else {
                    ProgressView("Checking with Lastys…")
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Verified Single card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await check() }
        .onDisappear { model.dismissVerifiedSingleCard() }
    }

    /// Asks Trustee again, then draws the card to share.
    private func check() async {
        shareImage = nil
        renderFailed = false
        await model.prepareVerifiedSingleCard()
        guard let card = model.verifiedSingleCard else { return }
        shareImage = Self.render(card)
        renderFailed = shareImage == nil
    }

    /// The card as an image at 3x, 1080 by 1350 pixels: the portrait size social apps show best.
    @MainActor
    private static func render(_ card: VerifiedSingleCard) -> UIImage? {
        let renderer = ImageRenderer(content: VerifiedSingleCardArt(card: card).frame(width: 360, height: 450))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// The card's design, used both on screen and for the shared image.
struct VerifiedSingleCardArt: View {
    let card: VerifiedSingleCard

    var body: some View {
        VStack(spacing: 18) {
            Wordmark(size: 26)
            Spacer(minLength: 0)
            avatar
            Text(verbatim: card.nickname)
                .font(.jakarta(26, .heavy))
                .foregroundStyle(Theme.ink)
            Label("Verified Single", systemImage: "checkmark.shield.fill")
                .font(.jakarta(20, .heavy))
                .foregroundStyle(Theme.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.greenTint))
            Text("Not linked to anyone on Lastys")
                .font(.jakarta(15, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Checked \(card.checkedAt, format: .dateTime.day().month(.wide).year())")
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            Label("Scan my QR to confirm", systemImage: "qrcode.viewfinder")
                .font(.jakarta(14, .bold))
                .foregroundStyle(Theme.roseDark)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Theme.surface, Theme.roseTint], startPoint: .top, endPoint: .bottom)
        )
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = card.photo, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle())
        } else {
            Text(String(card.nickname.prefix(1)).uppercased())
                .font(.jakarta(40, .heavy))
                .foregroundStyle(Theme.roseDark)
                .frame(width: 96, height: 96)
                .background(Circle().fill(Theme.surface))
        }
    }
}

extension VerifiedSingleCardProblem {
    var message: LocalizedStringKey {
        switch self {
        case .noLastysID: return "Create your Lastys ID first."
        case .hasActiveRelationship: return "You're in a Relationship, so there's no Verified Single card to share."
        case .needsInternet: return "Your status is checked with Lastys before every card, so this needs an internet connection."
        case .couldNotReachLastys: return "Couldn't reach Lastys to check your status. Try again."
        }
    }
}
