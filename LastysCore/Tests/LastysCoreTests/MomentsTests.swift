import Foundation
import Testing
import LastysCore

@MainActor
struct MomentsTests {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Phnom_Penh")!
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    /// A phone whose clock reads 24 Nov 2026, 15:00 in Phnom Penh.
    private func phone() -> TestPhone {
        TestPhone(calendar: Self.calendar, now: Self.date(2026, 11, 24, hour: 15))
    }

    private func draft(
        _ title: String, _ date: Date, type: MomentType = .custom, lunar: Bool = false
    ) -> MomentDraft {
        MomentDraft(type: type, title: title, date: date, repeatsOnKhmerLunarDate: lunar)
    }

    @Test func aMomentKeepsItsPlaceNoteAndAtMostSixPhotos() throws {
        let phone = phone()
        let photos = (0..<8).map { MomentMedia(kind: .photo, fileName: "\($0).jpg") }
        let moment = try #require(phone.model.addMoment(MomentDraft(
            type: .firstDate, title: "Coffee", date: Self.date(2026, 12, 2), repeatsOnKhmerLunarDate: false,
            media: photos, place: "  Riverside ", note: " Sunny day "
        )))
        #expect(moment.media.count == Moment.maxMedia)
        #expect(moment.place == "Riverside")
        #expect(moment.note == "Sunny day")
        #expect(phone.model.mediaFileNamesInUse == Set(photos.prefix(6).map(\.fileName)))
    }

    @Test func aMomentsDetailsShowItsNextOccurrenceAndFollowEdits() throws {
        let phone = phone()
        let moment = try #require(phone.model.addMoment(draft("Mom's birthday", Self.date(1970, 11, 29), type: .birthday)))
        #expect(phone.model.nextTime(for: moment).daysUntil == 5)
        phone.model.updateMoment(id: moment.id, to: draft("Mum's birthday", Self.date(1970, 11, 29), type: .birthday))
        #expect(phone.model.currentMoment(id: moment.id)?.title == "Mum's birthday")
        phone.model.deleteMoment(id: moment.id)
        #expect(phone.model.currentMoment(id: moment.id) == nil)
    }

    @Test func aMomentSavedWithOnePhotoStillLoads() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","type":"birthday","title":"Mom","date":0,"repeatsOnKhmerLunarDate":false,
         "media":{"kind":"photo","fileName":"a.jpg"},"isShared":false}
        """
        let moment = try JSONDecoder().decode(Moment.self, from: Data(json.utf8))
        #expect(moment.media == [MomentMedia(kind: .photo, fileName: "a.jpg")])
        #expect(moment.place == "")
        #expect(moment.note == "")
    }

    @Test func aMomentNeedsATitle() {
        let phone = phone()

        #expect(!phone.model.canSave(draft("  ", Self.date(2026, 12, 1))))
        #expect(phone.model.addMoment(draft("  ", Self.date(2026, 12, 1))) == nil)
        #expect(phone.model.moments.isEmpty)
    }

    @Test func upcomingShowsTheNextThreeOccurrencesFromTodayNearestFirst() {
        let phone = phone()
        for (title, date) in [
            ("Graduation day", Self.date(2026, 6, 21)),
            ("Mom's birthday", Self.date(1970, 11, 29)),
            ("Coffee", Self.date(2027, 2, 14)),
            ("Started today", Self.date(2025, 11, 24)),
            ("New year party", Self.date(2026, 12, 31)),
        ] {
            phone.model.addMoment(draft(title, date))
        }

        let upcoming = phone.model.upcomingMoments

        #expect(upcoming.map(\.moment.title) == ["Started today", "Mom's birthday", "New year party"])
        #expect(upcoming.map(\.date) == [Self.date(2026, 11, 24), Self.date(2026, 11, 29), Self.date(2026, 12, 31)])
        #expect(upcoming.map(\.daysUntil) == [0, 5, 37])
    }

    @Test func aPastMomentComesBackOnItsDateNextYear() {
        let phone = phone()

        phone.model.addMoment(draft("Graduation day", Self.date(2026, 6, 21)))

        #expect(phone.model.upcomingMoments.first?.date == Self.date(2027, 6, 21))
    }

    @Test func aMomentOnTheKhmerLunarDateComesBackAfterWholeLunarYears() {
        let phone = phone()

        // Sample lunar mapping: 12 lunar months (about 354 days) after 10 Dec 2025.
        phone.model.addMoment(draft("Ancestor ceremony", Self.date(2025, 12, 10), lunar: true))

        #expect(phone.model.upcomingMoments.first?.date == Self.date(2026, 11, 29))
    }

    @Test func theTimelineShowsEveryMomentOnItsOwnDateNewestFirst() {
        let phone = phone()
        phone.model.addMoment(draft("Mom's birthday", Self.date(2026, 11, 29)))
        phone.model.addMoment(draft("Graduation day", Self.date(2026, 6, 21)))
        phone.model.addMoment(draft("Ancestor ceremony", Self.date(2026, 12, 21)))

        #expect(phone.model.timeline.map(\.title) == ["Ancestor ceremony", "Mom's birthday", "Graduation day"])
    }

    @Test func editingAndDeletingAMomentChangesWhatHomeShows() throws {
        let phone = phone()
        let moment = try #require(phone.model.addMoment(draft("Coffee", Self.date(2027, 2, 14), type: .firstDate)))

        phone.model.updateMoment(id: moment.id, to: draft("First coffee", Self.date(2026, 12, 2), type: .firstDate))
        #expect(phone.model.upcomingMoments.map(\.moment.title) == ["First coffee"])
        #expect(phone.model.upcomingMoments.first?.date == Self.date(2026, 12, 2))

        phone.model.deleteMoment(id: moment.id)
        #expect(phone.model.upcomingMoments.isEmpty)
        #expect(phone.model.timeline.isEmpty)
    }

    @Test func photosAddedFromDetailsGoAfterTheOnesAlreadyThereInOrder() throws {
        let phone = phone()
        let moment = try #require(phone.model.addMoment(MomentDraft(
            type: .birthday, title: "Mom's birthday", date: Self.date(2026, 12, 2), repeatsOnKhmerLunarDate: false,
            media: [MomentMedia(kind: .photo, fileName: "cake.jpg")]
        )))
        #expect(phone.model.canAddMedia(to: moment))

        let added = phone.model.addMedia(
            [MomentMedia(kind: .photo, fileName: "candles.jpg"), MomentMedia(kind: .video, fileName: "song.mov")],
            to: moment.id
        )

        #expect(added == 2)
        #expect(phone.model.currentMoment(id: moment.id)?.media.map(\.fileName) == ["cake.jpg", "candles.jpg", "song.mov"])
        #expect(phone.model.mediaFileNamesInUse.contains("song.mov"))
    }

    @Test func addingMorePhotosFromDetailsThanFitKeepsSixInAll() throws {
        let phone = phone()
        let five = (0..<5).map { MomentMedia(kind: .photo, fileName: "\($0).jpg") }
        let moment = try #require(phone.model.addMoment(MomentDraft(
            type: .custom, title: "Trip", date: Self.date(2026, 12, 2), repeatsOnKhmerLunarDate: false, media: five
        )))

        let added = phone.model.addMedia([MomentMedia(kind: .photo, fileName: "a.jpg"), MomentMedia(kind: .photo, fileName: "b.jpg")], to: moment.id)

        #expect(added == 1)
        let media = try #require(phone.model.currentMoment(id: moment.id)?.media)
        #expect(media.count == Moment.maxMedia)
        #expect(media.last?.fileName == "a.jpg")
        #expect(!phone.model.canAddMedia(to: try #require(phone.model.currentMoment(id: moment.id))))
        #expect(phone.model.addMedia([MomentMedia(kind: .photo, fileName: "c.jpg")], to: moment.id) == 0)
    }

    @Test func photosAddedFromDetailsAreKeptAcrossALaunch() throws {
        let phone = phone()
        let moment = try #require(phone.model.addMoment(draft("Coffee", Self.date(2026, 12, 2))))

        phone.model.addMedia([MomentMedia(kind: .photo, fileName: "latte.jpg")], to: moment.id)
        phone.relaunch()

        #expect(phone.model.currentMoment(id: moment.id)?.media == [MomentMedia(kind: .photo, fileName: "latte.jpg")])
    }

    @Test func personalMomentsStayOnThePhoneAcrossALaunchAndNeverReachTrustee() async {
        let phone = phone()
        await phone.onboard()
        let requestsBefore = phone.trusteeRequests

        let moment = phone.model.addMoment(draft("Mom's birthday", Self.date(2026, 11, 29), type: .birthday))
        phone.model.updateMoment(id: moment!.id, to: draft("Mum's birthday", Self.date(2026, 11, 29), type: .birthday))
        phone.model.addMoment(draft("Coffee", Self.date(2027, 2, 14)))
        #expect(phone.trusteeRequests == requestsBefore)

        phone.relaunch()
        #expect(Set(phone.model.moments.map(\.title)) == ["Mum's birthday", "Coffee"])
    }

    @Test func aLongAgoKhmerLunarMomentStaysWithinAMonthOfItsDateEveryYear() throws {
        let phone = phone()

        phone.model.addMoment(draft("Dad's birthday", Self.date(1958, 4, 14), lunar: true))

        let next = try #require(phone.model.upcomingMoments.first?.date)
        let solar = Self.date(2027, 4, 14)
        #expect(abs(next.timeIntervalSince(solar)) < 31 * 86_400, "\(next)")
    }

    @Test func aMomentOn29FebruaryComesBackOn1MarchInOtherYears() {
        let phone = phone()

        phone.model.addMoment(draft("Leap day wedding", Self.date(2024, 2, 29)))

        #expect(phone.model.upcomingMoments.first?.date == Self.date(2027, 3, 1))
    }

    @Test func oneMomentThisBuildCannotReadNeverCostsTheOthers() throws {
        let phone = phone()
        try Data(#"""
        {"moments":[
          {"id":"7C9A1B2E-0000-4000-8000-000000000001","type":"birthday","title":"Mom's birthday",
           "date":815000000,"repeatsOnKhmerLunarDate":false,"isShared":false},
          {"id":"not-a-uuid","type":"custom"}
        ]}
        """#.utf8).write(to: phone.phoneFile)

        phone.relaunch()

        #expect(phone.model.moments.map(\.title) == ["Mom's birthday"])
    }
}
