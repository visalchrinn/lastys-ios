import AVKit
import LastysCore
import PhotosUI
import SwiftUI

/// One Moment in full: its photos, countdown, details and note, with Edit and Delete for my own.
/// The owner can add photos or videos here without opening the editor.
struct MomentDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// The Moment as it was when opened; the screen follows `model` after that.
    let opened: Moment

    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var selectedMedia = 0
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isAddingMedia = false
    @State private var showsMediaAdded = false
    @State private var hideMediaAdded: Task<Void, Never>?

    private var moment: Moment { model.currentMoment(id: opened.id) ?? opened }
    private var isGone: Bool { model.currentMoment(id: opened.id) == nil }
    private var isPartners: Bool { !model.isMine(moment) }
    private var canAddMedia: Bool { model.canAddMedia(to: moment) }
    private var upcoming: UpcomingMoment { model.nextTime(for: moment) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    gallery
                    titleBlock
                    countdownCard
                    detailsCard
                    if !moment.note.isEmpty { noteCard }
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $editing) {
            MomentEditorView(editing: .existing(moment))
                .environment(model)
        }
        .confirmationDialog("Delete this Moment?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteMoment(id: moment.id)
                dismiss()
            }
        }
        .onChange(of: isGone) { _, gone in
            if gone { dismiss() }
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            pickedItems = []
            Task { await addPicked(items) }
        }
        .overlay(alignment: .bottom) {
            if showsMediaAdded {
                Text("Photo added")
                    .font(.jakarta(14, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.ink))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showsMediaAdded)
    }

    /// Copies the picked photos or videos onto the phone and adds them after the ones already there.
    private func addPicked(_ items: [PhotosPickerItem]) async {
        isAddingMedia = true
        defer { isAddingMedia = false }
        let room = Moment.maxMedia - moment.media.count
        var saved: [MomentMedia] = []
        for item in items.prefix(max(0, room)) {
            if let media = try? await MomentMediaFiles.save(item) { saved.append(media) }
        }
        let firstNew = moment.media.count
        guard model.addMedia(saved, to: moment.id) > 0 else { return }
        selectedMedia = firstNew
        UIAccessibility.post(notification: .announcement, argument: AppText.string("Photo added"))
        showsMediaAdded = true
        hideMediaAdded?.cancel()
        hideMediaAdded = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { showsMediaAdded = false }
        }
    }

    /// The system photo picker, for what still fits in this Moment.
    private func mediaPicker<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        PhotosPicker(
            selection: $pickedItems,
            maxSelectionCount: max(1, Moment.maxMedia - moment.media.count),
            matching: .any(of: [.images, .videos])
        ) {
            label()
        }
        .disabled(isAddingMedia)
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
            Text("Moment")
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

    // MARK: Photos

    @ViewBuilder
    private var gallery: some View {
        if moment.media.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "heart")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Theme.rose)
                Text("No photo yet")
                    .font(.jakarta(14, .semibold))
                    .foregroundStyle(Theme.roseDeep)
                if canAddMedia {
                    mediaPicker {
                        if isAddingMedia {
                            ProgressView()
                        } else {
                            Text("Add a photo")
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.roseTint))
        } else {
            let index = min(selectedMedia, moment.media.count - 1)
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    MediaPage(media: moment.media[index])
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    if moment.media.count > 1 {
                        Text(verbatim: "\(index + 1)/\(moment.media.count)")
                            .font(.jakarta(12, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.ink.opacity(0.75)))
                            .padding(12)
                    }
                }
                if moment.media.count > 1 || canAddMedia {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(moment.media.enumerated()), id: \.element) { i, media in
                                Button { selectedMedia = i } label: {
                                    MediaPage(media: media)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .padding(2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(i == index ? Theme.rose : .clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(verbatim: "\(i + 1)/\(moment.media.count)"))
                            }
                            if canAddMedia {
                                mediaPicker {
                                    Group {
                                        if isAddingMedia {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                                        }
                                    }
                                    .foregroundStyle(Theme.muted)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color(hex: 0xD6CFCA), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                    )
                                    .padding(2)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Add photos or videos"))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Text

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                pill(Text(moment.type.title), fill: Theme.roseTint, ink: Theme.roseDeep)
                pill(moment.isShared ? Text("Shared") : Text("Personal"), fill: Color(hex: 0xF1ECE8), ink: Color(hex: 0x57534E))
            }
            Text(verbatim: moment.title)
                .font(.jakarta(28, .heavy))
                .tracking(-0.7)
                .foregroundStyle(Theme.ink)
            Text(moment.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .font(.jakarta(15))
                .foregroundStyle(Theme.muted)
        }
    }

    private func pill(_ text: Text, fill: Color, ink: Color) -> some View {
        text
            .font(.jakarta(12, .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }

    private var countdownCard: some View {
        let days = upcoming.daysUntil
        return HStack(spacing: 16) {
            Text(verbatim: "\(days)")
                .font(.jakarta(40, .heavy))
                .tracking(-1.5)
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if days == 0 {
                        Text("Today")
                    } else if days == 1 {
                        Text("day to go")
                    } else {
                        Text("days to go")
                    }
                }
                .font(.jakarta(15, .bold))
                Text(upcoming.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                    .font(.jakarta(13))
                    .foregroundStyle(Color(hex: 0xD6D3D1))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.ink))
        .accessibilityElement(children: .combine)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            row("Repeats", moment.repeatsOnKhmerLunarDate ? Text("Every year, on the Khmer lunar date") : Text("Every year"))
            divider
            row("Reminders", Text("7 days before, 1 day before and on the day"))
            if !moment.place.isEmpty {
                divider
                row("Place", Text(verbatim: moment.place))
            }
            divider
            row("Added by", isPartners ? Text(verbatim: model.partnerNickname) : Text("You"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
    }

    private func row(_ label: LocalizedStringKey, _ value: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).foregroundStyle(Theme.muted)
            Spacer(minLength: 12)
            value.multilineTextAlignment(.trailing).foregroundStyle(Theme.ink)
        }
        .font(.jakarta(14))
        .padding(.vertical, 12)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note").font(.jakarta(14, .bold))
            Text(verbatim: moment.note).font(.jakarta(15)).lineSpacing(4)
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        if isPartners {
            Text("Shared by \(model.partnerNickname). Only they can change it.")
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
        } else {
            HStack(spacing: 8) {
                Button("Edit") { editing = true }
                    .buttonStyle(GhostButtonStyle())
                if model.canShare(moment) {
                    Button("Share with \(model.partnerNickname)") {
                        Task { await model.share(moment.id) }
                    }
                    .buttonStyle(GhostButtonStyle())
                } else if model.canStopSharing(moment) {
                    Button("Stop sharing") {
                        Task { await model.stopSharing(moment.id) }
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            Button("Delete this Moment", role: .destructive) { confirmingDelete = true }
                .font(.jakarta(14, .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

/// One photo (filled to its frame) or video (with controls) of a Moment.
private struct MediaPage: View {
    let media: MomentMedia

    var body: some View {
        let url = MomentMediaFiles.url(for: media)
        switch media.kind {
        case .photo:
            if let image = UIImage(contentsOfFile: url.path) {
                Color.clear.overlay { Image(uiImage: image).resizable().scaledToFill() }.clipped()
            } else {
                placeholder("photo.fill")
            }
        case .video:
            VideoPlayer(player: AVPlayer(url: url))
        }
    }

    private func placeholder(_ symbol: String) -> some View {
        ZStack {
            Theme.roseTint
            Image(systemName: symbol).foregroundStyle(Theme.rose)
        }
    }
}
