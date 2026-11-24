import LastysCore
import PhotosUI
import SwiftUI
import UIKit

/// Where Lastys's Help and support lives. Set to the team's Telegram link before release;
/// until then the Me tab says it's coming, rather than send anyone to a stranger's account.
enum SupportLinks {
    static let telegram: URL? = nil
}

/// The Me tab: my profile, my Lastys ID, what Scans show, who scanned me (by time only),
/// my Recovery code, and Help and support.
struct MeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingProfile = false
    @State private var confirmingNewCode = false
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Me")
                    .font(.jakarta(26, .heavy))
                    .tracking(-0.6)
                profile
                lastysID
                shareLevel
                whoScannedMe
                recoveryCode
                help
                deleteMyData
                if let problem = model.meProblem {
                    Text(problem.message)
                        .font(.jakarta(13, .medium))
                        .foregroundStyle(Theme.roseDeep)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .foregroundStyle(Theme.ink)
        .task { await model.refreshMe() }
        // The Recovery code never stays on screen once the person leaves this tab.
        .onDisappear { model.hideRecoveryCode() }
        // Nor once the app leaves the foreground, so it never shows in the app switcher.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.hideRecoveryCode() }
        }
        .sheet(isPresented: $editingProfile) {
            ProfileEditorView().environment(model)
        }
        .confirmationDialog("Delete your Lastys ID and all your data?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                Task {
                    await model.deleteMyData()
                    // Photos and videos no Moment uses any more go too.
                    MomentMediaFiles.removeUnused(keeping: model.mediaFileNamesInUse)
                }
            }
        } message: {
            Text("Your Lastys ID, profile, Moments and reminders are removed from this phone and from Lastys. This can't be undone.")
        }
        .confirmationDialog("Make a new Recovery code?", isPresented: $confirmingNewCode, titleVisibility: .visible) {
            Button("Make a new code") { Task { await model.makeNewRecoveryCode() } }
        } message: {
            Text("Your current Recovery code stops working straight away. Save the new one somewhere safe.")
        }
    }

    // MARK: Sections

    private var profile: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: model.nickname)
                    .font(.jakarta(20, .heavy))
                if let birthDate = model.birthDate {
                    Text("Born \(birthDate, format: .dateTime.day().month(.wide).year())")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            Button("Edit") { editingProfile = true }
                .font(.jakarta(14, .semibold))
                .foregroundStyle(Theme.roseDark)
                .frame(minWidth: 44, minHeight: 44)
        }
        .card()
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = model.photo, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(Circle())
        } else {
            Text(String(model.nickname.prefix(1)).uppercased())
                .font(.jakarta(22, .heavy))
                .foregroundStyle(Theme.roseDark)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.roseTint))
        }
    }

    private var lastysID: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Your Lastys ID")
            row("Personal ID") { Text(verbatim: model.lastysID?.personalID ?? "") }
            if let details = model.myDetails {
                row("Created") { Text(details.createdAt, format: .dateTime.day().month(.abbreviated).year()) }
                row("Phone transfers") { Text(verbatim: String(details.phoneTransferCount)) }
            }
            Text("Scanners see how old your Lastys ID is and how many times it moved phone.")
                .font(.jakarta(12))
                .foregroundStyle(Theme.muted)
        }
        .card()
    }

    private var shareLevel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("What a Scan shows")
            Picker("Share level", selection: Binding(
                get: { model.shareLevel },
                set: { level in Task { await model.setShareLevel(level) } }
            )) {
                Text("Status only").tag(ShareLevel.statusOnly)
                Text("Status + history").tag(ShareLevel.statusAndHistory)
            }
            .pickerStyle(.segmented)
            Text(model.shareLevel == .statusOnly
                ? LocalizedStringKey("Scans show whether you're Single or Taken. Your Relationship history is hidden.")
                : LocalizedStringKey("Scans also show how many past Relationships you've had, with only their start and end months."))
                .font(.jakarta(12))
                .foregroundStyle(Theme.muted)
        }
        .card()
    }

    private var whoScannedMe: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Who scanned me")
            Text("Only when, never who.")
                .font(.jakarta(12))
                .foregroundStyle(Theme.muted)
            if model.whoScannedMe.isEmpty {
                Text("Nobody has scanned you yet.")
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(model.whoScannedMe, id: \.self) { time in
                Label {
                    Text(time, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                } icon: {
                    Image(systemName: "qrcode.viewfinder").foregroundStyle(Theme.muted)
                }
                .font(.jakarta(14))
            }
        }
        .card()
    }

    private var recoveryCode: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Recovery code")
            if model.needsNewRecoveryCode {
                Label("Your Lastys ID was made before Recovery codes were checked. Make a new code so Recovery can work.", systemImage: "exclamationmark.triangle")
                    .font(.jakarta(13, .semibold))
                    .foregroundStyle(Theme.roseDeep)
            }
            if let code = model.revealedRecoveryCode {
                Text(verbatim: code)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .textSelection(.enabled)
                Button("Hide") { model.hideRecoveryCode() }
                    .buttonStyle(GhostButtonStyle())
            } else {
                Button("Show my Recovery code") { Task { await model.revealRecoveryCode() } }
                    .buttonStyle(GhostButtonStyle())
            }
            Button("Make a new Recovery code") { confirmingNewCode = true }
                .buttonStyle(GhostButtonStyle())
            Text("Face ID or your passcode is needed first. Anyone with this code can try to move your Lastys ID to their phone.")
                .font(.jakarta(12))
                .foregroundStyle(Theme.muted)
        }
        .card()
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Help and support")
            if let telegram = SupportLinks.telegram {
                Button("Message us on Telegram") { openURL(telegram) }
                    .buttonStyle(GhostButtonStyle())
            } else {
                Text("Help and support on Telegram is coming soon.")
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)
            }
        }
        .card()
    }

    private var deleteMyData: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Delete my data")
            if model.canDeleteMyData {
                Text("Removes your Lastys ID and everything about you from Lastys and this phone.")
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
                Button("Delete my data", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(GhostButtonStyle())
            } else {
                Text("You can't delete your data while you're in a Relationship, because that would end it one-sidedly. Ask to end it first: your Partner can agree, or the Lastys team can decide after a Team review.")
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            if let problem = model.deleteProblem {
                Text(problem.message)
                    .font(.jakarta(13, .medium))
                    .foregroundStyle(Theme.roseDeep)
            }
        }
        .card()
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.jakarta(16, .bold))
    }

    private func row<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Text(title).font(.jakarta(14)).foregroundStyle(Theme.muted)
            Spacer()
            value().font(.jakarta(14, .bold))
        }
    }
}

/// Changes the nickname, photo and birth date. The birth date stays on this phone.
private struct ProfileEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var photo: Data?
    @State private var birthDate = Date()
    @State private var photoItem: PhotosPickerItem?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nickname", text: $nickname)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photo == nil ? LocalizedStringKey("Add a photo") : LocalizedStringKey("Change the photo"), systemImage: "camera")
                    }
                    if photo != nil {
                        Button("Remove the photo", role: .destructive) { photo = nil }
                    }
                } footer: {
                    Text("Your nickname and photo show when someone Scans you.")
                }
                Section {
                    DatePicker("Birth date", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                } footer: {
                    Text("Stays on this phone. It's used for reminders and the Lucky Day Planner, and never appears on a Scan.")
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saving = true
                        Task {
                            if await model.saveProfile(nickname: nickname, photo: photo, birthDate: birthDate) { dismiss() }
                            saving = false
                        }
                    }
                    .disabled(saving || !model.canSaveProfile(nickname: nickname))
                }
            }
            .onAppear {
                nickname = model.nickname
                photo = model.photo
                birthDate = model.birthDate ?? birthDate
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                    photo = ProfilePhoto.shrunk(data) ?? image.jpegData(compressionQuality: 0.8)
                }
            }
        }
    }
}

extension MeProblem {
    var message: LocalizedStringKey {
        switch self {
        case .needsInternet: return "This needs an internet connection."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Try again."
        case .notAuthenticated: return "Face ID or your passcode is needed for this."
        }
    }
}

extension DeleteProblem {
    var message: LocalizedStringKey {
        switch self {
        case .relationshipNotOver: return "Your Relationship isn't over yet. End it first with an End request or a Team review."
        case .notAuthenticated: return "Face ID or your passcode is needed to delete your data."
        case .needsInternet: return "Deleting your data needs an internet connection."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Nothing was deleted. Try again."
        }
    }
}
