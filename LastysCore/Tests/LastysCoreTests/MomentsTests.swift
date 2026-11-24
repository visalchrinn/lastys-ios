import Foundation
import Testing
@testable import LastysCore

@MainActor
struct MomentsTests {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        return c
    }()

    private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func model(moments: [Moment], now: Date) -> AppModel {
        AppModel(
            phoneKey: SoftwarePhoneKey(),
            trustee: FakeTrustee().client(forPhone: "phone-a"),
            store: InMemoryPhoneStore(),
            connectivity: SwitchableConnectivity(),
            moments: moments,
            calendar: Self.calendar,
            now: { now }
        )
    }

    @Test func upcomingMomentsAreTheNextThreeFromTodaySoonestFirst() {
        let model = model(
            moments: [
                Moment(type: "Custom", title: "Graduation day", date: Self.date(2026, 6, 21)),
                Moment(type: "Custom", title: "Ancestor ceremony", date: Self.date(2026, 12, 21), repeatsOnKhmerLunarDate: true),
                Moment(type: "Birthday", title: "Mom's birthday", date: Self.date(2026, 11, 29)),
                Moment(type: "First date", title: "Coffee", date: Self.date(2027, 2, 14)),
                Moment(type: "Anniversary", title: "Today", date: Self.date(2026, 11, 24)),
            ],
            now: Self.date(2026, 11, 24, hour: 15)
        )

        #expect(model.upcomingMoments.map(\.title) == ["Today", "Mom's birthday", "Ancestor ceremony"])
    }

    @Test func theTimelineShowsEveryMomentNewestFirst() {
        let model = model(
            moments: [
                Moment(type: "Birthday", title: "Mom's birthday", date: Self.date(2026, 11, 29)),
                Moment(type: "Custom", title: "Graduation day", date: Self.date(2026, 6, 21)),
                Moment(type: "Custom", title: "Ancestor ceremony", date: Self.date(2026, 12, 21)),
            ],
            now: Self.date(2026, 11, 24)
        )

        #expect(model.timeline.map(\.title) == ["Ancestor ceremony", "Mom's birthday", "Graduation day"])
    }

    @Test func aMomentIsUpcomingFromTheStartOfItsDay() {
        let today = Moment(type: "Birthday", title: "Today", date: Self.date(2026, 11, 24))
        let yesterday = Moment(type: "Birthday", title: "Yesterday", date: Self.date(2026, 11, 23))
        let model = model(moments: [today, yesterday], now: Self.date(2026, 11, 24, hour: 23))

        #expect(model.isUpcoming(today))
        #expect(!model.isUpcoming(yesterday))
        #expect(model.daysUntil(today) == 0)
    }
}
