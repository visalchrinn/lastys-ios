import LastysCore
import SwiftUI

/// What the person who opens an Invite link sees: who's asking, Accept & link, or Not now.
/// Phase A shows it as a preview on the sender's own phone; with #20 a real link opens it on the partner's.
struct InviteAnswerView: View {
    let senderNickname: String
    /// Shown as "your partner's phone" on the sender's own phone.
    var isPreview = false
    var isWorking = false
    var problem: LocalizedStringKey?
    let accept: () -> Void
    let decline: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                if isPreview {
                    Text("PREVIEW · YOUR PARTNER'S PHONE")
                        .font(.jakarta(11, .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.roseDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.roseTint))
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isPreview ? "Close preview" : "Close"))
            }

            Spacer()

            Wordmark(size: 22)
            Text(String(senderNickname.prefix(1)).uppercased())
                .font(.jakarta(32, .heavy))
                .foregroundStyle(Theme.roseDark)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Theme.roseTint))
                .accessibilityHidden(true)
            Text("\(senderNickname) wants to link with you")
                .font(.jakarta(24, .heavy))
                .tracking(-0.5)
                .multilineTextAlignment(.center)
            Text("Accept to show you're together on Lastys. Either of you can end it later.")
                .font(.jakarta(15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)

            Spacer()

            if let problem {
                Text(problem)
                    .font(.jakarta(13, .medium))
                    .foregroundStyle(Theme.roseDeep)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                Button(action: accept) {
                    if isWorking { ProgressView().tint(.white) } else { Text("Accept & link") }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Not now", action: decline)
                    .buttonStyle(GhostButtonStyle())
            }
            .disabled(isWorking)
            Text("New to Lastys? Your ID is created in seconds. No sign-up.")
                .font(.jakarta(12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .background(Theme.background.ignoresSafeArea())
    }
}

extension ReceivedInviteProblem {
    var message: LocalizedStringKey {
        switch self {
        case .needsInternet: return "Answering an invite needs an internet connection."
        case .noLongerValid: return "This invite is no longer valid."
        case .thatIsYou: return "This is your own invite."
        case .youAreTaken: return "You're already in a Relationship, so you can't accept this invite."
        case .youAreCoolingOff: return "You're in a Cooling-off period, so you can't accept an invite yet."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Try again."
        }
    }
}
