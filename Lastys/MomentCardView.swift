import LastysCore
import Photos
import SwiftUI
import UIKit

/// The owner's Moment card: a preview, the style and what goes on it, then Save image or Share.
/// What the card shows is decided by `AppModel.momentCard`; this screen only draws it.
struct MomentCardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let momentID: UUID
    /// The photo open in the Moment's gallery, which the card uses.
    let photoIndex: Int

    @State private var options = MomentCardOptions()
    @State private var photo: UIImage?
    @State private var sharedCard: SharedCardImage?
    @State private var message: LocalizedStringKey?

    private var card: MomentCard? {
        model.momentCard(for: momentID, photoIndex: photoIndex, options: options)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let card {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MomentCardArt(card: card, photo: photo)
                            .frame(width: MomentCardArt.designSize.width, height: MomentCardArt.designSize.height)
                            .scaleEffect(0.9)
                            .frame(width: MomentCardArt.designSize.width * 0.9, height: MomentCardArt.designSize.height * 0.9)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(Text("Card preview"))
                        StyleSwitch(style: $options.style)
                        switches(for: card)
                        Text("Your note never goes on the card. The card has no QR and doesn't show whether you're single or taken.")
                            .font(.jakarta(13))
                            .foregroundStyle(Theme.muted)
                        if let message {
                            Text(message)
                                .font(.jakarta(13, .semibold))
                                .foregroundStyle(Theme.roseDeep)
                        }
                        HStack(spacing: 8) {
                            Button("Save image") { Task { await save(card) } }
                                .buttonStyle(GhostButtonStyle())
                            Button("Share") { share(card) }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                        Text("Sharing is always your choice.")
                            .font(.jakarta(12))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task(id: card?.photo) {
            guard let media = card?.photo else { photo = nil; return }
            // Big enough for the 1080 by 1350 image.
            photo = await MomentThumbnails.image(for: media, maxPixelSize: 1350)
        }
        .onChange(of: card == nil) { _, gone in
            if gone { dismiss() }
        }
        .sheet(item: $sharedCard) { shared in
            ActivityView(image: shared.image)
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Moment card")
                .font(.jakarta(17, .bold))
                .tracking(-0.2)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    /// One switch for each piece the card can show; Photo, Place and Our names only when there is one.
    private func switches(for card: MomentCard) -> some View {
        VStack(spacing: 0) {
            if card.offersPhoto {
                Toggle("Photo", isOn: $options.showsPhoto)
                Divider()
            }
            if card.offersPlace {
                Toggle("Place", isOn: $options.showsPlace)
                Divider()
            }
            Toggle("Countdown", isOn: $options.showsCountdown)
            if card.offersNames {
                Divider()
                Toggle("Our names", isOn: $options.showsNames)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.rose))
        .font(.jakarta(15, .semibold))
        .foregroundStyle(Theme.ink)
        .frame(minHeight: 44)
        .card(padding: 14)
    }

    /// The card as an image at 3x, 1080 by 1350 pixels: exactly what the preview shows.
    private func render(_ card: MomentCard) -> UIImage? {
        let renderer = ImageRenderer(
            content: MomentCardArt(card: card, photo: photo)
                .frame(width: MomentCardArt.designSize.width, height: MomentCardArt.designSize.height)
                .environment(\.locale, Locale(identifier: model.language.rawValue))
        )
        renderer.scale = 3
        return renderer.uiImage
    }

    private func share(_ card: MomentCard) {
        message = nil
        guard let image = render(card) else {
            message = "Couldn't make the card image. Try again."
            return
        }
        sharedCard = SharedCardImage(image: image)
    }

    /// Saves to Photos with add-only access, so Lastys never sees the rest of the library.
    private func save(_ card: MomentCard) async {
        message = nil
        guard let image = render(card) else {
            message = "Couldn't make the card image. Try again."
            return
        }
        guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
            message = "Lastys can't save to Photos. Allow it in Settings."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            message = "Saved to Photos"
        } catch {
            message = "Couldn't save the card. Try again."
        }
    }
}

/// Rose or Dark, as a two-part switch.
private struct StyleSwitch: View {
    @Binding var style: MomentCardOptions.Style

    var body: some View {
        HStack(spacing: 0) {
            option("Rose", .rose)
            option("Dark", .dark)
        }
        .padding(3)
        .frame(height: 44)
        .background(Capsule().fill(Theme.divider))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Card style"))
    }

    private func option(_ title: LocalizedStringKey, _ value: MomentCardOptions.Style) -> some View {
        let isOn = style == value
        return Button { style = value } label: {
            Text(title)
                .font(.jakarta(14, .bold))
                .foregroundStyle(isOn ? Theme.ink : Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Capsule()
                        .fill(isOn ? Theme.surface : .clear)
                        .shadow(color: .black.opacity(isOn ? 0.1 : 0), radius: 1.5, y: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The card's design, used both on screen and for the saved or shared image.
struct MomentCardArt: View {
    let card: MomentCard
    /// The loaded photo, or a video's first frame, when the card shows one.
    let photo: UIImage?

    /// The image at 1x: 4:5, the portrait size social apps show best. On screen it is scaled from this.
    static let designSize = CGSize(width: 360, height: 450)

    private var isDark: Bool { card.style == .dark }
    private var ground: Color { isDark ? Theme.ink : Theme.roseTint }
    private var kicker: Color { isDark ? Color(hex: 0xF9A8C9) : Theme.roseDark }
    private var heading: Color { isDark ? .white : Theme.roseDeep }
    private var detail: Color { isDark ? Color(hex: 0xD6D3D1) : Theme.roseDeep }

    var body: some View {
        VStack(spacing: 0) {
            top
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(card.type.title)
                    .textCase(.uppercase)
                    .font(.jakarta(12, .bold))
                    .tracking(1.5)
                    .foregroundStyle(kicker)
                Text(verbatim: card.title)
                    .font(.jakarta(30, .heavy))
                    .tracking(-0.8)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(heading)
                Text(card.date, format: .dateTime.day().month(.wide).year())
                    .font(.jakarta(14))
                    .foregroundStyle(detail)
                if let place = card.place {
                    Label { Text(verbatim: place) } icon: { Image(systemName: "mappin") }
                        .font(.jakarta(14))
                        .foregroundStyle(detail)
                        .lineLimit(1)
                }
                if let countdown = card.countdown {
                    countdownText(countdown)
                        .font(.jakarta(13, .bold))
                        .foregroundStyle(isDark ? .white : Theme.roseDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isDark ? Theme.rose : .white))
                        .padding(.top, 4)
                }
                HStack {
                    (Text(verbatim: "Lastys").foregroundColor(isDark ? .white : Theme.ink)
                        + Text(verbatim: ".").foregroundColor(isDark ? Color(hex: 0xF472A0) : Theme.rose))
                        .font(.jakarta(16, .heavy))
                    Spacer(minLength: 8)
                    if let names = card.names {
                        Text(verbatim: "\(names.mine) & \(names.partner)")
                            .font(.jakarta(14))
                            .foregroundStyle(detail)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .background(ground)
    }

    @ViewBuilder
    private var top: some View {
        if card.photo != nil, let photo {
            Color.clear.overlay { Image(uiImage: photo).resizable().scaledToFill() }
        } else {
            ZStack {
                isDark ? Color(hex: 0x292524) : Color(hex: 0xF9D3E0)
                Image(systemName: "heart")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.rose)
            }
        }
    }

    private func countdownText(_ countdown: MomentCard.Countdown) -> Text {
        switch countdown {
        case .today: return Text("It's today")
        case .daysToGo(1): return Text("1 day to go")
        case .daysToGo(let days): return Text("\(days) days to go")
        case .daysAgo(1): return Text("1 day ago")
        case .daysAgo(let days): return Text("\(days) days ago")
        }
    }
}
