import CoreImage.CIFilterBuiltins
import LastysCore
import PhotosUI
import SwiftUI
import UIKit

/// Where Lastys's Help and support lives. Set to the team's Telegram link before release;
/// until then the Me tab says it's coming, rather than send anyone to a stranger's account.
enum SupportLinks {
    static let telegram: URL? = nil
}

/// The Me tab: my profile, my Lastys ID, what Scans show, and a list that opens Language, Who scanned me
/// (by time only), Change phone, my Recovery code, Revoke my QR, Help and support, and Delete my data.
struct MeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingProfile = false
    @State private var sheet: MeSheet?

    enum MeSheet: String, Identifiable {
        case language, whoScannedMe, changePhone, recovery, revokeQR, delete
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Me")
                    .font(.jakarta(26, .heavy))
                    .tracking(-0.6)
                profile
                pendingRecovery
                lastysID
                shareLevel
                list
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
        .sheet(item: $sheet) { sheet in
            Group {
                switch sheet {
                case .language: LanguageSheet()
                case .whoScannedMe: WhoScannedMeSheet()
                case .changePhone: ChangePhoneSheet()
                case .recovery: RecoveryCodeSheet()
                case .revokeQR: MyLastysQRView()
                case .delete: DeleteMyDataSheet()
                }
            }
            .environment(model)
        }
    }

    // MARK: Cards

    private var statusWord: LocalizedStringKey {
        if case .active = model.relationship { return "Taken" }
        return "Single"
    }

    private var profile: some View {
        HStack(spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: model.nickname)
                    .font(.jakarta(18, .heavy))
                Group {
                    if let birthDate = model.birthDate {
                        Text("Born \(birthDate, format: .dateTime.day().month(.wide).year())") + Text(verbatim: " · ") + Text(statusWord)
                    } else {
                        Text(statusWord)
                    }
                }
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Personal ID")
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
            Text(verbatim: model.lastysID?.personalID ?? "")
                .font(.jakarta(20, .heavy))
                .tracking(1)
            if let details = model.myDetails {
                (Text("Created") + Text(verbatim: " ") + Text(details.createdAt, format: .dateTime.day().month(.abbreviated).year())
                    + Text(verbatim: " · ") + Text("Phone transfers") + Text(verbatim: " \(details.phoneTransferCount)"))
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            Text("Scanners see how old your Lastys ID is and how many times it moved phone.")
                .font(.jakarta(12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
        .card()
    }

    private var shareLevel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What a Scan shows").font(.jakarta(16, .bold))
            HStack(spacing: 4) {
                segment("Status only", .statusOnly)
                segment("Status + history", .statusAndHistory)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: 0xF1ECE8)))
            Text(model.shareLevel == .statusOnly
                ? LocalizedStringKey("Scans show whether you're Single or Taken. Your Relationship history is hidden.")
                : LocalizedStringKey("Scans also show how many past Relationships you've had, with only their start and end months."))
                .font(.jakarta(12))
                .foregroundStyle(Theme.muted)
        }
        .card()
    }

    private func segment(_ title: LocalizedStringKey, _ level: ShareLevel) -> some View {
        let selected = model.shareLevel == level
        return Button { Task { await model.setShareLevel(level) } } label: {
            Text(title)
                .font(.jakarta(13, .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(selected ? Theme.surface : .clear))
                .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: 0) {
            listRow("Language", detail: Text(verbatim: model.language.nativeName)) { sheet = .language }
            listRow("Who scanned me") { sheet = .whoScannedMe }
            listRow("Change phone") { sheet = .changePhone }
            listRow("Recovery code") { sheet = .recovery }
            listRow("Revoke my QR", detail: Text("Get a new one")) { sheet = .revokeQR }
            if let telegram = SupportLinks.telegram {
                listRow("Help and support", detail: Text(verbatim: "Telegram")) { openURL(telegram) }
            } else {
                listRow("Help and support", detail: Text("Coming soon"), enabled: false) {}
            }
            listRow("Delete my data", tint: Color(hex: 0xB91C1C), last: true) { sheet = .delete }
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func listRow(
        _ title: LocalizedStringKey, detail: Text? = nil, tint: Color = Theme.ink,
        enabled: Bool = true, last: Bool = false, action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(title).font(.jakarta(15, .medium)).foregroundStyle(tint)
                    Spacer(minLength: 8)
                    if let detail { detail.font(.jakarta(13)).foregroundStyle(Theme.muted) }
                    if enabled && !last {
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            if !last { Rectangle().fill(Theme.divider).frame(height: 1) }
        }
    }

    @ViewBuilder
    private var pendingRecovery: some View {
        if let completesAt = model.myDetails?.recoveryCompletesAt {
            VStack(alignment: .leading, spacing: 8) {
                Label("A Recovery of your Lastys ID has started", systemImage: "exclamationmark.triangle.fill")
                    .font(.jakarta(15, .bold))
                    .foregroundStyle(Theme.roseDeep)
                Text("Someone entered your Recovery code on another phone. Unless you cancel, your Lastys ID moves there on \(completesAt, format: .dateTime.day().month(.wide).hour().minute()). If this wasn't you, cancel it and make a new Recovery code.")
                    .font(.jakarta(13))
                Button("Cancel this Recovery", role: .destructive) { Task { await model.cancelRecovery() } }
                    .buttonStyle(GhostButtonStyle())
            }
            .card()
        }
    }
}

// MARK: Sheets

/// A Me sheet: a title with a close button over a scrolling stack of cards.
private struct MeSheetFrame<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.jakarta(20, .bold))
                    .tracking(-0.2)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Done")
            }
            .padding(.leading, 20)
            .padding(.trailing, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct LanguageSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        MeSheetFrame(title: "Language") {
            ForEach(Language.allCases, id: \.self) { language in
                Button { model.chooseLanguage(language) } label: {
                    HStack {
                        Text(verbatim: language.nativeName).font(.jakarta(17, .bold))
                        Spacer()
                        if model.language == language {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.rose)
                        }
                    }
                    .frame(minHeight: 44)
                    .card(border: model.language == language ? Theme.rose : Theme.cardBorder)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.language == language ? .isSelected : [])
            }
        }
    }
}

private struct WhoScannedMeSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        MeSheetFrame(title: "Who scanned me") {
            VStack(alignment: .leading, spacing: 10) {
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
        .task { await model.refreshMe() }
    }
}

private struct RecoveryCodeSheet: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingNewCode = false

    var body: some View {
        MeSheetFrame(title: "Recovery code") {
            VStack(alignment: .leading, spacing: 10) {
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
                if let problem = model.meProblem {
                    Text(problem.message)
                        .font(.jakarta(13, .medium))
                        .foregroundStyle(Theme.roseDeep)
                }
            }
            .card()
        }
        // The Recovery code never stays on screen once the sheet closes.
        .onDisappear { model.hideRecoveryCode() }
        .confirmationDialog("Make a new Recovery code?", isPresented: $confirmingNewCode, titleVisibility: .visible) {
            Button("Make a new code") { Task { await model.makeNewRecoveryCode() } }
        } message: {
            Text("Your current Recovery code stops working straight away. Save the new one somewhere safe.")
        }
    }
}

private struct ChangePhoneSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        MeSheetFrame(title: "Move to a new phone") {
            VStack(alignment: .leading, spacing: 10) {
                if let qr = model.phoneTransferQR {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = model.phoneTransferSecondsLeft(at: context.date)
                        VStack(spacing: 10) {
                            if left > 0 {
                                TransferQRImage(payload: qr.payload)
                                    .frame(width: 220, height: 220)
                                    .frame(maxWidth: .infinity)
                                Text("On your new phone, choose Move my ID from another phone and scan this. Valid for \(left / 60):\(String(format: "%02d", left % 60)).")
                                    .font(.jakarta(13))
                                    .foregroundStyle(Theme.muted)
                            } else {
                                Text("This code has expired.")
                                    .font(.jakarta(13))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    Button("Stop") { model.stopOfferingPhoneTransfer() }
                        .buttonStyle(GhostButtonStyle())
                } else {
                    Text("Your Lastys ID, Relationship and Moments move to the new phone, which makes its own key. Photos and videos on Moments don't move yet, and this phone starts over. One move every 30 days.")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                    Button("Show a transfer code") { Task { await model.offerPhoneTransfer() } }
                        .buttonStyle(GhostButtonStyle())
                }
                if let problem = model.phoneMoveProblem {
                    Text(problem.message)
                        .font(.jakarta(13, .medium))
                        .foregroundStyle(Theme.roseDeep)
                }
            }
            .card()
        }
        // While the code shows, notice as soon as the new phone has taken the Lastys ID.
        .task(id: model.phoneTransferQR?.payload) {
            while model.phoneTransferQR != nil, !Task.isCancelled {
                try? await Task.sleep(for: AppModel.transferWatchInterval)
                await model.start()
            }
        }
    }
}

private struct DeleteMyDataSheet: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingDelete = false

    var body: some View {
        MeSheetFrame(title: "Delete my data") {
            VStack(alignment: .leading, spacing: 8) {
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

/// The transfer QR, drawn crisp.
private struct TransferQRImage: View {
    let payload: String

    var body: some View {
        let filter = CIFilter.qrCodeGenerator()
        let _ = filter.message = Data(payload.utf8)
        if let output = filter.outputImage, let image = CIContext().createCGImage(output, from: output.extent) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
        }
    }
}
