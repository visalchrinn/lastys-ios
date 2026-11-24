import LastysCore
import SwiftUI

/// Under a Scan result: send a Relationship request, or why it isn't possible.
struct RelationshipRequestButton: View {
    @Environment(AppModel.self) private var model
    let result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await model.sendRelationshipRequest() }
            } label: {
                if model.isSendingRequest {
                    ProgressView().tint(.white)
                } else {
                    Text("Send Relationship request")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.canSendRelationshipRequest)

            if let block = result.requestBlock {
                Text(block.reason)
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            if let problem = model.requestProblem {
                Text(problem.message)
                    .font(.jakarta(13, .medium))
                    .foregroundStyle(Theme.roseDeep)
            }
        }
    }
}

/// "Waiting for …" until the receiver answers, then the outcome.
struct RelationshipRequestStatusView: View {
    @Environment(AppModel.self) private var model
    let request: RelationshipRequest
    let done: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.rose)
                        .accessibilityHidden(true)
                    Text(headline)
                        .font(.jakarta(20, .heavy))
                    Text(detail)
                        .font(.jakarta(14))
                        .foregroundStyle(Theme.muted)
                }
                .card(padding: 20)

                if request.status == .pending {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Checking for their answer…")
                            .font(.jakarta(13))
                            .foregroundStyle(Theme.muted)
                    }
                    #if DEBUG
                    DemoReceiverControls(request: request)
                    #endif
                } else {
                    Button("Done", action: done)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var icon: String {
        switch request.status {
        case .pending: return "hourglass"
        case .accepted: return "heart.fill"
        case .declined: return "xmark.circle"
        case .expired: return "clock.arrow.circlepath"
        }
    }

    private var headline: LocalizedStringKey {
        switch request.status {
        case .pending: return "Waiting for \(request.toNickname)"
        case .accepted: return "You and \(request.toNickname) are Taken"
        case .declined: return "\(request.toNickname) declined"
        case .expired: return "No longer possible"
        }
    }

    private var detail: LocalizedStringKey {
        switch request.status {
        case .pending:
            return "Your Relationship starts only when \(request.toNickname) accepts. You can close this; Home updates when they answer."
        case .accepted:
            return "Your Relationship has started. Anyone who Scans either of you now sees Taken."
        case .declined:
            return "Nothing has changed for either of you."
        case .expired:
            return "One of you started a Relationship with someone else."
        }
    }
}

#if DEBUG
/// Demo: the sample person answers, since Phase A has no second phone.
private struct DemoReceiverControls: View {
    @Environment(AppModel.self) private var model
    @Environment(\.demoTrustee) private var trustee
    let request: RelationshipRequest

    var body: some View {
        if let trustee {
            VStack(spacing: 10) {
                Button(demoTitle("accepts")) { respond(trustee, accept: true) }
                    .buttonStyle(GhostButtonStyle())
                Button(demoTitle("declines")) { respond(trustee, accept: false) }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }

    /// Demo labels stay in English: they never ship.
    private func demoTitle(_ verb: String) -> String {
        "Demo: \(request.toNickname) \(verb)"
    }

    private func respond(_ trustee: FakeTrustee, accept: Bool) {
        Task {
            try? await trustee.demoRespondToRelationshipRequest(id: request.id, accept: accept)
            await model.refreshOutgoingRequest()
        }
    }
}
#endif

extension RelationshipRequestBlock {
    var reason: LocalizedStringKey {
        switch self {
        case .youAreTaken:
            return "You're Taken, so you can't send a Relationship request."
        case .youAreCoolingOff(let until):
            return "You're in a Cooling-off period until \(until, format: .dateTime.day().month(.abbreviated).year())."
        case .theyAreTaken:
            return "They're Taken, so they can't receive a Relationship request."
        case .thatIsYou:
            return "This is your own Lastys QR."
        }
    }
}

extension RelationshipRequestProblem {
    var message: LocalizedStringKey {
        switch self {
        case .needsInternet: return "Sending a Relationship request needs an internet connection."
        case .scanAgain: return "Something changed since this Scan. Scan them again."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Try again."
        }
    }
}
