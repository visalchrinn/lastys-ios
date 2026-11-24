import Foundation
import Observation

/// Owns all domain-visible state on the phone and exposes the person's intents.
/// Screens render from it and never decide anything themselves.
@MainActor
@Observable
public final class AppModel {
    public private(set) var lastysID: LastysID?
    public private(set) var nickname: String
    public private(set) var relationship: RelationshipStatus = .none
    public private(set) var moments: [Moment]

    @ObservationIgnored private let trustee: TrusteeClient
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    public init(
        trustee: TrusteeClient,
        nickname: String,
        moments: [Moment] = [],
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.trustee = trustee
        self.nickname = nickname
        self.moments = moments
        self.calendar = calendar
        self.now = now
    }

    // MARK: Moments

    /// The start of today on this phone.
    private var today: Date { calendar.startOfDay(for: now()) }

    /// The next three Moments from today, soonest first.
    public var upcomingMoments: [Moment] {
        Array(moments.filter(isUpcoming).sorted { $0.date < $1.date }.prefix(3))
    }

    /// Every Moment, newest first.
    public var timeline: [Moment] {
        moments.sorted { $0.date > $1.date }
    }

    public func isUpcoming(_ moment: Moment) -> Bool {
        moment.date >= today
    }

    /// Whole days from today until the Moment; 0 means today.
    public func daysUntil(_ moment: Moment) -> Int {
        calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: moment.date)).day ?? 0
    }

    // MARK: Lastys ID

    /// Makes sure this phone has a Lastys ID and loads its current status from Trustee.
    public func start() async {
        do {
            if lastysID == nil {
                lastysID = try await trustee.createLastysID(nickname: nickname)
            }
            relationship = try await trustee.relationshipStatus()
        } catch {
            // Errors surface in later slices; for now the last known state stays on screen.
        }
    }
}
