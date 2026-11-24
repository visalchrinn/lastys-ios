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
    @State private var mediaItem: PhotosPickerItem?
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
                repeatsOnKhmerLunarDate: moment.repeatsOnKhmerLunarDate, media: moment.media
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
        NavigationStack {
            Form {
                if let existing, isPartners {
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
                } else {
                    editableSections
                }
            }
            .navigationTitle(existing == nil ? LocalizedStringKey("New Moment") : LocalizedStringKey("Moment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isPartners ? LocalizedStringKey("Done") : LocalizedStringKey("Cancel")) { dismiss() }
                }
                if !isPartners {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let existing {
                                model.updateMoment(id: existing.id, to: draft)
                            } else {
                                model.addMoment(draft)
                            }
                            dismiss()
                        }
                        .disabled(!model.canSave(draft) || isLoadingMedia)
                    }
                }
            }
            .confirmationDialog("Delete this Moment?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let existing { model.deleteMoment(id: existing.id) }
                    dismiss()
                }
            }
            .onChange(of: mediaItem) { _, item in
                guard let item else { return }
                isLoadingMedia = true
                Task {
                    draft.media = (try? await MomentMediaFiles.save(item)) ?? draft.media
                    isLoadingMedia = false
                }
            }
        }
    }

    @ViewBuilder
    private var editableSections: some View {
                Section {
                    Picker("Type", selection: $draft.type) {
                        ForEach(MomentType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Title, e.g. Mom's birthday", text: $draft.title)
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                }

                Section {
                    Toggle("Repeat every year on its Khmer lunar date", isOn: $draft.repeatsOnKhmerLunarDate)
                        .tint(Theme.rose)
                } footer: {
                    Text("Otherwise it comes back on the same date every year. Khmer lunar dates are samples until the cultural advisor's rules arrive.")
                }

                Section {
                    PhotosPicker(selection: $mediaItem, matching: .any(of: [.images, .videos])) {
                        Label(draft.media == nil ? LocalizedStringKey("Add a photo or video") : LocalizedStringKey("Change the photo or video"), systemImage: "photo.on.rectangle")
                    }
                    if isLoadingMedia {
                        ProgressView()
                    } else if let media = draft.media {
                        Label(media.kind == .video ? LocalizedStringKey("Video attached") : LocalizedStringKey("Photo attached"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.green)
                        Button("Remove it", role: .destructive) { draft.media = nil }
                    }
                } footer: {
                    Text("Reminders come 7 days before, the day before and on the day, every year. Personal Moments never leave this phone.")
                }

                if let existing, !isPartners {
                    Section {
                        if model.canShare(existing) {
                            Button("Share with \(model.partnerNickname)") {
                                Task { await model.share(existing.id); dismiss() }
                            }
                        } else if model.canStopSharing(existing) {
                            Button("Stop sharing") {
                                Task { await model.stopSharing(existing.id); dismiss() }
                            }
                        }
                    } footer: {
                        if model.canShare(existing) || model.canStopSharing(existing) {
                            Text("A Shared Moment's title, type and date reach your Partner through Lastys. Its photo or video stays on this phone.")
                        }
                    }
                    Section {
                        Button("Delete this Moment", role: .destructive) { confirmingDelete = true }
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
