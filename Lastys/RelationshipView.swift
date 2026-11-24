import LastysCore
import SwiftUI

/// Where the Relationship stands, and the ending actions open to this Partner right now.
struct RelationshipView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirming: EndingAction?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Relationship")
                    .font(.jakarta(22, .heavy))
                    .tracking(-0.4)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    RelationshipStageCard(status: model.relationship)

                    ForEach(model.endingActions, id: \.self) { action in
                        Button(action.title) {
                            if action.needsConfirmation {
                                confirming = action
                            } else {
                                Task { await model.perform(action) }
                            }
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(model.isPerformingEndingAction)
                    }

                    if let problem = model.endingProblem {
                        Text(problem.message)
                            .font(.jakarta(13, .medium))
                            .foregroundStyle(Theme.roseDeep)
                    }

                    #if DEBUG
                    DemoEndingControls()
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { model.clearEndingProblem() }
        // Once the Relationship has ended (or never was), Home shows the Cooling-off period instead.
        .onChange(of: model.partnerNickname.isEmpty) { _, ended in
            if ended { dismiss() }
        }
        .confirmationDialog(
            confirming?.confirmationTitle ?? "",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { action in
            Button(action.title) { Task { await model.perform(action) } }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.confirmationMessage(partner: model.partnerNickname))
        }
    }
}

/// What the Relationship's stage means for this Partner, in words.
struct RelationshipStageCard: View {
    let status: RelationshipStatus

    var body: some View {
        if case .active(let partner, _, let stage) = status {
            VStack(alignment: .leading, spacing: 8) {
                Text(headline(stage, partner: partner))
                    .font(.jakarta(17, .bold))
                Text(detail(stage, partner: partner))
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)
            }
            .card(padding: 20)
        }
    }

    private func headline(_ stage: RelationshipStage, partner: String) -> LocalizedStringKey {
        switch stage {
        case .together: return "Together with \(partner)"
        case .ending(let request) where request.sentByMe: return request.declined ? "\(partner) declined to end it" : "You asked to end your Relationship"
        case .ending(let request): return request.declined ? "You declined to end it" : "\(partner) asked to end your Relationship"
        case .inTeamReview(let review): return review.reason == .safetyConcern ? "Safety concern reported" : "Team review"
        }
    }

    private func detail(_ stage: RelationshipStage, partner: String) -> LocalizedStringKey {
        switch stage {
        case .together:
            return "A Relationship ends only when you both agree, or after a review by the Lastys team."
        case .ending(let request) where request.sentByMe:
            return request.declined
                ? "You're both still Taken. You can ask the Lastys team to decide, or withdraw your request."
                : "\(partner) has until \(request.answerBy, format: .dateTime.day().month(.abbreviated).year()) to agree or decline. You're both still Taken until then."
        case .ending(let request):
            return request.declined
                ? "You're both still Taken. \(partner) may ask the Lastys team to decide."
                : "You have until \(request.answerBy, format: .dateTime.day().month(.abbreviated).year()) to agree or decline. You're both still Taken until then."
        case .inTeamReview(let review):
            return review.reason == .safetyConcern
                ? "The Lastys team will act within 24 hours."
                : "The Lastys team will contact you both and decide within 3 working days. You're both still Taken until then."
        }
    }
}

extension EndingAction {
    var title: LocalizedStringKey {
        switch self {
        case .sendEndRequest: return "Ask to end the Relationship"
        case .withdrawEndRequest: return "Withdraw my End request"
        case .agreeToEndRequest: return "Agree to end it"
        case .declineEndRequest: return "Decline"
        case .escalateToTeamReview: return "Ask the Lastys team to decide"
        case .reportSafetyConcern: return "Report a safety concern"
        }
    }

    var needsConfirmation: Bool {
        self == .sendEndRequest || self == .reportSafetyConcern || self == .agreeToEndRequest
    }

    var confirmationTitle: LocalizedStringKey {
        switch self {
        case .sendEndRequest: return "Ask to end your Relationship?"
        case .reportSafetyConcern: return "Report a safety concern?"
        case .agreeToEndRequest: return "End your Relationship?"
        default: return ""
        }
    }

    func confirmationMessage(partner: String) -> LocalizedStringKey {
        switch self {
        case .sendEndRequest:
            return "\(partner) will be asked to agree. You both stay Taken while \(partner) has 7 days to answer."
        case .reportSafetyConcern:
            return "The Lastys team will review your Relationship within 24 hours and may contact you both."
        case .agreeToEndRequest:
            return "Your Relationship ends now. You both can't start a new one for 7 days."
        default:
            return ""
        }
    }
}

extension EndingProblem {
    var message: LocalizedStringKey {
        switch self {
        case .needsInternet: return "This needs an internet connection."
        case .changedMeanwhile: return "Something changed meanwhile. This screen now shows where things stand."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Try again."
        }
    }
}

#if DEBUG
/// Demo: the Partner and the Lastys team act, since Phase A has no second phone and no staff console.
private struct DemoEndingControls: View {
    @Environment(AppModel.self) private var model
    @Environment(\.demoTrustee) private var trustee

    var body: some View {
        if let trustee, let me = model.lastysID?.personalID, case .active(let partner, _, let stage) = model.relationship {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: "Demo")
                    .font(.jakarta(13, .semibold))
                    .foregroundStyle(Theme.muted)
                switch stage {
                case .together:
                    demoButton("Demo: \(partner) asks to end it") { try await trustee.demoPartnerSendsEndRequest(of: me) }
                    demoButton("Demo: \(partner) reports a safety concern") { try await trustee.demoPartnerReportsSafetyConcern(of: me) }
                case .ending(let request) where request.sentByMe && !request.declined:
                    demoButton("Demo: \(partner) agrees") { try await trustee.demoPartnerRespondsToEndRequest(of: me, agree: true) }
                    demoButton("Demo: \(partner) declines") { try await trustee.demoPartnerRespondsToEndRequest(of: me, agree: false) }
                    demoButton("Demo: no answer after 7 days") { try await trustee.demoNoAnswerFor7Days(toEndRequestOf: me) }
                case .inTeamReview:
                    demoButton("Demo: the team ends it") { try await trustee.teamDecides(aboutRelationshipOf: me, endIt: true) }
                    demoButton("Demo: the team keeps it") { try await trustee.teamDecides(aboutRelationshipOf: me, endIt: false) }
                default:
                    EmptyView()
                }
            }
        }
    }

    private func demoButton(_ title: String, _ act: @escaping () async throws -> Void) -> some View {
        Button(title) {
            Task {
                try? await act()
                await model.start()
            }
        }
        .buttonStyle(GhostButtonStyle())
    }
}
#endif
