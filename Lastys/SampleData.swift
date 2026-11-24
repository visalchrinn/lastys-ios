import Foundation
import LastysCore

/// Phase A sample Moments shown on Home until "+ Add" arrives.
enum SampleData {
    static func moments(relativeTo today: Date = Date()) -> [Moment] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: today)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: start) ?? start }
        return [
            Moment(type: "Birthday", title: "Mom's birthday", date: day(5)),
            Moment(type: "Custom", title: "Graduation day", date: day(-156)),
            Moment(type: "Custom", title: "Ancestor ceremony", date: day(27), repeatsOnKhmerLunarDate: true),
        ]
    }
}

extension AppModel {
    /// A model for SwiftUI previews: either a phone that finished onboarding, or a new one.
    @MainActor static func preview(onboarded: Bool = true) -> AppModel {
        var phone = PhoneState()
        if onboarded {
            phone.lastysID = LastysID(personalID: "LT-8K2F-91QA")
            phone.recoveryCode = "7QX2-M4KD-9PLA-3HTV"
            phone.hasSavedRecoveryCode = true
            phone.nickname = "Srey Pich"
            phone.hasFinishedOnboarding = true
        }
        return AppModel(
            phoneKey: SoftwarePhoneKey(),
            trustee: FakeTrustee().client(forPhone: "preview"),
            store: InMemoryPhoneStore(phone),
            moments: SampleData.moments()
        )
    }
}
