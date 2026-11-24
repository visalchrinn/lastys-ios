import Foundation
import Testing
import LastysCore

@MainActor
struct CalendarTests {
    /// Phnom Penh, weeks starting on Monday.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        c.firstWeekday = 2
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    /// A phone whose clock reads Tuesday 24 Nov 2026, 15:00 in Phnom Penh.
    private func phone() -> TestPhone {
        TestPhone(calendar: Self.calendar, now: Self.date(2026, 11, 24, hour: 15))
    }

    static func days(_ list: [(Int, Int, Int)]) -> [Date] {
        list.map { date($0.0, $0.1, $0.2) }
    }

    /// Sub-Decree No. 167 (2025): 21 days.
    static let official2026 = days([
        (2026, 1, 1), (2026, 1, 7), (2026, 3, 8), (2026, 4, 14), (2026, 4, 15), (2026, 4, 16),
        (2026, 5, 1), (2026, 5, 5), (2026, 5, 14), (2026, 6, 18), (2026, 9, 24),
        (2026, 10, 10), (2026, 10, 11), (2026, 10, 12), (2026, 10, 15), (2026, 10, 29),
        (2026, 11, 9), (2026, 11, 23), (2026, 11, 24), (2026, 11, 25), (2026, 12, 29),
    ])

    /// Sub-Decree No. 198 (16 Sept 2026): 22 days.
    static let official2027 = days([
        (2027, 1, 1), (2027, 1, 7), (2027, 3, 8), (2027, 4, 14), (2027, 4, 15), (2027, 4, 16),
        (2027, 5, 1), (2027, 5, 14), (2027, 5, 20), (2027, 5, 24), (2027, 6, 18), (2027, 9, 24),
        (2027, 9, 29), (2027, 9, 30), (2027, 10, 1), (2027, 10, 15), (2027, 10, 29),
        (2027, 11, 9), (2027, 11, 12), (2027, 11, 13), (2027, 11, 14), (2027, 12, 29),
    ])

    @Test func publicHolidaysMatchTheOfficial2026And2027Lists() {
        let phone = TestPhone(calendar: Self.calendar, now: Self.date(2026, 1, 1))

        let all = phone.model.upcomingPublicHolidays(limit: 100).map(\.date)

        #expect(all == Self.official2026 + Self.official2027)
        #expect(phone.model.publicHolidaysKnownThrough == 2027)
    }

    @Test func theMonthGridMarksTodayAndTheSelectedDayDistinctly() throws {
        let phone = phone()

        phone.model.selectCalendarDay(Self.date(2026, 11, 29))
        let month = phone.model.calendarMonth

        #expect(month.firstDay == Self.date(2026, 11, 1))
        let days = month.days
        // November 2026 starts on a Sunday: the Monday-first grid opens on 26 October.
        #expect(days.first?.date == Self.date(2026, 10, 26))
        #expect(days.count % 7 == 0)
        #expect(days.filter(\.isToday).map(\.date) == [Self.date(2026, 11, 24)])
        #expect(days.filter(\.isSelected).map(\.date) == [Self.date(2026, 11, 29)])
        #expect(!days.first!.isInMonth)
    }

    @Test func monthsCanBeNavigated() {
        let phone = phone()

        phone.model.showNextCalendarMonth()
        phone.model.showNextCalendarMonth()
        #expect(phone.model.calendarMonth.firstDay == Self.date(2027, 1, 1))

        phone.model.showPreviousCalendarMonth()
        #expect(phone.model.calendarMonth.firstDay == Self.date(2026, 12, 1))
    }

    @Test func aDayShowsItsHolidayItsMomentsAndASampleKhmerLunarDate() throws {
        let phone = phone()
        phone.model.addMoment(MomentDraft(type: .birthday, title: "Mom's birthday", date: Self.date(1970, 11, 23), repeatsOnKhmerLunarDate: false))

        phone.model.selectCalendarDay(Self.date(2026, 11, 23))
        let day = phone.model.selectedCalendarDay

        #expect(day.holiday?.name == .waterFestival)
        #expect(day.moments.map(\.title) == ["Mom's birthday"])
        #expect(day.lunarDate.isSample)
        #expect((1...15).contains(day.lunarDate.day))
        let gridDay = try #require(phone.model.calendarMonth.days.first { $0.date == Self.date(2026, 11, 23) })
        #expect(gridDay.hasMoments)
        #expect(gridDay.holiday != nil)
    }

    @Test func aMonthHasAboutFourSampleSilDays() {
        let phone = phone()

        let silDays = phone.model.calendarMonth.days.filter { $0.isInMonth && $0.isSilDay }

        #expect((3...5).contains(silDays.count))
        #expect(phone.model.silDaysAreSample)
    }

    @Test func upcomingPublicHolidaysStartFromToday() {
        let phone = phone()

        let upcoming = phone.model.upcomingPublicHolidays(limit: 4)

        #expect(upcoming.map(\.date) == Self.days([(2026, 11, 24), (2026, 11, 25), (2026, 12, 29), (2027, 1, 1)]))
    }

    @Test func theSampleLunarDateFollowsTheMoonAtKnownFestivals() {
        let phone = phone()

        // The Water Festival is held at Kadeuk's full moon; Visak Bochea at Pisakh's.
        phone.model.selectCalendarDay(Self.date(2026, 11, 24))
        let waterFestival = phone.model.selectedCalendarDay.lunarDate
        phone.model.selectCalendarDay(Self.date(2027, 5, 20))
        let visakBochea = phone.model.selectedCalendarDay.lunarDate

        #expect(waterFestival.month == .kadeuk)
        #expect(waterFestival.isWaxing && (14...15).contains(waterFestival.day))
        #expect(visakBochea.month == .pisakh)
        #expect(visakBochea.isWaxing && (14...15).contains(visakBochea.day))
    }

    @Test func homeShowsTodaysSampleKhmerLunarDate() {
        let phone = phone()

        phone.model.selectCalendarDay(Self.date(2026, 11, 24))
        #expect(phone.model.todayLunarDate == phone.model.selectedCalendarDay.lunarDate)
        #expect(phone.model.todayLunarDate.isSample)
    }

    @Test func aDayWithNoHolidayMomentOrSilDayHasNothingOnIt() throws {
        let phone = phone()
        let plain = try #require(phone.model.calendarMonth.days.first { $0.isInMonth && $0.holiday == nil && !$0.isSilDay && !$0.hasMoments })
        let sil = try #require(phone.model.calendarMonth.days.first { $0.isInMonth && $0.holiday == nil && $0.isSilDay && !$0.hasMoments })

        phone.model.selectCalendarDay(plain.date)
        #expect(phone.model.selectedCalendarDay.hasNothingOn)
        phone.model.selectCalendarDay(sil.date)
        #expect(!phone.model.selectedCalendarDay.hasNothingOn)
    }
}
