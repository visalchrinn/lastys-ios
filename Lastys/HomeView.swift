import LastysCore
import SwiftUI

struct HomeView: View {
    var showToast: (String) -> Void
    var openMe: () -> Void

    @Environment(AppModel.self) private var model
    @State private var showingMyLastysQR = false
    @State private var showingScan = false
    @State private var showingRelationship = false
    @State private var showingVerifiedSingleCard = false
    @State private var editing: MomentEditorView.Target?
    @State private var viewing: Moment?
    #if DEBUG
    @Environment(\.demoTrustee) private var demoTrustee
    #else
    private let demoTrustee: FakeTrustee? = nil
    #endif

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !model.notices.isEmpty {
                    NoticesBanner()
                }
                if model.showsStatusCard {
                    statusCard
                }
                if let request = model.outgoingRequest, request.status == .pending {
                    waitingCard(for: request)
                }
                quickActions
                safetyTips
                if model.showsFormerSharedMoments {
                    FormerSharedMomentsCard()
                }
                momentsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .foregroundStyle(Theme.ink)
        .sheet(isPresented: $showingMyLastysQR) {
            MyLastysQRView()
                .environment(model)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showingScan) {
            ScanView()
                .environment(model)
                .demoTrustee(demoTrustee)
        }
        .sheet(isPresented: $showingVerifiedSingleCard) {
            VerifiedSingleCardSheet()
                .environment(model)
        }
        .sheet(isPresented: $showingRelationship) {
            RelationshipView()
                .environment(model)
                .demoTrustee(demoTrustee)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Wordmark()
                (Text(model.currentDay, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                    + Text(verbatim: " · ") + Text(model.todayLunarDate.text))
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if model.canUseQuickHide {
                Button {
                    model.setQuickHide(!model.isQuickHideOn)
                } label: {
                    Image(systemName: model.isQuickHideOn ? "eye.slash" : "eye")
                        .font(.system(size: 18, weight: .semibold))
                        // The same quiet look either way, so it never draws an onlooker's eye.
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("Quick hide"))
                .accessibilityValue(Text(model.isQuickHideOn ? "On" : "Off"))
                .accessibilityHint(Text("Hides your status and Shared Moments on this screen. Scans of you still show the truth."))
            }
            Button(action: openMe) {
                Text(String(model.nickname.prefix(1)).uppercased())
                    .font(.jakarta(16, .heavy))
                    .foregroundStyle(Theme.roseDark)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.roseTint))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Open Me")
        }
    }

    // MARK: Status

    @ViewBuilder
    private var statusCard: some View {
        switch model.relationship {
        case .none:
            verifiedSingleCard
        case .active(let partnerNickname, let since, let stage):
            takenCard(partnerNickname: partnerNickname, since: since, stage: stage)
        case .coolingOff(let until):
            coolingOffCard(until: until)
        }
    }

    private func coolingOffCard(until: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: model.nickname)
                .font(.jakarta(13, .semibold))
                .foregroundStyle(Theme.muted)
            Text("Relationship ended")
                .font(.jakarta(18, .heavy))
            Text("Cooling-off period until \(until, format: .dateTime.day().month(.abbreviated).year()). You can't send or accept a Relationship request until then.")
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
            // No active Relationship, so Verified Single: the card is offered here too.
            if model.canShareVerifiedSingleCard {
                Button("Share my Verified Single card") {
                    showingVerifiedSingleCard = true
                }
                .buttonStyle(GhostButtonStyle())
            }
            #if DEBUG
            if let demoTrustee, let me = model.lastysID?.personalID {
                Button("Demo: skip the Cooling-off period") {
                    Task {
                        try? await demoTrustee.demoSkipCoolingOff(of: me)
                        await model.start()
                    }
                }
                .buttonStyle(GhostButtonStyle())
            }
            #endif
        }
        .card(padding: 20)
    }

    private func waitingCard(for request: RelationshipRequest) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Waiting for \(request.toNickname) to answer your Relationship request")
                .font(.jakarta(14, .semibold))
            Spacer(minLength: 0)
        }
        .card()
    }

    private func takenCard(partnerNickname: String, since: Date, stage: RelationshipStage) -> some View {
        Button {
            showingRelationship = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                takenSummary(partnerNickname: partnerNickname, since: since)
                if stage != .together {
                    RelationshipStageCard(status: model.relationship)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint(Text("Shows your Relationship"))
    }

    private func takenSummary(partnerNickname: String, since: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.rose)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.roseTint))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: model.nickname)
                    .font(.jakarta(13, .semibold))
                    .foregroundStyle(Theme.muted)
                Text("Taken")
                    .font(.jakarta(18, .heavy))
                Text("With \(partnerNickname)")
                    .font(.jakarta(15, .semibold))
                Text("Day \(model.dayTogether(on: Date()) ?? 1) together since \(since, format: .dateTime.day().month(.abbreviated).year())")
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 20)
    }

    private var verifiedSingleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.green)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.greenTint))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: model.nickname)
                        .font(.jakarta(13, .semibold))
                        .foregroundStyle(Theme.muted)
                    Text("Verified Single")
                        .font(.jakarta(18, .heavy))
                    Text("Not linked to anyone")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            if model.canShareVerifiedSingleCard {
                Button("Share my Verified Single card") {
                    showingVerifiedSingleCard = true
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .card(padding: 20)
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            actionTile(icon: "qrcode", title: "Show my QR", dark: false) {
                showingMyLastysQR = true
            }
            actionTile(icon: "qrcode.viewfinder", title: "Scan a QR", dark: true) {
                showingScan = true
            }
        }
    }

    private func actionTile(icon: String, title: String, dark: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(dark ? Color.white : Theme.rose)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Text(title)
                    .font(.jakarta(16, .bold))
                    .foregroundStyle(dark ? Color.white : Theme.ink)
            }
            .frame(height: 72, alignment: .leading)
            .card(fill: dark ? Theme.ink : Theme.surface, border: dark ? Theme.ink : Theme.cardBorder)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Safety tips

    private var safetyTips: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dating safety tips")
                    .font(.jakarta(17, .bold))
                    .tracking(-0.2)
                Spacer()
                VersionTag(text: "1.1")
            }
            ForEach([
                "Meet in a public place the first few times",
                "Scan each other's QR before you commit",
                "Tell a friend where you are going",
            ], id: \.self) { tip in
                HStack(spacing: 10) {
                    Circle().fill(Theme.green).frame(width: 8, height: 8)
                    Text(tip).font(.jakarta(14))
                }
            }
        }
        .card()
    }

    // MARK: Moments

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming moments")
                    .font(.jakarta(17, .bold))
                    .tracking(-0.2)
                Spacer()
                Button("+ Add") {
                    editing = .new
                }
                .font(.jakarta(14, .semibold))
                .foregroundStyle(Theme.roseDark)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.top, 4)

            if let problem = model.sharingProblem {
                Text(problem.message)
                    .font(.jakarta(13, .medium))
                    .foregroundStyle(Theme.roseDeep)
            }

            VStack(spacing: 10) {
                if model.upcomingMoments.isEmpty {
                    Text("No upcoming moments yet. Tap + Add.")
                        .font(.jakarta(14))
                        .foregroundStyle(Theme.muted)
                        .card()
                } else {
                    ForEach(model.upcomingMoments) { upcoming in
                        Button {
                            viewing = upcoming.moment
                        } label: {
                            UpcomingRow(upcoming: upcoming)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }

            if !model.timeline.isEmpty {
                Text("My timeline")
                    .font(.jakarta(17, .bold))
                    .tracking(-0.2)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.timeline) { moment in
                        Button {
                            viewing = moment
                        } label: {
                            TimelineRow(moment: moment, isUpcoming: model.isUpcoming(moment))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Theme.roseLine).frame(width: 2)
                }
                .padding(.leading, 6)
            }
        }
        .sheet(item: $editing) { target in
            MomentEditorView(editing: target)
                .environment(model)
        }
        .sheet(item: $viewing) { moment in
            MomentDetailView(opened: moment)
                .environment(model)
        }
    }
}

private struct UpcomingRow: View {
    let upcoming: UpcomingMoment

    private var moment: Moment { upcoming.moment }

    private var subtitle: Text {
        var text = Text(moment.type.title) + Text(verbatim: " · ")
            + (upcoming.daysUntil == 0 ? Text("Today") : Text("in \(upcoming.daysUntil) days"))
        if moment.repeatsOnKhmerLunarDate { text = text + Text(verbatim: " · ") + Text("Khmer lunar date (sample)") }
        return text
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(upcoming.date, format: .dateTime.day())
                    .font(.jakarta(18, .heavy))
                    .foregroundStyle(Theme.roseDeep)
                Text(upcoming.date, format: .dateTime.month(.abbreviated))
                    .textCase(.uppercase)
                    .font(.jakarta(11, .bold))
                    .foregroundStyle(Theme.roseDark)
            }
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: moment.title).font(.jakarta(15, .bold))
                subtitle
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            SharedBadge(isShared: moment.isShared)
            if let first = moment.media.first {
                MomentThumbnail(media: first, width: 52, height: 52)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct TimelineRow: View {
    let moment: Moment
    let isUpcoming: Bool

    private var meta: Text {
        var text = Text(moment.type.title)
        if moment.repeatsOnKhmerLunarDate { text = text + Text(verbatim: " · ") + Text("repeats on Khmer lunar date (sample)") }
        if isUpcoming { text = text + Text(verbatim: " · ") + Text("upcoming") }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(moment.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                .font(.jakarta(12, .semibold))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 6) {
                Text(verbatim: moment.title).font(.jakarta(15, .bold))
                SharedBadge(isShared: moment.isShared)
            }
            meta
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
            if let first = moment.media.first {
                MomentThumbnail(media: first, width: 220, height: 130, cornerRadius: 14)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(Theme.rose)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                .frame(width: 14, height: 14)
                .offset(x: -23, y: 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A small mark on a Moment shared into the Relationship.
private struct SharedBadge: View {
    let isShared: Bool

    var body: some View {
        if isShared {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.rose)
                .accessibilityLabel(Text("Shared Moment"))
        }
    }
}

#Preview {
    HomeView(showToast: { _ in }, openMe: {})
        .environment(AppModel.preview())
        .background(Theme.background)
}

/// What Trustee told this Lastys ID since the app opened.
private struct NoticesBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(model.notices.enumerated()), id: \.offset) { _, notice in
                Label(notice.message, systemImage: "bell.fill")
                    .font(.jakarta(14, .semibold))
            }
            Button("Dismiss") { model.dismissNotices() }
                .font(.jakarta(13, .semibold))
                .foregroundStyle(Theme.roseDark)
                .frame(minHeight: 44)
        }
        .card()
    }
}

