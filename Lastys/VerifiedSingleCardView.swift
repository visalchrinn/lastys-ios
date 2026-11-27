import LastysCore
import SwiftUI
import UIKit

/// Checks the status with Trustee, then shows the Verified Single card and shares it as an image.
struct VerifiedSingleCardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sharedCard: SharedCardImage?
    @State private var renderFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let card = model.verifiedSingleCard {
                    // The QR stays the same until it is revoked from My Lastys QR.
                    // Drawn at the shared image's size, then scaled down, so the screen and the image match.
                    VerifiedSingleCardArt(card: card, qrPayload: model.verifiedSingleCardQR()?.payload)
                        .frame(width: VerifiedSingleCardArt.designSize.width, height: VerifiedSingleCardArt.designSize.height)
                        .scaleEffect(0.8)
                        .frame(width: 288, height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                    Button {
                        shareNow(card)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    if renderFailed {
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
        .sheet(item: $sharedCard) { shared in
            // The system share sheet for an image, which offers Save Image.
            ActivityView(image: shared.image)
                .presentationDetents([.medium, .large])
        }
        .task { await check() }
        .onDisappear { model.dismissVerifiedSingleCard() }
    }

    /// Asks Trustee again before the card is shown.
    private func check() async {
        renderFailed = false
        await model.prepareVerifiedSingleCard()
    }

    /// Draws the image at the moment of sharing, with whatever QR is current then.
    private func shareNow(_ card: VerifiedSingleCard) {
        renderFailed = false
        guard let qr = model.verifiedSingleCardQR(), let image = Self.render(card, qr: qr) else {
            renderFailed = true
            return
        }
        sharedCard = SharedCardImage(image: image)
    }

    /// The card as an image at 3x, 1080 by 1350 pixels: the portrait size social apps show best.
    @MainActor
    private static func render(_ card: VerifiedSingleCard, qr: VerifiedSingleCardQR) -> UIImage? {
        let renderer = ImageRenderer(content: VerifiedSingleCardArt(card: card, qrPayload: qr.payload).frame(width: VerifiedSingleCardArt.designSize.width, height: VerifiedSingleCardArt.designSize.height))
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
        VStack(spacing: 6) {
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

/// The card image made at the moment of sharing, so the share sheet can be shown for it.
private struct SharedCardImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// The system share sheet for one image. For an image it offers Save Image, which saves it to Photos.
private struct ActivityView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
