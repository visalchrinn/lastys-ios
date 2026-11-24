import Foundation

/// A local notification about an upcoming Moment.
public struct Reminder: Equatable, Sendable {
    public enum When: Equatable, Sendable {
        case inDays(Int)
        case tomorrow
        case today
    }


    /// Before the Moment: 7 days, 1 day, and on the day.
    public static let daysBefore = [7, 1, 0]
    /// Reminders arrive at this hour of the day.
    public static let hour = 9

    public let momentID: UUID
    public let title: String
    public let fires: Date
    public let when: When

    public init(momentID: UUID, title: String, fires: Date, when: When) {
        self.momentID = momentID
        self.title = title
        self.fires = fires
        self.when = when
    }
}

/// Delivers reminders on this phone. Given the full set each time, it drops whatever isn't in it,
/// so a changed or deleted Moment never leaves a stale reminder behind.
public protocol ReminderScheduler: Sendable {
    func replaceAll(with reminders: [Reminder])
}

/// SAMPLE Khmer lunar dates until the cultural advisor's rules arrive: each year after the original,
/// the date moves by the whole number of synodic months nearest that many solar years, with no real
/// leap-month rules. It stays within about two weeks of the solar anniversary, however long ago.
public enum SampleKhmerLunarCalendar {
    static let synodicMonth: TimeInterval = 29.530_588 * 86_400
    static let lunarMonthsPerYear = 365.242_19 / 29.530_588

    /// The first day on or after `day` that falls on the same sample lunar date as `original`.
    public static func nextOccurrence(of original: Date, onOrAfter day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: original)
        var years = 0.0
        while true {
            let months = (years * lunarMonthsPerYear).rounded()
            let candidate = calendar.startOfDay(for: start.addingTimeInterval(months * synodicMonth))
            if candidate >= day { return candidate }
            years += 1
        }
    }
}

extension Reminder.When {
    init(daysBefore days: Int) {
        switch days {
        case 0: self = .today
        case 1: self = .tomorrow
        default: self = .inDays(days)
        }
    }
}
