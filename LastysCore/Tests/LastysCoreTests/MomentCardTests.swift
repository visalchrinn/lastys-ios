import Foundation
import Testing
import LastysCore

@MainActor
struct MomentCardTests {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    /// A single phone whose clock reads 24 Nov 2026, 15:00 in Phnom Penh.
    private func phone() async -> TestPhone {
        let phone = TestPhone(calendar: Self.calendar, now: Self.date(2026, 11, 24, hour: 15))
        await phone.onboard(as: "Srey Pich")
        return phone
    }

    private let photos = [MomentMedia(kind: .photo, fileName: "cake.jpg"), MomentMedia(kind: .photo, fileName: "candles.jpg")]

    private func birthday(on date: Date, media: [MomentMedia] = [], place: String = "Home, Takhmao") -> MomentDraft {
        MomentDraft(
            type: .birthday, title: "Mom's birthday", date: date, repeatsOnKhmerLunarDate: false,
            media: media, place: place, note: "Order the cake by Monday."
        )
    }

    @Test func aCardShowsTheTypeTitleDatePlaceAndTheChosenPhoto() async throws {
        let phone = await phone()
        let moment = try #require(phone.model.addMoment(birthday(on: Self.date(2026, 12, 6), media: photos)))

        let card = try #require(phone.model.momentCard(for: moment.id, photoIndex: 1, options: MomentCardOptions()))

        #expect(card.type == .birthday)
        #expect(card.title == "Mom's birthday")
        #expect(card.date == Self.date(2026, 12, 6))
        #expect(card.place == "Home, Takhmao")
        #expect(card.photo == photos[1])
        #expect(card.countdown == .daysToGo(12))
        #expect(card.names == nil)
        #expect(card.style == .rose)
    }

    @Test func theCountdownSaysTodayOrHowLongAgo() async throws {
        let phone = await phone()
        let today = try #require(phone.model.addMoment(birthday(on: Self.date(2026, 11, 24))))
        let past = try #require(phone.model.addMoment(birthday(on: Self.date(2026, 11, 21))))

        #expect(phone.model.momentCard(for: today.id, options: MomentCardOptions())?.countdown == .today)
        #expect(phone.model.momentCard(for: past.id, options: MomentCardOptions())?.countdown == .daysAgo(3))
    }

    @Test func eachSwitchIsOfferedOnlyWhenThereIsSomethingToShow() async throws {
        let phone = await phone()
        let bare = try #require(phone.model.addMoment(birthday(on: Self.date(2026, 12, 6), place: "")))

        let card = try #require(phone.model.momentCard(for: bare.id, options: MomentCardOptions()))

        #expect(!card.offersPhoto)
        #expect(!card.offersPlace)
        #expect(!card.offersNames)
        #expect(card.photo == nil)
        #expect(card.place == nil)
    }

    @Test func turningASwitchOffTakesThatPieceOffTheCard() async throws {
        let phone = await phone()
        let moment = try #require(phone.model.addMoment(birthday(on: Self.date(2026, 12, 6), media: photos)))
        var options = MomentCardOptions()
        options.showsPhoto = false
        options.showsPlace = false
        options.showsCountdown = false
        options.style = .dark

        let card = try #require(phone.model.momentCard(for: moment.id, options: options))

        #expect(card.offersPhoto && card.offersPlace)
        #expect(card.photo == nil)
        #expect(card.place == nil)
        #expect(card.countdown == nil)
        #expect(card.style == .dark)
    }

    @Test func aPhotoNumberPastTheEndFallsBackToTheLastPhoto() async throws {
        let phone = await phone()
        let moment = try #require(phone.model.addMoment(birthday(on: Self.date(2026, 12, 6), media: photos)))

        #expect(phone.model.momentCard(for: moment.id, photoIndex: 9, options: MomentCardOptions())?.photo == photos[1])
    }

    @Test func theNoteNeverGoesOnTheCard() async throws {
        let phone = await phone()
        let moment = try #require(phone.model.addMoment(birthday(on: Self.date(2026, 12, 6), media: photos)))

        let card = try #require(phone.model.momentCard(for: moment.id, options: MomentCardOptions()))

        #expect(!String(describing: card).contains("Order the cake"))
    }

    @Test func whileTakenTheCardCanCarryBothNicknames() async throws {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard(as: "Srey Pich")
        try await me.becomePartners(with: dara)
        let moment = try #require(me.model.addMoment(birthday(on: Date().addingTimeInterval(10 * 86_400))))

        let card = try #require(me.model.momentCard(for: moment.id, options: MomentCardOptions()))
        var withoutNames = MomentCardOptions()
        withoutNames.showsNames = false

        #expect(card.offersNames)
        #expect(card.names == MomentCard.Names(mine: "Srey Pich", partner: "Dara"))
        #expect(me.model.momentCard(for: moment.id, options: withoutNames)?.names == nil)
    }

    @Test func onlyAMomentsOwnerCanMakeItsCard() async throws {
        let dara = TestPhone()
        await dara.onboard(as: "Dara")
        let me = TestPhone(nearby: dara)
        await me.onboard()
        try await me.becomePartners(with: dara)
        let shared = try #require(me.model.addMoment(birthday(on: Date().addingTimeInterval(10 * 86_400))))
        await me.model.share(shared.id)
        await dara.model.start()
        let darasCopy = try #require(dara.model.timeline.first { $0.id == shared.id })

        #expect(me.model.canMakeMomentCard(for: shared))
        #expect(!dara.model.canMakeMomentCard(for: darasCopy))
        #expect(dara.model.momentCard(for: darasCopy.id, options: MomentCardOptions()) == nil)
    }
}
