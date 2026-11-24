import Foundation
import Testing
import LastysCore

@MainActor
struct LuckyDayTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        CalendarTests.date(y, m, d, hour: hour)
    }

    /// Onboarded on 24 Nov 2026 with a birth date of 26 Dec 1996 (TestPhone's).
    private func phone() async -> TestPhone {
        let phone = TestPhone(calendar: CalendarTests.calendar, now: date(2026, 11, 24, hour: 15))
        await phone.onboard()
        return phone
    }

    @Test func myBirthDateIsPrefilledFromMyProfile() async {
        let phone = await phone()

        #expect(phone.model.plannerMyBirthDate == TestPhone.birthDate)
    }

    @Test func suggestionsNeedBothBirthDates() async {
        let phone = await phone()

        #expect(phone.model.luckyDays.isEmpty)
        #expect(phone.model.plannerNeedsPartnerBirthDate)
    }

    @Test func suggestionsAreUpcomingDaysWithAScoreAndReasonsMarkedAsSamples() async {
        let phone = await phone()

        phone.model.plannerPartnerBirthDate = date(1995, 3, 2)
        let days = phone.model.luckyDays

        #expect(days.count == 5)
        #expect(days.allSatisfy { $0.date > date(2026, 11, 24) && $0.date < date(2027, 5, 25) })
        #expect(days.allSatisfy { (0...100).contains($0.score) && !$0.reasons.isEmpty })
        #expect(days.map(\.score) == days.map(\.score).sorted(by: >))
        #expect(phone.model.luckyDaysAreSample)
    }

    @Test func suggestionsChangeWithTheEvent() async {
        let phone = await phone()
        phone.model.plannerPartnerBirthDate = date(1995, 3, 2)

        phone.model.plannerEvent = .wedding
        let wedding = phone.model.luckyDays
        phone.model.plannerEvent = .houseBlessing
        let houseBlessing = phone.model.luckyDays

        #expect(wedding != houseBlessing)
    }

    @Test func suggestionsChangeWithTheBirthDates() async {
        let phone = await phone()
        phone.model.plannerPartnerBirthDate = date(1995, 3, 2)
        let before = phone.model.luckyDays

        phone.model.plannerPartnerBirthDate = date(1998, 8, 19)
        let partnerChanged = phone.model.luckyDays
        phone.model.plannerMyBirthDate = date(1993, 1, 9)
        let mineChanged = phone.model.luckyDays

        #expect(before != partnerChanged)
        #expect(partnerChanged != mineChanged)
    }

    @Test func birthDatesStayOnThePhone() async {
        let phone = await phone()
        let requestsBefore = phone.trusteeRequests

        phone.model.plannerPartnerBirthDate = date(1995, 3, 2)
        phone.model.plannerEvent = .engagement
        _ = phone.model.luckyDays
        #expect(phone.trusteeRequests == requestsBefore)

        phone.relaunch()
        #expect(phone.model.plannerPartnerBirthDate == date(1995, 3, 2))
    }

    @Test func aFormerPartnersBirthDateIsForgottenWhenTheRelationshipEnds() async throws {
        let me = await phone()
        let dara = TestPhone(nearby: me)
        await dara.onboard(as: "Dara")
        try await me.becomePartners(with: dara)
        me.model.plannerPartnerBirthDate = date(1995, 3, 2)

        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()

        #expect(me.model.plannerPartnerBirthDate == nil)
    }

    @Test func thePartnersBirthDateCanBeAddedAndRemoved() async {
        let phone = await phone()

        phone.model.addPlannerPartnerBirthDate()
        #expect(phone.model.plannerPartnerBirthDate != nil)
        phone.model.removePlannerPartnerBirthDate()

        #expect(phone.model.plannerPartnerBirthDate == nil)
        #expect(phone.model.luckyDays.isEmpty)
    }

    @Test func onlyTheFifteenthOfTheWaxingMoonIsCalledAFullMoon() async {
        let phone = await phone()
        phone.model.plannerPartnerBirthDate = date(1995, 3, 2)

        for event in LuckyEvent.allCases {
            phone.model.plannerEvent = event
            for day in phone.model.luckyDays where day.reasons.contains(.fullMoon) {
                phone.model.selectCalendarDay(day.date)
                let lunar = phone.model.selectedCalendarDay.lunarDate
                #expect(lunar.isWaxing && lunar.day == 15)
            }
        }
    }

    @Test func aPublicHolidayCountsAgainstADayAndSaysSo() async throws {
        let phone = await phone()
        phone.model.plannerPartnerBirthDate = date(1995, 3, 2)

        let all = phone.model.luckyDayScores(for: [date(2026, 12, 29), date(2026, 12, 30)])

        let holiday = try #require(all.first)
        #expect(holiday.reasons.contains(.publicHoliday))
        #expect(!all[1].reasons.contains(.publicHoliday))
    }
}
