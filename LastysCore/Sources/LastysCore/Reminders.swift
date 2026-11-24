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


extension Reminder.When {
    init(daysBefore days: Int) {
        switch days {
        case 0: self = .today
        case 1: self = .tomorrow
        default: self = .inDays(days)
        }
    }
}
