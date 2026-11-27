import LastysCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Adds a Moment, or changes or deletes one. Moments stay on this phone.
struct MomentEditorView: View {
    enum Target: Identifiable {
        case new
        case existing(Moment)

        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let moment): return moment.id.uuidString
            }
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let editing: Target

    @State private var draft: MomentDraft
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isLoadingMedia = false
    @State private var confirmingDelete = false

    init(editing: Target) {
        self.editing = editing
        switch editing {
        case .new:
            _draft = State(initialValue: MomentDraft(type: .birthday, title: "", date: Date(), repeatsOnKhmerLunarDate: false))
        case .existing(let moment):
            _draft = State(initialValue: MomentDraft(
                type: moment.type, title: moment.title, date: moment.date,
                repeatsOnKhmerLunarDate: moment.repeatsOnKhmerLunarDate, media: moment.media,
                place: moment.place, note: moment.note
            ))
        }
    }

    private var existing: Moment? {
        if case .existing(let moment) = editing { return moment }
        return nil
    }

    /// A Moment my Partner shared: shown, but theirs to change.
    private var isPartners: Bool {
        existing.map { !model.isMine($0) } ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let existing, isPartners {
                partnerForm(existing)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) { editableSections }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .confirmationDialog("Delete this Moment?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existing { model.deleteMoment(id: existing.id) }
                dismiss()
            }
        }
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            pickedItems = []
            isLoadingMedia = true
            Task {
                for item in items where draft.media.count < Moment.maxMedia {
                    if let saved = try? await MomentMediaFiles.save(item) { draft.media.append(saved) }
                }
                isLoadingMedia = false
            }
        }
    }

    private var header: some View {
        HStack {
            Text(existing == nil ? LocalizedStringKey("New Moment") : LocalizedStringKey("Moment"))
                .font(.jakarta(20, .bold))
                .tracking(-0.2)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isPartners ? LocalizedStringKey("Done") : LocalizedStringKey("Cancel"))
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func partnerForm(_ existing: Moment) -> some View {
        Form {
            Section {
                LabeledContent("Type") { Text(existing.type.title) }
                LabeledContent("Title") { Text(verbatim: existing.title) }
                LabeledContent("Date") { Text(existing.date, format: .dateTime.day().month().year()) }
                if existing.repeatsOnKhmerLunarDate {
                    Text("Repeats every year on its Khmer lunar date (sample)")
                }
            } footer: {
                Text("Shared by \(model.partnerNickname). Only they can change it.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.jakarta(14, .semibold)).foregroundStyle(Theme.ink)
    }

    private func optionalLabel(_ key: LocalizedStringKey) -> some View {
        (Text(key) + Text(verbatim: " ") + Text("Optional").foregroundColor(Theme.muted).font(.jakarta(12, .medium)))
            .font(.jakarta(14, .semibold))
            .foregroundStyle(Theme.ink)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.fieldBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var editableSections: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MomentType.allCases, id: \.self) { type in
                    let selected = draft.type == type
                    Button { draft.type = type } label: {
                        Text(type.title)
                            .font(.jakarta(14, .semibold))
                            .foregroundStyle(selected ? Color.white : Theme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(Capsule().fill(selected ? Theme.ink : Theme.surface))
                            .overlay(Capsule().strokeBorder(selected ? Theme.ink : Theme.fieldBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }

        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Title")
            TextField("Title, e.g. Mom's birthday", text: $draft.title)
                .font(.jakarta(15, .medium))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(fieldBackground)
        }

        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Date")
            HStack {
                DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Theme.rose)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(fieldBackground)
        }

        VStack(alignment: .leading, spacing: 8) {
            (Text("Photos") + Text(verbatim: " ") + Text("· optional, up to 6").foregroundColor(Theme.muted).fontWeight(.medium))
                .font(.jakarta(14, .semibold))
                .foregroundStyle(Theme.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(draft.media.enumerated()), id: \.element) { index, media in
                    MediaThumbnail(media: media) { draft.media.remove(at: index) }
                }
                if draft.media.count < Moment.maxMedia {
                    PhotosPicker(
                        selection: $pickedItems,
                        maxSelectionCount: Moment.maxMedia - draft.media.count,
                        matching: .any(of: [.images, .videos])
                    ) {
                        VStack(spacing: 4) {
                            if isLoadingMedia {
                                ProgressView()
                            } else {
                                Image(systemName: "photo.on.rectangle").font(.system(size: 20))
                                Text("Add").font(.jakarta(12, .semibold))
                            }
                        }
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color(hex: 0xD6CFCA), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                )
                        )
                    }
                    .disabled(isLoadingMedia)
                }
            }
        }

        VStack(alignment: .leading, spacing: 6) {
            optionalLabel("Place")
            TextField("e.g. Riverside, Phnom Penh", text: $draft.place)
                .font(.jakarta(15, .medium))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(fieldBackground)
        }

        VStack(alignment: .leading, spacing: 6) {
            optionalLabel("Note")
            TextField("What made it special?", text: $draft.note, axis: .vertical)
                .font(.jakarta(15, .medium))
                .lineLimit(3...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 88, alignment: .topLeading)
                .background(fieldBackground)
        }

        Toggle(isOn: $draft.repeatsOnKhmerLunarDate) {
            Text("Repeat every year on its Khmer lunar date")
                .font(.jakarta(15, .semibold))
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.rose)
        .card()

        VStack(alignment: .leading, spacing: 6) {
            Text("Otherwise it comes back on the same date every year. Khmer lunar dates are samples until the cultural advisor's rules arrive.")
            Text("Reminders come 7 days before, the day before and on the day, every year. Personal Moments never leave this phone.")
        }
        .font(.jakarta(13))
        .foregroundStyle(Theme.ink)
        .lineSpacing(3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: 0xF6F1EE)))

        Button("Save") {
            if let existing {
                model.updateMoment(id: existing.id, to: draft)
            } else {
                model.addMoment(draft)
            }
            dismiss()
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!model.canSave(draft) || isLoadingMedia)

        if let existing {
            VStack(alignment: .leading, spacing: 10) {
                if model.canShare(existing) {
                    Button("Share with \(model.partnerNickname)") {
                        Task { await model.share(existing.id); dismiss() }
                    }
                    .buttonStyle(GhostButtonStyle())
                } else if model.canStopSharing(existing) {
                    Button("Stop sharing") {
                        Task { await model.stopSharing(existing.id); dismiss() }
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                if model.canShare(existing) || model.canStopSharing(existing) {
                    Text("A Shared Moment's title, type and date reach your Partner through Lastys. Its photo or video stays on this phone.")
                        .font(.jakarta(12))
                        .foregroundStyle(Theme.muted)
                }
                Button("Delete this Moment", role: .destructive) { confirmingDelete = true }
                    .font(.jakarta(14, .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}

extension MomentType {
    var title: LocalizedStringKey {
        switch self {
        case .firstMeet: return "First meet"
        case .firstDate: return "First date"
        case .anniversary: return "Anniversary"
        case .birthday: return "Birthday"
        case .custom: return "Custom"
        }
    }
}

/// One attached photo or video in the editor's grid, with a remove button.
private struct MediaThumbnail: View {
    let media: MomentMedia
    let remove: () -> Void

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if media.kind == .photo, let image = UIImage(contentsOfFile: MomentMediaFiles.url(for: media).path) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        Theme.roseTint
                        Image(systemName: media.kind == .video ? "video.fill" : "photo.fill").foregroundStyle(Theme.rose)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.ink.opacity(0.75)))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Remove it")
            }
    }
}

/// Where Moment photos and videos live: a folder on this phone, never backed up or sent anywhere.
enum MomentMediaFiles {
    static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "Lastys/MomentMedia", directoryHint: .isDirectory)
    }

    static func url(for media: MomentMedia) -> URL {
        folder.appending(path: media.fileName)
    }

    /// Creates the folder, left out of backups like the rest of this phone's private state.
    static func prepareFolder() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = folder
        try url.setResourceValues(values)
    }

    /// Copies the picked photo or video into the folder.
    static func save(_ item: PhotosPickerItem) async throws -> MomentMedia? {
        try prepareFolder()
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { return nil }
            return MomentMedia(kind: .video, fileName: movie.url.lastPathComponent)
        }
        guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
        let ext = item.supportedContentTypes.first { $0.conforms(to: .image) }?.preferredFilenameExtension ?? "jpg"
        let name = UUID().uuidString + "." + ext
        try data.write(to: folder.appending(path: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return MomentMedia(kind: .photo, fileName: name)
    }

    /// Removes files no Moment uses any more, such as a replaced photo or a deleted Moment's video.
    static func removeUnused(keeping inUse: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for file in files where !inUse.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// A picked video, copied into the Moment media folder as it arrives.
private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            try MomentMediaFiles.prepareFolder()
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = MomentMediaFiles.folder.appending(path: UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}
