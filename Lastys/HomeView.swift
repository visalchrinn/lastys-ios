import SwiftUI

struct Moment: Identifiable {
    let id = UUID()
    let type: String
    let title: String
    let date: Date
    let lunar: Bool
}

enum SampleData {
    static func moments(relativeTo today: Date = Date()) -> [Moment] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: today)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: start) ?? start }
        return [
            Moment(type: "Birthday", title: "Mom's birthday", date: day(5), lunar: false),
            Moment(type: "Custom", title: "Graduation day", date: day(-156), lunar: false),
            Moment(type: "Custom", title: "Ancestor ceremony", date: day(27), lunar: true),
        ]
    }
}

struct HomeView: View {
    var showToast: (String) -> Void
    var openMe: () -> Void

    var nickname: String = "Srey Pich"
    @State private var moments: [Moment] = SampleData.moments()

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusCard
                quickActions
                safetyTips
                momentsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .foregroundStyle(Theme.ink)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Wordmark()
                Text("\(Self.headerDate.string(from: Date())) · Khmer lunar date (sample)")
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button(action: openMe) {
                Text(String(nickname.prefix(1)).uppercased())
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

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.green)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.greenTint))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verified Single")
                        .font(.jakarta(18, .heavy))
                    Text("Not linked to anyone")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            Button("Share my Verified Single card") {
                showToast("Verified Single card is coming soon")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .card(padding: 20)
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            actionTile(icon: "qrcode", title: "Show my QR", dark: false) {
                showToast("Your QR code opens here")
            }
            actionTile(icon: "qrcode.viewfinder", title: "Scan a QR", dark: true) {
                showToast("The camera scanner opens here")
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

    private var upcoming: [Moment] {
        moments.filter { $0.date >= today }.sorted { $0.date < $1.date }.prefix(3).map { $0 }
    }

    private var timeline: [Moment] {
        moments.sorted { $0.date > $1.date }
    }

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming moments")
                    .font(.jakarta(17, .bold))
                    .tracking(-0.2)
                Spacer()
                Button("+ Add") {
                    showToast("Adding moments is coming soon")
                }
                .font(.jakarta(14, .semibold))
                .foregroundStyle(Theme.roseDark)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                if upcoming.isEmpty {
                    Text("No upcoming moments yet. Tap + Add.")
                        .font(.jakarta(14))
                        .foregroundStyle(Theme.muted)
                        .card()
                } else {
                    ForEach(upcoming) { moment in
                        UpcomingRow(moment: moment, today: today)
                    }
                }
            }

            Text("My timeline")
                .font(.jakarta(17, .bold))
                .tracking(-0.2)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(timeline) { moment in
                    TimelineRow(moment: moment, isUpcoming: moment.date >= today)
                }
            }
            .padding(.leading, 16)
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.roseLine).frame(width: 2)
            }
            .padding(.leading, 6)
        }
    }

    static let headerDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE d MMM yyyy"
        return f
    }()
}

private struct UpcomingRow: View {
    let moment: Moment
    let today: Date

    private static let month: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM"
        return f
    }()

    private var subtitle: String {
        let days = Calendar.current.dateComponents([.day], from: today, to: moment.date).day ?? 0
        var s = moment.type + " · " + (days == 0 ? "Today" : "in \(days) days")
        if moment.lunar { s += " · Khmer lunar date" }
        return s
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(Calendar.current.component(.day, from: moment.date))")
                    .font(.jakarta(18, .heavy))
                    .foregroundStyle(Theme.roseDeep)
                Text(Self.month.string(from: moment.date).uppercased())
                    .font(.jakarta(11, .bold))
                    .foregroundStyle(Theme.roseDark)
            }
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))

            VStack(alignment: .leading, spacing: 3) {
                Text(moment.title).font(.jakarta(15, .bold))
                Text(subtitle)
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
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

    private var meta: String {
        var s = moment.type
        if moment.lunar { s += " · repeats on Khmer lunar date" }
        if isUpcoming { s += " · upcoming" }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(HomeView.headerDate.string(from: moment.date))
                .font(.jakarta(12, .semibold))
                .foregroundStyle(Theme.muted)
            Text(moment.title).font(.jakarta(15, .bold))
            Text(meta)
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
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
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView(showToast: { _ in }, openMe: {})
        .background(Theme.background)
}
