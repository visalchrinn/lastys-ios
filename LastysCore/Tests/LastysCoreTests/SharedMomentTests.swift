import Foundation
import Testing
import LastysCore

@MainActor
struct SharedMomentTests {
    private let firstDate = MomentDraft(
        type: .firstDate, title: "Our first date", date: Date().addingTimeInterval(20 * 86_400), repeatsOnKhmerLunarDate: false
    )
    private let diary = MomentDraft(
        type: .custom, title: "My secret diary day", date: Date().addingTimeInterval(30 * 86_400), repeatsOnKhmerLunarDate: false
    )

    private func partners() async throws -> (dara: TestPhone, me: TestPhone) {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard()
        try await me.becomePartners(with: dara)
        // Linking gives me "The day we linked" and "Our 1st anniversary" (RelationshipRequestTests).
        // These tests are about other Moments, so they start without them.
        for moment in me.model.moments { me.model.deleteMoment(id: moment.id) }
        await me.model.syncSharedMoments()
        await dara.model.start()
        return (dara, me)
    }

    private func titles(_ phone: TestPhone) -> [String] {
        phone.model.timeline.map(\.title).sorted()
    }

    @Test func onlyPartnersCanShareAMoment() async throws {
        let single = TestPhone()
        await single.onboard()
        let moment = try #require(single.model.addMoment(firstDate))

        #expect(!single.model.canShare(moment))
    }

    @Test func thePartnerSeesASharedMomentButNeverAPersonalOne() async throws {
        let (dara, me) = try await partners()
        let shared = try #require(me.model.addMoment(firstDate))
        me.model.addMoment(diary)
        #expect(me.model.canShare(shared))

        await me.model.share(shared.id)
        await dara.model.start()

        #expect(titles(dara) == ["Our first date"])
        let received = try #require(dara.model.timeline.first)
        #expect(received.isShared)
        #expect(!dara.model.isMine(received))
        #expect(!me.trusteeRequests.contains { $0.contains("My secret diary day") })
    }

    @Test func changingOrDeletingASharedMomentReachesThePartner() async throws {
        let (dara, me) = try await partners()
        let shared = try #require(me.model.addMoment(firstDate))
        await me.model.share(shared.id)

        var renamed = firstDate
        renamed.title = "Coffee at Brown"
        me.model.updateMoment(id: shared.id, to: renamed)
        await me.model.syncSharedMoments()
        await dara.model.start()
        #expect(titles(dara) == ["Coffee at Brown"])

        me.model.deleteMoment(id: shared.id)
        await me.model.syncSharedMoments()
        await dara.model.start()
        #expect(titles(dara).isEmpty)
    }

    @Test func aSharedMomentGetsItsRemindersOnBothPhones() async throws {
        let (dara, me) = try await partners()
        let shared = try #require(me.model.addMoment(firstDate))

        await me.model.share(shared.id)
        await dara.model.start()

        #expect(dara.reminders.scheduled.contains { $0.title == "Our first date" })
    }

    @Test func afterTheEndEachFormerPartnerDecidesAboutTheirOwnCopyIndependently() async throws {
        let (dara, me) = try await partners()
        let mine = try #require(me.model.addMoment(firstDate))
        await me.model.share(mine.id)
        let darasMoment = try #require(dara.model.addMoment(
            MomentDraft(type: .birthday, title: "Dara's birthday", date: Date().addingTimeInterval(40 * 86_400), repeatsOnKhmerLunarDate: false)
        ))
        await dara.model.share(darasMoment.id)
        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()

        // Each decides about everything shared in the Relationship: their own and the other's.
        #expect(me.model.moments.allSatisfy { !$0.isShared })
        #expect(me.model.formerSharedMoments.map(\.title).sorted() == ["Dara's birthday", "Our first date"])
        #expect(dara.model.formerSharedMoments.map(\.title).sorted() == ["Dara's birthday", "Our first date"])
        #expect(me.model.showsFormerSharedMoments)

        await dara.model.deleteFormerSharedMoments()
        await me.model.keepFormerSharedMoments()

        #expect(dara.model.formerSharedMoments.isEmpty)
        #expect(titles(dara).isEmpty)
        #expect(titles(me) == ["Dara's birthday", "Our first date"])
        #expect(me.model.formerSharedMoments.isEmpty)
        #expect(!me.model.showsFormerSharedMoments)
    }

    @Test func formerSharedMomentsExportAsACalendarFile() async throws {
        let (dara, me) = try await partners()
        let mine = try #require(me.model.addMoment(firstDate))
        await me.model.share(mine.id)
        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await dara.model.start()

        let file = dara.model.formerSharedMomentsCalendar()

        #expect(file.hasPrefix("BEGIN:VCALENDAR"))
        #expect(file.contains("SUMMARY:Our first date"))
        #expect(file.contains("RRULE:FREQ=YEARLY"))
        #expect(file.hasSuffix("END:VCALENDAR\r\n"))
    }

    @Test func someoneWhoOnlySharedStillDecidesAboutTheirOwnSharedMoments() async throws {
        let (dara, me) = try await partners()
        let mine = try #require(me.model.addMoment(firstDate))
        await me.model.share(mine.id)
        await me.model.perform(.sendEndRequest)
        await dara.model.start()
        await dara.model.perform(.agreeToEndRequest)
        await me.model.start()

        #expect(me.model.formerSharedMoments.map(\.title) == ["Our first date"])

        await me.model.deleteFormerSharedMoments()

        #expect(me.model.moments.isEmpty)
        #expect(dara.model.formerSharedMoments.map(\.title) == ["Our first date"])
    }

    @Test func quickHideKeepsSharedMomentsOffTheLockScreenToo() async throws {
        let (dara, me) = try await partners()
        let shared = try #require(me.model.addMoment(firstDate))
        await me.model.share(shared.id)
        me.model.addMoment(diary)
        await dara.model.start()

        me.model.setQuickHide(true)
        dara.model.setQuickHide(true)

        #expect(me.reminders.scheduled.allSatisfy { $0.title == "My secret diary day" })
        #expect(dara.reminders.scheduled.isEmpty)
    }

    @Test func onlyItsOwnerCanAddPhotosToASharedMoment() async throws {
        let (dara, me) = try await partners()
        let shared = try #require(me.model.addMoment(firstDate))
        await me.model.share(shared.id)
        await dara.model.start()
        let darasCopy = try #require(dara.model.timeline.first)

        #expect(!dara.model.canAddMedia(to: darasCopy))
        #expect(dara.model.addMedia([MomentMedia(kind: .photo, fileName: "mine.jpg")], to: darasCopy.id) == 0)
        #expect(dara.model.timeline.first?.media.isEmpty == true)
    }

    @Test func sharingWithoutInternetSaysSoAndSharesNothing() async throws {
        let (dara, me) = try await partners()
        let moment = try #require(me.model.addMoment(firstDate))
        me.isOnline = false

        await me.model.share(moment.id)

        #expect(me.model.sharingProblem == .needsInternet)
        #expect(me.model.moments.allSatisfy { !$0.isShared })
        await dara.model.start()
        #expect(titles(dara).isEmpty)
    }

    @Test func aLongTitleIsFoldedIntoCalendarLinesOf75BytesAtMost() {
        let moment = Moment(
            type: .birthday,
            title: String(repeating: "ខួបកំណើតម្ដាយ ", count: 8) + "\r\nnext line",
            date: Date(timeIntervalSince1970: 1_795_928_415)
        )

        let file = MomentCalendarFile.make([moment], calendar: Calendar(identifier: .gregorian), now: Date())

        let lines = file.components(separatedBy: "\r\n").dropLast()
        #expect(lines.allSatisfy { $0.utf8.count <= 75 })
        #expect(lines.contains { $0.hasPrefix(" ") })
        #expect(!file.replacingOccurrences(of: "\r\n", with: "").contains("\r"))
    }
}
