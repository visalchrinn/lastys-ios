import LastysCore
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The first-run flow: intro, language, consent, Recovery code, profile.
/// Every decision lives in `AppModel`; these screens only render it and pass on taps.
struct OnboardingView: View {
    let step: OnboardingStep

    var body: some View {
        Group {
            switch step {
            case .intro(let page): IntroStep(page: page)
            case .language: LanguageStep()
            case .consent: ConsentStep()
            case .recoveryCode: RecoveryCodeStep()
            case .profile: ProfileStep()
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

            Button(page + 1 < AppModel.introPageCount ? LocalizedStringKey("Next") : LocalizedStringKey("Get started")) {
                model.nextIntroPage()
            }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }
}

// MARK: Language

private struct LanguageStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        StepLayout(title: "Choose your language", subtitle: "You can change it later in Me.") {
            VStack(spacing: 10) {
                ForEach(Language.allCases, id: \.self) { language in
                    Button {
                        model.chooseLanguage(language)
                    } label: {
                        HStack {
                            Text(verbatim: language.nativeName)
                                .font(.jakarta(17, .bold))
                            Spacer()
                            if model.language == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.rose)
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
        } footer: {
            Button("Continue") { model.confirmLanguage() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

private extension Language {
    /// Each language's name in itself, so anyone can find their own.
    var nativeName: String {
        switch self {
        case .khmer: return "ខ្មែរ"
        case .english: return "English"
        }
    }
}

// MARK: Consent

private struct ConsentStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        StepLayout(
            title: "Before you start",
            subtitle: "Lastys is for adults, and works only if everyone plays by the same rules."
        ) {
            VStack(alignment: .leading, spacing: 4) {
                CheckboxRow(title: "I'm 18 or older", isOn: $model.isOver18)
                CheckboxRow(title: "I accept the Terms and the Privacy Notice", isOn: $model.acceptsTerms)
            }
            .card()
            ProblemText(problem: model.onboardingProblem)
        } footer: {
            Button {
                Task { await model.continueFromConsent() }
            } label: {
                if model.isCreatingLastysID {
                    ProgressView().tint(.white)
                } else {
                    Text("Create my Lastys ID")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.canContinueFromConsent)
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

#Preview("New phone") {
    AppRootView()
        .environment(AppModel.preview(onboarded: false))
}
