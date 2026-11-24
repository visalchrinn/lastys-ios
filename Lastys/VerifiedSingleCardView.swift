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
                    // Ticks on whole seconds from the start of the minute, so the QR changes right at the boundary.
                    TimelineView(.periodic(from: LastysQRToken.startOfMinute(containing: .now), by: 1)) { context in
                        let qr = model.verifiedSingleCardQR(at: context.date)
                        VStack(spacing: 12) {
                            // Drawn at the shared image's size, then scaled down, so the screen and the image match.
                            VerifiedSingleCardArt(card: card, qrPayload: qr?.payload)
                                .frame(width: VerifiedSingleCardArt.designSize.width, height: VerifiedSingleCardArt.designSize.height)
                                .scaleEffect(0.8)
                                .frame(width: 288, height: 360)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                            if let qr {
                                Text("New code in \(qr.secondsUntilNextCode)s")
                                    .font(.jakarta(13, .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
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
        shareImage = Self.render(card, qrPayload: model.verifiedSingleCardQR(at: Date())?.payload)
        renderFailed = shareImage == nil
    }

    /// The card as an image at 3x, 1080 by 1350 pixels: the portrait size social apps show best.
    @MainActor
    private static func render(_ card: VerifiedSingleCard, qrPayload: String?) -> UIImage? {
        let renderer = ImageRenderer(content: VerifiedSingleCardArt(card: card, qrPayload: qrPayload).frame(width: VerifiedSingleCardArt.designSize.width, height: VerifiedSingleCardArt.designSize.height))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// The card's design, used both on screen and for the shared image.
struct VerifiedSingleCardArt: View {
    let card: VerifiedSingleCard
    /// The Lastys QR to print on the card, if there is one.
    let qrPayload: String?

    /// The size the card is drawn at: the shared image at 1x. On screen it is scaled down from this.
    static let designSize = CGSize(width: 360, height: 450)

    var body: some View {
        VStack(spacing: 8) {
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
            if let qrPayload {
                QRCodeImage(payload: qrPayload)
                    .frame(width: 80, height: 80)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    .accessibilityLabel(Text("My Lastys QR"))
            }
            Label("Scan my QR to confirm", systemImage: "qrcode.viewfinder")
                .font(.jakarta(14, .bold))
                .foregroundStyle(Theme.roseDark)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Theme.surface, Theme.roseTint], startPoint: .top, endPoint: .bottom)
        )
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = card.photo, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(Circle())
        } else {
            Text(String(card.nickname.prefix(1)).uppercased())
                .font(.jakarta(30, .heavy))
                .foregroundStyle(Theme.roseDark)
                .frame(width: 72, height: 72)
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
