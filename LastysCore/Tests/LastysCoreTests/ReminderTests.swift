import Foundation
import Testing
import LastysCore

@MainActor
struct ReminderTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        MomentsTests.date(y, m, d, hour: hour)
    }

    /// A phone whose clock reads 24 Nov 2026, 15:00 in Phnom Penh.
    private func phone() -> TestPhone {
        TestPhone(calendar: MomentsTests.calendar, now: date(2026, 11, 24, hour: 15))
    }

    @Test func aMomentIsRemindedAt9On7DaysBeforeTheDayBeforeAndTheDay() throws {
        let phone = phone()

        let moment = try #require(phone.model.addMoment(
            MomentDraft(type: .birthday, title: "Mom's birthday", date: date(1970, 12, 10), repeatsOnKhmerLunarDate: false)
        ))

        #expect(phone.reminders.scheduled.count == 6) // this year's three, and next year's
        #expect(Array(phone.reminders.scheduled.prefix(3)) == [
            Reminder(momentID: moment.id, title: "Mom's birthday", fires: date(2026, 12, 3, hour: 9), when: .inDays(7)),
            Reminder(momentID: moment.id, title: "Mom's birthday", fires: date(2026, 12, 9, hour: 9), when: .tomorrow),
            Reminder(momentID: moment.id, title: "Mom's birthday", fires: date(2026, 12, 10, hour: 9), when: .today),
        ])
    }

    @Test func remindersThatWouldAlreadyHaveFiredAreSkipped() throws {
        let phone = phone()

        // In 3 days: the 7-days-before reminder is already in the past.
        try #require(phone.model.addMoment(
            MomentDraft(type: .custom, title: "Exam", date: date(2026, 11, 27), repeatsOnKhmerLunarDate: false)
        ))

        #expect(phone.reminders.scheduled.prefix(2).map(\.when) == [.tomorrow, .today])
        #expect(phone.reminders.scheduled.count == 5) // and next year's three
    }

    @Test func changingAMomentReschedulesItsReminders() throws {
        let phone = phone()
        let moment = try #require(phone.model.addMoment(
            MomentDraft(type: .firstDate, title: "Coffee", date: date(2027, 2, 14), repeatsOnKhmerLunarDate: false)
        ))

        phone.model.updateMoment(
            id: moment.id,
            to: MomentDraft(type: .firstDate, title: "Coffee", date: date(2027, 3, 1), repeatsOnKhmerLunarDate: false)
        )

        #expect(phone.reminders.scheduled.prefix(3).map(\.fires) == [
            date(2027, 2, 22, hour: 9), date(2027, 2, 28, hour: 9), date(2027, 3, 1, hour: 9),
        ])
    }

    @Test func deletingAMomentRemovesItsReminders() throws {
        let phone = phone()
        let moment = try #require(phone.model.addMoment(
            MomentDraft(type: .custom, title: "Exam", date: date(2026, 12, 20), repeatsOnKhmerLunarDate: false)
        ))

        phone.model.deleteMoment(id: moment.id)

        #expect(phone.reminders.scheduled.isEmpty)
    }

    @Test func eachYearTheNextOccurrenceIsRemindedAgain() async throws {
        let phone = phone()
        try #require(phone.model.addMoment(
            MomentDraft(type: .birthday, title: "Mom's birthday", date: date(1970, 11, 26), repeatsOnKhmerLunarDate: false)
        ))
        #expect(phone.reminders.scheduled.map(\.fires).contains(date(2026, 11, 26, hour: 9)))

        phone.clock.advance(days: 3)
        phone.relaunch()
        await phone.model.start()

        let fires = phone.reminders.scheduled.map(\.fires)
        #expect(!fires.contains(date(2026, 11, 26, hour: 9)))
        #expect(fires.contains(date(2027, 11, 26, hour: 9)))
        #expect(fires.contains(date(2028, 11, 26, hour: 9)))
    }

    @Test func onTheDayAfterItsReminderNextYearIsAlreadyBooked() throws {
        let phone = TestPhone(calendar: MomentsTests.calendar, now: date(2026, 12, 10, hour: 10))

        try #require(phone.model.addMoment(
            MomentDraft(type: .birthday, title: "Mom's birthday", date: date(1970, 12, 10), repeatsOnKhmerLunarDate: false)
        ))

        #expect(phone.reminders.scheduled.first?.fires == date(2027, 12, 3, hour: 9))
        #expect(phone.reminders.scheduled.count == 3) // today's have all fired; next year's are booked
    }
}
