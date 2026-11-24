import Foundation

/// What a couple is planning a date for.
public enum LuckyEvent: String, CaseIterable, Sendable {
    case engagement
    case wedding
    case houseBlessing = "house-blessing"
}

/// One suggested date, with how good it is and why.
public struct LuckyDay: Equatable, Sendable {
    public let date: Date
    /// 0 to 100.
    public let score: Int
    /// The reasons that raised the score, strongest first.
    public let reasons: [LuckyReason]
}

public enum LuckyReason: Equatable, Sendable {
    case waxingMoon
    case fullMoon
    case silDay
    case goodMonthFor(LuckyEvent)
    case yourBirthWeekday
    case partnersBirthWeekday
    case numbersAgree
    /// Counts against the day: public holidays are busy.
    case publicHoliday
}

/// SAMPLE Lucky Day rules until the cultural advisor's rules arrive. They are made up to show the shape of
/// the planner, not real Khmer astrology, and every result is shown as a sample. Birth dates are used here,
/// on the phone, and nowhere else.
public enum SampleLuckyDays {
    public static let isSample = true
    /// How far ahead the planner looks.
    public static let daysAhead = 180

    /// The best `count` days after `today`, best first (ties: sooner first).
    public static func suggest(
        _ event: LuckyEvent, myBirthDate: Date, partnerBirthDate: Date,
        after today: Date, count: Int = 5, calendar: Calendar
    ) -> [LuckyDay] {
        let days = (1...daysAhead).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let scored = scores(for: days, event: event, myBirthDate: myBirthDate, partnerBirthDate: partnerBirthDate, calendar: calendar)
        return Array(
            scored.sorted { $0.score != $1.score ? $0.score > $1.score : $0.date < $1.date }.prefix(count)
        )
    }

    /// The score of each given day, in the order given.
    public static func scores(
        for days: [Date], event: LuckyEvent, myBirthDate: Date, partnerBirthDate: Date, calendar: Calendar
    ) -> [LuckyDay] {
        let years = Set(days.map { calendar.component(.year, from: $0) })
        let holidays = Set(years.flatMap { CambodianPublicHolidays.days(in: $0, calendar: calendar) }.map(\.date))
        return days.map { day in
            score(day, event: event, myBirthDate: myBirthDate, partnerBirthDate: partnerBirthDate,
                  isHoliday: holidays.contains(calendar.startOfDay(for: day)), calendar: calendar)
        }
    }

    private static func score(
        _ day: Date, event: LuckyEvent, myBirthDate: Date, partnerBirthDate: Date, isHoliday: Bool, calendar: Calendar
    ) -> LuckyDay {
        var points = 40
        var reasons: [(LuckyReason, Int)] = []
        func add(_ reason: LuckyReason, _ value: Int) {
            points += value
            reasons.append((reason, value))
        }

        let lunar = SampleKhmerCalendar.lunarDate(of: day, calendar: calendar)
        if lunar.isWaxing {
            if lunar.day == 15 { add(.fullMoon, 12) } else { add(.waxingMoon, 8) }
        }
        if SampleKhmerCalendar.isSilDay(day, calendar: calendar) {
            add(.silDay, event == .houseBlessing ? 14 : 4)
        }
        if goodMonths[event, default: []].contains(lunar.month) {
            add(.goodMonthFor(event), 10)
        }
        let weekday = calendar.component(.weekday, from: day)
        if weekday == calendar.component(.weekday, from: myBirthDate) { add(.yourBirthWeekday, 9) }
        if weekday == calendar.component(.weekday, from: partnerBirthDate) { add(.partnersBirthWeekday, 9) }
        let birthNumber = [myBirthDate, partnerBirthDate].map { calendar.component(.day, from: $0) }.reduce(0, +)
        if (birthNumber + calendar.component(.day, from: day)) % 9 == 0 { add(.numbersAgree, 7) }
        if isHoliday { add(.publicHoliday, -15) }

        return LuckyDay(
            date: day,
            score: min(max(points, 0), 100),
            reasons: reasons.sorted { $0.1 > $1.1 }.map(\.0)
        )
    }

    /// Sample "good months" per event.
    private static let goodMonths: [LuckyEvent: Set<KhmerLunarMonth>] = [
        .engagement: [.migasir, .bos, .phalkun, .pisakh],
        .wedding: [.meak, .phalkun, .chaet, .pisakh],
        .houseBlessing: [.bos, .meak, .ches, .kadeuk],
    ]
}
