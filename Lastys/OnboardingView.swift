import LastysCore
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The first-run flow: intro, Welcome, Recovery code, profile.
/// Every decision lives in `AppModel`; these screens only render it and pass on taps.
struct OnboardingView: View {
    let step: OnboardingStep

    var body: some View {
        Group {
            switch step {
            case .intro(let page): IntroStep(page: page)
            case .welcome: WelcomeStep()
            case .recoveryCode: RecoveryCodeStep()
            case .profile: ProfileStep()
            case .moveFromAnotherPhone: MoveFromAnotherPhoneStep()
            case .enterRecoveryCode: EnterRecoveryCodeStep()
            case .waitingForRecovery: WaitingForRecoveryStep()
            }
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
    }
}

/// Title, body content and a bottom action, laid out the same on every step.
private struct StepLayout<Content: View, Footer: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.jakarta(26, .heavy))
                            .tracking(-0.6)
                        if let subtitle {
                            Text(subtitle)
                                .font(.jakarta(15))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            VStack(spacing: 12) { footer }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }
}

private struct ProblemText: View {
    let problem: OnboardingProblem?

    var body: some View {
        if let problem {
            Text(message(for: problem))
                .font(.jakarta(14, .medium))
                .foregroundStyle(Theme.roseDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))
        }
    }

    private func message(for problem: OnboardingProblem) -> LocalizedStringKey {
        switch problem {
        case .phoneAlreadyHasLastysID:
            return "This iPhone has already made a Lastys ID, so it can't make another. To get your Lastys ID back, use Recovery with your Recovery code, or a Phone transfer from your old phone."
        case .phoneMadeALastysIDRecently:
            return "This iPhone made a Lastys ID recently, so it can't make a new one yet, even after a deletion. Try again in a few weeks, or use Recovery if you still have your Recovery code."
        case .couldNotReachTrustee:
            return "Couldn't reach Lastys. Check your connection and try again."
        }
    }
}

// MARK: Intro

private struct IntroStep: View {
    @Environment(AppModel.self) private var model
    let page: Int

    private static let pages: [(icon: String, title: LocalizedStringKey, text: LocalizedStringKey)] = [
        ("heart", "One person, one relationship",
         "Lastys proves you're single, and keeps one relationship at a time, confirmed by both of you."),
        ("qrcode.viewfinder", "Scan to know for sure",
         "Scan someone's Lastys QR to see, live, whether they're Verified Single or Taken."),
        ("lock.shield", "Nothing that identifies you",
         "No phone number, real name or ID card. Your Lastys ID lives on this phone."),
    ]

    var body: some View {
        let content = Self.pages[min(page, Self.pages.count - 1)]
        VStack(spacing: 0) {
            HStack {
                Wordmark()
                Spacer()
                Button("Skip") { model.skipIntro() }
                    .font(.jakarta(15, .semibold))
                    .foregroundStyle(Theme.roseDark)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: content.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.rose)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Theme.roseTint))
                    .accessibilityHidden(true)
                Text(content.title)
                    .font(.jakarta(28, .heavy))
                    .tracking(-0.6)
                Text(content.text)
                    .font(.jakarta(16))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .id(page)
            .transition(.opacity)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<AppModel.introPageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.rose : Theme.roseLine)
                        .frame(width: index == page ? 20 : 8, height: 8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Page \(page + 1) of \(AppModel.introPageCount)"))
            .padding(.bottom, 20)

            if model.lastysIDMovedAway {
                Text("Your Lastys ID now lives on your new phone. This phone no longer holds it.")
                    .font(.jakarta(14, .semibold))
                    .foregroundStyle(Theme.roseDeep)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
            Button(page + 1 < AppModel.introPageCount ? LocalizedStringKey("Next") : LocalizedStringKey("Get started")) {
                model.nextIntroPage()
            }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
            HStack(spacing: 8) {
                Button("Move my ID from another phone") { model.startMovingFromAnotherPhone() }
                Text(verbatim: "·").foregroundStyle(Theme.muted)
                Button("I lost my phone") { model.startRecoveryWithCode() }
            }
            .font(.jakarta(13, .semibold))
            .foregroundStyle(Theme.roseDark)
            .frame(minHeight: 44)
            .padding(.bottom, 8)
        }
    }
}

// MARK: Welcome

/// Language, the one consent line, and Get started, on one screen.
private struct WelcomeStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack {
                Wordmark(size: 22)
                Spacer()
                LanguageSwitch()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "heart")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.rose))
                    .padding(.bottom, 14)
                    .accessibilityHidden(true)
                Text("Welcome")
                    .font(.jakarta(34, .heavy))
                    .tracking(-1)
                    .accessibilityAddTraits(.isHeader)
                Text("Love you can trust.")
                    .font(.jakarta(16))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                CheckboxRow(title: "I'm 18 or older and agree to the Terms and Privacy Policy", isOn: $model.acceptsTerms)
                ProblemText(problem: model.onboardingProblem)
                Button {
                    Task { await model.getStarted() }
                } label: {
                    if model.isCreatingLastysID {
                        ProgressView().tint(.white)
                    } else {
                        Text("Get started")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!model.canGetStarted)
                Text("No sign-up. No password.")
                    .font(.jakarta(12))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

/// ខ្មែរ / EN, applied the moment it's tapped.
private struct LanguageSwitch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Language.allCases, id: \.self) { language in
                let isOn = model.language == language
                Button {
                    model.chooseLanguage(language)
                } label: {
                    Text(verbatim: language.shortName)
                        .font(.jakarta(14, .bold))
                        .foregroundStyle(isOn ? Theme.ink : Theme.muted)
                        .frame(minWidth: 52, maxHeight: .infinity)
                        .padding(.horizontal, 6)
                        .background(
                            Capsule()
                                .fill(isOn ? Theme.surface : .clear)
                                .shadow(color: .black.opacity(isOn ? 0.1 : 0), radius: 1.5, y: 1)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: language.nativeName))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(height: 44)
        .background(Capsule().fill(Theme.divider))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Language"))
    }
}

extension Language {
    /// Each language's name in itself, so anyone can find their own.
    var nativeName: String {
        switch self {
        case .khmer: return "ខ្មែរ"
        case .english: return "English"
        }
    }

    /// The label on Welcome's language switch.
    var shortName: String {
        switch self {
        case .khmer: return "ខ្មែរ"
        case .english: return "EN"
        }
    }
}

// MARK: Recovery code

private struct RecoveryCodeStep: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false

    var body: some View {
        @Bindable var model = model
        StepLayout(
            title: "Save your Recovery code",
            subtitle: "If you lose this phone, this code gets your Lastys ID back. Anyone who has it can try to move your Lastys ID, so keep it private."
        ) {
            if let personalID = model.lastysID?.personalID {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Lastys ID")
                        .font(.jakarta(13, .semibold))
                        .foregroundStyle(Theme.muted)
                    Text(verbatim: personalID)
                        .font(.jakarta(20, .heavy))
                        .tracking(0.5)
                }
                .card()
            }
            if let recoveryCode = model.recoveryCode {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recovery code")
                        .font(.jakarta(13, .semibold))
                        .foregroundStyle(Theme.muted)
                    Text(verbatim: recoveryCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    Button(copied ? LocalizedStringKey("Copied") : LocalizedStringKey("Copy")) {
                        // Local only, and cleared after two minutes, so it doesn't linger on the pasteboard.
                        UIPasteboard.general.setItems(
                            [[UTType.plainText.identifier: recoveryCode]],
                            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]
                        )
                        copied = true
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .card()
            }
            VStack(alignment: .leading) {
                CheckboxRow(title: "I've saved my Recovery code somewhere safe", isOn: $model.hasSavedRecoveryCode)
            }
            .card()
        } footer: {
            Button("Continue") { model.continueFromRecoveryCode() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!model.canContinueFromRecoveryCode)
        }
    }
}

// MARK: Profile

private struct ProfileStep: View {
    @Environment(AppModel.self) private var model
    @State private var photoItem: PhotosPickerItem?

    private static let defaultBirthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    var body: some View {
        @Bindable var model = model
        StepLayout(title: "How people see you", subtitle: "Your nickname and photo show when someone Scans your Lastys QR.") {
            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    photoCircle
                }
                .accessibilityLabel(Text("Choose a photo"))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photo")
                        .font(.jakarta(15, .bold))
                    Text("Optional")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                    if model.profilePhoto != nil {
                        Button("Remove photo") {
                            model.profilePhoto = nil
                            photoItem = nil
                        }
                        .font(.jakarta(13, .semibold))
                        .foregroundStyle(Theme.roseDark)
                        .frame(minHeight: 44)
                    }
                }
                Spacer(minLength: 0)
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                Text("Nickname")
                    .font(.jakarta(13, .semibold))
                    .foregroundStyle(Theme.muted)
                TextField("e.g. Srey Pich", text: $model.profileNickname)
                    .font(.jakarta(17, .semibold))
                    .textContentType(.nickname)
                    .submitLabel(.done)
                    .frame(minHeight: 44)
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                Text("Birth date")
                    .font(.jakarta(13, .semibold))
                    .foregroundStyle(Theme.muted)
                if let birthDate = model.profileBirthDate {
                    DatePicker(
                        "Birth date",
                        selection: Binding(get: { birthDate }, set: { model.profileBirthDate = $0 }),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Add your birth date") { model.profileBirthDate = Self.defaultBirthDate }
                        .buttonStyle(GhostButtonStyle())
                }
                Label("Stays on this phone. It's used for reminders and the Lucky Day Planner, and never appears on a Scan.", systemImage: "lock")
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            .card()

            ProblemText(problem: model.onboardingProblem)
        } footer: {
            Button {
                Task { await model.finishProfile() }
            } label: {
                if model.isSavingProfile {
                    ProgressView().tint(.white)
                } else {
                    Text("Done")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.canFinishProfile)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                model.profilePhoto = ProfilePhoto.shrunk(data)
            }
        }
    }

    @ViewBuilder
    private var photoCircle: some View {
        if let data = model.profilePhoto, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
        } else {
            Image(systemName: "camera")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.rose)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Theme.roseTint))
        }
    }

}

// MARK: Moving to this phone

/// A new phone scanning the old phone's transfer QR (Me > Move to a new phone).
private struct MoveFromAnotherPhoneStep: View {
    @Environment(AppModel.self) private var model
    @State private var scanned = false
    /// A new scanner after each failed attempt, so the camera reads codes again.
    @State private var attempt = 0

    var body: some View {
        StepLayout(
            title: "Move your Lastys ID here",
            subtitle: "On your old phone, open Me and choose Move to a new phone, then scan its code. The code works for 5 minutes."
        ) {
            CameraQRScanner(torchOn: false) { payload in
                guard !scanned else { return }
                scanned = true
                Task {
                    await model.receivePhoneTransfer(payload)
                    scanned = false
                    attempt += 1
                }
            }
            .id(attempt)
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            ChooseFromPhotosButton { codes in
                guard !scanned else { return }
                scanned = true
                Task {
                    await model.receivePhoneTransfer(photoCodes: codes)
                    scanned = false
                }
            }
            PhotoProblemLabel(problem: model.photoProblem)
            PhoneMoveProblemText(problem: model.phoneMoveProblem)
        } footer: {
            Button("Back") { model.backToIntro() }
                .buttonStyle(GhostButtonStyle())
        }
    }
}

/// A new phone starting a Recovery with the Recovery code.
private struct EnterRecoveryCodeStep: View {
    @Environment(AppModel.self) private var model
    @State private var code = ""

    var body: some View {
        StepLayout(
            title: "Recover your Lastys ID",
            subtitle: "Enter the Recovery code you saved. Your Lastys ID moves to this phone after 7 days, unless your old phone cancels."
        ) {
            TextField("XXXX-XXXX-XXXX-XXXX", text: $code)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
                .card()
            PhoneMoveProblemText(problem: model.phoneMoveProblem)
        } footer: {
            Button("Start Recovery") { Task { await model.beginRecovery(code: code) } }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Back") { model.backToIntro() }
                .buttonStyle(GhostButtonStyle())
        }
    }
}

/// A new phone waiting out the Recovery's 7 days. It checks back now and then.
private struct WaitingForRecoveryStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        StepLayout(title: "Recovery in progress", subtitle: "Your old phone has been told, in case this wasn't you.") {
            VStack(alignment: .leading, spacing: 8) {
                if let completesAt = model.recoveryCompletesAt {
                    Text("Your Lastys ID moves to this phone on \(completesAt, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute()).")
                        .font(.jakarta(15, .semibold))
                }
                Text("Keep Lastys installed. You can close it; it checks again when you open it.")
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            .card()
            PhoneMoveProblemText(problem: model.phoneMoveProblem)
        } footer: {
            Button("Check now") { Task { await model.checkRecovery() } }
                .buttonStyle(GhostButtonStyle())
        }
        .task {
            while !Task.isCancelled {
                await model.checkRecovery()
                try? await Task.sleep(for: AppModel.recoveryCheckInterval)
            }
        }
    }
}

private struct PhoneMoveProblemText: View {
    let problem: PhoneMoveProblem?

    var body: some View {
        if let problem {
            Text(problem.message)
                .font(.jakarta(14, .medium))
                .foregroundStyle(Theme.roseDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))
        }
    }
}

extension PhoneMoveProblem {
    var message: LocalizedStringKey {
        switch self {
        case .transferTooSoon: return "Your Lastys ID moved phone less than 30 days ago. You can move it again after that."
        case .notATransferQR: return "That's not a Lastys transfer code. Open Me > Move to a new phone on your old phone."
        case .transferCodeExpired: return "That transfer code has expired. Make a new one on your old phone."
        case .transferCodeInvalid: return "That transfer code was already used or isn't valid. Make a new one on your old phone."
        case .wrongRecoveryCode: return "That Recovery code doesn't match any Lastys ID. Check it and try again."
        case .recoveryCancelled: return "The Recovery was cancelled from the phone that holds the Lastys ID."
        case .someDataDidNotMove: return "Your Lastys ID is now on this phone, but your Moments and settings couldn't be opened. Add them again here."
        case .needsInternet: return "This needs an internet connection."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Try again."
        }
    }
}

#Preview("New phone") {
    AppRootView()
        .environment(AppModel.preview(onboarded: false))
}
